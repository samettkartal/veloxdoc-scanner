import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
// OpenCV Dart paketi (Eğer pubspec.yaml'da varsa)
import 'package:opencv_dart/opencv_dart.dart' as cv;

class SegmentationService {
  Interpreter? _interpreter;
  static const int INPUT_SIZE = 256; // Eğitimde kullandığımız boyut

  // Modeli Yükle
  Future<void> loadModel() async {
    try {
      // Model dosyasının adı assets klasöründekiyle AYNI olmalı
      _interpreter = await Interpreter.fromAsset('assets/scan_model_pro.tflite');
      debugPrint("✅ Yapay Zeka Modeli Hazır");
    } catch (e) {
      debugPrint("❌ Model Yükleme Hatası: $e");
    }
  }

  // Tahmin Yap
  Future<List<Offset>> predict(String imagePath) async {
    if (_interpreter == null) await loadModel();
    if (_interpreter == null) return [];

    // 1. Resmi Oku
    final imageFile = File(imagePath);
    final imageData = await imageFile.readAsBytes();
    final decodedImage = img.decodeImage(imageData);

    if (decodedImage == null) return [];

    final originalW = decodedImage.width;
    final originalH = decodedImage.height;

    // 2. Resize (256x256) - Image v4 uyumlu
    final resized = img.copyResize(decodedImage, width: INPUT_SIZE, height: INPUT_SIZE);
    
    // Girdi Tensörü Hazırlığı [1, 256, 256, 3]
    // Float32 (0.0 - 1.0 arası normalize edilmiş)
    var input = List.generate(1, (i) => List.generate(INPUT_SIZE, (y) => List.generate(INPUT_SIZE, (x) {
      var pixel = resized.getPixel(x, y);
      return [pixel.r / 255.0, pixel.g / 255.0, pixel.b / 255.0];
    })));

    // Çıktı Tensörü Hazırlığı [1, 256, 256, 1]
    var output = List.filled(1 * INPUT_SIZE * INPUT_SIZE, 0.0).reshape([1, INPUT_SIZE, INPUT_SIZE, 1]);

    // 3. ÇALIŞTIR (Inference)
    _interpreter!.run(input, output);

    // 4. Maskeyi İşle (Thresholding -> Contour)
    // Çıktıyı byte array'e çevir (0 veya 255)
    Uint8List maskBytes = Uint8List(INPUT_SIZE * INPUT_SIZE);
    List<dynamic> outData = output[0];
    int ptr = 0;

    for (int y = 0; y < INPUT_SIZE; y++) {
      for (int x = 0; x < INPUT_SIZE; x++) {
        // 0.5'ten büyükse kağıt (Beyaz), değilse arka plan (Siyah)
        maskBytes[ptr++] = outData[y][x][0] > 0.5 ? 255 : 0;
      }
    }

    // OpenCV Matrisine çevir
    final maskMat = cv.Mat.fromVec(cv.VecU8.fromList(maskBytes)).reshape(1, INPUT_SIZE);

    // Konturları bul (RETR_EXTERNAL: Sadece en dış konturu al)
    final (contours, _) = cv.findContours(maskMat, cv.RETR_EXTERNAL, cv.CHAIN_APPROX_SIMPLE);
    
    List<Offset> corners = [];
    double maxArea = 0;

    // En büyük konturu bul
    for (var c in contours) {
      double area = cv.contourArea(c);
      if (area < 500) continue; // Çok küçük gürültüleri at

      double peri = cv.arcLength(c, true);
      // Çokgen yaklaşımı (Köşe sayısını azalt)
      var approx = cv.approxPolyDP(c, 0.02 * peri, true);

      // Eğer 4 köşeli bir şekil bulduysa ve alanı en büyükse
      if (approx.length == 4 && area > maxArea) {
        maxArea = area;
        corners.clear();
        
        // Noktaları al
        // approx bir VecPoint olabilir, erişim şekli kütüphaneye göre değişebilir
        // Genellikle liste gibi erişilir
        for (int j = 0; j < 4; j++) {
          var p = approx[j]; // Point(x, y)
          // Koordinatları Orijinal Boyuta Geri Oranla
          corners.add(Offset(
            (p.x / INPUT_SIZE) * originalW,
            (p.y / INPUT_SIZE) * originalH
          ));
        }
      }
      approx.dispose();
    }

    // Temizlik
    maskMat.dispose();
    contours.dispose();

    // Sonuçları Sırala ve Normalize Et (0.0 - 1.0 arası)
    // CropScreen 0.0-1.0 arası bekliyor, o yüzden tekrar normalize ediyoruz.
    if (corners.length == 4) {
      return _sortAndNormalize(corners, originalW, originalH);
    }

    // Bulamazsa varsayılanı dön (%20 içeriden)
    return [
      const Offset(0.2, 0.2), const Offset(0.8, 0.2),
      const Offset(0.8, 0.8), const Offset(0.2, 0.8)
    ];
  }

  List<Offset> _sortAndNormalize(List<Offset> points, int w, int h) {
    // 1. Y koordinatına göre sırala (Üsttekiler ve Alttakiler)
    points.sort((a, b) => a.dy.compareTo(b.dy));
    
    List<Offset> top = points.sublist(0, 2);
    List<Offset> bottom = points.sublist(2, 4);
    
    // 2. X koordinatına göre sırala (Sol ve Sağ)
    top.sort((a, b) => a.dx.compareTo(b.dx)); // TL, TR
    bottom.sort((a, b) => a.dx.compareTo(b.dx)); // BL, BR (Dikkat: BL solda olmalı)
    
    // Sıralama: TL, TR, BR, BL (Saat yönü veya Z düzeni)
    // CropScreen genellikle: TL, TR, BR, BL bekler.
    // Ancak senin CropScreen kodunda sıralama: 0:TL, 1:TR, 2:BR, 3:BL
    
    return [
      top[0],      // TL
      top[1],      // TR
      bottom[1],   // BR
      bottom[0]    // BL
    ].map((p) => Offset(
      (p.dx / w).clamp(0.0, 1.0),
      (p.dy / h).clamp(0.0, 1.0)
    )).toList();
  }
}