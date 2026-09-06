import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/listening_stats.dart';
import '../providers/history_provider.dart';

/// Dashboard de estadisticas de escucha.
///
/// Diseno (siguiendo la guia de dataviz):
///  - Los KPIs son "stat tiles" (numero protagonista), no graficos.
///  - Rankings e histograma son UNA sola serie -> un unico tono (primary),
///    sin leyenda (el titulo nombra la serie).
///  - Barras de puntas redondeadas, separacion de 2px, ejes discretos.
///  - El texto va en tinta neutra, nunca en el color de la serie.
class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final stats = history.stats;

    return Scaffold(
      appBar: AppBar(title: const Text('Estadisticas')),
      body: history.loading
          ? const Center(child: CircularProgressIndicator())
          : stats.isEmpty
              ? const _EmptyStats()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _KpiRow(stats: stats),
                    const SizedBox(height: 24),
                    _Section(
                      title: 'A que horas escuchas',
                      child: _HourHistogram(playsByHour: stats.playsByHour),
                    ),
                    const SizedBox(height: 24),
                    _Section(
                      title: 'Tus artistas top',
                      child: _RankedBars(items: stats.topArtists),
                    ),
                    const SizedBox(height: 24),
                    _Section(
                      title: 'Tus canciones top',
                      child: _RankedTrackList(items: stats.topTracks),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
    );
  }
}

class _EmptyStats extends StatelessWidget {
  const _EmptyStats();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              'Aun no hay datos.\nEscucha algo de musica y aqui veras tus '
              'estadisticas.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// --- KPIs (stat tiles) ---

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.stats});
  final ListeningStats stats;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _StatTile(
                value: '${stats.totalPlays}', label: 'Escuchas')),
        const SizedBox(width: 12),
        Expanded(
            child: _StatTile(
                value: '${stats.uniqueTracks}', label: 'Canciones')),
        const SizedBox(width: 12),
        Expanded(
            child: _StatTile(
                value: '${stats.uniqueArtists}', label: 'Artistas')),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        child,
      ],
    );
  }
}

// --- Histograma "por hora" (24 barras, una sola serie) ---

class _HourHistogram extends StatelessWidget {
  const _HourHistogram({required this.playsByHour});
  final List<int> playsByHour;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxVal =
        playsByHour.isEmpty ? 0 : playsByHour.reduce((a, b) => a > b ? a : b);
    if (maxVal == 0) return const SizedBox.shrink();

    return Column(
      children: [
        SizedBox(
          height: 120,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var h = 0; h < 24; h++) ...[
                Expanded(
                  child: _Bar(
                    // Altura proporcional; minimo visible si hay algun play.
                    fraction: playsByHour[h] / maxVal,
                    color: scheme.primary,
                    tooltip: '${h}h: ${playsByHour[h]} escuchas',
                  ),
                ),
                if (h < 23) const SizedBox(width: 2), // separacion de 2px
              ],
            ],
          ),
        ),
        const SizedBox(height: 6),
        // Eje discreto: solo unas pocas marcas de hora.
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (final h in const ['0h', '6h', '12h', '18h', '23h'])
              Text(h,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: scheme.onSurfaceVariant)),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color, this.tooltip});
  final double fraction;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // Puntas superiores redondeadas (4px), ancladas a la linea base.
    final bar = FractionallySizedBox(
      alignment: Alignment.bottomCenter,
      heightFactor: fraction <= 0 ? 0.02 : fraction,
      child: Container(
        decoration: BoxDecoration(
          color: fraction <= 0 ? color.withValues(alpha: 0.15) : color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ),
    );
    return tooltip == null ? bar : Tooltip(message: tooltip!, child: bar);
  }
}

// --- Ranking de artistas (barras horizontales, una sola serie) ---

class _RankedBars extends StatelessWidget {
  const _RankedBars({required this.items});
  final List<Ranked> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final maxVal = items.first.plays; // ya vienen ordenados desc

    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 110,
                  child: Text(item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: item.plays / maxVal,
                        child: Container(height: 16, color: scheme.primary),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${item.plays}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );
  }
}

// --- Ranking de canciones (lista con badge de plays) ---

class _RankedTrackList extends StatelessWidget {
  const _RankedTrackList({required this.items});
  final List<Ranked> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: scheme.surfaceContainerHighest,
              child: Text('${i + 1}',
                  style: TextStyle(color: scheme.onSurface)),
            ),
            title: Text(items[i].label,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: items[i].sublabel != null
                ? Text(items[i].sublabel!,
                    maxLines: 1, overflow: TextOverflow.ellipsis)
                : null,
            trailing: Text('${items[i].plays} plays',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant)),
          ),
      ],
    );
  }
}
