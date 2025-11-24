---
sidebar_position: 2
sidebar_label: 👋 Hello world
---

# Hello world

Once you have Dart installed, it only takes a few lines of code to set up your Relic server. These are the steps you need to take to get a simple _Hello world_ server up and running.

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

GITHUB_CODE_BLOCK lang="dart" doctag="hello-world-app" file="../_example/example.dart" title="Hello world server"

**What this code does:**

1. **Router and route**: `RelicApp()` configures routing and registers a `/user` route.
2. **Middleware**: `use('/', logRequests())` logs each request for all paths under `/`.
3. **Server and fallback**: `app.serve()` starts on port 8080; `fallback` handles unmatched routes and returns a 404 (not found).

The result is a server that responds with a personalized greeting when you send a GET request matching `/user/:name/age/:age`.

### Running locally

Start your server with:

```bash
dart bin/hello_world.dart
```

Then, open your browser and visit `http://localhost:8080/user/Nova/age/27`, or use curl:

```bash
curl http://localhost:8080/user/Nova/age/37
```

You should see:

```bash
Hello Nova! To think you are 27 years old.
```

Congratulations! You just ran your first Relic server.
