# MusicList

App Android (Flutter + Kotlin) que guarda en local las canciones que suenan en Spotify, también con la app cerrada y la pantalla apagada. No necesita Spotify Premium ni cuenta de desarrollador, y el registro de canciones funciona sin red (solo «Descargar» usa la Wi-Fi de casa).

## Cómo funciona

- Un servicio nativo (`NotificationListenerService`) lee la **sesión multimedia de Spotify**, es decir, los mismos datos que muestra su notificación: título, artista, portada y el URI `spotify:track:<id>`.
- Android mantiene el servicio vinculado mientras tenga **Acceso a notificaciones**, así que funciona con la app cerrada y la pantalla apagada.
- **No hay polling**: el servicio solo se despierta cuando Spotify cambia de canción o de estado.
- Reglas:
  - Solo se procesa lo que está sonando (`STATE_PLAYING`).
  - Solo se guardan canciones (`spotify:track:`). Se descartan podcasts (`spotify:episode:`), anuncios (`spotify:ad:`) y archivos locales.
  - No hay duplicados: el track ID es la clave primaria.
- El historial se guarda en SQLite (nativo de Android) y las portadas como JPEG de ≤ 256 px en el almacenamiento interno. Flutter solo lo muestra.
- Las canciones se reparten en dos pestañas según su campo **`descargado`**: **Sin procesar** y **Procesadas**.
- Deslizar una canción a la **izquierda** la borra. Durante 4 s puedes pulsar «Deshacer»; después se borran del móvil la fila y su portada. Si la canción estaba sonando, no reaparece mientras siga sonando; si se vuelve a escuchar más adelante, se añade de nuevo.
- En **Procesadas**, deslizar a la **derecha** devuelve la canción a **Sin procesar**.
- **Tocar** una canción abre un panel con la llamada exacta que hará «Descargar» (como `curl`, para copiarla) y un botón **Descargar esta canción** que la descarga sola y enseña el resultado o el error.

## Descargar

El botón **Descargar** recorre las canciones sin procesar y, una a una, hace esta llamada a tu servidor, que devuelve directamente el archivo:

```bash
curl -X 'POST'   'http://pi-isaac.local:8010/download?artist=Melendi&title=Jardin%20con%20enanitos'   -H 'accept: */*'   -d ''
```

Guarda el archivo en la carpeta elegida como `Artista - Título.ext`, con la extensión que indique el servidor, y marca la canción como descargada, así que pasa a **Procesadas**. Si una canción falla, sigue con las demás y al final enseña, por cada fallo, la llamada y el motivo. Pulsando el botón mientras descarga, se para al acabar la canción en curso.

- **Ajustes** (el engranaje) solo tiene la carpeta de descargas. Se elige con el selector del sistema y no hacen falta permisos de almacenamiento. Android no deja usar la raíz ni la carpeta Download entera: elige o crea una como `Music`. Se conserva al instalar versiones nuevas.
- **El servidor** está en [lib/services/descargas.dart](lib/services/descargas.dart) (`servidorDescargas`). También se puede cambiar sin tocar el código: `flutter run --dart-define=SERVIDOR_DESCARGAS=http://192.168.1.31:8010/download`.
- **El móvil tiene que estar en la misma Wi-Fi.** Algunos móviles (el Realme, por ejemplo) no siempre resuelven nombres `.local`; en ese caso la app pregunta por mDNS quién es `pi-isaac.local` y usa su IP.
- **La conexión es `http://`** (sin cifrar). Android lo bloquea por defecto, así que se permite en el manifiesto (`usesCleartextTraffic`).

`flutter run` actualiza la app sin borrar sus datos. Solo desinstala si falla la actualización; en un Realme puede pasar si no aceptas a tiempo el aviso de instalación por USB. En ese caso se pierden las canciones guardadas y la carpeta elegida.

## Puesta en marcha

1. Conecta el móvil (Android 7 o superior) y ejecuta `flutter run`.
2. En la app, pulsa **Dar acceso a notificaciones** y activa MusicList.
3. Recomendado: pulsa **Permitir** en el aviso de batería.

Si instalas el APK a mano (no con `flutter run`), Android 13+ bloquea ese permiso. Para desbloquearlo: Ajustes › Aplicaciones › MusicList › ⋮ › **Permitir ajustes restringidos**.

Para comprobar qué ve el servicio: `adb logcat -s MusicList` muestra cada cambio, con el formato `Spotify reproduce: spotify:track:… · Título · Artista`.

## Estructura

```
android/app/src/main/kotlin/com/isaac/musiclist/
├── SpotifyListenerService.kt   Escucha a Spotify en segundo plano
├── SpotifyRules.kt             Reglas de negocio (con tests JUnit)
├── TrackStore.kt               SQLite + portadas, en un hilo de fondo
├── Downloads.kt                POST al servidor y guardado en la carpeta elegida
├── Mdns.kt                     Resuelve pi-isaac.local si el móvil no sabe (con tests)
└── MainActivity.kt             Canales con Flutter (historial, permisos, descargas)
lib/
├── main.dart                   Permiso pendiente → configuración; si no → lista
├── models/track.dart
├── services/
│   ├── track_repository.dart   Lee el historial y recibe las canciones nuevas en directo
│   ├── permissions.dart        Acceso a notificaciones y batería
│   ├── ajustes.dart            Carpeta de descargas, guardada en el móvil
│   └── descargas.dart          Servidor, URL de cada canción y bucle de «Descargar»
└── ui/
    ├── setup_screen.dart
    ├── ajustes_screen.dart
    ├── llamada_sheet.dart      Panel al tocar una canción: su llamada y «Descargar esta canción»
    └── tracks_screen.dart      Pestañas, lista, botones Ajustes y Descargar
```

## Limitaciones

- **Solo Android**: iOS no permite leer la sesión multimedia de otras apps.
- Solo ve lo que reproduce, o controla, la app de Spotify de **este móvil**.
- Si Spotify dejara de publicar el URI, las canciones se guardarían por título + artista y ya no se distinguirían los podcasts.
- En móviles con gestión de batería agresiva (Xiaomi, Huawei, algunos Samsung) puede que se pierdan canciones. En ese caso, pon la batería de MusicList en «Sin restricciones» y activa el autoinicio. Si aun así fallara, el siguiente paso sería un servicio en primer plano, con una notificación fija.

## Tests

```bash
flutter test                                          # UI y puente con la parte nativa
./android/gradlew -p android :app:testDebugUnitTest   # reglas de negocio (Kotlin)
```
