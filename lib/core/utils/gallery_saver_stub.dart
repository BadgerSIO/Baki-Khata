import 'dart:typed_data';

class GallerySaver {
  static bool get isSupported => false;

  static Future<bool> saveImageBytes(Uint8List bytes, {required String name}) async {
    return false;
  }

  static Future<void> openGallery() async {}
}
