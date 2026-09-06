import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config.dart';

/// Persiste el Client ID de Spotify que el usuario introduce desde la app,
/// para no tener que editar lib/config.dart a mano.
///
/// El Client ID no es un secreto (es un identificador publico), pero
/// reutilizamos el almacen seguro que ya usamos para los tokens.
class SpotifySettingsStore {
  static const _kClientId = 'spotify_client_id';

  final FlutterSecureStorage _storage;

  SpotifySettingsStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  /// Carga el Client ID guardado y lo aplica a SpotifyConfig.
  Future<void> load() async {
    final id = await _storage.read(key: _kClientId);
    if (id != null && id.trim().isNotEmpty) {
      SpotifyConfig.clientId = id.trim();
    }
  }

  Future<void> save(String clientId) async {
    final trimmed = clientId.trim();
    SpotifyConfig.clientId = trimmed;
    await _storage.write(key: _kClientId, value: trimmed);
  }

  Future<void> clear() async {
    SpotifyConfig.clientId = '';
    await _storage.delete(key: _kClientId);
  }
}
