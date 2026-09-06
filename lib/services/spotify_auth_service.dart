import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:http/http.dart' as http;

import '../config.dart';
import 'token_storage.dart';

/// Errores de autenticacion legibles para la UI.
class SpotifyAuthException implements Exception {
  final String message;
  SpotifyAuthException(this.message);
  @override
  String toString() => message;
}

/// Gestiona el login con Spotify usando Authorization Code + PKCE
/// y el refresco de tokens. No guarda ningun secreto en la app.
class SpotifyAuthService {
  final TokenStorage _tokens;
  final http.Client _http;

  SpotifyAuthService({TokenStorage? tokens, http.Client? httpClient})
      : _tokens = tokens ?? TokenStorage(),
        _http = httpClient ?? http.Client();

  /// Lanza el flujo de login: abre el navegador seguro, el usuario autoriza,
  /// y volvemos con los tokens ya guardados. Lanza [SpotifyAuthException] si falla.
  Future<void> signIn() async {
    if (!SpotifyConfig.isConfigured) {
      throw SpotifyAuthException(
          'Falta tu Client ID de Spotify. Editalo en lib/config.dart.');
    }

    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _codeChallengeFromVerifier(codeVerifier);

    final authUrl = Uri.parse(SpotifyConfig.authorizeUrl).replace(
      queryParameters: {
        'client_id': SpotifyConfig.clientId,
        'response_type': 'code',
        'redirect_uri': SpotifyConfig.redirectUri,
        'code_challenge_method': 'S256',
        'code_challenge': codeChallenge,
        'scope': SpotifyConfig.scopes.join(' '),
      },
    );

    final String result;
    try {
      result = await FlutterWebAuth2.authenticate(
        url: authUrl.toString(),
        callbackUrlScheme: SpotifyConfig.callbackScheme,
      );
    } catch (e) {
      throw SpotifyAuthException('Login cancelado o fallido: $e');
    }

    final returnedUri = Uri.parse(result);
    final error = returnedUri.queryParameters['error'];
    if (error != null) {
      throw SpotifyAuthException('Spotify devolvio un error: $error');
    }
    final code = returnedUri.queryParameters['code'];
    if (code == null) {
      throw SpotifyAuthException('No se recibio el codigo de autorizacion.');
    }

    await _exchangeCodeForTokens(code: code, codeVerifier: codeVerifier);
  }

  Future<void> _exchangeCodeForTokens({
    required String code,
    required String codeVerifier,
  }) async {
    final res = await _http.post(
      Uri.parse(SpotifyConfig.tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': SpotifyConfig.redirectUri,
        'client_id': SpotifyConfig.clientId,
        'code_verifier': codeVerifier,
      },
    );

    if (res.statusCode != 200) {
      throw SpotifyAuthException(
          'Fallo al canjear el codigo (${res.statusCode}): ${res.body}');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    await _tokens.save(
      accessToken: data['access_token'] as String,
      refreshToken: data['refresh_token'] as String,
      expiry: _expiryFrom(data['expires_in'] as int),
    );
  }

  /// Devuelve un access token valido, refrescandolo si esta a punto de caducar.
  /// Devuelve null si no hay sesion (el usuario debe hacer login).
  Future<String?> getValidAccessToken() async {
    final refresh = await _tokens.refreshToken;
    if (refresh == null) return null;

    final expiry = await _tokens.expiry;
    final token = await _tokens.accessToken;

    // Margen de 60s para no usar un token que caduca en mitad de la llamada.
    final soon = DateTime.now().add(const Duration(seconds: 60));
    if (token != null && expiry != null && expiry.isAfter(soon)) {
      return token;
    }
    return _refreshAccessToken(refresh);
  }

  Future<String?> _refreshAccessToken(String refreshToken) async {
    final res = await _http.post(
      Uri.parse(SpotifyConfig.tokenUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'grant_type': 'refresh_token',
        'refresh_token': refreshToken,
        'client_id': SpotifyConfig.clientId,
      },
    );

    if (res.statusCode != 200) {
      // Refresh invalido (revocado/expirado): forzamos re-login.
      await _tokens.clear();
      return null;
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final newAccess = data['access_token'] as String;
    await _tokens.updateAccessToken(
      accessToken: newAccess,
      expiry: _expiryFrom(data['expires_in'] as int),
      refreshToken: data['refresh_token'] as String?, // a veces viene, a veces no
    );
    return newAccess;
  }

  Future<bool> get isSignedIn => _tokens.hasSession;

  Future<void> signOut() => _tokens.clear();

  DateTime _expiryFrom(int expiresInSeconds) =>
      DateTime.now().add(Duration(seconds: expiresInSeconds));

  // --- PKCE helpers ---

  /// code_verifier: cadena aleatoria de 64 chars del alfabeto permitido.
  String _generateCodeVerifier() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~';
    final rand = Random.secure();
    return List.generate(64, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// code_challenge = base64url( SHA256(code_verifier) ), sin padding.
  String _codeChallengeFromVerifier(String verifier) {
    final digest = sha256.convert(utf8.encode(verifier));
    return base64UrlEncode(digest.bytes).replaceAll('=', '');
  }
}
