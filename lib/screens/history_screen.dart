import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/listening_entry.dart';
import '../models/wishlist_item.dart';
import '../providers/history_provider.dart';
import '../providers/wishlist_provider.dart';
import '../services/legal_links.dart';

/// Diario: dos pestanas.
///  - Historial: todo lo que has escuchado, por dia (+ anadir a deseos).
///  - Deseos: canciones que quieres conseguir por vias legales.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diario'),
          actions: [
            if (history.entries.isNotEmpty)
              IconButton(
                tooltip: 'Borrar historial',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmClear(context, history),
              ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Historial', icon: Icon(Icons.auto_stories)),
              Tab(text: 'Deseos', icon: Icon(Icons.favorite)),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _HistoryTab(history: history),
            const _WishlistTab(),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmClear(
      BuildContext context, HistoryProvider history) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar todo el historial?'),
        content: const Text('Esta accion no se puede deshacer.'),
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
    if (ok == true) await history.clear();
  }
}

// ------------------- Pestana HISTORIAL -------------------

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({required this.history});
  final HistoryProvider history;

  @override
  Widget build(BuildContext context) {
    if (history.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (history.entries.isEmpty) {
      return const _Empty(
        icon: Icons.auto_stories,
        text: 'Tu diario esta vacio.\nPon musica y las canciones apareceran '
            'aqui automaticamente.',
      );
    }
    return _DiaryList(entries: history.entries);
  }
}

class _DiaryList extends StatelessWidget {
  const _DiaryList({required this.entries});
  final List<ListeningEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final showHeader =
            i == 0 || !_sameDay(entries[i - 1].playedAt, entry.playedAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeader) _DayHeader(date: entry.playedAt),
            _EntryTile(entry: entry),
          ],
        );
      },
    );
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.date});
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Text(
        _friendlyDate(date),
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  static String _friendlyDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(date.year, date.month, date.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Hoy';
    if (diff == 1) return 'Ayer';
    const meses = [
      'ene', 'feb', 'mar', 'abr', 'may', 'jun',
      'jul', 'ago', 'sep', 'oct', 'nov', 'dic'
    ];
    return '${date.day} ${meses[date.month - 1]} ${date.year}';
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});
  final ListeningEntry entry;

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider>();
    final inWishlist = wishlist.contains(entry.dedupeKey);

    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: entry.artworkUrl != null
            ? Image.network(entry.artworkUrl!,
                width: 48, height: 48, fit: BoxFit.cover)
            : Container(
                width: 48,
                height: 48,
                color: Colors.grey.shade300,
                child: const Icon(Icons.music_note, size: 24),
              ),
      ),
      title: Text(entry.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text('${entry.artist} · ${_hhmm(entry.playedAt)}',
          maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: inWishlist ? 'En tu lista de deseos' : 'Anadir a deseos',
        icon: Icon(inWishlist ? Icons.favorite : Icons.favorite_border,
            color: inWishlist ? Theme.of(context).colorScheme.primary : null),
        onPressed: () async {
          await wishlist.toggleEntry(entry);
          if (context.mounted) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(inWishlist
                    ? 'Quitada de deseos'
                    : 'Anadida a deseos'),
              ));
          }
        },
      ),
    );
  }

  static String _hhmm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}

// ------------------- Pestana DESEOS -------------------

class _WishlistTab extends StatelessWidget {
  const _WishlistTab();

  @override
  Widget build(BuildContext context) {
    final wishlist = context.watch<WishlistProvider>();
    if (wishlist.items.isEmpty) {
      return const _Empty(
        icon: Icons.favorite_border,
        text: 'Aun no tienes deseos.\nEn "Historial", toca el corazon de una '
            'cancion para guardarla y conseguirla por vias legales.',
      );
    }
    return ListView.separated(
      itemCount: wishlist.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) => _WishlistTile(item: wishlist.items[i]),
    );
  }
}

class _WishlistTile extends StatelessWidget {
  const _WishlistTile({required this.item});
  final WishlistItem item;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.favorite, color: Colors.pink),
      title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(item.artist, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: FilledButton.tonalIcon(
        icon: const Icon(Icons.shopping_bag, size: 18),
        label: const Text('Conseguir'),
        onPressed: () => _showLegalSheet(context),
      ),
    );
  }

  void _showLegalSheet(BuildContext context) {
    final wishlist = context.read<WishlistProvider>();
    final destinations = legalDestinationsFor(
      artist: item.artist,
      title: item.title,
      spotifyId: item.spotifyId,
    );

    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(item.title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(item.artist),
            ),
            const Divider(height: 1),
            for (final d in destinations)
              ListTile(
                leading: const Icon(Icons.open_in_new),
                title: Text('Buscar en ${d.label}'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await launchUrl(Uri.parse(d.url),
                      mode: LaunchMode.externalApplication);
                },
              ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(Icons.delete_outline,
                  color: Theme.of(ctx).colorScheme.error),
              title: const Text('Quitar de deseos'),
              onTap: () {
                Navigator.pop(ctx);
                wishlist.removeByKey(item.dedupeKey);
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------- Comun -------------------

class _Empty extends StatelessWidget {
  const _Empty({required this.icon, required this.text});
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
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
