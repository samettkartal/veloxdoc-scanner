import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img; // Resim işleme için
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../utils/theme_manager.dart'; // ThemeManager import
import 'crop_screen.dart'; // CropScreen import

class ContrastAdjustmentScreen extends StatefulWidget {
  final String imagePath;

  const ContrastAdjustmentScreen({super.key, required this.imagePath});

  @override
  State<ContrastAdjustmentScreen> createState() => _ContrastAdjustmentScreenState();
}

class _ContrastAdjustmentScreenState extends State<ContrastAdjustmentScreen> {
  // Görüntü Durumu
  String _currentImagePath = "";
  Key _imageKey = UniqueKey(); // Görüntüyü zorla yenilemek için

  // Ayarlar
  double _contrastValue = 1.0; 
  double _brightnessValue = 1.0;
  bool _isSaving = false;
  
  // Filtreler (Basitleştirilmiş Presetler)
  // 0: Normal, 1: Gri Tonlama, 2: Sepya, 3: Ters Çevir
  int _selectedFilterIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentImagePath = widget.imagePath;
  }

  // --- ACTIONS ---

  // 1. Kırpma (Crop)
  Future<void> _cropImage() async {
    // Önce mevcut filtreleri/kontrastı uygula ve yeni bir dosyaya kaydet
    // Böylece CropScreen en güncel haliyle çalışır
    String cropInputPath = _currentImagePath;

    if (_contrastValue != 1.0 || _brightnessValue != 1.0 || _selectedFilterIndex != 0) {
        setState(() => _isSaving = true);
        try {
           final bytes = await File(_currentImagePath).readAsBytes();
           img.Image? image = img.decodeImage(bytes);

           if (image != null) {
              // Filtre Uygula
              if (_selectedFilterIndex != 0) {
                 if (_selectedFilterIndex == 1) image = img.grayscale(image);
                 else if (_selectedFilterIndex == 2) image = img.sepia(image);
                 else if (_selectedFilterIndex == 3) image = img.invert(image);
              }

              // Kontrast ve Parlaklık Uygula
              if (_contrastValue != 1.0 || _brightnessValue != 1.0) {
                 image = img.adjustColor(image, contrast: _contrastValue, brightness: _brightnessValue);
              }
              
              // Temp olarak kaydet
              final outputDir = await getTemporaryDirectory();
              final tempPath = "${outputDir.path}/baked_${const Uuid().v4()}.jpg";
              await File(tempPath).writeAsBytes(img.encodeJpg(image));
              cropInputPath = tempPath;
           }
        } catch(e) {
           debugPrint("Bake error: $e");
        } finally {
           setState(() => _isSaving = false);
        }
    }

    // CropScreen'e güncel dosya ile git
    final croppedPath = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CropScreen(imagePath: cropInputPath, mode: CropMode.rectangular),
      ),
    );

    if (croppedPath != null && croppedPath is String) {
      // Eğer temp dosya oluşturduysak ve sonuç farklıysa, temp'i silebiliriz ama cache mantığıyla uğraşmayalım.
      // Dönen croppedPath en güncel halidir.
      // Filtreler zaten "bake" edildiği için, UI'daki slider ve seçimleri sıfırlamalı mıyız?
      // Kullanıcı deneyimi açısından: Evet, çünkü resim artık o filtreli haliyle "yeni orijinal" oldu.
      
      await FileImage(File(croppedPath)).evict(); // Cache temizle
      setState(() {
        _currentImagePath = croppedPath;
        _imageKey = UniqueKey(); // Yenile
        
        // Değerleri sıfırla çünkü artık resmin kendisi bu efektleri içeriyor
        _contrastValue = 1.0;
        _brightnessValue = 1.0;
        _selectedFilterIndex = 0; 
      });
    }
  }

  // 2. Döndürme (Rotate 90°)
  Future<void> _rotateImage() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await File(_currentImagePath).readAsBytes();
      final image = img.decodeImage(bytes);
      if (image != null) {
        final rotated = img.copyRotate(image, angle: 90);
        
        final outputDir = await getTemporaryDirectory();
        final newPath = "${outputDir.path}/rotated_${const Uuid().v4()}.jpg";
        await File(newPath).writeAsBytes(img.encodeJpg(rotated));

        setState(() {
          _currentImagePath = newPath;
          _imageKey = UniqueKey();
        });
      }
    } catch (e) {
      debugPrint("Rotate error: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // 3. Filtre Seçimi
  void _showFilterOptions(bool isDarkMode) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDarkMode ? const Color(0xFF1E1E1E) : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          height: 200, // Fixed height for visual consistency
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text("Filtre Seçin", style: GoogleFonts.outfit(color: isDarkMode ? Colors.white : Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
               const SizedBox(height: 16),
               Expanded(
                 child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterOptionPreview("Normal", 0, isDarkMode),
                    _buildFilterOptionPreview("Gri", 1, isDarkMode),
                    _buildFilterOptionPreview("Sepya", 2, isDarkMode),
                    _buildFilterOptionPreview("Negatif", 3, isDarkMode),
                  ],
                 ),
               ),
            ],
          ),
        );
      },
    );
  }

  // Pre-calculated matrices for previews (simplified)
  List<double> _getPreviewMatrix(int type) {
     if (type == 1) return [0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0];
     if (type == 2) return [0.393, 0.769, 0.189, 0, 0, 0.349, 0.686, 0.168, 0, 0, 0.272, 0.534, 0.131, 0, 0, 0, 0, 0, 1, 0];
     if (type == 3) return [-1, 0, 0, 0, 255, 0, -1, 0, 0, 255, 0, 0, -1, 0, 255, 0, 0, 0, 1, 0];
     return [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0];
  }

  Widget _buildFilterOptionPreview(String label, int index, bool isDarkMode) {
    final isSelected = _selectedFilterIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedFilterIndex = index);
        Navigator.pop(context);
      },
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: isSelected ? Border.all(color: const Color(0xFF213448), width: 3) : Border.all(color: Colors.transparent, width: 3),
              boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 5)
              ]
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(_getPreviewMatrix(index)),
                child: Image.file(
                  File(_currentImagePath), // TODO: Optimisation - Use a Thumbnail here if possible
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label, 
            style: GoogleFonts.inter(
              color: isSelected ? const Color(0xFF213448) : (isDarkMode ? Colors.white70 : Colors.black87), 
              fontSize: 12, // Small font
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
            )
          ),
        ],
      ),
    );
  }

  List<double> _getFilterMatrix() {
    // Contrast matrix base
    double c = _contrastValue;
    double b = _brightnessValue;
    // Contrast offset: pivots around 128 (0.5 in 0-1 space, 128 in 0-255 space)
    double contrastOffset = 255 * 0.5 * (1 - c);
    
    // Scale everything by brightness (gain)
    // Formula: (Pixel * c + contrastOffset) * b
    //        = Pixel * (c * b) + (contrastOffset * b)
    
    double scale = c * b;
    double translate = contrastOffset * b;

    List<double> matrix = [
      scale, 0, 0, 0, translate,
      0, scale, 0, 0, translate,
      0, 0, scale, 0, translate,
      0, 0, 0, 1, 0
    ];

    if (_selectedFilterIndex == 1) { // Grayscale
      double r = 0.2126 * scale;
      double g = 0.7152 * scale;
      double blue = 0.0722 * scale;
      return [
        r, g, blue, 0, translate,
        r, g, blue, 0, translate,
        r, g, blue, 0, translate,
        0, 0, 0, 1, 0,
      ];
    } else if (_selectedFilterIndex == 2) { // Sepia
       return [
         0.393 * scale, 0.769 * scale, 0.189 * scale, 0, translate,
         0.349 * scale, 0.686 * scale, 0.168 * scale, 0, translate,
         0.272 * scale, 0.534 * scale, 0.131 * scale, 0, translate,
         0, 0, 0, 1, 0
       ];
    } else if (_selectedFilterIndex == 3) { // Invert
       return [
         -1, 0, 0, 0, 255,
         0, -1, 0, 0, 255,
         0, 0, -1, 0, 255,
         0, 0, 0, 1, 0
       ];
    }

    return matrix; // Normal + Contrast
  }
  
  Future<void> _saveImage() async {
    setState(() => _isSaving = true);
    try {
      final bytes = await File(_currentImagePath).readAsBytes();
      var image = img.decodeImage(bytes);

      if (image != null) {
        // 1. Filtre Uygula
        if (_selectedFilterIndex == 1) {
          image = img.grayscale(image);
        } else if (_selectedFilterIndex == 2) {
          image = img.sepia(image);
        } else if (_selectedFilterIndex == 3) {
          image = img.invert(image);
        }

        // 2. Kontrast ve Parlaklık Uygula
        if (_selectedFilterIndex != 3) {
           image = img.adjustColor(image, contrast: _contrastValue, brightness: _brightnessValue);
        }

        final outputDir = await getTemporaryDirectory();
        final newPath = "${outputDir.path}/adjusted_${const Uuid().v4()}.jpg";
        await File(newPath).writeAsBytes(img.encodeJpg(image));

        if (mounted) {
          Navigator.pop(context, newPath); 
        }
      }
    } catch (e) {
      debugPrint("Save error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorMatrix = _getFilterMatrix();

    return ValueListenableBuilder<bool>(
      valueListenable: ThemeManager.instance,
      builder: (context, isDarkMode, child) {
        final backgroundColor = isDarkMode ? const Color(0xFF1E1E2C) : Colors.white;
        final panelColor = isDarkMode ? const Color(0xFF2E2E3E) : Colors.grey[100];
        final textColor = isDarkMode ? Colors.white : Colors.black;
        final iconColor = isDarkMode ? Colors.white70 : Colors.black54;

        return Scaffold(
          backgroundColor: backgroundColor,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("İptal", style: GoogleFonts.inter(color: isDarkMode ? Colors.white70 : Colors.black54)),
            ),
            leadingWidth: 80,
            title: Text("Kontrast Ayarı", style: GoogleFonts.outfit(color: textColor, fontWeight: FontWeight.bold)),
            centerTitle: true,
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveImage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF213448),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                    ),
                    child: _isSaving 
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : Text("Kaydet", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              )
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                // --- Görüntü Önizleme ---
                Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ColorFiltered(
                      colorFilter: ColorFilter.matrix(colorMatrix),
                      child: InteractiveViewer(
                        minScale: 0.1,
                        maxScale: 4.0,
                        child: Image.file(
                          File(_currentImagePath),
                          key: _imageKey,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // --- Kontrast Ayar Paneli ---
              Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                decoration: BoxDecoration(
                  color: panelColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                  boxShadow: [
                    if (!isDarkMode)
                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
                  ]
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Değer Göstergesi
                    Row(
                      children: [
                        Icon(Icons.contrast, color: iconColor),
                        const SizedBox(width: 12),
                        Text("Kontrast", style: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(_contrastValue.toStringAsFixed(1), style: GoogleFonts.inter(color: isDarkMode ? Colors.white54 : Colors.black45, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    
                    // Slider
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: const Color(0xFF213448),
                        inactiveTrackColor: isDarkMode ? Colors.black26 : Colors.black12,
                        thumbColor: const Color(0xFF213448),
                        overlayColor: const Color(0xFF213448).withOpacity(0.2),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                      ),
                      child: Slider(
                        value: _contrastValue,
                        min: 0.5,
                        max: 2.0,
                        onChanged: (value) {
                          setState(() {
                            _contrastValue = value;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Parlaklık Kontrolü
                    Row(
                      children: [
                        Icon(Icons.brightness_6, color: iconColor),
                        const SizedBox(width: 12),
                        Text("Parlaklık", style: GoogleFonts.inter(color: textColor, fontSize: 16, fontWeight: FontWeight.w600)),
                        const Spacer(),
                        Text(_brightnessValue.toStringAsFixed(1), style: GoogleFonts.inter(color: isDarkMode ? Colors.white54 : Colors.black45, fontSize: 14)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4,
                        activeTrackColor: const Color(0xFF213448),
                        inactiveTrackColor: isDarkMode ? Colors.black26 : Colors.black12,
                        thumbColor: const Color(0xFF213448),
                        overlayColor: const Color(0xFF213448).withOpacity(0.2),
                        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
                        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
                      ),
                      child: Slider(
                        value: _brightnessValue,
                        min: 0.5,
                        max: 1.5,
                        onChanged: (value) {
                          setState(() {
                            _brightnessValue = value;
                          });
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // --- Alt İkonlar ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildBottomIcon(Icons.crop, "Kırp", false, isDarkMode, onTap: _cropImage),
                        _buildBottomIcon(Icons.filter_vintage, "Filtreler", _selectedFilterIndex != 0, isDarkMode, onTap: () => _showFilterOptions(isDarkMode)),
                        _buildBottomIcon(Icons.tune, "Ayarla", true, isDarkMode, onTap: () {}), // Zaten buradayız
                        _buildBottomIcon(Icons.rotate_right, "Döndür", false, isDarkMode, onTap: _rotateImage),
                      ],
                    )
                  ],
                ),
              ),
            ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildBottomIcon(IconData icon, String label, bool isActive, bool isDarkMode, {required VoidCallback onTap}) {
    final color = isActive ? const Color(0xFF213448) : (isDarkMode ? Colors.white54 : Colors.black54);
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: isActive 
                ? BoxDecoration(color: const Color(0xFF213448).withOpacity(0.2), shape: BoxShape.circle) 
                : null,
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.inter(color: isActive ? (isDarkMode ? Colors.white : Colors.black) : (isDarkMode ? Colors.white38 : Colors.black38), fontSize: 10)),
        ],
      ),
    );
  }
}
