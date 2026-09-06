import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Guarda los tokens de Spotify en el almacen seguro del sistema
/// (Keychain en iOS, EncryptedSharedPreferences/Keystore en Android).
/// Nunca en texto plano.
class TokenStorage {
  static const _kAccessToken = 'spotify_access_token';
  static const _kRefreshToken = 'spotify_refresh_token';
  static const _kExpiry = 'spotify_expiry_epoch_ms';

  final FlutterSecureStorage _storage;

  TokenStorage([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    required DateTime expiry,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(key: _kRefreshToken, value: refreshToken);
    await _storage.write(
        key: _kExpiry, value: expiry.millisecondsSinceEpoch.toString());
  }

  /// Actualiza solo el access token y su expiracion (tras un refresh).
  /// Spotify a veces NO devuelve un refresh_token nuevo, por eso va aparte.
  Future<void> updateAccessToken({
    required String accessToken,
    required DateTime expiry,
    String? refreshToken,
  }) async {
    await _storage.write(key: _kAccessToken, value: accessToken);
    await _storage.write(
        key: _kExpiry, value: expiry.millisecondsSinceEpoch.toString());
    if (refreshToken != null && refreshToken.isNotEmpty) {
      await _storage.write(key: _kRefreshToken, value: refreshToken);
    }
  }

  Future<String?> get accessToken => _storage.read(key: _kAccessToken);
  Future<String?> get refreshToken => _storage.read(key: _kRefreshToken);

  Future<DateTime?> get expiry async {
    final raw = await _storage.read(key: _kExpiry);
    if (raw == null) return null;
    final ms = int.tryParse(raw);
    if (ms == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  Future<bool> get hasSession async => (await refreshToken) != null;

  Future<void> clear() async {
    await _storage.delete(key: _kAccessToken);
    await _storage.delete(key: _kRefreshToken);
    await _storage.delete(key: _kExpiry);
  }
}
