// Block 4.2b: pure-logic tests for the profile photo gallery.

import 'package:flutter_test/flutter_test.dart';

import 'package:ecora/main.dart';

void main() {
  group('contentTypeForFileName', () {
    test('jpeg extensions map to image/jpeg', () {
      expect(contentTypeForFileName('foto.jpg'), 'image/jpeg');
      expect(contentTypeForFileName('foto.jpeg'), 'image/jpeg');
      expect(contentTypeForFileName('FOTO.JPG'), 'image/jpeg');
    });

    test('png and webp map to their mime types (case-insensitive)', () {
      expect(contentTypeForFileName('img.png'), 'image/png');
      expect(contentTypeForFileName('img.PNG'), 'image/png');
      expect(contentTypeForFileName('img.webp'), 'image/webp');
    });

    test('unknown or missing extension falls back to image/jpeg', () {
      expect(contentTypeForFileName('senza_estensione'), 'image/jpeg');
      expect(contentTypeForFileName('strano.gif'), 'image/jpeg');
      expect(contentTypeForFileName(''), 'image/jpeg');
    });
  });

  group('ProfilePhoto', () {
    test('holds bucket path and signed url', () {
      final photo = ProfilePhoto(
          path: 'uid1/123_a.jpg', url: 'https://example.com/signed');
      expect(photo.path, 'uid1/123_a.jpg');
      expect(photo.url, 'https://example.com/signed');
    });
  });

  test('gallery cap is 6 photos', () {
    expect(EcoraDataService.maxProfilePhotos, 6);
  });
}
