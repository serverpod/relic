# relic_dst, design

Deterministic simulation testing (DST) for the adapter layer: the core's
`RelicServer`, an adapter, and HTTP clients run in one isolate under a
virtual clock, a seeded random and an in-memory network. `packages/relic_dst`
holds it. This document records the decisions. The package README says
how to use it.

## 1. Goal

Adapter behaviour that the conformance suite tests over real sockets with
real delays is timing dependent there: a 300 ms handler, a 50 ms wait for
requests to start, a 5 second drain, a CI machine twice as slow. The
simulation runs the same behaviour with no wall clock and no socket, so a
scenario lands on the exact instant it is about, a run that fails replays
from its seed, and a random workload with faults runs thousands of
exchanges in a second.

## 2. Not in scope

- More than one isolate. `noOfIsolates: n` spawns real isolates the
  simulation cannot see into.
- Running `relic_io` or `relic_native` under the simulation. The one is
  bound to `dart:io`, the other to a Zig server on its own threads. The
  adapter under simulation is `SimAdapter`, an HTTP/1.1 adapter in Dart
  that does what they do between the bytes and the core.
- TLS, HTTP/2 and HTTP/3.

## 3. Decisions

| # | Decision | Why |
|---|----------|-----|
| D1 | One `Simulation` owns the clock, the random and an event queue, and runs the body in a zone that intercepts `createTimer`, `createPeriodicTimer`, `scheduleMicrotask` and `print`. | Everything asynchronous in Dart goes through the zone, so `Future.delayed`, `Stream.timeout`, `Future.timeout` and `Timer.periodic` all become queue entries with no change to the code under test. The run is one synchronous call. |
| D2 | The zone stays in the caller's error zone. | A future's error does not cross error zones. With its own error zone the body's failure would be reported as uncaught instead of reaching `run`, and the core's `catchTopLevelErrors` would see a non-root error zone and change behaviour. |
| D3 | Time reaches the core through `package:clock`. `httpDate`, `logMessage` and `logRequests` read `clock.now()` and `clock.stopwatch()`, and the simulation installs its clock with `withClock`. | The Date header and the log lines are the core's only wall clock reads. `DateTime.now()` cannot be intercepted by a zone. The Date cache is per clock, keyed by identity, so a simulation's dates never come from the previous run's cache. |
| D4 | Microtasks run before any timer, timers in order of due time and then creation, and the clock jumps to each timer. Network deliveries are timers with a flag. | The same order Dart's event loop gives, which is what the code under test was written for. Randomness enters through the network's latencies and fragment sizes, not the scheduler. |
| D5 | The network models TCP as far as the adapters depend on it: ordered delivery per direction, pieces, a receive window that stalls the writer, FIN as a half-close, RST as a reset the peer learns of after a latency. | The adapter scenarios that matter are about these: a peer that stops reading during a hijack flood, a reset mid-request, a half-close before the response. A writer that stalls when the window is full is what makes a close "never complete" the way a socket's does. |
| D6 | The window is honoured whole-segment: nothing goes out until the window has room for a full segment or all that is left. | Without it each delivery frees a little room, the next piece fits exactly that room, and pieces shrink towards one byte, which is the silly window syndrome. The first flood scenario took two minutes of real time delivering 64 MB one byte at a time. |
| D7 | `SimAdapter` parses heads into a `ByteHeaderStore` and writes responses through `ResponseFraming` and `ResponseHead`, which moved from `relic_native` to `relic_core` for the purpose. | The simulated adapter exercises the same framing and header code as the native one, and every adapter writes the same head bytes. |
| D8 | `SimAdapter` advertises hijack and not WebSocket. | The core then does the handshake and framing itself over the hijacked channel, which puts `FramedWebSocket`, its ping timer and its close timeout under the simulation. A ping interval of 10 seconds is tested at 10 and 20 seconds exactly. |
| D9 | `ContractAdapter` wraps the adapter under test and records violations instead of throwing. | A throw inside an adapter callback would be swallowed or would end the scenario at the first breach. Recording lets the random workload run to its end and report every breach with its instant. |
| D10 | The contract allows the core a second `respond` or an `abort` after a `respond` that failed, and the adapter owes it a no-op when the exchange is over. | The core answers a failed response with a 500 through the same `respond`, which is right when the failure came before any byte went out and must be a no-op when the peer is gone. The workload with network resets found the checker stricter than the documented behaviour here. |
| D11 | `simProperty` runs a body once per seed, sequentially from `firstSeed`, and `DST_SEED` pins one seed while `DST_SEEDS` sets the count. | A failure names its seed in the output, and replaying is setting one variable. Sequential seeds make the default run the same on every machine. |
| D12 | A failing run prints the seed and the tail of the trace with `printOnFailure`. | The trace is the story of the run: connects, pieces, FINs, resets, the adapter's accepts and rejects, contract violations and every `print`. It is what a stack trace cannot say about a scenario that went wrong over simulated seconds. |

## 4. What runs under the simulation

```
 test body                   simTest / simProperty, one seed per run
   RelicServer               relic_core, unchanged
     ContractAdapter         records violations
       SimAdapter            HTTP/1.1 in Dart, timeouts as sim timers
         SimSocket  <----->  SimSocket     SimNetwork: latency, pieces,
                                           window, FIN, RST
                             SimHttpClient, SimWebSocketClient, Workload
   FramedWebSocket           relic_core, over the hijacked channel
   Body, Headers, framing    relic_core, unchanged
```

## 5. Soak properties

The random workload checks each answer as it comes, and the test holds the
server to an end state once every client is gone and the wire has settled.
The end state is where a leak shows: a connection the adapter forgot, an
exchange that never ended, a cancellation that never fired.

| Property | Checked where |
|----------|---------------|
| An `/echo` answer carries the request method, the body length and the FNV-1a hash of the body bytes. | Per response, in `Workload` |
| Every response the handler wrote has one Date, and a Content-Length or chunked coding, not both. | Per response |
| No checked response takes longer than `responseBound` (5 s) in simulated time. | Per response |
| An idle connection is closed by the server between `idleTimeout` and `idleTimeout` plus two latencies after it was accepted. | The `idleClose` action |
| A `/wait` request the client resets reaches the handler as a cancellation, once. | `onCancelled` count against `abandonedWaits` |
| After the clients are gone, `connectionsInfo` is all zeros and every exchange has ended. | `_expectSettled` |
| Completed exchanges are bounded below by the responses the clients read and above by those plus the answers no client read (`abandon`, `stopReading`). | `_expectSettled` |
| `close()` after that takes no simulated time. | The property |
| No contract violation, and no timer or event pending after close. | The property |

## 6. Found while building it

- The first flood scenario exposed the silly window syndrome in the
  network model (D6).
- The contract checker's first reading of "exactly one of respond, hijack,
  upgradeWebSocket and abort" was stricter than the core's error path
  (D10). The documentation of `AdapterExchange` describes the no-op, so
  the behaviour stands and the checker follows it.
- Two runs with one seed leave identical traces except for one thing: the
  core logs the stack trace of a handler that threw, and a stack trace
  names the line that started the run. The determinism tests start both
  runs from one call site.
- The first idle timeout check measured from the client's `socket` getter,
  which on a kept-alive connection returns at once while the server's
  idle timer has run since the last response. The check uses a fresh
  connection. The adapter was right.
