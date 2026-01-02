import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image/image.dart' as img; // decode, encode
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import '../utils/platform_utils.dart';
import '../utils/ui_utils.dart';
import '../utils/theme_manager.dart'; // ThemeManager eklendi

// Çizim noktası modeli
class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint(this.offset, this.paint);
}

class EditScreen extends StatefulWidget {
  final String imagePath;

  const EditScreen({super.key, required this.imagePath});

  @override
  State<EditScreen> createState() => _EditScreenState();
}

class _EditScreenState extends State<EditScreen> {
  // Çizim Verileri
  List<DrawingPoint?> drawingPoints = []; // Null = Yeni çizgi başlangıcı
  List<DrawingPoint?> deletedPoints = []; // Redo için (opsiyonel)
  
  // UI State
  Color _selectedColor = Colors.red;
  double _strokeWidth = 3.0;
  bool _isSaving = false;
  bool _showControls = true;
  int _selectedTool = 0; // 0: Kalem, 1: Fosforlu, 2: Silgi

  // Resim Gösterimi için
  ui.Image? _image;
  final GlobalKey _canvasKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    final data = await File(widget.imagePath).readAsBytes();
    final image = await decodeImageFromList(data);
    setState(() {
      _image = image;
    });
  }

  // --- Çizim Aksiyonları ---

  void _updateTool(int toolIndex) {
    setState(() {
      if (_selectedTool == toolIndex) {
        _selectedTool = -1; // Deselect (View Mode)
      } else {
        _selectedTool = toolIndex;
        if (_selectedTool == 1) { // Fosforlu
          _strokeWidth = 25.0;
        } else if (_selectedTool == 2) { // Silgi
          _strokeWidth = 20.0;
        } else { // Kalem
          _strokeWidth = 3.0;
        }
      }
    });
  }

  void _updateColor(Color color) {
    setState(() {
      _selectedColor = color;
    });
  }

  void _undo() {
    if (drawingPoints.isNotEmpty) {
      setState(() {
        // Son çizgiyi bul ve sil (aradaki null'a kadar)
        // drawingPoints sonu her zaman null olmayabilir çizim bitince null atıyoruz
        
        // Sondan başla, ilk null olmayanları sil, null görünce dur
        // Önce sondaki null'ı sil (varsa)
        if (drawingPoints.isNotEmpty && drawingPoints.last == null) {
          drawingPoints.removeLast();
        }
        
        while (drawingPoints.isNotEmpty && drawingPoints.last != null) {
          drawingPoints.removeLast();
        }
      });
    }
  }

  void _clearCanvas() {
    setState(() {
      drawingPoints.clear();
    });
  }

  // --- Kaydetme ---

  Future<void> _saveImage() async {
    if (_image == null) return;
    setState(() => _isSaving = true);
    
    try {
      // 1. Recorder ile yeni resim oluştur
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      
      // Orijinal Resmi Çiz
      canvas.drawImage(_image!, Offset.zero, Paint());
      
      // Çizimleri Üstüne Çiz
      // Not: SaveLayer kullanmalıyız ki silgi (BlendMode.clear) alttaki resmi silmesin?
      // Hayır, silgi "Çizgileri" silmeli.
      // EĞER "Layer" mantığı istiyorsak:
      // Silgi modunda çizilen noktalar, SADECE "kendi katmanındaki" pikselleri siler.
      // Ancak biz burada çizgileri tek tek çiziyoruz.
      // Canvas üzerinde "silgi" ile çizim yapmak, alttaki resmi de siler (BlendMode.clear).
      // Kullanıcının isteği: "Resim kalsın, yazıları sileyim".
      // BU çok zor çünkü çizdiğimiz çizgiler vektör değil bitmapleşiyor mu? Hayır şu an vektör (List<Point>) tutuyoruz.
      
      // ÇÖZÜM: Silgi aslında "beyaz boya" DEĞİL, listeden silme işlemi mi olmalı? Hayır bu imkansız.
      // Silgi ile boyadığımız yerdeki "çizgilerin" görünmemesi lazım.
      // Bunu sağlamak için: 
      // 1. Katman aç (SaveLayer).
      // 2. Tüm "Normal" çizgileri çiz.
      // 3. "Silgi" çizgilerini BlendMode.clear ile çiz (Bu sadece katmanındaki boyaları siler).
      // 4. Katmanı kapat (Restore).
      // Böylece alttaki `_image` etkilenmez! MÜKEMMEL ÇÖZÜM.
      
      canvas.saveLayer(Rect.fromLTWH(0, 0, _image!.width.toDouble(), _image!.height.toDouble()), Paint());
      
      for (int i = 0; i < drawingPoints.length - 1; i++) {
        if (drawingPoints[i] != null && drawingPoints[i + 1] != null) {
          canvas.drawLine(drawingPoints[i]!.offset, drawingPoints[i + 1]!.offset, drawingPoints[i]!.paint);
        } else if (drawingPoints[i] != null && drawingPoints[i + 1] == null) {
          canvas.drawPoints(ui.PointMode.points, [drawingPoints[i]!.offset], drawingPoints[i]!.paint);
        }
      }
      
      canvas.restore();

      final picture = recorder.endRecording();
      final imgResult = await picture.toImage(_image!.width, _image!.height);
      final byteData = await imgResult.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData == null) return;
      
      final buffer = byteData.buffer.asUint8List();
      final newPath = await PlatformUtils.saveFile(buffer, 'edited_${DateTime.now().millisecondsSinceEpoch}.png');

       if (mounted) {
        Navigator.pop(context, newPath);
      }

    } catch (e) {
      debugPrint("Save error: $e");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeManager.instance,
      builder: (context, isDarkMode, child) {
        return Scaffold(
          backgroundColor: isDarkMode ? Colors.black : Colors.white,
          body: _image == null 
            ? Center(child: CircularProgressIndicator(color: isDarkMode ? const Color(0xFF1D546C) : const Color(0xFF1D546C)))
            : Stack(
              children: [
                // Çizim Alanı
                Positioned.fill(
                  child: InteractiveViewer(
                    panEnabled: _selectedTool == -1, // Sadece araç seçili değilken pan serbest
                    scaleEnabled: true, // Her zaman zoom yapılabilir (eğer gesture detector engellemezse)
                    minScale: 0.5,
                    maxScale: 5.0,
                    boundaryMargin: const EdgeInsets.all(500),
                    child: Center(
                      child: GestureDetector(
                        onPanStart: _selectedTool == -1 ? null : (details) {
                           final RenderBox box = _canvasKey.currentContext!.findRenderObject() as RenderBox;
                           final offset = box.globalToLocal(details.globalPosition);
                           _addPoint(offset);
                        },
                        onPanUpdate: _selectedTool == -1 ? null : (details) {
                           final RenderBox box = _canvasKey.currentContext!.findRenderObject() as RenderBox;
                           final offset = box.globalToLocal(details.globalPosition);
                           _addPoint(offset);
                        },
                        onPanEnd: _selectedTool == -1 ? null : (details) {
                          setState(() {
                            drawingPoints.add(null);
                          });
                        },
                        child: FittedBox(
                          fit: BoxFit.contain,
                          child: SizedBox(
                            key: _canvasKey,
                            width: _image!.width.toDouble(),
                            height: _image!.height.toDouble(),
                            child: CustomPaint(
                              painter: DrawingPainter(image: _image!, points: drawingPoints),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                
                // UI Kontrolleri
                 if (_showControls)
                Positioned(
                  top: 0, left: 0, right: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                      color: isDarkMode ? Colors.black54 : Colors.white.withOpacity(0.9),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                           GestureDetector(
                             onTap: () => Navigator.pop(context),
                             child: Icon(Icons.arrow_back, color: isDarkMode ? Colors.white : Colors.black),
                           ),
                           Text("Düzenle", style: GoogleFonts.outfit(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20)),
                           _isSaving 
                           ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF1D546C)))
                           : GestureDetector(
                             onTap: _saveImage,
                             child: const Icon(Icons.check, color: Color(0xFF1D546C)),
                           ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                if (_showControls)
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      color: isDarkMode ? Colors.black87 : Colors.white,
                      child: Column(
                        children: [
                          // Araçlar
                          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            _buildToolButton(0, Icons.edit, "Kalem", isDarkMode),
                            const SizedBox(width: 20),
                            _buildToolButton(1, Icons.highlight, "Fosforlu", isDarkMode),
                            const SizedBox(width: 20),
                            _buildToolButton(2, Icons.cleaning_services, "Silgi", isDarkMode),
                          ]),
                          const SizedBox(height: 15),
                          // Renkler (Silgi değilse)
                          if (_selectedTool != 2)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                Colors.black, Colors.white, Colors.red, Colors.blue, Colors.green, Colors.yellow, Colors.purple
                              ].map((c) => GestureDetector(
                                onTap: () => _updateColor(c),
                                child: Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 5),
                                  width: 30, height: 30,
                                  decoration: BoxDecoration(color: c, shape: BoxShape.circle, border: Border.all(color: isDarkMode ? Colors.white : Colors.black12, width: _selectedColor == c ? 2 : 0)),
                                ),
                              )).toList(),
                            ),
                          ),
                          const SizedBox(height: 15),
                          // Slider
                          Slider(
                            value: _strokeWidth, 
                            min: 1, 
                            max: _selectedTool == 1 ? 50 : 30, 
                            activeColor: _selectedTool == 2 ? (isDarkMode ? Colors.white : Colors.black) : _selectedColor,
                            onChanged: (v) => setState(() => _strokeWidth = v)
                          ),
                          // Alt Butonlar
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              IconButton(icon: Icon(Icons.undo, color: isDarkMode ? Colors.white : Colors.black), onPressed: _undo),
                              IconButton(icon: Icon(Icons.delete, color: isDarkMode ? Colors.white : Colors.black), onPressed: _clearCanvas),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
        );
      },
    );
  }
  
  void _addPoint(Offset offset) {
    // ... _addPoint implementation (unchanged) ...
    // Note: The actual _addPoint method is not being replaced here as it was not included in the range. 
    // Wait, the range 169-351 covers _addPoint too. I must include it or split the chunk.
    // Splitting is safer or including the method body.
    // The previous implementation of _addPoint was fine. I will just paste it back.
    
    final paint = Paint()
      ..color = _selectedColor
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    if (_selectedTool == 2) {
      paint.blendMode = BlendMode.clear;
      paint.color = Colors.transparent; 
    } else if (_selectedTool == 1) {
      paint.color = _selectedColor.withOpacity(0.15); 
      paint.blendMode = BlendMode.srcOver;
    } else {
      paint.color = _selectedColor;
      paint.blendMode = BlendMode.srcOver;
    }

    setState(() {
      drawingPoints.add(DrawingPoint(offset, paint));
    });
  }
  
  Widget _buildToolButton(int index, IconData icon, String label, bool isDarkMode) {
    bool selected = _selectedTool == index;
    return GestureDetector(
      onTap: () => _updateTool(index),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF1D546C) : (isDarkMode ? Colors.white12 : Colors.grey[200]),
          borderRadius: BorderRadius.circular(10)
        ),
        child: Column(
          children: [
            Icon(icon, color: selected ? Colors.white : (isDarkMode ? Colors.white : Colors.black87)),
            Text(label, style: TextStyle(color: selected ? Colors.white : (isDarkMode ? Colors.white : Colors.black87), fontSize: 10))
          ],
        ),
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final ui.Image image;
  final List<DrawingPoint?> points;

  DrawingPainter({required this.image, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Resmi Çiz (Arka Plan)
    // Resmi size'a sığdır (FittedBox bunu ayarladı ama Painter'a orijinal resim geliyor olabilir mi? Hayır, parent size'a göre çiziyoruz)
    // Bekle, FittedBox parent size'ı kısıtlıyor ama CustomPaint size'ı alıyor.
    // Biz FittedBox'a fixed width/height verdik. Yani 'size' resmin orijinal boyutu olacak (scaled ekrana sığmış hali).
    
    // FittedBox çocuğu (SizedBox) ölçekleyerek ekrana sığdırır.
    // SizedBox'a verdiğimiz width/height: _image!.width ve height.
    // Dolayısıyla CustomPaint'in `size` parametresi orijinal resim boyutu olacak.
    // Touches (Gestures) FittedBox tarafından scale edilmiş koordinatlara sahip olur mu? 
    // Hayır, `globalToLocal` renderBox (SizedBox) üzerinden alınırsa, Orijinal Koordinatları verir!
    // Flutter'da transform (scale) edilmiş bir RenderBox üzerindeki touch offset'i, local coordinate system'e (yani unscaled boyuta) çevrilir.
    // Yani işlem TAMAMEN DOĞRU çalışmalı.
    
    canvas.drawImage(image, Offset.zero, Paint());
    
    // 2. Çizim Katmanını Aç (SaveLayer) - Silgi için kritik!
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());
    
    for (int i = 0; i < points.length - 1; i++) {
        if (points[i] != null && points[i + 1] != null) {
          canvas.drawLine(points[i]!.offset, points[i + 1]!.offset, points[i]!.paint);
        } else if (points[i] != null && points[i + 1] == null) {
          canvas.drawPoints(ui.PointMode.points, [points[i]!.offset], points[i]!.paint);
        }
    }
    
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
