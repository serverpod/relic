---
sidebar_position: 9
---

# Hot reload

Relic supports hot reloading of route handlers when running with the VM service enabled. This allows you to modify your route handlers and see the changes immediately without restarting the server.

## Enabling hot reload in your IDE

Open the settings for the Dart plugin in your IDE and and make sure that _Hot Reload On Save_ is enabled. Typically, this is set to _manual_ which will trigger hot reload when you save your file.

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

- When a hot reload is triggered, `RelicApp` automatically reconfigures its internal router with the latest route definitions.
- This works for changes to route handlers and route configurations.
- Changes to server state or global variables may still require a full restart.
