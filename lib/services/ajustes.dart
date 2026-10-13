import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ajustes de la app: solo la carpeta donde se guardan las descargas. Se
/// conserva al instalar versiones nuevas.
class Ajustes extends ChangeNotifier {
  Ajustes._(this._prefs);

  static Future<Ajustes> cargar() async =>
      Ajustes._(await SharedPreferences.getInstance());

  static const _nativo = MethodChannel('musiclist/downloads');

  final SharedPreferences _prefs;

  /// Carpeta de descargas elegida con el selector del sistema (URI de
  /// Android) y su nombre legible. `null` si aún no se ha elegido.
  String? get carpetaUri => _prefs.getString('carpetaUri');
  String? get carpetaNombre => _prefs.getString('carpetaNombre');

  /// Abre el selector de carpetas del sistema y guarda la elegida.
  Future<void> elegirCarpeta() async {
    final carpeta = await _nativo.invokeMapMethod<String, String>('pickFolder');
    if (carpeta == null) return; // cancelado
    await _prefs.setString('carpetaUri', carpeta['uri']!);
    await _prefs.setString('carpetaNombre', carpeta['name']!);
    notifyListeners();
  }
}
