import 'package:flutter/material.dart';

import 'services/ajustes.dart';
import 'services/permissions.dart';
import 'services/track_repository.dart';
import 'ui/setup_screen.dart';
import 'ui/tracks_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ajustes = await Ajustes.cargar();
  runApp(MusicListApp(repository: TrackRepository(), ajustes: ajustes));
}

class MusicListApp extends StatelessWidget {
  const MusicListApp({
    super.key,
    required this.repository,
    required this.ajustes,
  });

  final TrackRepository repository;
  final Ajustes ajustes;

  @override
  Widget build(BuildContext context) {
    const seed = Color(0xFF1DB954); // verde Spotify
    return MaterialApp(
      title: 'MusicList',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: seed),
      darkTheme: ThemeData(colorSchemeSeed: seed, brightness: Brightness.dark),
      home: _Home(repository: repository, ajustes: ajustes),
    );
  }
}

/// Muestra la configuración hasta que hay acceso a notificaciones y después
/// la lista. Lo comprueba al abrir la app y cada vez que se vuelve de Ajustes.
class _Home extends StatefulWidget {
  const _Home({required this.repository, required this.ajustes});

  final TrackRepository repository;
  final Ajustes ajustes;

  @override
  State<_Home> createState() => _HomeState();
}

class _HomeState extends State<_Home> {
  late final AppLifecycleListener _lifecycle;
  bool? _hasAccess;
  bool _batteryUnrestricted = true;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refresh);
    _refresh();
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final (access, battery) = await (
      Permissions.hasNotificationAccess(),
      Permissions.isBatteryUnrestricted(),
    ).wait;
    if (!mounted) return;
    setState(() {
      _hasAccess = access;
      _batteryUnrestricted = battery;
    });
  }

  @override
  Widget build(BuildContext context) {
    return switch (_hasAccess) {
      null => const Scaffold(), // comprobando (tarda milisegundos)
      false => const SetupScreen(),
      true => TracksScreen(
        repository: widget.repository,
        ajustes: widget.ajustes,
        showBatteryHint: !_batteryUnrestricted,
      ),
    };
  }
}
