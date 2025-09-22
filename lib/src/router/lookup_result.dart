import 'method.dart';
import 'normalized_path.dart';
import 'path_trie.dart';

sealed class LookupResult<T> {
  const LookupResult();
}

sealed class Miss<T> extends LookupResult<T> {
  const Miss();
}

final class PathMiss<T> extends Miss<T> {
  final NormalizedPath path;

  const PathMiss(this.path);
}

final class MethodMiss<T> extends Miss<T> {
  final Set<Method> allowed;

  const MethodMiss(this.allowed);
}

final class RouterMatch<T> extends TrieMatch<T> implements LookupResult<T> {
  RouterMatch(super.value, super.parameters, super.matched, super.remaining);
}

extension LookupResultExtension<T> on LookupResult<T> {
  TrieMatch<T> get asMatch => this as RouterMatch<T>;
}
