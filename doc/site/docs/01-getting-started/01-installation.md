---
sidebar_position: 1
---

# Installation 📦

To use Relic, you must have the Dart SDK installed on your machine.

::::note

Relic requires Dart SDK 3.5 or later

::::

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
  relic: ^0.7.0
```

Then run:

```bash
dart pub get
```

## Related reading

- [Relic on pub.dev](https://pub.dev/packages/relic)
- [Official Dart installation docs](https://dart.dev/get-dart)

---
