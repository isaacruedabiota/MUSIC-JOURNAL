import 'package:flutter_test/flutter_test.dart';
import 'package:music_journal/models/archive_item.dart';

void main() {
  group('isOpenLicenseUrl', () {
    test('Creative Commons -> true', () {
      expect(
          isOpenLicenseUrl('https://creativecommons.org/licenses/by/4.0/'),
          isTrue);
    });
    test('dominio publico -> true', () {
      expect(
          isOpenLicenseUrl('https://creativecommons.org/publicdomain/zero/1.0/'),
          isTrue);
    });
    test('null o vacio -> false', () {
      expect(isOpenLicenseUrl(null), isFalse);
      expect(isOpenLicenseUrl(''), isFalse);
    });
    test('licencia no libre -> false', () {
      expect(isOpenLicenseUrl('https://ejemplo.com/todos-los-derechos'), isFalse);
    });
  });

  group('licenseLabelFor', () {
    test('extrae el tipo de CC', () {
      expect(licenseLabelFor('https://creativecommons.org/licenses/by-sa/4.0/'),
          'CC BY-SA');
    });
    test('dominio publico', () {
      expect(
          licenseLabelFor('https://creativecommons.org/publicdomain/mark/1.0/'),
          'Dominio publico');
    });
    test('desconocida', () {
      expect(licenseLabelFor(null), 'Licencia desconocida');
    });
  });

  group('isAudioFileName', () {
    test('detecta extensiones de audio', () {
      expect(isAudioFileName('cancion.mp3'), isTrue);
      expect(isAudioFileName('CANCION.FLAC'), isTrue);
      expect(isAudioFileName('audio.ogg'), isTrue);
    });
    test('rechaza no-audio', () {
      expect(isAudioFileName('portada.jpg'), isFalse);
      expect(isAudioFileName('info.txt'), isFalse);
    });
  });

  group('ArchiveItem.fromSearchDoc', () {
    test('parsea campos y toma el primer valor de listas', () {
      final item = ArchiveItem.fromSearchDoc({
        'identifier': 'abc123',
        'title': 'Mi cancion',
        'creator': ['Artista Uno', 'Artista Dos'],
        'year': '2011',
        'licenseurl': 'https://creativecommons.org/licenses/by/4.0/',
      });
      expect(item, isNotNull);
      expect(item!.identifier, 'abc123');
      expect(item.title, 'Mi cancion');
      expect(item.creator, 'Artista Uno');
      expect(item.year, '2011');
      expect(item.isOpenLicense, isTrue);
      expect(item.licenseLabel, 'CC BY');
    });

    test('devuelve null sin identifier', () {
      expect(ArchiveItem.fromSearchDoc({'title': 'x'}), isNull);
    });

    test('usa el identifier como titulo si falta title', () {
      final item = ArchiveItem.fromSearchDoc({'identifier': 'only-id'});
      expect(item!.title, 'only-id');
      expect(item.creator, '');
    });
  });
}
