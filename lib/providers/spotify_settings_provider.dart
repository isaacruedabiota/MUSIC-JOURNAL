import 'package:flutter/foundation.dart';

import '../config.dart';
import '../services/spotify_settings_store.dart';

/// Estado reactivo de la configuracion de Spotify (Client ID).
/// La fuente de verdad sigue siendo SpotifyConfig.clientId; este provider
/// la envuelve para persistir y para que la UI se refresque al cambiarla.
class SpotifySettingsProvider extends ChangeNotifier {
  final SpotifySettingsStore _store;

  SpotifySettingsProvider([SpotifySettingsStore? store])
      : _store = store ?? SpotifySettingsStore();

  String get clientId => SpotifyConfig.clientId;
  bool get isConfigured => SpotifyConfig.isConfigured;

  /// Carga el Client ID guardado al arrancar la app.
  Future<void> load() async {
    await _store.load();
    notifyListeners();
  }

  Future<void> setClientId(String id) async {
    await _store.save(id);
    notifyListeners();
  }

  Future<void> clear() async {
    await _store.clear();
    notifyListeners();
  }
}
