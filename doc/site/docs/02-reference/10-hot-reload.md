---
sidebar_position: 10
---

# Hot reload

Changing a server usually means stopping it, starting it again, and repeating the request that showed the problem. The Dart VM can do better. With its service enabled, it can load changed code into the running program, which is called a hot reload. `RelicApp` listens for reloads and rebuilds its router when one happens, so most changes to handlers apply the moment you save.

## Turning it on

In your IDE, open the settings of the Dart plugin and make sure that _Hot Reload On Save_ is enabled. The usual value is _manual_, which reloads when you save a file yourself:

![Hot reload on save](/img/hot-reload/plugin-settings.png)

In `settings.json`, the same setting reads:

```json
"dart.hotReloadOnSave": "manual",
```

Then start the server in _Debug_ mode from the IDE, which enables the VM service and connects the IDE to it.

From the command line, start the server with the VM service enabled:

```bash
dart run --enable-vm-service bin/hello_world.dart
```

The VM prints the address of its service, and a reload is triggered from an IDE or another tool connected to that address.

## What a reload changes

A reload replaces the code of the program, but it does not run `main` again, and objects created before the reload stay as they were. Where a piece of code lives therefore decides whether a reload changes it. This program has three handlers in three different places:

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/hot_reload.dart" doctag="hot-reload-named" title="A named handler"

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/hot_reload.dart" doctag="hot-reload-injectable" title="Routes in a RouterInjectable"

GITHUB_CODE_BLOCK lang="dart" file="../_example/basic/hot_reload.dart" doctag="hot-reload-app" title="The app"

Start it with the VM service, and request each route:

```text
/hello        Hello, version 1
/inline       Inline, version 1
/api/status   Status, version 1
/api/version  404 Not Found
/new          404 Not Found
```

Now edit the program. Change every `version 1` to `version 2`, add a route for `/api/version` inside `injectIn`, and add a route for `/new` to the app in `main`. Save, let the reload happen, and request the same routes again:

```text
/hello        Hello, version 2
/inline       Inline, version 1
/api/status   Status, version 2
/api/version  Version 2
/new          404 Not Found
```

Each line has its own explanation. `hello` is a named function, the router holds the function itself, and the reload replaced its code. The inline handler for `/inline` is a closure that was created when `main` ran, and the router still holds that closure. Whether a reload changes the code of a closure that already exists is up to the Dart VM, and in this run, on Dart 3.13, it did not, so the handler still says version 1. Do not count on that one way or the other. `RelicApp` keeps the `ApiRoutes` object and calls its `injectIn` again on every reload, so the new code there ran, with its changed handler and its new route. The route for `/new` was added in `main`, which did not run again, so the router never heard of it.

That suggests how to arrange a program you are working on. Put handler code in named functions, and put routes you are still changing inside a `RouterInjectable`, registered with `inject`. A `HandlerObject` is a `RouterInjectable` too, which registers itself. Restart the server after changing the route list in `main`, after changing middleware that a factory function built at startup, as the [Middleware](./08-middleware.md#which-form-to-choose) page describes, and after changing global state.

## Examples & further reading

### Examples

- **[Hot reload example](https://github.com/serverpod/relic/blob/main/packages/examples/basic/hot_reload.dart)** - The program behind this page.
