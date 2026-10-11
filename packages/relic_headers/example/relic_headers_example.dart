// ignore_for_file: avoid_print
// A package that depends on relic_headers alone can build a response store
// and read any HeaderStore through the base class.
import 'package:relic_headers/relic_headers.dart';

void main() {
  final response = MapHeaderStore()
    ..set(HeaderName.contentType, ['text/plain; charset=utf-8'])
    ..add(HeaderName.setCookie, 'a=1')
    ..add(HeaderName.setCookie, 'b=2');

  print(response.value(HeaderName.contentType));
  print(response.values(HeaderName.setCookie).join(' | '));

  // Adapters hand over whatever store they have. Read it through the base
  // class without caring which one.
  describe(response);
  describe(_FixedStore());
}

void describe(HeaderStore store) {
  store.forEach((name, value) => print('$name: $value'));
}

/// A store over something that is not a map, to show the two members an
/// implementer provides.
final class _FixedStore extends HeaderStore {
  @override
  Iterable<HeaderName> get names => const [HeaderName.server];

  @override
  Iterable<String> values(HeaderName name) =>
      name == HeaderName.server ? const ['fixed/1.0'] : const [];
}
