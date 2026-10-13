import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musiclist/services/ajustes.dart';
import 'package:musiclist/services/track_repository.dart';
import 'package:musiclist/ui/tracks_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const tracksChannel = MethodChannel('musiclist/tracks');
  const updatesChannel = EventChannel('musiclist/track_updates');
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;

  /// Fila tal y como la envía `Track.toMap()` en Kotlin.
  Map<String, Object?> row(String id, String title, int minute) => {
    'id': id,
    'title': title,
    'artist': 'Artista',
    'coverPath': null,
    'detectedAt': DateTime(2026, 10, 11, 20, minute).millisecondsSinceEpoch,
    'descargado': false,
  };

  late MockStreamHandlerEventSink updates;
  late List<MethodCall> calls;

  Future<TrackRepository> pumpScreen(
    WidgetTester tester,
    List<Map<String, Object?>> saved, {
    Map<String, Object> prefs = const {}, // ajustes sin rellenar
  }) async {
    calls = [];
    messenger.setMockMethodCallHandler(tracksChannel, (call) async {
      calls.add(call);
      return call.method == 'getAll' ? saved : null;
    });
    messenger.setMockStreamHandler(
      updatesChannel,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          updates = sink;
        },
      ),
    );
    addTearDown(() {
      messenger.setMockMethodCallHandler(tracksChannel, null);
      messenger.setMockStreamHandler(updatesChannel, null);
    });

    SharedPreferences.setMockInitialValues(prefs);
    final ajustes = await Ajustes.cargar();
    final repository = TrackRepository();
    addTearDown(repository.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: TracksScreen(repository: repository, ajustes: ajustes),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Iterable<MethodCall> deletes() => calls.where((c) => c.method == 'delete');

  testWidgets('muestra el historial y añade arriba las canciones nuevas', (
    tester,
  ) async {
    await pumpScreen(tester, [row('b', 'Segunda', 2), row('a', 'Primera', 1)]);

    expect(find.text('Segunda'), findsOneWidget);
    expect(find.text('Primera'), findsOneWidget);

    updates.success(row('c', 'Nueva', 3));
    await tester.pumpAndSettle();

    final newY = tester.getTopLeft(find.text('Nueva')).dy;
    expect(newY, lessThan(tester.getTopLeft(find.text('Segunda')).dy));
  });

  testWidgets('una actualización de una canción ya guardada no la duplica', (
    tester,
  ) async {
    final repository = await pumpScreen(tester, [row('a', 'Primera', 1)]);

    // P. ej. Spotify mandó la portada después de guardarla.
    updates.success({...row('a', 'Primera', 1), 'coverPath': '/no/existe.jpg'});
    await tester.pumpAndSettle();

    expect(repository.tracks, hasLength(1));
    expect(repository.tracks.single.coverPath, '/no/existe.jpg');
    expect(find.text('Primera'), findsOneWidget);
  });

  testWidgets('sin canciones muestra cómo empezar', (tester) async {
    await pumpScreen(tester, []);

    expect(find.textContaining('Aún no hay canciones'), findsOneWidget);
  });

  testWidgets('deslizar quita la canción y «Deshacer» la devuelve a su sitio', (
    tester,
  ) async {
    await pumpScreen(tester, [row('b', 'Segunda', 2), row('a', 'Primera', 1)]);

    await tester.drag(find.text('Segunda'), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Segunda'), findsNothing);

    await tester.tap(find.text('Deshacer'));
    await tester.pumpAndSettle();

    final secondY = tester.getTopLeft(find.text('Segunda')).dy;
    expect(secondY, lessThan(tester.getTopLeft(find.text('Primera')).dy));
    expect(deletes(), isEmpty);
  });

  testWidgets('si no se deshace, se borra del móvil al cerrarse el aviso', (
    tester,
  ) async {
    final repository = await pumpScreen(tester, [row('a', 'Primera', 1)]);

    await tester.drag(find.text('Primera'), const Offset(600, 0));
    await tester.pumpAndSettle();
    expect(deletes(), isEmpty); // aún se puede deshacer

    // El aviso se cierra solo a los 4 s.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    expect(find.text('Deshacer'), findsNothing);
    expect(deletes().single.arguments, 'a');
    expect(repository.tracks, isEmpty);
  });

  testWidgets('cada canción sale en su pestaña según «descargado»', (
    tester,
  ) async {
    await pumpScreen(tester, [
      row('a', 'Pendiente', 2),
      {...row('b', 'Bajada', 1), 'descargado': true},
    ]);

    expect(find.text('Sin procesar (1)'), findsOneWidget);
    expect(find.text('Procesadas (1)'), findsOneWidget);
    expect(find.text('Pendiente'), findsOneWidget);
    expect(find.text('Bajada'), findsNothing);

    await tester.tap(find.text('Procesadas (1)'));
    await tester.pumpAndSettle();

    expect(find.text('Bajada'), findsOneWidget);
    expect(find.text('Pendiente'), findsNothing);
  });

  testWidgets('en «Procesadas», deslizar a la derecha la devuelve a '
      '«Sin procesar»', (tester) async {
    final repository = await pumpScreen(tester, [
      {...row('b', 'Bajada', 1), 'descargado': true},
    ]);
    await tester.tap(find.text('Procesadas (1)'));
    await tester.pumpAndSettle();

    await tester.drag(find.text('Bajada'), const Offset(600, 0));
    await tester.pumpAndSettle();

    expect(find.text('Sin procesar (1)'), findsOneWidget);
    expect(find.text('Procesadas (0)'), findsOneWidget);
    expect(repository.tracks.single.descargado, isFalse);
    expect(deletes(), isEmpty);
    final call = calls.singleWhere((c) => c.method == 'setDescargado');
    expect(call.arguments, {'id': 'b', 'value': false});
  });

  testWidgets('«Descargar» sin carpeta pide elegirla', (tester) async {
    await pumpScreen(tester, [row('a', 'Primera', 1)]);

    await tester.tap(find.text('Descargar'));
    await tester.pump();

    expect(find.text('Elige primero la carpeta de descargas.'), findsOneWidget);
  });

  testWidgets('tocar una canción enseña la llamada que se le hará', (
    tester,
  ) async {
    await pumpScreen(tester, [row('a', 'Jardin con enanitos', 1)]);

    await tester.tap(find.text('Jardin con enanitos'));
    await tester.pumpAndSettle();

    expect(find.text('Llamada que hará «Descargar»'), findsOneWidget);
    expect(
      find.textContaining(
        "'http://pi-isaac.local:8010/download"
        "?artist=Artista&title=Jardin%20con%20enanitos'",
      ),
      findsOneWidget,
    );
  });
}
