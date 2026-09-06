# Music Journal

App multiplataforma (iOS + Android, Flutter) que **detecta la música que escuchas**,
la **registra** y te deja **guardarla/comprarla por vías legales**.

> **Enfoque legal:** esta app NO descarga audio con copyright de fuentes no
> autorizadas. Usa la API oficial de Spotify (solo lectura) para saber qué suena,
> y para "tener música offline" se apoya en el offline de Spotify/Apple Music
> Premium y en descargas de fuentes con licencia (Bandcamp, Creative Commons, etc.).

## Estado actual

✅ **Módulo 1 — Captura de Spotify (OAuth + Web API)** — funciona en iOS y Android.
✅ **Módulo 2 — Diario + Estadísticas** — cada canción detectada se guarda en
   SQLite; pantallas de historial y de estadísticas (KPIs, top artistas/canciones,
   escuchas por hora). Navegación por pestañas: Ahora / Diario / Stats.
✅ **Módulo 3 — Notification Listener (Android)** — detecta la música de
   CUALQUIER app (YouTube Music, SoundCloud, etc.) vía `MediaSessionManager` +
   `NotificationListenerService` (código Kotlin nativo). Deduplicación entre
   fuentes para no contar dos veces la misma canción. Solo Android.
✅ **Módulo 4 — Biblioteca offline legal** — pestaña "Offline": busca música
   en el **Internet Archive** (filtra por licencia CC / dominio público),
   descarga al dispositivo con barra de progreso y la reproduce **sin conexión**
   (audioplayers). Los archivos viven en el almacenamiento privado de la app.
✅ **Módulo 5 — Wishlist (puente legal)** — en el "Diario", pestaña "Deseos":
   marca canciones que quieres conseguir y ábrelas en **Spotify / Bandcamp /
   Apple Music / YouTube Music** para comprarlas o añadirlas a tu biblioteca.
   Es el puente "lo que escucho → tenerlo", por la vía legal (sin descargar
   audio con copyright).
✅ **Conexión de Spotify in-app** — el Client ID se introduce desde la pantalla
   de ajustes (no hace falta tocar código).

Pendiente (siguientes módulos):
- ShazamKit (iOS) para reconocer por micrófono

## Configuración de Spotify (una sola vez)

Lo más fácil: **desde la app**. Abre la pestaña "Ahora" → **Configurar Spotify**
(o el icono ⚙️), y sigue los pasos en pantalla (abre el dashboard, copia el
Redirect URI, pega tu Client ID y guarda). El Client ID se guarda en el
almacén seguro del dispositivo; no hace falta tocar código.

Los pasos, en detalle:

1. Entra en https://developer.spotify.com/dashboard e inicia sesión.
2. **Create app**. Pon cualquier nombre y descripción.
3. En **Redirect URIs** añade EXACTAMENTE: `musicjournal://callback`
4. En **Which API/SDKs are you planning to use?** marca **Web API**.
5. Guarda. Copia el **Client ID** y pégalo en la pantalla de ajustes de la app.

No necesitas el Client Secret: usamos **Authorization Code + PKCE**, el flujo
recomendado para apps móviles (no guarda secretos en el binario).

> Alternativa para devs: también puedes fijar un Client ID por defecto en
> [`lib/config.dart`](lib/config.dart) (`_compiledClientId`), pero el valor
> introducido desde la app tiene prioridad.

## Ejecutar

```bash
flutter pub get
flutter run          # con un emulador/dispositivo conectado
flutter test         # tests del modelo Track
flutter analyze      # análisis estático
```

## Arquitectura

```
lib/
├── config.dart                        # Client ID, redirect URI, scopes, endpoints
├── main.dart                          # Wiring: Auth->Api->NowPlaying; Repo->History; onNewTrack->record
├── models/
│   ├── track.dart                     # Track + parseo de currently-playing + dedupe (ISRC)
│   ├── listening_entry.dart           # Evento de escucha (fila de la DB)
│   └── listening_stats.dart           # Cálculo PURO de estadísticas (testeable)
├── data/
│   └── listening_repository.dart      # Persistencia SQLite (abstracta + impl sqflite)
├── services/
│   ├── token_storage.dart             # Tokens en almacén seguro (Keychain/Keystore)
│   ├── spotify_auth_service.dart      # OAuth PKCE + refresh de tokens
│   ├── spotify_api_service.dart       # GET /me/player/currently-playing
│   └── system_media_service.dart      # Puente con los channels nativos de Android
├── providers/
│   ├── now_playing_provider.dart      # Estado + bucle de polling (5s) + onNewTrack
│   ├── system_media_provider.dart     # Deteccion de otras apps (Android, onNewTrack)
│   └── history_provider.dart          # Historial + stats + dedupe entre fuentes
└── screens/
    ├── main_scaffold.dart             # Navegación por pestañas (Ahora/Diario/Stats)
    ├── home_screen.dart               # Conectar Spotify + tarjeta "sonando ahora"
    ├── history_screen.dart            # Diario cronológico agrupado por día
    └── stats_screen.dart              # KPIs + top artistas/canciones + escuchas por hora
```

Código nativo Android (Kotlin) del Módulo 3:

```
android/app/src/main/kotlin/.../
├── MainActivity.kt                          # MethodChannel + EventChannel
├── MediaListener.kt                         # MediaSessionManager -> metadatos
└── NowPlayingNotificationListenerService.kt # Servicio que habilita el permiso
```

**Flujo de datos:** dos fuentes detectan canciones → cada una dispara `onNewTrack`
→ `HistoryProvider.record` la persiste en SQLite → el diario y las estadísticas se
recalculan.
- **Fuente A (Spotify, iOS+Android):** `SpotifyApiService` (polling Web API).
- **Fuente B (cualquier app, solo Android):** `SystemMediaService` (channels nativos).
- `HistoryProvider.record` deduplica entre fuentes con `isDuplicatePlay` (misma
  canción dentro de 30s = una sola escucha). La dedup de "¿ya la tengo?" usa
  `Track.dedupeKey` (ISRC, con fallback a título+artista).

## Tests

- `test/track_test.dart` — parseo del JSON de Spotify y deduplicación.
- `test/stats_test.dart` — cálculo de estadísticas (lógica pura, sin DB).
- `test/dedup_test.dart` — deduplicación entre fuentes (ventana temporal).

21 tests en total. `flutter test` para correrlos.

## Notas de plataforma

- **Android:**
  - Callback OAuth vía `CallbackActivity` (scheme `musicjournal`). Permiso `INTERNET`.
  - Módulo 3 requiere que el usuario conceda **"Acceso a notificaciones"** en
    Ajustes (la app abre esa pantalla desde la tarjeta "Otras apps de música").
    Sin ese permiso, solo funciona la detección de Spotify.
- **iOS:** usa `ASWebAuthenticationSession` (requiere iOS 13+, ya configurado).
  El build de iOS requiere un Mac con Xcode. La detección de "otras apps" NO existe
  en iOS (limitación del sistema); ahí se cubrirá con ShazamKit (micrófono) más adelante.
