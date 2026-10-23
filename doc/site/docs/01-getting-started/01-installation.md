---
sidebar_position: 1
sidebar_label: 📦 Installation
---

# Installation

Relic is a Dart package, so all it needs is the Dart SDK, version 3.10 or later. If you do not have Dart yet, follow the official guide, [Get the Dart SDK](https://dart.dev/get-dart). Then check which version you have:

```bash
dart --version
```

```text
Dart SDK version: 3.13.5 (stable) (Tue Sep 29 01:00:52 2026 -0700) on "macos_x64"
```

Any version from 3.10 on will do.

## Adding Relic to a project

In the directory of your Dart project, add the package:

```bash
dart pub add relic
```

That adds the latest stable release to the `dependencies` in `pubspec.yaml`, and fetches it. You can also add the line to `pubspec.yaml` yourself, and run `dart pub get`.

These pages describe the coming release of Relic, 2.0, and a few of the features they show are not in a published version yet. To try the latest prerelease instead of the stable release, give the version explicitly:

```bash
dart pub add 'relic:^2.0.0-rc.2'
```

The [Hello world](./02-hello-world-example.md) page continues from here, with a new project and a first server.

## Related reading

- [Relic on pub.dev](https://pub.dev/packages/relic)
- [Official Dart installation docs](https://dart.dev/get-dart)
