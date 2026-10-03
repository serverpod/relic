# relic_dst

Deterministic simulation testing for Relic adapters. Internal to the
repository, not published.

A test here runs a `RelicServer`, an adapter and any number of HTTP
clients inside one isolate with no socket, no wall clock and no thread.
Time is a virtual clock that only moves when nothing is left to run at the
current instant. Chance is a `Random` seeded once. Bytes travel over an
in-memory network with latency, fragmentation, flow control, half-close
and resets drawn from that random. A scenario about a 60 second idle
timeout runs in a millisecond and lands on the exact instant, and a run
that fails reproduces from its seed.

```dart
simTest(
  'Given a server with a 10 second header timeout, '
  'when a client sends half a head and waits, '
  'then it gets 408 exactly 10 seconds after the first byte.',
  (final sim) async {
    final network = SimNetwork(sim, options: NetworkOptions.quiet);
    final adapter = SimAdapter.bind(network);
    final server = RelicServer(() => ContractAdapter(adapter, sim));
    await server.mountAndStart((final _) => Response.ok());
    final client = SimHttpClient(network, adapter.port);

    await client.writeText('GET / HTTP/1.1\r\nhost: ');
    final sent = sim.elapsed;
    final response = await client.read();

    expect(response.statusCode, 408);
    expect(sim.elapsed - sent, const Duration(seconds: 10));
  },
);
```

## Parts

- `Simulation`: the run. A zone intercepts timers and microtasks, and
  `package:clock` carries the virtual clock to `clock.now()`, so
  `Future.delayed`, `Stream.timeout`, `Timer.periodic` and the Date header
  all follow it. `run` drives the body to completion in one synchronous
  call and throws `SimulationStalled` when nothing could ever complete it.
  Everything that happens goes into a bounded trace.
- `SimNetwork`, `SimListener`, `SimSocket`: loopback TCP as a model.
  Writes become pieces delivered in order after a random latency. A reader
  that stops taking bytes fills its receive window and stalls the writer,
  so a close to a peer that stopped reading never completes, as on a real
  socket. `destroy` resets, and the peer's stream fails with
  `SimConnectionReset`.
- `SimAdapter`: an HTTP/1.1 `Adapter` in Dart over that network. Head
  parsing into a `ByteHeaderStore`, inline and streamed bodies, chunked
  coding both ways, keep-alive, pipelining, idle, header and body timeouts,
  hijack, abort, cancellation on reset, and a graceful close that drains
  within `drainTimeout`. It advertises hijack and not WebSocket, so the
  core's `FramedWebSocket` runs under the simulation too.
- `SimHttpClient`, `SimWebSocketClient`: clients that write bytes and parse
  what comes back, with raw writes for requests the server should refuse.
- `ContractAdapter`: wraps the adapter under test and records every breach
  of the contract in `Adapter` and `AdapterExchange`, from either side,
  without throwing. A scenario runs to its end and reports them all.
- `Workload`: random client sessions against `workloadHandler`, whose
  routes have predictable answers. Plain, pipelined, chunked and large
  uploads, slow and streamed responses, errors, garbage, slowloris,
  abandoned requests, half-close, WebSocket, hijack, a peer that stops
  reading, a reset mid-body, an idle connection and a reset `/wait`.
  Every response the handler wrote is checked for its body, by length and
  hash, for one Date header, for a length or a coding and not both, and
  against a response time bound.
- `simTest`, `simProperty`: a test that runs inside a simulation, and one
  that runs its body once per seed. A failure prints the seed and the tail
  of the trace. `DST_SEED=n` replays one seed, `DST_SEEDS=n` sets how many
  a property runs.

## What the soak asserts

The workload property in `test/workload_test.dart` runs the sessions,
waits a second of simulated time for the last bytes to land, and then
holds the server to its end state before it is closed:

- `connectionsInfo` is all zeros: every client is gone, so every
  connection is.
- Every exchange the contract saw has ended.
- The handler saw exactly as many cancellations as clients reset a `/wait`.
- The exchanges that completed are at least the responses the clients
  read, and at most those plus the requests whose answer no client read.
- `close()` then takes no simulated time, since nothing is left to drain.
- No contract violation, and no timer or event left in the simulation.

## Replaying a failure

```
DST_SEED=17 dart test test/workload_test.dart
```

The seed names the whole run: the workload's choices, the network's
latencies and fragment sizes, and the order everything happened in. Two
runs with one seed leave the same trace, and a test checks that they do.

## What is not simulated

Isolates. A `RelicServer` with `noOfIsolates` above one spawns real
isolates, which the simulation cannot see into. The real adapters are not
under the simulation either: `relic_io` is bound to `dart:io` sockets and
`relic_native` to its Zig server. What runs here is everything above the
bytes, which is the same core, the same framer, the same bodies and the
same contract they are held to by the conformance suite in `test_utils`.
