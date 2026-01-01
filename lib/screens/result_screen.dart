import 'dart:io' show File; // Sadece File tipi için, kIsWeb kontrolü ile kullanılacak
import 'package:flutter/foundation.dart'; // kIsWeb için
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:uuid/uuid.dart';
import '../utils/pdf_generator.dart';
import 'edit_screen.dart';
import '../services/storage_service.dart';
import '../models/document_model.dart';
import '../models/folder_model.dart';
import '../main.dart'; // storageService erişimi için
import '../utils/platform_utils.dart'; // PlatformUtils eklendi
import '../utils/ui_utils.dart'; // ui_utils eklendi
import '../utils/theme_manager.dart'; // ThemeManager eklendi
import '../services/ad_service.dart'; // AdService eklendi

class ResultScreen extends StatefulWidget {
  final String imagePath;

  const ResultScreen({super.key, required this.imagePath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late String _currentImagePath;
  String _text = "";
  bool _scanning = false;
  bool _isPdfGenerating = false;

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.imagePath;
    // Preload Interstitial Ad
    AdService().loadInterstitialAd();
  }

  // Metin Okuma (OCR) İşlemi
  Future<void> _scanText() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Metin okuma özelliği Web'de desteklenmemektedir.")),
      );
      return;
    }

    setState(() => _scanning = true);
    try {
      final inputImage = InputImage.fromFilePath(_currentImagePath);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);

      setState(() {
        _text = recognizedText.text;
      });

      textRecognizer.close();
      _showResultSheet();
    } catch (e) {
      debugPrint("OCR Hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Metin okunamadı!")));
    } finally {
      setState(() => _scanning = false);
    }
  }

  // PDF Paylaşma İşlemi
  Future<void> _sharePdf() async {
    setState(() => _isPdfGenerating = true);
    try {
      await PdfGenerator.createAndSharePdf([_currentImagePath]); 
    } catch (e) {
      debugPrint("PDF Hatası: $e");
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF oluşturulamadı!")));
    } finally {
      setState(() => _isPdfGenerating = false);
    }
  }

  // Klasöre Kaydetme İşlemi
  Future<void> _saveToFolder() async {
    final List<FolderModel> folders = storageService.getFolders();
    
    await showDialog(
      context: context,
      builder: (context) {
        final isDarkMode = ThemeManager.instance.isDarkMode;
        return AlertDialog(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text("Klasöre Kaydet", style: GoogleFonts.outfit(color: isDarkMode ? Colors.white : Colors.black)),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: folders.length,
              itemBuilder: (context, index) {
                final folder = folders[index];
                return ListTile(
                  leading: Icon(Icons.folder, color: const Color(0xFF547792)), // Medium Slate universally for folders in list
                  title: Text(folder.name, style: TextStyle(color: isDarkMode ? Colors.white : const Color(0xFF213448))),
                  onTap: () async {
                    // Belgeyi Kalıcı Hafızaya Taşı
                    final permanentPath = await storageService.saveFilePermanently(File(_currentImagePath));

                    // Belgeyi Oluştur
                    final newDoc = DocumentModel(
                      id: const Uuid().v4(),
                      path: permanentPath,
                      date: DateTime.now(),
                      title: "Belge ${DateTime.now().hour}:${DateTime.now().minute}",
                    );
                    
                    // Klasöre Ekle
                    await storageService.addDocument(folder.id, newDoc);
                    
                    if (mounted) {
                      Navigator.pop(context); // Dialog'u kapat
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("${folder.name} klasörüne kaydedildi!")),
                      );
                      
                      // Show Interstitial Ad
                      AdService().showInterstitialAd();
                      
                      // İstersen ana ekrana dön: Navigator.pop(context);
                    }
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  // Düzenleme Ekranına Git
  Future<void> _openEditor() async {
    final newPath = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => EditScreen(imagePath: _currentImagePath)),
    );

    if (newPath != null) {
      setState(() {
        _currentImagePath = newPath;
      });
    }
  }

  void _showResultSheet() {
    final isDarkMode = ThemeManager.instance.isDarkMode;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, controller) => Container(
          padding: const EdgeInsets.all(24),
          child: ListView(
            controller: controller,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              Text("Okunan Metin", style: GoogleFonts.outfit(color: isDarkMode ? Colors.white : Colors.black, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SelectableText(_text.isEmpty ? "Metin bulunamadı." : _text, style: GoogleFonts.inter(color: isDarkMode ? Colors.white70 : Colors.black87, fontSize: 16, height: 1.5)),
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
          body: Container(
            decoration: BoxDecoration(
              gradient: isDarkMode
                  ? const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2E2E3E), Color(0xFF1A1A2E)], // Match HomeScreen Dark
                    )
                  : const LinearGradient(
                      begin: Alignment.topLeft, // Match HomeScreen Light direction
                      end: Alignment.bottomRight,
                      colors: [Colors.white, Color(0xFFF0F0F0)], // Match HomeScreen Light
                    ),
            ),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Container(
                  margin: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF213448).withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: buildImage(_currentImagePath, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            
            // Alt Kontrol Paneli
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDarkMode ? const Color(0xFF213448).withOpacity(0.9) : Colors.white.withOpacity(0.9), // More opaque background
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border(top: BorderSide(color: isDarkMode ? Colors.white10 : Colors.black12)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.folder_open_rounded,
                          label: "Klasöre Kaydet",
                          onPressed: _saveToFolder,
                          isPrimary: false,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.picture_as_pdf_rounded,
                          label: "PDF Paylaş",
                          onPressed: _isPdfGenerating ? null : _sharePdf,
                          isPrimary: false,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: _buildActionButton(
                      icon: Icons.text_fields_rounded,
                      label: _scanning ? "Okunuyor..." : "Metni Oku",
                      onPressed: _scanning ? null : _scanText,
                      isPrimary: true,
                      isLoading: _scanning,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ); // Scaffold end
      }, // builder end
    ); // ValueListenableBuilder end
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onPressed,
    required bool isPrimary,
    bool isLoading = false,
  }) {
    final isDarkMode = ThemeManager.instance.isDarkMode;
    // Buton metin rengi: Primary ise Beyaz, değilse Temaya göre (Beyaz/Siyah)
    // Ancak arka plan Gradient/Resim üstünde olduğu için Light modda bile Siyah metin okunmayabilir mi?
    // Alt panel yarı şeffaf. Light modda alt panel `Colors.white.withOpacity(0.05)` -> Beyaz üstüne beyaz olmaz.
    // Alt panel rengini de güncellemeliyiz.
    
    // Alt panel `Container` (line 209) güncellemesi yapılamadı çünkü bu method dışarıda.
    // Buradaki buton Primary değilse `Colors.transparent` background alır.
    // Border rengi ve Text/Icon rengi önemli.
    
    final Color contentColor = isPrimary 
        ? Colors.white 
        : (isDarkMode ? Colors.white : Colors.white); // Light modda arka plan Gradient olduğu için (MorumsU), yazı Beyaz kalabilir.
        // Fakat Light Mod gradient "White to Purple". Alt kısım Purple. O zaman Beyaz yazı mantıklı.
    
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: isPrimary ? const Color(0xFF213448) : Colors.transparent, // Dark Slate for Primary
        foregroundColor: isPrimary ? Colors.white : (isDarkMode ? const Color(0xFF94B4C1) : const Color(0xFF213448)), // Text color
        padding: const EdgeInsets.symmetric(vertical: 18),
        elevation: isPrimary ? 8 : 0,
        shadowColor: isPrimary ? const Color(0xFF000000).withOpacity(0.3) : null,
        side: isPrimary ? null : BorderSide(color: isDarkMode ? const Color(0xFF94B4C1) : const Color(0xFF213448), width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: isLoading 
        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 22),
              const SizedBox(width: 8),
              Text(label, style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
    );
  }
}