import 'package:flutter/foundation.dart';

import '../models/listening_entry.dart';
import '../models/wishlist_item.dart';
import '../services/wishlist_store.dart';

/// Estado de la lista de deseos: canciones que el usuario quiere conseguir
/// por vias legales.
class WishlistProvider extends ChangeNotifier {
  final WishlistStore _store;

  WishlistProvider([WishlistStore? store]) : _store = store ?? WishlistStore();

  List<WishlistItem> _items = [];
  List<WishlistItem> get items => _items;

  Future<void> load() async {
    _items = await _store.load();
    notifyListeners();
  }

  bool contains(String dedupeKey) =>
      _items.any((i) => i.dedupeKey == dedupeKey);

  /// Anade o quita una entrada del historial de la lista de deseos.
  Future<void> toggleEntry(ListeningEntry entry) async {
    if (contains(entry.dedupeKey)) {
      await removeByKey(entry.dedupeKey);
    } else {
      _items = [WishlistItem.fromEntry(entry), ..._items];
      await _store.save(_items);
      notifyListeners();
    }
  }

  Future<void> removeByKey(String dedupeKey) async {
    _items = _items.where((i) => i.dedupeKey != dedupeKey).toList();
    await _store.save(_items);
    notifyListeners();
  }
}
