import 'dart:io';

import 'package:http/http.dart' as http;

/// Descarga un archivo por HTTP a una ruta local, informando del progreso.
class DownloadService {
  final http.Client _http;

  DownloadService([http.Client? client]) : _http = client ?? http.Client();

  /// Descarga [url] en [destPath]. [onProgress] recibe 0.0..1.0 (o -1 si no se
  /// conoce el tamano total). Devuelve el File resultante.
  Future<File> download(
    String url,
    String destPath, {
    void Function(double progress)? onProgress,
  }) async {
    final request = http.Request('GET', Uri.parse(url));
    final response = await _http.send(request);

    if (response.statusCode != 200) {
      throw DownloadException('Descarga fallida (${response.statusCode})');
    }

    final total = response.contentLength ?? 0;
    final file = File(destPath);
    final tmp = File('$destPath.part');
    final sink = tmp.openWrite();

    var received = 0;
    try {
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
        if (onProgress != null) {
          onProgress(total > 0 ? received / total : -1);
        }
      }
      await sink.flush();
      await sink.close();
      // Movimiento atomico: solo aparece el archivo final si termino bien.
      await tmp.rename(destPath);
      return file;
    } catch (e) {
      await sink.close();
      if (await tmp.exists()) await tmp.delete();
      rethrow;
    }
  }
}

class DownloadException implements Exception {
  final String message;
  DownloadException(this.message);
  @override
  String toString() => message;
}
