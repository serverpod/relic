/// How many [ContextProperty] slots exist, so a request can make room for
/// all of them at once.
library;

import 'context_property.dart';

/// The number of [ContextProperty] instances created so far.
int contextSlotCount = 0;
