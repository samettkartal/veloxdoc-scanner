
import 'dart:html' as html;
import 'dart:typed_data';

dynamic getPlatformFile(String path) {
  // Web'de File nesnesi dart:io'daki gibi çalışmaz.
  // Genellikle path bir blob URL'dir veya dummy'dir.
  return null; 
}

Future<String> savePlatformFile(List<int> bytes, String fileName) async {
  // Web'de dosyayı indirme işlemi başlatır
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute("download", fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
  return url; // Web'de path yerine URL dönüyoruz
}

Future<void> sharePlatformFile(String path, {String? text}) async {
  // Web'de share API'si kısıtlıdır, genellikle indirme yeterlidir.
  // Eğer path bir blob URL ise zaten indirilmiştir veya erişilebilir.
  // Burada basitçe konsola yazabiliriz veya kullanıcıya link gösterebiliriz.
  print("Web share not fully supported, file should be downloaded: $path");
}

Future<Uint8List> readPlatformBytes(String path) async {
  // Web'de path genellikle bir blob URL'dir.
  // Blob URL'den veriyi okumak için HttpRequest kullanabiliriz.
  final request = await html.HttpRequest.request(path, responseType: 'arraybuffer');
  final response = request.response as ByteBuffer;
  return response.asUint8List();
}

Future<String> createPlatformTempFile(List<int> bytes, String fileName) async {
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  return html.Url.createObjectUrlFromBlob(blob);
}
