// Increments on each completed wash so capture screens get a fresh key.

import 'package:flutter_riverpod/flutter_riverpod.dart';

final washSessionProvider = StateProvider<int>((ref) => 0);
