
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

dynamic getPlatformFile(String path) {
  return File(path);
}

Future<String> savePlatformFile(List<int> bytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}

Future<void> sharePlatformFile(String path, {String? text}) async {
  await Share.shareXFiles([XFile(path)], text: text);
}

Future<Uint8List> readPlatformBytes(String path) async {
  return File(path).readAsBytes();
}

Future<String> createPlatformTempFile(List<int> bytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$fileName');
  await file.writeAsBytes(bytes);
  return file.path;
}
