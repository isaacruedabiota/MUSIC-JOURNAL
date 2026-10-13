import 'package:flutter/services.dart';

import '../models/track.dart';
import 'ajustes.dart';
import 'track_repository.dart';

/// Servidor que devuelve el archivo de cada canción. Para usar otro, cambia
/// el valor por defecto o compila con
/// `--dart-define=SERVIDOR_DESCARGAS=http://otra-direccion:8010/download`.
const servidorDescargas = String.fromEnvironment(
  'SERVIDOR_DESCARGAS',
  defaultValue: 'http://pi-isaac.local:8010/download',
);

/// URL de la descarga de [track]: el servidor con `?artist=…&title=…`.
String urlDescarga(Track track) =>
    '$servidorDescargas'
    '?artist=${Uri.encodeComponent(track.artist)}'
    '&title=${Uri.encodeComponent(track.title)}';

/// La llamada de [track] escrita como `curl`, para revisarla o copiarla.
String comoCurl(Track track) =>
    "curl -X 'POST' \\\n"
    "  '${urlDescarga(track)}' \\\n"
    "  -H 'accept: */*' \\\n"
    "  -d ''";

/// Nombre del archivo sin extensión, `Artista - Título`, sin los caracteres
/// que no admite Android. La extensión la pone el servidor.
String nombreBase(Track track) => '${track.artist} - ${track.title}'
    .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_')
    .trim();

/// Resultado de [Descargador.descargar].
class ResumenDescarga {
  ResumenDescarga(this.total);

  final int total;
  int descargadas = 0;

  /// Por cada canción que falló: título, llamada y motivo.
  final List<String> errores = [];

  bool cancelada = false;
}

/// Pide cada canción al servidor (un POST que devuelve el archivo), lo guarda
/// en la carpeta de Ajustes y marca la canción como descargada.
class Descargador {
  Descargador(this._repository, this._ajustes);

  static const _nativo = MethodChannel('musiclist/downloads');

  final TrackRepository _repository;
  final Ajustes _ajustes;

  /// Descarga una canción. Devuelve el nombre del archivo creado; si falla,
  /// lanza una [PlatformException] con el motivo.
  Future<String> descargarUna(Track track) async {
    final archivo = await _nativo.invokeMethod<String>('download', {
      'url': urlDescarga(track),
      'folder': _ajustes.carpetaUri,
      'baseName': nombreBase(track),
    });
    await _repository.setDescargado(track, true);
    return archivo!;
  }

  /// Descarga [canciones] en orden. Llama a [progreso] antes de cada una y
  /// para antes de la siguiente si [cancelar] devuelve `true`.
  Future<ResumenDescarga> descargar(
    List<Track> canciones, {
    void Function(int hechas, int total)? progreso,
    bool Function()? cancelar,
  }) async {
    final resumen = ResumenDescarga(canciones.length);
    for (final (i, track) in canciones.indexed) {
      if (cancelar?.call() ?? false) {
        resumen.cancelada = true;
        break;
      }
      progreso?.call(i, canciones.length);
      try {
        await descargarUna(track);
        resumen.descargadas++;
      } catch (e) {
        resumen.errores.add(
          [
            '«${track.title}» (${track.artist})',
            'POST ${urlDescarga(track)}',
            if (e is PlatformException) '${e.message}' else '$e',
          ].join('\n'),
        );
      }
    }
    return resumen;
  }
}
