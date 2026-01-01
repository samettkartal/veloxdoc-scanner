import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // rootBundle
import 'package:path_provider/path_provider.dart'; // getApplicationDocumentsDirectory
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img; // Resim kütüphanesi
import 'package:opencv_dart/opencv_dart.dart' as cv; // OpenCV

class ScanAIService {
  Interpreter? _interpreter;
  static const int INPUT_SIZE = 224; // Regresyon modeli için 224x224
  bool _useOpenCV = false;

  Future<void> loadModel() async {
    try {
      // Asset'i geçici dosyaya kopyala
      final modelData = await rootBundle.load('assets/scan_model_pro.tflite');
      final appDir = await getApplicationDocumentsDirectory();
      final modelFile = File('${appDir.path}/scan_model_pro.tflite');
      
      await modelFile.writeAsBytes(
        modelData.buffer.asUint8List(modelData.offsetInBytes, modelData.lengthInBytes),
        flush: true,
      );

      _interpreter = Interpreter.fromFile(modelFile);
      debugPrint("✅ AI Modeli Başarıyla Yüklendi.");

    } catch (e) {
      debugPrint("⚠️ Model yüklenemedi, OpenCV moduna geçiliyor: $e");
      _useOpenCV = true;
    }
  }

  Future<List<Offset>?> predictCorners(String imagePath) async {
    if (_interpreter == null && !_useOpenCV) await loadModel();

    if (_useOpenCV || _interpreter == null) {
      return _predictCornersOpenCV(imagePath);
    }

    try {
      return await _predictCornersAI(imagePath);
    } catch (e) {
      debugPrint("AI hatası, OpenCV deneniyor: $e");
      return _predictCornersOpenCV(imagePath);
    }
  }

  Future<List<Offset>?> _predictCornersAI(String imagePath) async {
    // 1. Resmi Hazırla
    final imageFile = File(imagePath);
    final imageData = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(imageData);
    if (decodedImage == null) return null;

    // 2. Resize
    final resized = img.copyResize(decodedImage, width: INPUT_SIZE, height: INPUT_SIZE);

    // Normalize
    var input = List.generate(
        1,
        (i) => List.generate(
            INPUT_SIZE,
            (y) => List.generate(INPUT_SIZE, (x) {
                  var pixel = resized.getPixel(x, y);
                  return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
                })));

    var output = List.filled(1 * 8, 0.0).reshape([1, 8]);

    // 3. Çalıştır
    _interpreter!.run(input, output);

    // 4. Çıktı
    List<double> coords = List<double>.from(output[0]);
    List<Offset> corners = [];
    for (int i = 0; i < 8; i += 2) {
      corners.add(Offset(coords[i].clamp(0.0, 1.0), coords[i + 1].clamp(0.0, 1.0)));
    }

    return _sortCorners(corners);
  }

  Future<List<Offset>?> _predictCornersOpenCV(String path) async {
    debugPrint("🔄 OpenCV ile kenar aranıyor...");
    try {
      // 1. Resmi Oku
      final src = cv.imread(path);
      
      // 2. İşle (Grileştir, Blur, Canny)
      final gray = cv.cvtColor(src, cv.COLOR_BGR2GRAY);
      final blurred = cv.gaussianBlur(gray, (5, 5), 0);
      final edges = cv.canny(blurred, 75, 200);

      // 3. Konturları Bul
      final (contours, _) = cv.findContours(edges, cv.RETR_LIST, cv.CHAIN_APPROX_SIMPLE);
      
      // 4. En büyük dörtgeni bul
      cv.VecPoint? maxCurve;
      double maxArea = 0;

      for (var contour in contours) {
        final area = cv.contourArea(contour);
        if (area < 1000) continue; // Küçük gürültüleri geç

        final perimeter = cv.arcLength(contour, true);
        final approx = cv.approxPolyDP(contour, 0.02 * perimeter, true);

        if (approx.length == 4 && area > maxArea) {
          maxArea = area;
          maxCurve = approx;
        }
      }

      if (maxCurve != null) {
         // Noktaları normalize et (0.0 - 1.0 arası)
         final width = src.width.toDouble();
         final height = src.height.toDouble();
         
         List<Offset> corners = [];
         for (var p in maxCurve) {
           corners.add(Offset(p.x / width, p.y / height));
         }
         
         debugPrint("✅ OpenCV Buldu: $corners");
         return _sortCorners(corners);
      }
      
    } catch (e) {
      debugPrint("❌ OpenCV Hatası: $e");
    }
    return null;
  }

  List<Offset> _sortCorners(List<Offset> corners) {
    if (corners.length != 4) return corners; // Fallback
    
    // Merkez noktayı bul
    double centerX = corners.fold(0.0, (sum, p) => sum + p.dx) / 4;
    double centerY = corners.fold(0.0, (sum, p) => sum + p.dy) / 4;
    
    // Merkezden konuma göre sırala: TL, TR, BR, BL
    corners.sort((a, b) {
       // Açıya göre sıralama veya basit quadrant kontrolü
       // Basit yöntem: Y'ye göre üst/alt, sonra X'e göre sol/sağ
       return a.dy.compareTo(b.dy);
    });
    
    // İlk ikisi üst, son ikisi alt
    List<Offset> top = corners.sublist(0, 2);
    List<Offset> bottom = corners.sublist(2, 4);
    
    top.sort((a, b) => a.dx.compareTo(b.dx)); // Sol-Sağ
    bottom.sort((a, b) => a.dx.compareTo(b.dx)); // Sol-Sağ
    
    // Sıra: TL, TR, BR, BL ( CropScreen genelde bunu ister: TL, TR, BR, BL)
    // Ancak CropScreen mantığına göre sıralamalıyız.
    // CropScreen genellikle [TL, TR, BR, BL] bekler.
    
    return [top[0], top[1], bottom[1], bottom[0]];
  }
}
