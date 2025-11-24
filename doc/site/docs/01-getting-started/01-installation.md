---
sidebar_position: 1
sidebar_label: 📦 Installation
---

# Installation

To use Relic, you must have the Dart SDK installed on your machine.

:::note
Relic requires Dart SDK 3.7 or later.
:::

If Dart is not installed, follow the official guide: [Install Dart](https://dart.dev/get-dart).

### Verify Dart installation

You can verify your Dart installation by running the following command:

```bash
dart --version
```

You should see a version compatible with the requirement above.

## Add Relic to your project

To add Relic to your project, run the following command:

```bash
dart pub add relic
```

Alternatively, add it manually to your `pubspec.yaml` file:

```yaml
dependencies:
  relic: <latest_version>
```

Then run:

```bash
dart pub get
```

## Hot reload

Relic supports hot reloading of route handlers when running with the VM service enabled. This allows you to modify your route handlers and see the changes immediately without restarting the server.

### Enabling hot reload

1. Start your server with the VM service enabled:

   ```bash
   dart run --enable-vm-service bin/example.dart
   ```

2. When you modify your route handlers, save the file and trigger a hot reload from your IDE or by sending a hot reload request to the VM service.

### How it works

- When a hot reload is triggered, `RelicApp` automatically reconfigures its internal router with the latest route definitions.
- This works for changes to route handlers and route configurations.
- Changes to server state or global variables may still require a full restart.

## Related reading

- [Relic on pub.dev](https://pub.dev/packages/relic)
- [Official Dart installation docs](https://dart.dev/get-dart)
