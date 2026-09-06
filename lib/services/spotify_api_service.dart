import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/track.dart';
import 'spotify_auth_service.dart';

/// Resultado de consultar "que suena ahora".
class NowPlayingResult {
  /// El track actual, o null si no hay nada sonando / es un podcast.
  final Track? track;

  /// True si Spotify respondio 204 (no hay reproduccion activa).
  final bool nothingPlaying;

  const NowPlayingResult({this.track, this.nothingPlaying = false});

  const NowPlayingResult.empty() : track = null, nothingPlaying = true;
}

/// Llama a la Web API de Spotify para leer la reproduccion actual.
/// Solo lectura: no reproduce ni descarga nada.
class SpotifyApiService {
  final SpotifyAuthService _auth;
  final http.Client _http;

  SpotifyApiService({required SpotifyAuthService auth, http.Client? httpClient})
      : _auth = auth,
        _http = httpClient ?? http.Client();

  /// GET /v1/me/player/currently-playing
  ///
  /// Devuelve:
  ///   - NowPlayingResult con track   -> hay una cancion sonando/pausada
  ///   - NowPlayingResult.empty()     -> nada sonando (HTTP 204)
  /// Lanza [SpotifyAuthException] si la sesion ya no es valida.
  Future<NowPlayingResult> getCurrentlyPlaying() async {
    final token = await _auth.getValidAccessToken();
    if (token == null) {
      throw SpotifyAuthException('Sesion no valida. Vuelve a conectar Spotify.');
    }

    final res = await _http.get(
      Uri.parse(SpotifyConfig.currentlyPlayingUrl),
      headers: {'Authorization': 'Bearer $token'},
    );

    switch (res.statusCode) {
      case 200:
        if (res.body.isEmpty) return const NowPlayingResult.empty();
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        return NowPlayingResult(track: Track.fromCurrentlyPlayingJson(json));
      case 204:
        // Nada reproduciendose en este momento.
        return const NowPlayingResult.empty();
      case 401:
        throw SpotifyAuthException('Token rechazado (401). Reconecta Spotify.');
      case 429:
        // Rate limit. El header Retry-After dice cuantos segundos esperar.
        final retry = res.headers['retry-after'] ?? '5';
        throw SpotifyRateLimitException(int.tryParse(retry) ?? 5);
      default:
        throw SpotifyApiException(
            'Error de la API (${res.statusCode}): ${res.body}');
    }
  }
}

class SpotifyApiException implements Exception {
  final String message;
  SpotifyApiException(this.message);
  @override
  String toString() => message;
}

/// Spotify pide frenar. [retryAfterSeconds] indica cuanto esperar.
class SpotifyRateLimitException implements Exception {
  final int retryAfterSeconds;
  SpotifyRateLimitException(this.retryAfterSeconds);
  @override
  String toString() => 'Rate limit: reintentar en ${retryAfterSeconds}s';
}
