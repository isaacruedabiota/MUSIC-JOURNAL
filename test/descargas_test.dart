import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musiclist/models/track.dart';
import 'package:musiclist/services/ajustes.dart';
import 'package:musiclist/services/descargas.dart';
import 'package:musiclist/services/track_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const tracksChannel = MethodChannel('musiclist/tracks');
  const downloadsChannel = MethodChannel('musiclist/downloads');
  const updatesChannel = EventChannel('musiclist/track_updates');
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;

  Track track(String title, String artist) => Track(
    id: 'x',
    title: title,
    artist: artist,
    coverPath: null,
    detectedAt: DateTime(2026),
  );

  group('la llamada', () {
    test('es igual que el ejemplo: ?artist=…&title=… con espacios en %20', () {
      expect(
        urlDescarga(track('Jardin con enanitos', 'Melendi')),
        'http://pi-isaac.local:8010/download'
        '?artist=Melendi&title=Jardin%20con%20enanitos',
      );
      expect(
        comoCurl(track('Jardin con enanitos', 'Melendi')),
        "curl -X 'POST' \\\n"
        "  'http://pi-isaac.local:8010/download?artist=Melendi&title=Jardin%20con%20enanitos' \\\n"
        "  -H 'accept: */*' \\\n"
        "  -d ''",
      );
    });

    test('codifica tildes y símbolos que romperían la URL', () {
      expect(
        urlDescarga(track('Quédate & Rock?', 'Bizarrap, Quevedo')),
        endsWith(
          '?artist=Bizarrap%2C%20Quevedo&title=Qu%C3%A9date%20%26%20Rock%3F',
        ),
      );
    });

    test('el nombre del archivo quita los caracteres prohibidos', () {
      expect(
        nombreBase(track('¿Back in Black?', 'AC/DC')),
        'AC_DC - ¿Back in Black_',
      );
    });
  });

  group('Descargador', () {
    late List<MethodCall> calls;
    late TrackRepository repository;
    late Ajustes ajustes;

    Map<String, Object?> row(String id, String title) => {
      'id': id,
      'title': title,
      'artist': 'Artista',
      'coverPath': null,
      'detectedAt': 0,
      'descargado': false,
    };

    setUp(() async {
      calls = [];
      messenger
        ..setMockMethodCallHandler(tracksChannel, (call) async {
          calls.add(call);
          return call.method == 'getAll'
              ? [row('a', 'Primera'), row('b', 'Segunda')]
              : null;
        })
        ..setMockMethodCallHandler(downloadsChannel, (call) async {
          calls.add(call);
          final args = call.arguments as Map;
          if (args['baseName'] == 'Artista - Segunda') {
            throw PlatformException(
              code: 'DOWNLOAD',
              message: 'El servidor respondió HTTP 404: {"detail":"Not found"}',
            );
          }
          return '${args['baseName']}.mp3';
        })
        ..setMockStreamHandler(
          updatesChannel,
          MockStreamHandler.inline(onListen: (_, _) {}),
        );
      repository = TrackRepository();
      await repository.load();
      SharedPreferences.setMockInitialValues({
        'carpetaUri': 'content://carpeta',
        'carpetaNombre': 'Music',
      });
      ajustes = await Ajustes.cargar();
    });

    tearDown(() {
      repository.dispose();
      messenger
        ..setMockMethodCallHandler(tracksChannel, null)
        ..setMockMethodCallHandler(downloadsChannel, null)
        ..setMockStreamHandler(updatesChannel, null);
    });

    test('descarga cada canción en la carpeta y la marca como descargada; '
        'si una falla, sigue y explica por qué', () async {
      final resumen = await Descargador(
        repository,
        ajustes,
      ).descargar(repository.tracks.toList());

      expect(resumen.descargadas, 1);
      expect(
        resumen.errores.single,
        '«Segunda» (Artista)\n'
        'POST http://pi-isaac.local:8010/download?artist=Artista&title=Segunda\n'
        'El servidor respondió HTTP 404: {"detail":"Not found"}',
      );

      final descarga = calls.firstWhere((c) => c.method == 'download');
      expect(descarga.arguments, {
        'url':
            'http://pi-isaac.local:8010/download?artist=Artista&title=Primera',
        'folder': 'content://carpeta',
        'baseName': 'Artista - Primera',
      });
      final marcada = calls.singleWhere((c) => c.method == 'setDescargado');
      expect(marcada.arguments, {'id': 'a', 'value': true});
      expect(repository.tracks.map((t) => t.descargado), [true, false]);
    });

    test('si se pide parar, no empieza la siguiente canción', () async {
      var parar = false;

      final resumen = await Descargador(repository, ajustes).descargar(
        repository.tracks.toList(),
        progreso: (hechas, _) => parar = hechas == 0, // tras empezar la 1.ª
        cancelar: () => parar,
      );

      expect(calls.where((c) => c.method == 'download'), hasLength(1));
      expect(resumen.descargadas, 1);
      expect(resumen.cancelada, isTrue);
    });
  });
}
