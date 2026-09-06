import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/archive_item.dart';
import '../models/downloaded_track.dart';
import '../providers/library_provider.dart';

/// Biblioteca offline legal: buscar en el Internet Archive (dominio publico /
/// Creative Commons), descargar al movil y reproducir sin conexion.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Biblioteca offline'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Buscar', icon: Icon(Icons.search)),
              Tab(text: 'Descargadas', icon: Icon(Icons.download_done)),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_SearchTab(), _DownloadedTab()],
        ),
      ),
    );
  }
}

// ------------------- Pestana BUSCAR -------------------

class _SearchTab extends StatefulWidget {
  const _SearchTab();

  @override
  State<_SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends State<_SearchTab> {
  final _controller = TextEditingController();
  List<ArchiveItem> _results = [];
  bool _loading = false;
  String? _error;
  bool _searched = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final q = _controller.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
    });
    try {
      final results = await context.read<LibraryProvider>().search(q);
      if (mounted) setState(() => _results = results);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _LegalBanner(),
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _controller,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _search(),
            decoration: InputDecoration(
              hintText: 'Busca musica libre (p. ej. "kevin macleod")',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: const Icon(Icons.search),
                onPressed: _search,
              ),
            ),
          ),
        ),
        Expanded(child: _buildResults(context)),
      ],
    );
  }

  Widget _buildResults(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('No se pudo buscar: $_error',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ),
      );
    }
    if (!_searched) {
      return const _Hint(
        icon: Icons.travel_explore,
        text: 'Busca en el Internet Archive musica de dominio publico y '
            'Creative Commons para descargarla y oirla offline.',
      );
    }
    if (_results.isEmpty) {
      return const _Hint(
        icon: Icons.search_off,
        text: 'Sin resultados con licencia libre. Prueba otra busqueda.',
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _ResultTile(item: _results[i]),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.item});
  final ArchiveItem item;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final downloading = lib.isDownloading(item.identifier);
    final downloaded = lib.hasTrack(item.identifier);
    final progress = lib.progress[item.identifier] ?? 0;

    return ListTile(
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.creator.isNotEmpty)
            Text(item.creator, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          _LicenseChip(label: item.licenseLabel),
          if (downloading) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progress >= 0 ? progress : null),
          ],
        ],
      ),
      isThreeLine: true,
      trailing: downloaded
          ? Icon(Icons.download_done, color: Theme.of(context).colorScheme.primary)
          : downloading
              ? const SizedBox(
                  width: 24, height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.download),
                  tooltip: 'Descargar',
                  onPressed: () => _download(context, lib),
                ),
    );
  }

  Future<void> _download(BuildContext context, LibraryProvider lib) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await lib.downloadItem(item);
      messenger.showSnackBar(
        const SnackBar(content: Text('Descargada. Esta en "Descargadas".')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('No se pudo descargar: $e')));
    }
  }
}

// ------------------- Pestana DESCARGADAS -------------------

class _DownloadedTab extends StatelessWidget {
  const _DownloadedTab();

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    if (lib.tracks.isEmpty) {
      return const _Hint(
        icon: Icons.library_music,
        text: 'Aun no has descargado nada.\nBusca musica libre en la pestana '
            '"Buscar" y descargala para oirla sin conexion.',
      );
    }
    return ListView.separated(
      itemCount: lib.tracks.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _DownloadedTile(track: lib.tracks[i]),
    );
  }
}

class _DownloadedTile extends StatelessWidget {
  const _DownloadedTile({required this.track});
  final DownloadedTrack track;

  @override
  Widget build(BuildContext context) {
    final lib = context.watch<LibraryProvider>();
    final isCurrent = lib.playingId == track.id;
    final isPlaying = isCurrent && lib.isPlaying;
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: IconButton(
        iconSize: 40,
        icon: Icon(isPlaying ? Icons.pause_circle : Icons.play_circle,
            color: scheme.primary),
        onPressed: () => lib.togglePlay(track),
      ),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Row(
        children: [
          Expanded(
            child: Text(
              track.artist.isEmpty ? track.album : track.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _LicenseChip(label: track.license),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Borrar de la biblioteca',
        onPressed: () => _confirmDelete(context, lib),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, LibraryProvider lib) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar de la biblioteca?'),
        content: Text('Se eliminara "${track.title}" del dispositivo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Borrar')),
        ],
      ),
    );
    if (ok == true) await lib.deleteTrack(track);
  }
}

// ------------------- Widgets comunes -------------------

class _LegalBanner extends StatelessWidget {
  const _LegalBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.primaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.verified_user, size: 18, color: scheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Solo musica de dominio publico y Creative Commons (Internet Archive).',
              style: TextStyle(color: scheme.onPrimaryContainer, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _LicenseChip extends StatelessWidget {
  const _LicenseChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, color: scheme.onSecondaryContainer)),
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
