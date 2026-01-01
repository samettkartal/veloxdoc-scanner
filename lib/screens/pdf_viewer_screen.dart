import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/pdf.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/theme_manager.dart'; // ThemeManager eklendi

class PdfViewerScreen extends StatelessWidget {
  final String filePath;
  final String title;

  const PdfViewerScreen({super.key, required this.filePath, required this.title});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeManager.instance,
      builder: (context, isDarkMode, child) {
        return Scaffold(
          backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
          appBar: AppBar(
            title: Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: isDarkMode ? Colors.white : Colors.black)),
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
            actions: [
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () {
                  Share.shareXFiles([XFile(filePath)], text: title);
                },
              ),
            ],
          ),
          body: PdfPreview(
            build: (format) => File(filePath).readAsBytes(),
            useActions: false, 
            canChangeOrientation: false,
            canChangePageFormat: false,
          ),
        );
      },
    );
  }
}
