![Relic web server banner](https://github.com/serverpod/relic/raw/main/misc/images/github-banner.jpg)

# Relic web server

Relic is a web server based on Shelf that supports middleware. It's currently available as a tech preview to gather feedback before we release a stable version. __Beware that the API is still subject to change.__ The best way to provide your feedback is through issues on GitHub here:
[https://github.com/serverpod/relic/issues](https://github.com/serverpod/relic/issues)

This package was born out of the needs of [Serverpod](https://serverpod.dev), as we wanted a more modern and performant base for our web server. Relic is based on [Shelf](https://pub.dev/packages/shelf), but we have made several improvements:

- We removed all `List<int>` in favor of `Uint8List`.
- We made everything type-safe (no more dynamic).
- Encoding types have been moved to the `Body` of a `Request`/`Response` to simplify the logic when syncing up the headers and to have a single source of truth.
- We've added parsers and validation for all commonly used HTTP headers. E.g., times are represented by `DateTime`, cookies have their own class with validation of formatting, etc.
- Extended test coverage.
- There are lots of smaller fixes here and there.

Although the structure is very similar to Shelf, this is no longer backward compatible. We like to think that a transition would be pretty straightforward, and we are planning put a guide in place.

Before a stable release, we're also planning on adding the following features:
- We want to more tightly integrate a http server (i.e., start with `HttpServer` from `dart:io` as a base) with Relic so that everything uses the same types. This will also improve performance as fewer conversions will be needed.
- Routing can be improved by using Radix trees. Currently, there is just a list being traversed, which can be an issue if you have many routes.
- We're planning to add an improved testing framework.
- Performance testing and optimizations.

In addition, we're planning to include Relic in [Serverpod](https://serverpod.dev), both for powering our RPC and as a base for our web server. This would add support for middleware in our RPC. In our web server integration, we have support for HTML templates and routing. You also get access to the rest of the Serverpod ecosystem in terms of serialization, caching, pub-sub, and database integrations.