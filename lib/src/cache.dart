import 'package:flutter/foundation.dart';
import 'package:vector_graphics_compiler/vector_graphics_compiler.dart';

/// The cache for decoded SVGs.
class FlutterSvgCache {
  final Map<Object, Future<ByteData>> _pending = {};
  final Map<Object, ByteData> _cache = {};

  /// Maximum number of entries to store in the cache.
  int _maximumSize = 100;

  /// Retrieves the current maximum cache size.
  int get maximumSize => _maximumSize;

  /// Changes the maximum cache size.
  ///
  /// If the new size is smaller than the current number of elements, the
  /// extraneous elements are evicted immediately. Setting this to zero and then
  /// returning it to its original value will therefore immediately clear the
  /// cache.
  set maximumSize(int value) {
    assert(value >= 0);
    if (value == _maximumSize) return;

    _maximumSize = value;

    // Clear cache if the maximum size is set to zero.
    if (_maximumSize == 0) {
      clear();
    } else {
      while (_cache.length > _maximumSize) {
        _cache.remove(_cache.keys.first);
      }
    }
  }

  /// Evicts all entries from the cache.
  ///
  /// This is useful if, for instance, the root asset bundle has been updated
  /// and therefore new images must be obtained.
  void clear() {
    _cache.clear();
  }

  /// Evicts a single entry from the cache, returning true if successful.
  bool evict(Object key) {
    return _cache.remove(key) != null;
  }

  /// Evicts a single entry from the cache if the `oldData` and `newData` are
  /// incompatible.
  bool maybeEvict(Object key, SvgTheme oldData, SvgTheme newData) {
    return evict(key);
  }

  /// Returns the previously cached [ByteData] for the given key, if available;
  /// if not, calls the given callback to obtain it first. In either case, the
  /// key is moved to the "most recently used" position.
  ///
  /// The arguments must not be null. The `loader` cannot return null.
  Future<ByteData> putIfAbsent(
    Object key,
    Future<ByteData> Function() loader,
  ) {
    assert(key != null);
    assert(loader != null);

    // Return pending result if the loader is already called.
    if (_pending.containsKey(key)) {
      return _pending[key]!;
    }

    ByteData? cachedResult = _cache[key];
    if (cachedResult != null) {
      // Move the cached item to the end to mark it as recently used.
      _cache.remove(key);
      _cache[key] = cachedResult;
      return SynchronousFuture<ByteData>(cachedResult);
    }

    // Call the loader to get new data.
    Future<ByteData> futureData = loader();
    _pending[key] = futureData;

    futureData.then((ByteData data) {
      _pending.remove(key);
      _add(key, data);
    });

    return futureData;
  }

  void _add(Object key, ByteData result) {
    if (_maximumSize > 0) {
      // Remove the key if it exists to update its position.
      _cache.remove(key);

      // Evict the least recently used entry if the cache is full.
      if (_cache.length == _maximumSize) {
        _cache.remove(_cache.keys.first);
      }

      _cache[key] = result;
    }
  }

  /// The number of entries in the cache.
  int get count => _cache.length;
}
