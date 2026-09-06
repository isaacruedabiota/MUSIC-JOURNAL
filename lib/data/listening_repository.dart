import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/listening_entry.dart';
import '../models/track.dart';

/// Contrato de persistencia del historial de escuchas.
/// Abstracto para poder cambiar de motor o usar una version en memoria en tests.
abstract class ListeningRepository {
  Future<void> recordPlay(Track track, {DateTime? at});

  /// Todas las entradas, de la mas reciente a la mas antigua.
  Future<List<ListeningEntry>> allEntries();

  /// Ultimas [limit] entradas (para el diario).
  Future<List<ListeningEntry>> recentEntries({int limit = 200});

  /// ¿Ya existe alguna escucha de esta cancion? (para "¿ya la tengo?").
  Future<bool> hasTrack(String dedupeKey);

  /// Cuantas veces se ha escuchado esta cancion.
  Future<int> playCount(String dedupeKey);

  Future<void> clear();
}

/// Implementacion con SQLite (sqflite). Persiste en el dispositivo.
class SqfliteListeningRepository implements ListeningRepository {
  static const _dbName = 'music_journal.db';
  static const _table = 'listening_history';
  static const _dbVersion = 1;

  Database? _db;

  Future<Database> get _database async {
    return _db ??= await _open();
  }

  Future<Database> _open() async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_table (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            dedupe_key TEXT NOT NULL,
            title TEXT NOT NULL,
            artist TEXT NOT NULL,
            album TEXT,
            artwork_url TEXT,
            isrc TEXT,
            spotify_id TEXT,
            source TEXT NOT NULL DEFAULT 'spotify',
            played_at INTEGER NOT NULL
          )
        ''');
        // Indices para consultas rapidas por cancion y por fecha.
        await db.execute(
            'CREATE INDEX idx_dedupe ON $_table (dedupe_key)');
        await db.execute(
            'CREATE INDEX idx_played_at ON $_table (played_at)');
      },
    );
  }

  @override
  Future<void> recordPlay(Track track, {DateTime? at}) async {
    final db = await _database;
    final entry = ListeningEntry.fromTrack(track, at: at);
    await db.insert(_table, entry.toMap());
  }

  @override
  Future<List<ListeningEntry>> allEntries() async {
    final db = await _database;
    final rows = await db.query(_table, orderBy: 'played_at DESC');
    return rows.map(ListeningEntry.fromMap).toList();
  }

  @override
  Future<List<ListeningEntry>> recentEntries({int limit = 200}) async {
    final db = await _database;
    final rows =
        await db.query(_table, orderBy: 'played_at DESC', limit: limit);
    return rows.map(ListeningEntry.fromMap).toList();
  }

  @override
  Future<bool> hasTrack(String dedupeKey) async {
    return (await playCount(dedupeKey)) > 0;
  }

  @override
  Future<int> playCount(String dedupeKey) async {
    final db = await _database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM $_table WHERE dedupe_key = ?',
      [dedupeKey],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  @override
  Future<void> clear() async {
    final db = await _database;
    await db.delete(_table);
  }
}
