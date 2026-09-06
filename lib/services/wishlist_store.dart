import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/wishlist_item.dart';

/// Persiste la lista de deseos en un JSON dentro del directorio de la app.
class WishlistStore {
  static const _fileName = 'wishlist.json';

  Future<File> _file() async {
    final base = await getApplicationDocumentsDirectory();
    return File(p.join(base.path, _fileName));
  }

  Future<List<WishlistItem>> load() async {
    final file = await _file();
    if (!await file.exists()) return [];
    try {
      final raw = jsonDecode(await file.readAsString()) as List;
      return raw
          .map((e) => WishlistItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> save(List<WishlistItem> items) async {
    final file = await _file();
    await file.writeAsString(jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}
