---
sidebar_position: 2
sidebar_label: 👋 Hello world
---

# Hello world

Once you have Dart installed, it only takes a few lines of code to set up your Relic server. These are the steps you need to take to get a simple "Hello world" server up and running.

## Create a Dart package

First, you need to create a new Dart package for your Relic server.

```bash
dart create -t console-full hello_world
```

## Add the Relic dependency

Next, add the `relic` package as a dependency to your `pubspec.yaml` file.

```bash
cd hello_world
dart pub add relic
```

## Edit the main file

Edit the `bin/hello_world.dart`:

```dart reference title="hello_world.dart"
https://github.com/serverpod/relic/blob/main/example/example.dart
```

**What this code does:**

1. **Router**: `RelicApp()` is used to configure routing for the server.
2. **Route**: `.get('/', ...)` handles GET requests to `/` and responds with "Hello, Relic!".
3. **Server**: `app.serve()` binds the router (as a handler) to port 8080 on all network interfaces.
4. **Logging**: The server logs to the console when started.

The result is a server that responds with "Hello, Relic!" when you send a GET request to `http://localhost:8080/`.

### Running locally

First, make sure you have Relic installed by following the [installation guide](/getting-started/installation).

Start your server with:

```bash
dart run bin/hello_world.dart
```

Then, open your browser and visit `http://localhost:8080/`, or use curl:

```bash
curl http://localhost:8080/
```

You should see:

```bash
Hello, Relic!
```

Congratulations! You just ran your first Relic server.
