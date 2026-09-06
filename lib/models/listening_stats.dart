import 'listening_entry.dart';

/// Un elemento de un ranking (una cancion o un artista) con su numero de plays.
class Ranked {
  final String label;
  final String? sublabel;
  final String? artworkUrl;
  final int plays;

  const Ranked({
    required this.label,
    this.sublabel,
    this.artworkUrl,
    required this.plays,
  });
}

/// Estadisticas agregadas del historial de escuchas.
///
/// Se calcula entero con la funcion pura [ListeningStats.from], que no depende
/// de la base de datos ni de Flutter -> facil de testear.
class ListeningStats {
  final int totalPlays;
  final int uniqueTracks;
  final int uniqueArtists;

  final List<Ranked> topTracks;
  final List<Ranked> topArtists;

  /// Plays por hora del dia (indice 0..23).
  final List<int> playsByHour;

  /// Plays por dia de la semana (indice 0 = lunes ... 6 = domingo).
  final List<int> playsByWeekday;

  final DateTime? firstListen;
  final DateTime? lastListen;

  const ListeningStats({
    required this.totalPlays,
    required this.uniqueTracks,
    required this.uniqueArtists,
    required this.topTracks,
    required this.topArtists,
    required this.playsByHour,
    required this.playsByWeekday,
    this.firstListen,
    this.lastListen,
  });

  static const empty = ListeningStats(
    totalPlays: 0,
    uniqueTracks: 0,
    uniqueArtists: 0,
    topTracks: [],
    topArtists: [],
    playsByHour: [],
    playsByWeekday: [],
  );

  bool get isEmpty => totalPlays == 0;

  /// Calcula todas las metricas a partir de la lista de eventos de escucha.
  /// [topN] limita el tamano de los rankings.
  factory ListeningStats.from(List<ListeningEntry> entries, {int topN = 5}) {
    if (entries.isEmpty) return empty;

    // Acumuladores por cancion (por dedupeKey) y por artista.
    final trackPlays = <String, int>{};
    final trackInfo = <String, ListeningEntry>{};
    final artistPlays = <String, int>{};

    final byHour = List<int>.filled(24, 0);
    final byWeekday = List<int>.filled(7, 0);

    DateTime? first;
    DateTime? last;

    for (final e in entries) {
      // Rankings.
      trackPlays.update(e.dedupeKey, (v) => v + 1, ifAbsent: () => 1);
      trackInfo.putIfAbsent(e.dedupeKey, () => e);

      final artistKey = e.artist.trim().toLowerCase();
      artistPlays.update(artistKey, (v) => v + 1, ifAbsent: () => 1);

      // Distribuciones temporales.
      byHour[e.playedAt.hour] += 1;
      byWeekday[e.playedAt.weekday - 1] += 1; // DateTime.monday == 1

      // Rango temporal.
      if (first == null || e.playedAt.isBefore(first)) first = e.playedAt;
      if (last == null || e.playedAt.isAfter(last)) last = e.playedAt;
    }

    // Ranking de canciones.
    final topTracks = trackPlays.entries
        .map((kv) {
          final info = trackInfo[kv.key]!;
          return Ranked(
            label: info.title,
            sublabel: info.artist,
            artworkUrl: info.artworkUrl,
            plays: kv.value,
          );
        })
        .toList()
      ..sort((a, b) => b.plays.compareTo(a.plays));

    // Ranking de artistas (usamos el nombre "bonito" del primer evento visto).
    final artistDisplay = <String, String>{};
    for (final e in entries) {
      artistDisplay.putIfAbsent(e.artist.trim().toLowerCase(), () => e.artist);
    }
    final topArtists = artistPlays.entries
        .map((kv) => Ranked(label: artistDisplay[kv.key] ?? kv.key, plays: kv.value))
        .toList()
      ..sort((a, b) => b.plays.compareTo(a.plays));

    return ListeningStats(
      totalPlays: entries.length,
      uniqueTracks: trackPlays.length,
      uniqueArtists: artistPlays.length,
      topTracks: topTracks.take(topN).toList(),
      topArtists: topArtists.take(topN).toList(),
      playsByHour: byHour,
      playsByWeekday: byWeekday,
      firstListen: first,
      lastListen: last,
    );
  }
}
