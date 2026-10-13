import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:musiclist/services/ajustes.dart';
import 'package:musiclist/services/track_repository.dart';
import 'package:musiclist/ui/llamada_sheet.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const tracksChannel = MethodChannel('musiclist/tracks');
  const downloadsChannel = MethodChannel('musiclist/downloads');
  const updatesChannel = EventChannel('musiclist/track_updates');
  final messenger =
      TestWidgetsFlutterBinding.ensureInitialized().defaultBinaryMessenger;

  late List<MethodCall> calls;

  /// Pinta el panel de «Jardin con enanitos»; [descarga] simula la parte
  /// nativa (devuelve el nombre del archivo o lanza el error).
  Future<TrackRepository> pumpSheet(
    WidgetTester tester, {
    Map<String, Object> prefs = const {
      'carpetaUri': 'content://carpeta',
      'carpetaNombre': 'Music',
    },
    Future<Object?> Function()? descarga,
  }) async {
    calls = [];
    messenger
      ..setMockMethodCallHandler(tracksChannel, (call) async {
        calls.add(call);
        return call.method == 'getAll'
            ? [
                {
                  'id': 'a',
                  'title': 'Jardin con enanitos',
                  'artist': 'Melendi',
                  'coverPath': null,
                  'detectedAt': 0,
                  'descargado': false,
                },
              ]
            : null;
      })
      ..setMockMethodCallHandler(downloadsChannel, (call) async {
        calls.add(call);
        return descarga?.call();
      })
      ..setMockStreamHandler(
        updatesChannel,
        MockStreamHandler.inline(onListen: (_, _) {}),
      );
    addTearDown(() {
      messenger
        ..setMockMethodCallHandler(tracksChannel, null)
        ..setMockMethodCallHandler(downloadsChannel, null)
        ..setMockStreamHandler(updatesChannel, null);
    });

    final repository = TrackRepository();
    addTearDown(repository.dispose);
    await repository.load();
    SharedPreferences.setMockInitialValues(prefs);
    final ajustes = await Ajustes.cargar();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LlamadaSheet(
            track: repository.tracks.single,
            repository: repository,
            ajustes: ajustes,
          ),
        ),
      ),
    );
    return repository;
  }

  testWidgets('enseña la llamada exacta, como el curl del ejemplo', (
    tester,
  ) async {
    await pumpSheet(tester);

    expect(
      find.text(
        "curl -X 'POST' \\\n"
        "  'http://pi-isaac.local:8010/download?artist=Melendi&title=Jardin%20con%20enanitos' \\\n"
        "  -H 'accept: */*' \\\n"
        "  -d ''",
      ),
      findsOneWidget,
    );
  });

  testWidgets('«Descargar esta canción» la descarga y la marca', (
    tester,
  ) async {
    final repository = await pumpSheet(
      tester,
      descarga: () async => 'Melendi - Jardin con enanitos.mp3',
    );

    await tester.tap(find.text('Descargar esta canción'));
    await tester.pumpAndSettle();

    expect(find.text('Resultado: correcto'), findsOneWidget);
    expect(
      find.text('Guardada en Music como «Melendi - Jardin con enanitos.mp3».'),
      findsOneWidget,
    );
    expect(repository.tracks.single.descargado, isTrue);
  });

  testWidgets('si falla, enseña el motivo y no la marca', (tester) async {
    final repository = await pumpSheet(
      tester,
      descarga: () async => throw PlatformException(
        code: 'DOWNLOAD',
        message: 'No se encuentra pi-isaac.local en la red.',
      ),
    );

    await tester.tap(find.text('Descargar esta canción'));
    await tester.pumpAndSettle();

    expect(find.text('Resultado: error'), findsOneWidget);
    expect(
      find.text('No se encuentra pi-isaac.local en la red.'),
      findsOneWidget,
    );
    expect(repository.tracks.single.descargado, isFalse);
  });

  testWidgets('sin carpeta pide elegirla y no deja descargar', (tester) async {
    await pumpSheet(tester, prefs: {});

    expect(
      find.text('Elige primero la carpeta de descargas en Ajustes.'),
      findsOneWidget,
    );
    final boton = tester.widget<ButtonStyleButton>(
      find.ancestor(
        of: find.text('Descargar esta canción'),
        matching: find.bySubtype<ButtonStyleButton>(),
      ),
    );
    expect(boton.onPressed, isNull);
  });
}
