import 'package:flutter_test/flutter_test.dart';
import 'package:music_journal/models/listening_entry.dart';
import 'package:music_journal/models/listening_stats.dart';

ListeningEntry entry({
  required String key,
  required String title,
  required String artist,
  required DateTime at,
}) {
  return ListeningEntry(
    dedupeKey: key,
    title: title,
    artist: artist,
    album: '',
    playedAt: at,
  );
}

void main() {
  group('ListeningStats.from', () {
    test('lista vacia -> stats vacias', () {
      final s = ListeningStats.from([]);
      expect(s.isEmpty, isTrue);
      expect(s.totalPlays, 0);
    });

    test('cuenta plays totales, canciones y artistas unicos', () {
      final entries = [
        entry(key: 'a', title: 'A', artist: 'Queen', at: DateTime(2026, 7, 1, 10)),
        entry(key: 'a', title: 'A', artist: 'Queen', at: DateTime(2026, 7, 1, 11)),
        entry(key: 'b', title: 'B', artist: 'Queen', at: DateTime(2026, 7, 2, 9)),
        entry(key: 'c', title: 'C', artist: 'Bowie', at: DateTime(2026, 7, 2, 9)),
      ];
      final s = ListeningStats.from(entries);

      expect(s.totalPlays, 4);
      expect(s.uniqueTracks, 3); // a, b, c
      expect(s.uniqueArtists, 2); // Queen, Bowie
    });

    test('topTracks ordenado por numero de plays descendente', () {
      final entries = [
        entry(key: 'a', title: 'A', artist: 'X', at: DateTime(2026, 7, 1, 10)),
        entry(key: 'a', title: 'A', artist: 'X', at: DateTime(2026, 7, 1, 11)),
        entry(key: 'a', title: 'A', artist: 'X', at: DateTime(2026, 7, 1, 12)),
        entry(key: 'b', title: 'B', artist: 'Y', at: DateTime(2026, 7, 1, 13)),
      ];
      final s = ListeningStats.from(entries);

      expect(s.topTracks.first.label, 'A');
      expect(s.topTracks.first.plays, 3);
      expect(s.topTracks[1].label, 'B');
      expect(s.topTracks[1].plays, 1);
    });

    test('topArtists agrupa por artista (insensible a mayusculas)', () {
      final entries = [
        entry(key: 'a', title: 'A', artist: 'Queen', at: DateTime(2026, 7, 1, 10)),
        entry(key: 'b', title: 'B', artist: 'QUEEN', at: DateTime(2026, 7, 1, 11)),
        entry(key: 'c', title: 'C', artist: 'Bowie', at: DateTime(2026, 7, 1, 12)),
      ];
      final s = ListeningStats.from(entries);

      expect(s.topArtists.first.plays, 2); // Queen + QUEEN
      expect(s.topArtists.first.label.toLowerCase(), 'queen');
    });

    test('playsByHour reparte por hora del dia', () {
      final entries = [
        entry(key: 'a', title: 'A', artist: 'X', at: DateTime(2026, 7, 1, 9)),
        entry(key: 'b', title: 'B', artist: 'X', at: DateTime(2026, 7, 1, 9)),
        entry(key: 'c', title: 'C', artist: 'X', at: DateTime(2026, 7, 1, 22)),
      ];
      final s = ListeningStats.from(entries);

      expect(s.playsByHour.length, 24);
      expect(s.playsByHour[9], 2);
      expect(s.playsByHour[22], 1);
      expect(s.playsByHour[0], 0);
    });

    test('playsByWeekday usa indice 0=lunes', () {
      // 2026-07-01 es miercoles (weekday 3 -> indice 2).
      final entries = [
        entry(key: 'a', title: 'A', artist: 'X', at: DateTime(2026, 7, 1, 9)),
      ];
      final s = ListeningStats.from(entries);

      expect(s.playsByWeekday.length, 7);
      expect(s.playsByWeekday[2], 1); // miercoles
      expect(s.playsByWeekday[0], 0); // lunes
    });

    test('firstListen y lastListen abarcan el rango completo', () {
      final entries = [
        entry(key: 'a', title: 'A', artist: 'X', at: DateTime(2026, 7, 5, 12)),
        entry(key: 'b', title: 'B', artist: 'X', at: DateTime(2026, 7, 1, 8)),
        entry(key: 'c', title: 'C', artist: 'X', at: DateTime(2026, 7, 3, 20)),
      ];
      final s = ListeningStats.from(entries);

      expect(s.firstListen, DateTime(2026, 7, 1, 8));
      expect(s.lastListen, DateTime(2026, 7, 5, 12));
    });

    test('topN limita el tamano de los rankings', () {
      final entries = [
        for (var i = 0; i < 10; i++)
          entry(
              key: 'k$i',
              title: 'T$i',
              artist: 'Art$i',
              at: DateTime(2026, 7, 1, 10)),
      ];
      final s = ListeningStats.from(entries, topN: 3);

      expect(s.topTracks.length, 3);
      expect(s.topArtists.length, 3);
    });
  });
}
