import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../utils/platform_utils.dart'; // PlatformUtils

class PdfGenerator {
  
  /// Resim LISTESINI alıp çok sayfalı PDF oluşturur ve Paylaşır
  static Future<void> createAndSharePdf(List<String> imagePaths, {String? password}) async {
    final pdf = pw.Document();

    // Listedeki her bir resim için döngü
    for (var path in imagePaths) {
      // PlatformUtils ile byte'ları oku
      final imageBytes = await PlatformUtils.readBytes(path);
      final image = pw.MemoryImage(imageBytes);

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain), // Sayfaya sığdır
            );
          },
        ),
      );
    }

    // PDF'i Kaydet (Web'de indirir, Mobilde kaydeder)
    final pdfBytes = await pdf.save();
    final savedPath = await PlatformUtils.saveFile(pdfBytes, "veloxdoc_belge.pdf");

    // Paylaş (Web'de indirme yeterli olabilir, mobilde share sheet)
    await PlatformUtils.shareFile(savedPath, text: "VeloxDoc ile oluşturulmuş ${imagePaths.length} sayfalık belge.");
  }
}