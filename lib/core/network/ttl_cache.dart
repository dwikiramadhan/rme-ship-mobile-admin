/// Small in-memory cache for rarely-changing master data (ports, crews,
/// regions, ...). Entries expire after [ttl]; concurrent requests for the same
/// key share one in-flight Future. Failed fetches are never cached, and
/// [shouldCache] can veto caching a result (e.g. an empty list returned by an
/// API that swallows its own errors).
class TtlCache<V> {
  TtlCache(this.ttl, {this.shouldCache});

  final Duration ttl;
  final bool Function(V value)? shouldCache;

  final Map<String, ({DateTime storedAt, V value})> _entries = {};
  final Map<String, Future<V>> _inFlight = {};

  Future<V> getOrFetch(String key, Future<V> Function() fetch) {
    final entry = _entries[key];
    if (entry != null && DateTime.now().difference(entry.storedAt) < ttl) {
      return Future.value(entry.value);
    }

    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = fetch().then((value) {
      if (shouldCache?.call(value) ?? true) {
        _entries[key] = (storedAt: DateTime.now(), value: value);
      }
      return value;
    }).whenComplete(() {
      // Block body on purpose: returning the removed Future would make
      // whenComplete wait on itself and never complete.
      _inFlight.remove(key);
    });
    _inFlight[key] = future;
    return future;
  }

  void clear() => _entries.clear();
}
