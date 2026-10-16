/// Storage abstraction for the REST authentication token.
///
/// [RestAuthService] only writes the token returned by the backend through this
/// interface and never persists it itself. The default [InMemoryTokenStore]
/// keeps the token for the lifetime of the process; hosts that need persistence
/// can inject their own implementation (for example one backed by the platform
/// keychain) without the module depending on a storage package.
abstract class TokenStore {
  /// Stores [token], replacing any previously stored value.
  Future<void> save(String token);

  /// Returns the stored token, or `null` when none is stored.
  Future<String?> read();

  /// Removes the stored token.
  Future<void> clear();
}

/// Default [TokenStore] that keeps the token only in memory.
///
/// Nothing is written to disk and the token is lost when the process ends.
class InMemoryTokenStore implements TokenStore {
  String? _token;

  @override
  Future<void> save(String token) async {
    _token = token;
  }

  @override
  Future<String?> read() async => _token;

  @override
  Future<void> clear() async {
    _token = null;
  }
}
