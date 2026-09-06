import 'dart:async';

import 'package:flutter/foundation.dart';

import '../config.dart';
import '../models/track.dart';
import '../services/spotify_api_service.dart';
import '../services/spotify_auth_service.dart';

enum SpotifyConnectionState { unknown, disconnected, connected }

/// Estado central de "que suena ahora". Hace polling a Spotify mientras
/// la app esta en primer plano y notifica a la UI de los cambios.
///
/// Cuando detecta una cancion NUEVA (distinta de la anterior) llama a
/// [onNewTrack]: ese sera el enganche para el diario/historial y para la
/// deduplicacion ("¿ya la tengo?"). De momento solo lo dejamos preparado.
class NowPlayingProvider extends ChangeNotifier {
  final SpotifyAuthService _auth;
  final SpotifyApiService _api;

  NowPlayingProvider({
    required SpotifyAuthService auth,
    required SpotifyApiService api,
  })  : _auth = auth,
        _api = api;

  SpotifyConnectionState _connection = SpotifyConnectionState.unknown;
  SpotifyConnectionState get connection => _connection;

  Track? _current;
  Track? get current => _current;

  bool _isPolling = false;
  bool get isPolling => _isPolling;

  String? _error;
  String? get error => _error;

  bool _busy = false;
  bool get busy => _busy;

  Timer? _timer;

  /// Se dispara una vez por cada cancion nueva detectada.
  /// Aqui conectaremos el guardado en el historial mas adelante.
  void Function(Track track)? onNewTrack;

  /// Llamar al arrancar la app: comprueba si ya hay sesion guardada.
  Future<void> init() async {
    _connection = (await _auth.isSignedIn)
        ? SpotifyConnectionState.connected
        : SpotifyConnectionState.disconnected;
    notifyListeners();
    if (_connection == SpotifyConnectionState.connected) {
      startPolling();
    }
  }

  /// Lanza el login con Spotify y empieza a escuchar.
  Future<void> connect() async {
    _busy = true;
    _error = null;
    notifyListeners();
    try {
      await _auth.signIn();
      _connection = SpotifyConnectionState.connected;
      startPolling();
    } on SpotifyAuthException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'No se pudo conectar: $e';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    stopPolling();
    await _auth.signOut();
    _connection = SpotifyConnectionState.disconnected;
    _current = null;
    _error = null;
    notifyListeners();
  }

  void startPolling() {
    if (_isPolling) return;
    _isPolling = true;
    notifyListeners();
    _tick(); // primera lectura inmediata
    _timer = Timer.periodic(SpotifyConfig.pollInterval, (_) => _tick());
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
    _isPolling = false;
    notifyListeners();
  }

  Future<void> _tick() async {
    try {
      final result = await _api.getCurrentlyPlaying();
      _error = null;

      final newTrack = result.track;
      final changed = newTrack != null &&
          (_current == null || newTrack.dedupeKey != _current!.dedupeKey);

      _current = newTrack;
      if (changed) {
        onNewTrack?.call(newTrack);
      }
      notifyListeners();
    } on SpotifyRateLimitException catch (e) {
      // Respetamos el backoff que pide Spotify: pausamos y reanudamos.
      stopPolling();
      Timer(Duration(seconds: e.retryAfterSeconds + 1), () {
        if (_connection == SpotifyConnectionState.connected) startPolling();
      });
    } on SpotifyAuthException catch (e) {
      // La sesion murio: paramos y pedimos reconexion.
      stopPolling();
      _connection = SpotifyConnectionState.disconnected;
      _error = e.message;
      notifyListeners();
    } catch (e) {
      _error = 'Error leyendo la reproduccion: $e';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
