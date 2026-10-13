import 'dart:io';

import 'package:flutter/material.dart';

import '../models/track.dart';
import '../services/ajustes.dart';
import '../services/descargas.dart';
import '../services/permissions.dart';
import '../services/track_repository.dart';
import 'ajustes_screen.dart';
import 'llamada_sheet.dart';

/// Historial en dos pestañas según `descargado`: «Sin procesar» y
/// «Procesadas». Las canciones nuevas aparecen en directo.
class TracksScreen extends StatefulWidget {
  const TracksScreen({
    super.key,
    required this.repository,
    required this.ajustes,
    this.showBatteryHint = false,
  });

  final TrackRepository repository;
  final Ajustes ajustes;
  final bool showBatteryHint;

  @override
  State<TracksScreen> createState() => _TracksScreenState();
}

class _TracksScreenState extends State<TracksScreen> {
  @override
  void initState() {
    super.initState();
    widget.repository.load();
  }

  /// Quita la canción al momento y la borra del móvil cuando se cierra el
  /// aviso, salvo que se pulse «Deshacer».
  void _delete(Track track) {
    final repository = widget.repository..remove(track);
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger
        .showSnackBar(
          SnackBar(
            content: Text('«${track.title}» eliminada'),
            // Con acción, Flutter lo dejaría abierto hasta que se tocase: así
            // se cierra solo a los 4 s y el borrado se hace efectivo.
            persist: false,
            action: SnackBarAction(
              label: 'Deshacer',
              onPressed: () => repository.restore(track),
            ),
          ),
        )
        .closed
        .then((reason) {
          if (reason != SnackBarClosedReason.action) repository.delete(track);
        });
  }

