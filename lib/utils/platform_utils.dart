
import 'platform_utils_io.dart' if (dart.library.html) 'platform_utils_web.dart';
import 'dart:typed_data';

class PlatformUtils {
  /// Dosya yolundan dosya nesnesi döndürür (Web'de null veya dummy dönebilir)
  static dynamic getFile(String path) => getPlatformFile(path);

  /// Dosyayı kaydeder (Web'de indirir, Mobilde kaydeder)
  static Future<String> saveFile(List<int> bytes, String fileName) => savePlatformFile(bytes, fileName);

  /// Paylaşım yapar (Web'de indirir, Mobilde share sheet açar)
  static Future<void> shareFile(String path, {String? text}) => sharePlatformFile(path, text: text);

  /// Dosyayı byte olarak okur
  static Future<Uint8List> readBytes(String path) => readPlatformBytes(path);

  /// Geçici dosya oluşturur (Web'de Blob URL, Mobilde temp file)
  static Future<String> createTempFile(List<int> bytes, String fileName) => createPlatformTempFile(bytes, fileName);
}
