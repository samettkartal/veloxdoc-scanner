import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:uuid/uuid.dart';
import '../utils/pdf_generator.dart';
import 'edit_screen.dart';
import 'contrast_adjustment_screen.dart'; // Import eklendi
import 'package:flutter/services.dart'; // Clipboard için
import '../services/ad_service.dart'; // AdService eklendi

import '../services/storage_service.dart';
import '../models/document_model.dart';
import '../models/folder_model.dart';
import '../main.dart';
import '../utils/platform_utils.dart';
import '../utils/theme_manager.dart'; // ThemeManager eklendi



class PdfPreviewScreen extends StatefulWidget {
  final List<String> imagePaths;

  const PdfPreviewScreen({super.key, required this.imagePaths});

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  late List<String> _imagePaths;
  bool _isOcrLoading = false;

  @override
  void initState() {
    super.initState();
    _imagePaths = List.from(widget.imagePaths);
  }

  // --- PDF OLUŞTURMA ---
  Future<Uint8List> _generatePdf(PdfPageFormat format) async {
    final pdf = pw.Document();

    for (var path in _imagePaths) {
      pw.MemoryImage? image;
      try {
        final imageBytes = File(path).readAsBytesSync();
        if (imageBytes.isNotEmpty) {
           image = pw.MemoryImage(imageBytes);
        }
      } catch (e) {
        debugPrint("Error loading image for PDF: $e");
      }
      if (image == null) continue;


      pdf.addPage(
        pw.Page(
          // Kenar boşluklarını sıfırla, tam sayfa resim
          pageFormat: format.copyWith(marginTop: 0, marginBottom: 0, marginLeft: 0, marginRight: 0),
          build: (pw.Context context) {
            return pw.Center(child: pw.Image(image!, fit: pw.BoxFit.fill));
          },
        ),
      );
    }
    return pdf.save();
  }

  // --- PAYLAŞMA ---
  Future<void> _sharePdf() async {
    // İmzaları PDF'e ekleyerek oluştur
    final pdfBytes = await _generatePdf(PdfPageFormat.a4);
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/VeloxDoc_Imzali_Belge.pdf");
    await file.writeAsBytes(pdfBytes);
    
    await Share.shareXFiles(
      [XFile(file.path)],
      text: "VeloxDoc ile oluşturulmuş imzalı belge.",
    );
    
    // Show Ad after sharing
    AdService().showInterstitialAd();
  }



