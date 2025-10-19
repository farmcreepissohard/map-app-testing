import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

class CounterNotifier extends AsyncNotifier<int> {
  @override
  FutureOr<int> build() async {
    return 0;
  }

  Future<void> increment() async {
    state = const AsyncLoading();

    int x = state.value!;

    state = AsyncData(x + 1);
  }

  Future<void> decrement() async {
    state = const AsyncLoading();

    int x = state.value!;

    state = AsyncData(x - 1);
  }
}

final counterProvider = AsyncNotifierProvider<CounterNotifier, int>(
  CounterNotifier.new,
);
