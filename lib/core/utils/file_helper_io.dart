import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

Uint8List? readFileBytesSync(String path) {
  try {
    final file = File(path);
    if (file.existsSync()) {
      return file.readAsBytesSync();
    }
  } catch (_) {}
  return null;
}

Future<String?> saveFileToDisk(Uint8List bytes, String fileName) async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes);
    return file.path;
  } catch (_) {
    return null;
  }
}