  // --- SAYFA DÜZENLEME (Çizim) ---
  void _showEditPageSelector() {
    final isDarkMode = ThemeManager.instance.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
               colors: isDarkMode 
                ? [const Color(0xFF2E2E3E), const Color(0xFF1A1A2E)] 
                : [Colors.white, const Color(0xFFF0F0F0)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Düzenlenecek Sayfayı Seçin",
                style: GoogleFonts.outfit(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 160, 
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagePaths.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context); 
                        _openEditor(index); // Direkt edit ekranını aç
                      },
                      child: Container(
                        width: 110,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDarkMode ? Colors.white30 : Colors.grey[300]!, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          color: isDarkMode ? Colors.black26 : Colors.white,
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_imagePaths[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                              child: Text(
                                "Sayfa ${index + 1}",
                                style: GoogleFonts.inter(color: isDarkMode ? Colors.white70 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Kapat", style: GoogleFonts.inter(color: isDarkMode ? Colors.white54 : Colors.black54)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- KONTRAST SEÇİMİ ---
  void _showContrastPageSelector() {
    final isDarkMode = ThemeManager.instance.isDarkMode;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
               colors: isDarkMode 
                ? [const Color(0xFF2E2E3E), const Color(0xFF1A1A2E)] 
                : [Colors.white, const Color(0xFFF0F0F0)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Kontrast Ayarı İçin Sayfa Seçin",
                style: GoogleFonts.outfit(color: isDarkMode ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),

              SizedBox(
                height: 160, 
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _imagePaths.length,
                  itemBuilder: (context, index) {
                    return GestureDetector(
                      onTap: () {
                        Navigator.pop(context); 
                        _openContrastAdjustment(index); // Kontrast ekranını aç
                      },
                      child: Container(
                        width: 110,
                        margin: const EdgeInsets.only(right: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: isDarkMode ? Colors.white30 : Colors.grey[300]!, width: 2),
                          borderRadius: BorderRadius.circular(12),
                          color: isDarkMode ? Colors.black26 : Colors.white,
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(_imagePaths[index]),
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                              child: Text(
                                "Sayfa ${index + 1}",
                                style: GoogleFonts.inter(color: isDarkMode ? Colors.white70 : Colors.black54, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text("Kapat", style: GoogleFonts.inter(color: isDarkMode ? Colors.white54 : Colors.black54)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openEditor(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditScreen(imagePath: _imagePaths[index]),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        _imagePaths[index] = result; // Düzenlenmiş resim yolu ile güncelle
      });
    }
  }

  // --- KONTRAST EKRANI AÇMA ---
  Future<void> _openContrastAdjustment(int index) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ContrastAdjustmentScreen(imagePath: _imagePaths[index]),
      ),
    );

    if (result != null && result is String) {
      setState(() {
        _imagePaths[index] = result; // Kontrastı ayarlanmış resim ile güncelle
      });
    }
  }

  Widget _buildActionBtn(BuildContext context, IconData icon, String label, String value, bool isDarkMode) {
    return GestureDetector(
      onTap: () => Navigator.pop(context, value),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.05) : Colors.grey[100],
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: const Color(0xFF213448), size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: GoogleFonts.inter(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // --- OCR İŞLEMİ ---
  Future<void> _performOcr() async {
    setState(() {
      _isOcrLoading = true;
    });

    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final StringBuffer fullText = StringBuffer();

    try {
      for (var path in _imagePaths) {
        final inputImage = InputImage.fromFilePath(path);
        final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
        fullText.writeln(recognizedText.text);
        fullText.writeln("\n--- Sayfa Sonu ---\n");
      }

      if (mounted) {
        final isDarkMode = ThemeManager.instance.isDarkMode;
        showDialog(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDarkMode 
                    ? [const Color(0xFF2E2E3E), const Color(0xFF1A1A2E)] 
                    : [Colors.white, const Color(0xFFF0F0F0)],
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Tanınan Metin (OCR)",
                    style: GoogleFonts.outfit(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.maxFinite,
                    constraints: const BoxConstraints(maxHeight: 300),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDarkMode ? Colors.black26 : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
                    ),
                    child: SingleChildScrollView(
                      child: Text(
                        fullText.toString().isEmpty ? "Metin bulunamadı." : fullText.toString(),
                        style: GoogleFonts.inter(color: isDarkMode ? Colors.white70 : Colors.black87, height: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Text("Kapat", style: GoogleFonts.inter(color: isDarkMode ? Colors.white54 : Colors.black54)),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                              Clipboard.setData(ClipboardData(text: fullText.toString()));
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Metin kopyalandı")),
                              );
                          },
                          icon: const Icon(Icons.copy, size: 18),
                          label: Text("Kopyala", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF213448),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("OCR hatası: $e")),
        );
      }
    } finally {
      setState(() {
        _isOcrLoading = false;
      });
      textRecognizer.close();
    }
  }

  // --- KLASÖRE KAYDETME ---
  Future<void> _saveToFolder() async {
    // Önce PDF'i oluştur
    final pdfBytes = await _generatePdf(PdfPageFormat.a4);
    final output = await getTemporaryDirectory();
    final fileName = "VeloxDoc_Belge_${const Uuid().v4()}.pdf";
    final file = File("${output.path}/$fileName");
    await file.writeAsBytes(pdfBytes);

    // Klasör seçimi için StorageService kullan
    final List<FolderModel> folders = storageService.getFolders();
    final isDarkMode = ThemeManager.instance.isDarkMode;

    if (!mounted) return;

    // Dosya Adı İste
    String? fileNameInput;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final TextEditingController _nameController = TextEditingController(text: "Yeni Belge");
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDarkMode 
                    ? [const Color(0xFF2E2E3E), const Color(0xFF1A1A2E)] 
                    : [Colors.white, const Color(0xFFF0F0F0)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
              ],
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "Dosya Adı",
                  style: GoogleFonts.outfit(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _nameController,
                  style: GoogleFonts.inter(color: isDarkMode ? Colors.white : Colors.black),
                  cursorColor: const Color(0xFF213448),
                  decoration: InputDecoration(
                    hintText: "Belge adı giriniz",
                    hintStyle: GoogleFonts.inter(color: isDarkMode ? Colors.white30 : Colors.black38),
                    filled: true,
                    fillColor: isDarkMode ? Colors.black26 : Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF213448)),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text("İptal", style: GoogleFonts.inter(color: isDarkMode ? Colors.white54 : Colors.black54)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          if (_nameController.text.trim().isNotEmpty) {
                            fileNameInput = _nameController.text.trim();
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF213448),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        child: Text("Devam", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    if (fileNameInput == null) return; // İptal edildi

    // Klasör seçimi
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
               colors: isDarkMode 
                    ? [const Color(0xFF2E2E3E), const Color(0xFF1A1A2E)] 
                    : [Colors.white, const Color(0xFFF0F0F0)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Klasör Seçin",
                style: GoogleFonts.outfit(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 200,
                width: double.maxFinite,
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: folders.length,
                  separatorBuilder: (c, i) => Divider(color: isDarkMode ? Colors.white10 : Colors.grey[300], height: 1),
                  itemBuilder: (context, index) {
                    final folder = folders[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(folder.colorValue).withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.folder, color: Color(folder.colorValue)),
                      ),
                      title: Text(
                        folder.name, 
                        style: GoogleFonts.inter(color: isDarkMode ? Colors.white : Colors.black, fontWeight: FontWeight.w500)
                      ),
                      onTap: () async {
                        Navigator.pop(context); // Dialog'u kapat
                        
                        // Belgeyi Kalıcı Hafızaya Taşı
                        final permanentPath = await storageService.saveFilePermanently(file);

                        final newDocument = DocumentModel(
                          id: const Uuid().v4(),
                          title: fileNameInput!,
                          path: permanentPath,
                          date: DateTime.now(),
                        );

                        await storageService.addDocument(folder.id, newDocument);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("Belge başarıyla kaydedildi!")),
                          );
                          
                          // Show Interstitial Ad (Trigger)
                          debugPrint("PdfPreviewScreen: Requesting Interstitial Ad");
                          AdService().showInterstitialAd();
                          
                          Navigator.popUntil(context, (route) => route.isFirst);
                        }
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    backgroundColor: Colors.white.withOpacity(0.05),
                  ),
                  child: Text("İptal", style: GoogleFonts.inter(color: Colors.white54)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeManager.instance,
      builder: (context, isDarkMode, child) {
        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          appBar: AppBar(
            title: Text("Onayla", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            foregroundColor: isDarkMode ? Colors.white : Colors.black,
            elevation: 0,
            iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
          ),
          body: Column(
            children: [
              // 1. PDF Önizleme
              Expanded(
                child: PdfPreview(
                  build: (format) => _generatePdf(format),
                  canChangeOrientation: false,
                  canChangePageFormat: false,
                  useActions: false, 
                  loadingWidget: const Center(child: CircularProgressIndicator(color: Color(0xFF213448))),
                  padding: const EdgeInsets.all(0), 
                ),
              ),

              // 2. Alt Kontrol Paneli (Modern Bottom Bar)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDarkMode ? Colors.black : Colors.white,
                  border: Border(top: BorderSide(color: isDarkMode ? Colors.white10 : Colors.black12)),
                  boxShadow: [
                    if (!isDarkMode)
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -4))
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Üst Sıra Butonlar (Düzenle, Kontrast, OCR)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildIconButton(Icons.edit, "Düzenle", _showEditPageSelector, isDarkMode: isDarkMode),
                        _buildIconButton(Icons.contrast, "Kontrast", _showContrastPageSelector, isDarkMode: isDarkMode),
                        _buildIconButton(Icons.text_fields, "OCR", _performOcr, isLoading: _isOcrLoading, isDarkMode: isDarkMode),
                      ],
                    ),
                    const SizedBox(height: 20),
                    // Alt Sıra Butonlar (Kaydet, Paylaş)
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _saveToFolder,
                            icon: Icon(Icons.folder_open, color: isDarkMode ? Colors.white : Colors.black),
                            label: Text("Klasöre Kaydet", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: BorderSide(color: isDarkMode ? Colors.white54 : Colors.black12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _sharePdf,
                            icon: const Icon(Icons.share, color: Colors.white),
                            label: const Text("Paylaş", style: TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF213448),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildIconButton(IconData icon, String label, VoidCallback onTap, {bool isLoading = false, required bool isDarkMode}) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: isLoading 
              ? SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: isDarkMode ? Colors.white : Colors.black))
              : Icon(icon, color: isDarkMode ? Colors.white : Colors.black, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: isDarkMode ? Colors.white70 : Colors.black54, fontSize: 12)),
        ],
      ),
    );
  }
}