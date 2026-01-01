import 'dart:io';
import 'dart:typed_data';
import 'package:printing/printing.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/folder_model.dart';
import '../models/document_model.dart';
import '../services/storage_service.dart';
import '../utils/pdf_generator.dart';
import '../main.dart'; // storageService erişimi için
import 'pdf_preview_screen.dart';
import 'pdf_viewer_screen.dart';
import '../utils/theme_manager.dart'; // ThemeManager eklendi

class FolderScreen extends StatefulWidget {
  final FolderModel folder;

  const FolderScreen({super.key, required this.folder});

  @override
  State<FolderScreen> createState() => _FolderScreenState();
}

class _FolderScreenState extends State<FolderScreen> {
  Future<void> _deleteDocument(DocumentModel doc) async {
    await storageService.deleteDocument(widget.folder.id, doc.id);
  }

  Future<void> _shareFolderPdf() async {
    final currentFolder = storageService.getFolders().firstWhere((f) => f.id == widget.folder.id, orElse: () => widget.folder);
    if (currentFolder.documents.isEmpty) return;
    
    // Şifre Sor
    String? password;
    if (currentFolder.isSecure) {
      // Güvenli klasörse şifre isteyebiliriz (opsiyonel)
      // Şimdilik basit tutalım
    }

    await PdfGenerator.createAndSharePdf(
      currentFolder.documents.map((d) => d.path).toList(),
      password: password,
    );
  }

  Future<Uint8List?> _generatePdfThumbnail(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return null;
      final pdfBytes = await file.readAsBytes();
      // İlk sayfayı render et
      await for (final page in Printing.raster(pdfBytes, pages: [0], dpi: 72)) {
        return page.toPng();
      }
    } catch (e) {
      debugPrint("Thumbnail hatası: $e");
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeManager.instance,
      builder: (context, isDarkMode, child) {
        return Scaffold(
          backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: Text(widget.folder.name.toUpperCase(), style: GoogleFonts.outfit(fontWeight: FontWeight.bold, letterSpacing: 1.2, color: isDarkMode ? Colors.white : Colors.black)),
            centerTitle: true,
            backgroundColor: isDarkMode ? Color(widget.folder.colorValue).withOpacity(0.2) : Color(widget.folder.colorValue).withOpacity(0.1),
            iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
            actions: [
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: _shareFolderPdf,
                tooltip: "Tümünü PDF Yap",
              )
            ],
          ),
          body: ValueListenableBuilder<Box<FolderModel>>(
            valueListenable: storageService.listenable,
            builder: (context, box, _) {
              final currentFolder = box.get(widget.folder.id);
              
              if (currentFolder == null) {
                return Center(child: Text("Klasör bulunamadı", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)));
              }

              final documents = currentFolder.documents;

              if (documents.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.folder_open, size: 80, color: isDarkMode ? Colors.white10 : Colors.black12),
                      const SizedBox(height: 16),
                      Text(
                        "Klasör boş",
                        style: GoogleFonts.inter(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(20),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.75,
                ),
                itemCount: documents.length,
                itemBuilder: (context, index) {
                  final doc = documents[index];
                  return GestureDetector(
                    onTap: () {
                      if (doc.path.toLowerCase().endsWith('.pdf')) {
                         Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfViewerScreen(filePath: doc.path, title: doc.title),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PdfPreviewScreen(imagePaths: [doc.path]),
                          ),
                        );
                      }
                    },
                    onLongPress: () => _deleteDocument(doc),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDarkMode ? const Color(0xFF1A1A2E) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isDarkMode ? Colors.white10 : Colors.black12),
                        boxShadow: [
                          BoxShadow(color: isDarkMode ? Colors.black.withOpacity(0.3) : Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                        image: doc.path.toLowerCase().endsWith('.pdf') 
                          ? null 
                          : DecorationImage(
                              image: FileImage(File(doc.path)),
                              fit: BoxFit.cover,
                            ),
                      ),
                      child: Stack(
                        children: [
                          if (doc.path.toLowerCase().endsWith('.pdf'))
                            FutureBuilder<Uint8List?>(
                              future: _generatePdfThumbnail(doc.path),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState == ConnectionState.done && snapshot.data != null) {
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.memory(
                                      snapshot.data!,
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                      height: double.infinity,
                                    ),
                                  );
                                } else {
                                  return Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.picture_as_pdf, size: 48, color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black12),
                                        const SizedBox(height: 8),
                                        Text("PDF", style: TextStyle(color: isDarkMode ? Colors.white.withOpacity(0.2) : Colors.black26, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  );
                                }
                              },
                            ),
                          
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16)),
                                gradient: LinearGradient(
                                  begin: Alignment.bottomCenter,
                                  end: Alignment.topCenter,
                                  colors: [
                                    isDarkMode ? Colors.black.withOpacity(0.9) : Colors.white.withOpacity(0.9),
                                    isDarkMode ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.6),
                                    Colors.transparent
                                  ],
                                  stops: const [0.0, 0.6, 1.0],
                                ),
                              ),
                              padding: const EdgeInsets.fromLTRB(12, 30, 12, 12),
                              child: Text(
                                doc.title,
                                style: GoogleFonts.inter(color: isDarkMode ? Colors.white : Colors.black87, fontSize: 12),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        );
      },
    );
  }
}
