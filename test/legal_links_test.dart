import 'package:flutter_test/flutter_test.dart';
import 'package:music_journal/services/legal_links.dart';

void main() {
  group('LegalLinks.spotify', () {
    test('usa el id exacto si es un uri de track', () {
      final url = LegalLinks.spotify('spotify:track:abc123', 'Queen', 'Bohemian');
      expect(url, 'https://open.spotify.com/track/abc123');
    });

    test('cae a busqueda si no hay id valido', () {
      final url = LegalLinks.spotify(null, 'Queen', 'Bohemian Rhapsody');
      expect(url, startsWith('https://open.spotify.com/search/'));
      expect(url, contains('Queen'));
      expect(url, contains('Bohemian'));
    });

    test('cae a busqueda si el id no es de track', () {
      final url = LegalLinks.spotify('spotify:album:xyz', 'A', 'B');
      expect(url, startsWith('https://open.spotify.com/search/'));
    });
  });

  group('URLs de tiendas', () {
    test('bandcamp construye una busqueda', () {
      final url = LegalLinks.bandcamp('Nirvana', 'Come as You Are');
      expect(url, startsWith('https://bandcamp.com/search?q='));
      expect(url, contains('Nirvana'));
    });

    test('apple music', () {
      final url = LegalLinks.appleMusic('Adele', 'Hello');
      expect(url, startsWith('https://music.apple.com/search?term='));
    });

    test('youtube music', () {
      final url = LegalLinks.youtubeMusic('Daft Punk', 'One More Time');
      expect(url, startsWith('https://music.youtube.com/search?q='));
    });

    test('codifica correctamente espacios y caracteres', () {
      final url = LegalLinks.bandcamp('AC/DC', 'Back in Black');
      // La barra de AC/DC debe ir codificada, no romper la URL.
      expect(url, isNot(contains('AC/DC')));
      expect(url, contains('AC%2FDC'));
    });
  });

  group('legalDestinationsFor', () {
    test('devuelve los 4 destinos en orden', () {
      final dests = legalDestinationsFor(artist: 'X', title: 'Y');
      expect(dests.map((d) => d.label).toList(),
          ['Spotify', 'Bandcamp', 'Apple Music', 'YouTube Music']);
    });
  });
}
