# relic_headers

HTTP header names and stores, shared by Relic's server adapters and by any
package that reads or produces HTTP headers without wanting the rest of
Relic.

- `HeaderName` interns the standard header names. A known name has a stable
  small id, so a store can index it without hashing strings. `lookupBytes`
  finds a known name in a request head without allocating.
- `HeaderStore` is what a server adapter hands the framework for a request.
  It is a base class with four abstract members, so it can grow without
  breaking implementers.
- `MutableHeaderStore` is what a response is built in. Every writer rejects
  CR, LF and NUL in a value.
- `MapHeaderStore` is the plain map implementation of both.

```dart
import 'package:relic_headers/relic_headers.dart';

final headers = MapHeaderStore()
  ..set(HeaderName.contentType, ['text/plain'])
  ..add(HeaderName.custom('x-request-id'), 'abc');

print(headers.value(HeaderName.contentType)); // text/plain
```

The typed headers, their codecs and the `Headers` view live in
`relic_core`.
