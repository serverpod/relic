---
sidebar_position: 9
---

# Hot reload

Relic supports hot reloading of route handlers when running with the VM service enabled. This allows you to modify your route handlers and see the changes immediately without restarting the server.

## Enabling hot reload in your IDE

Open the settings for the Dart plugin in your IDE and make sure that _Hot Reload On Save_ is enabled. Typically, this is set to _manual_ which will trigger hot reload when you save your file.

![Hot reload on save](/img/hot-reload/plugin-settings.png)

Or, if you prefer, you can edit the `settings.json` directly:

```json
"dart.hotReloadOnSave": "manual",
```

Now, start the server in _Debug_ mode from your IDE. This will enable the VM service and your IDE will be able to connect to it.

## Enabling hot reload through the command line

1. Start your server with the VM service enabled:

   ```bash
   dart run --enable-vm-service bin/example.dart
   ```

2. Connect to the VM service using the link displayed in the terminal.

## How it works

When a hot reload is triggered, `RelicApp` rebuilds its router by replaying how it was set up. `main()` does not run again, so what applies depends on where the code lives:

- Changes inside a named handler function, such as `Response hello(Request req)`, apply on reload.
- Routes registered inside a `RouterInjectable` or a `HandlerObject` are registered again through its `injectIn`. Adding, removing or changing routes there applies, inline handlers included.
- Routes and inline handler closures written directly in `main()` stay as they were at startup. Restart the server after changing those.
- Changes to server state or global variables may still require a full restart.
