/// Configuracion de la integracion con Spotify.
///
/// PASOS PARA RELLENAR ESTO (una sola vez):
/// 1. Entra en https://developer.spotify.com/dashboard e inicia sesion.
/// 2. Pulsa "Create app". Pon cualquier nombre/descripcion.
/// 3. En "Redirect URIs" añade EXACTAMENTE:  musicjournal://callback
/// 4. En "Which API/SDKs..." marca "Web API".
/// 5. Guarda. Copia el "Client ID" y pegalo abajo en [spotifyClientId].
///
/// NO hace falta el Client Secret: usamos el flujo Authorization Code + PKCE,
/// que es el recomendado para apps moviles (no guarda secretos en el binario).
class SpotifyConfig {
  /// Valor por defecto en codigo (opcional). Lo normal ahora es configurarlo
  /// DESDE LA APP (pantalla de Ajustes), no tocando este archivo.
  static const String _compiledClientId = 'PON_AQUI_TU_CLIENT_ID';

  /// Client ID puesto en tiempo de ejecucion (desde Ajustes). Tiene prioridad.
  static String _runtimeClientId = '';

  /// Client ID efectivo: el de runtime si existe, si no el compilado.
  static String get clientId =>
      _runtimeClientId.isNotEmpty ? _runtimeClientId : _compiledClientId;

  /// Lo fija la pantalla de Ajustes (via SpotifySettingsStore).
  static set clientId(String value) => _runtimeClientId = value.trim();

  /// Debe coincidir EXACTAMENTE con el Redirect URI del dashboard
  /// y con el scheme configurado en Android/iOS.
  static const String redirectUri = 'musicjournal://callback';

  /// Solo el scheme (sin "://callback"). Lo usa flutter_web_auth_2.
  static const String callbackScheme = 'musicjournal';

  /// Permisos que pedimos. Solo lectura de reproduccion: no modificamos nada.
  ///   - user-read-currently-playing: la cancion que suena ahora
  ///   - user-read-playback-state: estado del reproductor (dispositivo, play/pausa)
  static const List<String> scopes = [
    'user-read-currently-playing',
    'user-read-playback-state',
  ];

  /// Dashboard donde el usuario crea su app y saca el Client ID.
  static const String dashboardUrl = 'https://developer.spotify.com/dashboard';

  // --- Endpoints oficiales de Spotify (no tocar) ---
  static const String authorizeUrl = 'https://accounts.spotify.com/authorize';
  static const String tokenUrl = 'https://accounts.spotify.com/api/token';
  static const String currentlyPlayingUrl =
      'https://api.spotify.com/v1/me/player/currently-playing';

  /// Cada cuanto consultamos la cancion actual mientras la app esta en primer plano.
  static const Duration pollInterval = Duration(seconds: 5);

  /// True cuando el usuario todavia no ha pegado su Client ID.
  static bool get isConfigured => clientId != 'PON_AQUI_TU_CLIENT_ID' && clientId.isNotEmpty;
}
