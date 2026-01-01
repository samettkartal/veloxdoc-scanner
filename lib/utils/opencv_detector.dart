import 'dart:ui';
import 'package:opencv_dart/opencv_dart.dart' as cv;

class OpencvDocumentDetector {
  
  /// Resmi okur, işler ve belgenin 4 köşesini bulup döner (Geleneksel Yöntem).
  static List<Offset> detect(String imagePath) {
    try {
      final img = cv.imread(imagePath, flags: cv.IMREAD_COLOR);
      if (img.isEmpty) return _defaultCorners();

      final gray = cv.cvtColor(img, cv.COLOR_BGR2GRAY);
      final blurred = cv.gaussianBlur(gray, (5, 5), 0);
      final edges = cv.canny(blurred, 75, 200);

      final (contours, _) = cv.findContours(edges, cv.RETR_LIST, cv.CHAIN_APPROX_SIMPLE);

      List<cv.Point> bestCorners = [];
      double maxArea = 0;

      for (var c in contours) {
        final area = cv.contourArea(c);
        if (area < (img.rows * img.cols) / 100) continue;

        final peri = cv.arcLength(c, true);
        final approx = cv.approxPolyDP(c, 0.02 * peri, true);

        if (approx.length == 4 && area > maxArea) {
          maxArea = area;
          bestCorners.clear();
          for(int j=0; j<4; j++) {
             bestCorners.add(approx[j]);
          }
        }
        approx.dispose();
      }

      int w = img.cols;
      int h = img.rows;

      // Temizlik
      img.dispose();
      gray.dispose();
      blurred.dispose();
      edges.dispose();
      contours.dispose();

      if (bestCorners.length == 4) {
        return _sortAndNormalizeCorners(bestCorners, w, h);
      }

      return _defaultCorners();
    } catch (e) {
      print("OpenCV Algılama Hatası: $e");
      return _defaultCorners();
    }
  }

  static List<Offset> _sortAndNormalizeCorners(List<cv.Point> points, int w, int h) {
    List<Offset> offsets = points.map((p) => Offset(p.x.toDouble(), p.y.toDouble())).toList();

    offsets.sort((a, b) => a.dy.compareTo(b.dy));
    List<Offset> top = offsets.sublist(0, 2);
    List<Offset> bottom = offsets.sublist(2, 4);

    top.sort((a, b) => a.dx.compareTo(b.dx));
    bottom.sort((a, b) => a.dx.compareTo(b.dx));

    List<Offset> sorted = [top[0], top[1], bottom[1], bottom[0]];

    return sorted.map((p) => Offset(
      (p.dx / w).clamp(0.0, 1.0),
      (p.dy / h).clamp(0.0, 1.0)
    )).toList();
  }

  static List<Offset> _defaultCorners() {
    return [
      const Offset(0.2, 0.2), const Offset(0.8, 0.2),
      const Offset(0.8, 0.8), const Offset(0.2, 0.8),
    ];
  }
}