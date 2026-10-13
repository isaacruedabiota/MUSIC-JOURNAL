import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/track.dart';
import '../services/ajustes.dart';
import '../services/descargas.dart';
import '../services/track_repository.dart';

/// Panel de una canción: la llamada exacta que hará «Descargar» y un botón
/// para descargar solo esa, viendo el resultado o el error.
class LlamadaSheet extends StatefulWidget {
  const LlamadaSheet({
    super.key,
    required this.track,
    required this.repository,
    required this.ajustes,
  });

  final Track track;
  final TrackRepository repository;
  final Ajustes ajustes;

  @override
  State<LlamadaSheet> createState() => _LlamadaSheetState();
}

class _LlamadaSheetState extends State<LlamadaSheet> {
  bool _descargando = false;
  bool _copiada = false;

  /// Resultado de «Descargar esta canción» y si fue bien.
  (String, bool)? _resultado;

  Future<void> _descargar() async {
    setState(() {
      _descargando = true;
      _resultado = null;
    });
    (String, bool) resultado;
    try {
      final archivo = await Descargador(
        widget.repository,
        widget.ajustes,
      ).descargarUna(widget.track);
      resultado = (
        'Guardada en ${widget.ajustes.carpetaNombre} como «$archivo».',
        true,
      );
    } on PlatformException catch (e) {
      resultado = ('${e.message}', false);
    } catch (e) {
      resultado = ('$e', false);
    }
    if (!mounted) return;
    setState(() {
      _descargando = false;
      _resultado = resultado;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final track = widget.track;
    final curl = comoCurl(track);
    final sinCarpeta = widget.ajustes.carpetaUri == null;

    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    Widget caja(String texto, {Color? color}) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color ?? colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: SelectableText(texto, style: mono),
    );
    final resultado = _resultado;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(track.title, style: theme.textTheme.titleLarge),
          Text(track.artist, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 20),
          Text(
            'Llamada que hará «Descargar»',
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          caja(curl),
          const SizedBox(height: 12),
          if (sinCarpeta)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Elige primero la carpeta de descargas en Ajustes.',
                style: TextStyle(color: colors.error),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: curl));
                  setState(() => _copiada = true);
                },
                icon: const Icon(Icons.copy, size: 18),
                label: Text(_copiada ? 'Copiada' : 'Copiar'),
              ),
              FilledButton.icon(
                onPressed: _descargando || sinCarpeta ? null : _descargar,
                icon: _descargando
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download),
                label: const Text('Descargar esta canción'),
              ),
            ],
          ),
          if (resultado case (final texto, final ok)) ...[
            const SizedBox(height: 20),
            Text(
              ok ? 'Resultado: correcto' : 'Resultado: error',
              style: theme.textTheme.titleSmall?.copyWith(
                color: ok ? colors.primary : colors.error,
              ),
            ),
            const SizedBox(height: 8),
            caja(
              texto,
              color: ok ? colors.primaryContainer : colors.errorContainer,
            ),
          ],
        ],
      ),
    );
  }
}
