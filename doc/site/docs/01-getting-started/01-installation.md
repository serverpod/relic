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

## Reading the code on these pages

Every code block on these pages is cut from a complete program in the [examples](https://github.com/serverpod/relic/tree/main/packages/examples) directory of the Relic repository, and each page links the program behind it under Related reading. A few things hold for all of them:

- Most blocks show a part of a program without its imports. Each program imports `package:relic/relic.dart`, and `dart:io` or `dart:convert` where it uses them.
- The programs start their server with `app.serve()` and no arguments, so they listen on port 8080. The output shown after a block is what `curl -i http://localhost:8080/...` printed.
- The code uses dot shorthands, which Dart 3.10 added. A leading dot stands for the type expected in that position, so in a handler declared to return `Response`, `.ok(body: .fromString('pong\n'))` means `Response.ok(body: Body.fromString('pong\n'))`. A project whose `pubspec.yaml` declares `sdk: ^3.10.0` or later can use them.
- A few programs read files from the directory they live in, and their pages say where to run them from.

The [Hello world](./02-hello-world-example.md) page continues from here, with a new project and a first server.

## Related reading

- [Relic on pub.dev](https://pub.dev/packages/relic)
- [Official Dart installation docs](https://dart.dev/get-dart)
