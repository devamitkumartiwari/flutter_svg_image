import 'dart:async';
import 'package:flutter/foundation.dart' as foundation;

/// A test-specific compute implementation that avoids isolates in debug mode
/// or during automated tests, and executes the callback synchronously.
Future<R> _testCompute<Q, R>(
  foundation.ComputeCallback<Q, R> callback,
  Q message, {
  String? debugLabel,
}) {
  // In debug mode, check if we are in an automated test environment.
  if (foundation.kDebugMode) {
    final bindingType = foundation.BindingBase.debugBindingType();
    // You can add custom logic inside this block if needed for tests.
    if (bindingType.toString() == 'AutomatedTestWidgetsFlutterBinding') {
      // No-op, but you can add custom logging or test-specific behavior here.
    }
  }

  // Execute the callback either synchronously or asynchronously, depending on its nature.
  final result = callback(message);
  // Return immediately if it's already a Future, otherwise wrap in SynchronousFuture.
  return result is Future<R> ? result : foundation.SynchronousFuture<R>(result);
}

/// A compute implementation that does not spawn isolates in debug mode, web, or tests.
/// Uses the standard `compute` function in release mode.
const foundation.ComputeImpl compute =
    (foundation.kDebugMode || foundation.kIsWeb)
        ? _testCompute
        : foundation.compute;
