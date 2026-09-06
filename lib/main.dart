import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'data/listening_repository.dart';
import 'providers/history_provider.dart';
import 'providers/library_provider.dart';
import 'providers/now_playing_provider.dart';
import 'providers/spotify_settings_provider.dart';
import 'providers/system_media_provider.dart';
import 'providers/wishlist_provider.dart';
import 'screens/main_scaffold.dart';
import 'services/spotify_api_service.dart';
import 'services/spotify_auth_service.dart';

void main() {
  runApp(const MusicJournalApp());
}

class MusicJournalApp extends StatefulWidget {
  const MusicJournalApp({super.key});

  @override
  State<MusicJournalApp> createState() => _MusicJournalAppState();
}

class _MusicJournalAppState extends State<MusicJournalApp> {
  late final NowPlayingProvider _nowPlaying;
  late final SystemMediaProvider _systemMedia;
  late final HistoryProvider _history;
  late final SpotifySettingsProvider _spotifySettings;
  late final LibraryProvider _library;
  late final WishlistProvider _wishlist;

  @override
  void initState() {
    super.initState();

    // Cableado de dependencias: Auth -> Api -> NowPlaying;  Repo -> History.
    final auth = SpotifyAuthService();
    final api = SpotifyApiService(auth: auth);
    final repo = SqfliteListeningRepository();

    _nowPlaying = NowPlayingProvider(auth: auth, api: api);
    _systemMedia = SystemMediaProvider();
    _history = HistoryProvider(repo);
    _spotifySettings = SpotifySettingsProvider();
    _library = LibraryProvider()..load();
    _wishlist = WishlistProvider()..load();

    // ENGANCHE CLAVE: cada cancion nueva detectada (por cualquiera de las dos
    // fuentes) se guarda en el diario. HistoryProvider deduplica entre fuentes.
    _nowPlaying.onNewTrack = _history.record;
    _systemMedia.onNewTrack = _history.record;

    // Cargas iniciales.
    _history.load();
    _systemMedia.init(); // no-op fuera de Android
    _bootstrapSpotify();
  }

  /// Carga el Client ID guardado ANTES de arrancar el polling de Spotify,
  /// para que un posible refresh de token no use un Client ID vacio.
  Future<void> _bootstrapSpotify() async {
    await _spotifySettings.load();
    await _nowPlaying.init();
  }

  @override
  void dispose() {
    _nowPlaying.dispose();
    _systemMedia.dispose();
    _history.dispose();
    _spotifySettings.dispose();
    _library.dispose();
    _wishlist.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: _nowPlaying),
        ChangeNotifierProvider.value(value: _systemMedia),
        ChangeNotifierProvider.value(value: _history),
        ChangeNotifierProvider.value(value: _spotifySettings),
        ChangeNotifierProvider.value(value: _library),
        ChangeNotifierProvider.value(value: _wishlist),
      ],
      child: MaterialApp(
        title: 'Music Journal',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1DB954)),
          useMaterial3: true,
        ),
        home: const MainScaffold(),
      ),
    );
  }
}
