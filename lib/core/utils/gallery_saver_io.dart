import 'dart:typed_data';
import 'package:gal/gal.dart';

class GallerySaver {
  static bool get isSupported => true;

  static Future<bool> saveImageBytes(Uint8List bytes, {required String name}) async {
    try {
      await Gal.putImageBytes(bytes, name: name);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openGallery() async {
    try {
      await Gal.open();
    } catch (_) {}
  }
}