  /// Panel con la llamada de descarga de esa canción, para revisarla o
  /// descargar solo esa.
  void _showCall(Track track) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => LlamadaSheet(
        track: track,
        repository: widget.repository,
        ajustes: widget.ajustes,
      ),
    );
  }

  /// Devuelve una canción procesada a «Sin procesar».
  void _unmark(Track track) {
    widget.repository.setDescargado(track, false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text('«${track.title}» vuelve a Sin procesar')),
      );
  }

  @override
  Widget build(BuildContext context) {
    final repository = widget.repository;
    return DefaultTabController(
      length: 2,
      // Solo se reconstruye cuando cambia alguna canción.
      child: ListenableBuilder(
        listenable: repository,
        builder: (context, _) {
          final pending = [
            for (final t in repository.tracks)
              if (!t.descargado) t,
          ];
          final done = [
            for (final t in repository.tracks)
              if (t.descargado) t,
          ];
          return Scaffold(
            appBar: AppBar(
              title: const Text('MusicList'),
              bottom: TabBar(
                tabs: [
                  Tab(text: 'Sin procesar (${pending.length})'),
                  Tab(text: 'Procesadas (${done.length})'),
                ],
              ),
            ),
            floatingActionButton: _Botones(
              repository: repository,
              ajustes: widget.ajustes,
            ),
            body: Column(
              children: [
                if (widget.showBatteryHint) const _BatteryHint(),
                Expanded(
                  child: TabBarView(
                    // Se cambia de pestaña tocándolas: el gesto horizontal es
                    // para deslizar las canciones.
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _TrackList(
                        pending,
                        emptyText: repository.tracks.isEmpty
                            ? 'Aún no hay canciones.\nPon música en Spotify '
                                  '(aunque sea con la pantalla apagada) y '
                                  'aparecerá aquí.'
                            : 'No queda nada por procesar.',
                        onTap: _showCall,
                        onDelete: _delete,
                      ),
                      _TrackList(
                        done,
                        emptyText: 'Aún no se ha descargado ninguna canción.',
                        onTap: _showCall,
                        onDelete: _delete,
                        onUnmark: _unmark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Lista de una pestaña. Tocar una canción enseña su llamada a la API;
/// deslizar a la izquierda la borra; en «Procesadas», deslizar a la derecha
/// la devuelve a «Sin procesar».
class _TrackList extends StatelessWidget {
  const _TrackList(
    this.tracks, {
    required this.emptyText,
    required this.onTap,
    required this.onDelete,
    this.onUnmark,
  });

  final List<Track> tracks;
  final String emptyText;
  final void Function(Track) onTap;
  final void Function(Track) onDelete;
  final void Function(Track)? onUnmark;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) return _EmptyState(emptyText);
    final unmark = onUnmark;
    return ListView.builder(
      // Hueco final para que los botones no tapen la última canción.
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: tracks.length,
      // Todas las filas miden igual: con un prototipo el scroll no tiene que
      // medirlas una a una (y respeta el tamaño de letra).
      prototypeItem: _TrackTile(tracks.first),
      itemBuilder: (context, i) {
        final track = tracks[i];
        return Dismissible(
          key: ValueKey(track.id),
          background: unmark == null
              ? const _SwipeBackground.delete(Alignment.centerLeft)
              : const _SwipeBackground.unmark(),
          secondaryBackground: const _SwipeBackground.delete(
            Alignment.centerRight,
          ),
          onDismissed: (direction) =>
              unmark != null && direction == DismissDirection.startToEnd
              ? unmark(track)
              : onDelete(track),
          child: _TrackTile(track, onTap: () => onTap(track)),
        );
      },
    );
  }
}

/// «Ajustes» y «Descargar», abajo a la derecha.
class _Botones extends StatefulWidget {
  const _Botones({required this.repository, required this.ajustes});

  final TrackRepository repository;
  final Ajustes ajustes;

  @override
  State<_Botones> createState() => _BotonesState();
}

class _BotonesState extends State<_Botones> {
  /// Progreso de la descarga en curso («3/10»), o `null` si no hay ninguna.
  String? _progress;
  bool _stop = false;

  void _openSettings() => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => AjustesScreen(ajustes: widget.ajustes),
    ),
  );

  void _snack(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), action: action, persist: false),
      );
  }

  /// Descarga todas las canciones sin procesar. Si ya está descargando, la
  /// para al terminar la canción en curso.
  Future<void> _download() async {
    if (_progress != null) {
      setState(() {
        _stop = true;
        _progress = 'parando…';
      });
      return;
    }
    if (widget.ajustes.carpetaUri == null) {
      _snack(
        'Elige primero la carpeta de descargas.',
        action: SnackBarAction(label: 'Ajustes', onPressed: _openSettings),
      );
      return;
    }
    final pending = [
      for (final t in widget.repository.tracks)
        if (!t.descargado) t,
    ];
    if (pending.isEmpty) {
      _snack('No hay canciones sin procesar.');
      return;
    }

    _stop = false;
    setState(() => _progress = '1/${pending.length}');
    final summary = await Descargador(widget.repository, widget.ajustes)
        .descargar(
          pending,
          progreso: (done, total) {
            if (mounted && !_stop) {
              setState(() => _progress = '${done + 1}/$total');
            }
          },
          cancelar: () => _stop,
        );
    if (!mounted) return;
    setState(() => _progress = null);

    final title =
        '${summary.descargadas} de ${summary.total} descargadas'
        '${summary.cancelada ? ' (parada a mano)' : ''}';
    if (summary.errores.isEmpty) {
      _snack('$title.');
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: SelectableText(summary.errores.join('\n\n')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = _progress;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton.small(
          heroTag: 'ajustes',
          tooltip: 'Ajustes',
          onPressed: _openSettings,
          child: const Icon(Icons.settings_outlined),
        ),
        const SizedBox(width: 12),
        FloatingActionButton.extended(
          heroTag: 'descargar',
          tooltip: progress == null
              ? null
              : 'Parar al acabar la canción actual',
          onPressed: _download,
          icon: progress == null
              ? const Icon(Icons.download)
              : const SizedBox.square(
                  dimension: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
          label: Text(progress == null ? 'Descargar' : 'Descargando $progress'),
        ),
      ],
    );
  }
}

/// Aviso para quitar la optimización de batería (recomendado, no obligatorio).
class _BatteryHint extends StatelessWidget {
  const _BatteryHint();

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: ListTile(
        leading: const Icon(Icons.battery_alert_outlined),
        title: const Text(
          'Para no perder canciones con la pantalla apagada, quita las '
          'restricciones de batería.',
        ),
        trailing: TextButton(
          onPressed: Permissions.requestBatteryUnrestricted,
          child: const Text('Permitir'),
        ),
      ),
    );
  }
}

/// Fondo que asoma al deslizar una canción: borrar (rojo) o devolverla a
/// «Sin procesar».
class _SwipeBackground extends StatelessWidget {
  const _SwipeBackground.delete(this.alignment) : unmark = false;

  const _SwipeBackground.unmark()
    : alignment = Alignment.centerLeft,
      unmark = true;

  final Alignment alignment;
  final bool unmark;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final foreground = unmark
        ? colors.onTertiaryContainer
        : colors.onErrorContainer;
    return ColoredBox(
      color: unmark ? colors.tertiaryContainer : colors.errorContainer,
      child: Align(
        alignment: alignment,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                unmark ? Icons.undo : Icons.delete_outline,
                color: foreground,
              ),
              if (unmark) ...[
                const SizedBox(width: 8),
                Text('Sin procesar', style: TextStyle(color: foreground)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackTile extends StatelessWidget {
  const _TrackTile(this.track, {this.onTap});

  final Track track;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _Cover(track.coverPath),
      title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        track.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        _formatDate(track.detectedAt),
        textAlign: TextAlign.end,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }

  /// `11/10/26` y debajo `20:30`, sin depender del paquete intl.
  static String _formatDate(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${two(d.year % 100)}\n'
        '${two(d.hour)}:${two(d.minute)}';
  }
}

/// Miniatura de la portada, decodificada al tamaño con que se pinta.
class _Cover extends StatelessWidget {
  const _Cover(this.path);

  static const _size = 48.0;

  final String? path;

  @override
  Widget build(BuildContext context) {
    final placeholder = ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Icon(Icons.music_note),
    );
    final path = this.path;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: SizedBox.square(
        dimension: _size,
        child: path == null
            ? placeholder
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                // Se decodifica a 48 dp × densidad y no al tamaño del JPEG.
                cacheWidth: (_size * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Text(text, textAlign: TextAlign.center),
      ),
    );
  }
}
