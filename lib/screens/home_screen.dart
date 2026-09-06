import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/track.dart';
import '../providers/now_playing_provider.dart';
import '../providers/spotify_settings_provider.dart';
import '../providers/system_media_provider.dart';
import '../services/system_media_service.dart';
import 'spotify_settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de Ajustes (donde se concede el permiso), refrescamos estado.
    if (state == AppLifecycleState.resumed) {
      context.read<SystemMediaProvider>().onResume();
    }
  }

  void _openSpotifySettings() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SpotifySettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final np = context.watch<NowPlayingProvider>();
    final sm = context.watch<SystemMediaProvider>();
    // Observamos los ajustes para refrescar cuando se guarde el Client ID.
    final settings = context.watch<SpotifySettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Music Journal'),
        actions: [
          if (np.connection == SpotifyConnectionState.connected)
            IconButton(
              tooltip: 'Desconectar Spotify',
              icon: const Icon(Icons.logout),
              onPressed: np.disconnect,
            ),
          IconButton(
            tooltip: 'Conectar / configurar Spotify',
            icon: const Icon(Icons.settings),
            onPressed: _openSpotifySettings,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildSpotifySection(context, np, settings),
          if (sm.supported) ...[
            const SizedBox(height: 32),
            _OtherAppsCard(sm: sm),
          ],
        ],
      ),
    );
  }

  Widget _buildSpotifySection(
    BuildContext context,
    NowPlayingProvider np,
    SpotifySettingsProvider settings,
  ) {
    // Aviso + boton si todavia no se ha configurado el Client ID.
    if (!settings.isConfigured) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings, size: 48),
              const SizedBox(height: 12),
              Text('Conecta tu Spotify',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              const Text(
                'Configura Spotify una sola vez para empezar a detectar tu '
                'musica. Te guiamos paso a paso.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _openSpotifySettings,
                icon: const Icon(Icons.tune),
                label: const Text('Configurar Spotify'),
              ),
            ],
          ),
        ),
      );
    }

    switch (np.connection) {
      case SpotifyConnectionState.unknown:
        return const Center(child: CircularProgressIndicator());

      case SpotifyConnectionState.disconnected:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.music_note, size: 72),
            const SizedBox(height: 16),
            const Text(
              'Conecta tu cuenta de Spotify para empezar a detectar '
              'la musica que escuchas.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: np.busy ? null : np.connect,
              icon: np.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.link),
              label: Text(np.busy ? 'Conectando...' : 'Conectar Spotify'),
            ),
            if (np.error != null) ...[
              const SizedBox(height: 16),
              Text(np.error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                  textAlign: TextAlign.center),
            ],
          ],
        );

      case SpotifyConnectionState.connected:
        return _NowPlayingView(np: np);
    }
  }
}

class _NowPlayingView extends StatelessWidget {
  const _NowPlayingView({required this.np});
  final NowPlayingProvider np;

  @override
  Widget build(BuildContext context) {
    final track = np.current;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(np.isPolling ? Icons.podcasts : Icons.pause_circle,
                size: 16, color: Colors.green),
            const SizedBox(width: 6),
            Text(np.isPolling ? 'Escuchando Spotify...' : 'En pausa',
                style: Theme.of(context).textTheme.labelMedium),
          ],
        ),
        const SizedBox(height: 24),
        if (track == null)
          const _InfoCard(
            icon: Icons.hourglass_empty,
            title: 'Nada sonando',
            message:
                'Pon una cancion en Spotify y aparecera aqui automaticamente.',
          )
        else
          _TrackCard(track: track),
        if (np.error != null) ...[
          const SizedBox(height: 16),
          Text(np.error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center),
        ],
      ],
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({required this.track});
  final Track track;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: track.artworkUrl != null
                  ? Image.network(track.artworkUrl!,
                      width: 220, height: 220, fit: BoxFit.cover)
                  : Container(
                      width: 220,
                      height: 220,
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.album, size: 64),
                    ),
            ),
            const SizedBox(height: 20),
            Text(track.title,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center),
            const SizedBox(height: 4),
            Text(track.artist,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center),
            if (track.album.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(track.album,
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center),
            ],
            if (track.isrc != null) ...[
              const SizedBox(height: 12),
              Chip(
                label: Text('ISRC: ${track.isrc}'),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tarjeta (solo Android) para detectar la musica de CUALQUIER otra app
/// via el acceso a notificaciones.
class _OtherAppsCard extends StatelessWidget {
  const _OtherAppsCard({required this.sm});
  final SystemMediaProvider sm;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.hearing),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Otras apps de musica',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (!sm.permissionGranted)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Concede "Acceso a notificaciones" para detectar tambien '
                    'lo que suena en YouTube Music, SoundCloud, etc.',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.tonalIcon(
                    onPressed: sm.openSettings,
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Conceder acceso'),
                  ),
                ],
              )
            else if (sm.current == null)
              const Text('Permiso concedido. Nada sonando en otras apps ahora.')
            else
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.play_circle, color: scheme.primary),
                title: Text(sm.current!.title,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${sm.current!.artist} · ${friendlyAppName(sm.current!.source)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
