import 'dart:math' as math;
import 'package:flutter/material.dart'; // Offset için
import 'package:image/image.dart' as img;

class AdvancedEdgeDetector {
  
  // Ana Fonksiyon
  static List<Offset> detectDocument(img.Image original) {
    // 1. Ön işleme
    final processed = _preprocessImage(original);
    
    // 2. Kenar Tespiti (Canny)
    final edges = _detectEdges(processed);
    
    // 3. Kontur Bulma (DÜZELTİLDİ: Stack Overflow riskine karşı iterative yapıldı)
    final contours = _findContours(edges);
    
    // 4. En büyük dörtgeni bul
    final quad = _findLargestQuadrilateral(contours, processed.width, processed.height);
    
    // 5. Normalize et
    return _normalizeCorners(quad, original.width, original.height);
  }

  static img.Image _preprocessImage(img.Image src) {
    const int targetSize = 800;
    double scale = targetSize / math.max(src.width, src.height);
    
    img.Image processed;
    if (scale < 1.0) {
      processed = img.copyResize(src, width: (src.width * scale).toInt(), height: (src.height * scale).toInt(), interpolation: img.Interpolation.average);
    } else {
      processed = src.clone();
    }

    img.grayscale(processed);
    // Basit kontrast artırma (Histogram eşitleme bazen çok gürültü yaratabilir, bu daha güvenli)
    img.adjustColor(processed, contrast: 1.5); 
    img.gaussianBlur(processed, radius: 2);
    
    return processed;
  }

  // Canny Edge Detection
  static img.Image _detectEdges(img.Image src) {
    int w = src.width, h = src.height;
    List<List<double>> magnitude = List.generate(h, (_) => List.filled(w, 0.0));
    List<List<double>> direction = List.generate(h, (_) => List.filled(w, 0.0));
    
    // 1. Sobel

    
    // 2. Non-maximum suppression
    List<List<double>> suppressed = List.generate(h, (_) => List.filled(w, 0.0));
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        double angle = direction[y][x] * 180 / math.pi;
        if (angle < 0) angle += 180;
        double mag = magnitude[y][x];
        double q = 255, r = 255;

        if ((angle >= 0 && angle < 22.5) || (angle >= 157.5 && angle <= 180)) {
          q = magnitude[y][x+1]; r = magnitude[y][x-1];
        } else if (angle >= 22.5 && angle < 67.5) {
          q = magnitude[y+1][x-1]; r = magnitude[y-1][x+1];
        } else if (angle >= 67.5 && angle < 112.5) {
          q = magnitude[y+1][x]; r = magnitude[y-1][x];
        } else if (angle >= 112.5 && angle < 157.5) {
          q = magnitude[y-1][x-1]; r = magnitude[y+1][x+1];
        }

        if (mag >= q && mag >= r) suppressed[y][x] = mag;
      }
    }

    // 3. Thresholding
    double maxVal = 0;
    for (var row in suppressed) for (var val in row) if (val > maxVal) maxVal = val;
    
    double highThreshold = maxVal * 0.15;
    double lowThreshold = highThreshold * 0.4;
    
    img.Image result = img.Image(width: w, height: h);
    List<List<bool>> visited = List.generate(h, (_) => List.filled(w, false));
    
    // Iterative Hysteresis (Stack yapısı ile)
    List<int> stack = [];
    
    for (int y = 1; y < h - 1; y++) {
      for (int x = 1; x < w - 1; x++) {
        if (suppressed[y][x] >= highThreshold && !visited[y][x]) {
          stack.add(y * w + x);
          visited[y][x] = true;
          result.setPixel(x, y, img.ColorRgba8(255, 255, 255, 255));
          
          while (stack.isNotEmpty) {
            int curr = stack.removeLast();
            int cy = curr ~/ w;
            int cx = curr % w;
            
            for (int dy = -1; dy <= 1; dy++) {
              for (int dx = -1; dx <= 1; dx++) {
                int ny = cy + dy;
                int nx = cx + dx;
                if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
                   if (!visited[ny][nx] && suppressed[ny][nx] >= lowThreshold) {
                     visited[ny][nx] = true;
                     result.setPixel(nx, ny, img.ColorRgba8(255, 255, 255, 255));
                     stack.add(ny * w + nx);
                   }
                }
              }
            }
          }
        }
      }
    }
    return result;
  }

  // DÜZELTME: Iterative Contour Finding (Recursive hatasını önler)
  static List<List<Offset>> _findContours(img.Image edges) {
    int w = edges.width, h = edges.height;
    List<bool> visited = List.filled(w * h, false);
    List<List<Offset>> contours = [];
    List<int> stack = [];

    // 8-komşu offsetleri
    final dxList = [-1, 0, 1, -1, 1, -1, 0, 1];
    final dyList = [-1, -1, -1, 0, 0, 1, 1, 1];

    for (int i = 0; i < w * h; i++) {
      int y = i ~/ w;
      int x = i % w;
      
      if (!visited[i] && edges.getPixel(x, y).r > 128) {
        List<Offset> contour = [];
        stack.add(i);
        visited[i] = true;

        while (stack.isNotEmpty) {
          int currIdx = stack.removeLast();
          int cy = currIdx ~/ w;
          int cx = currIdx % w;
          contour.add(Offset(cx.toDouble(), cy.toDouble()));

          for (int k = 0; k < 8; k++) {
            int nx = cx + dxList[k];
            int ny = cy + dyList[k];
            
            if (nx >= 0 && nx < w && ny >= 0 && ny < h) {
              int nIdx = ny * w + nx;
              if (!visited[nIdx] && edges.getPixel(nx, ny).r > 128) {
                visited[nIdx] = true;
                stack.add(nIdx);
              }
            }
          }
        }
        if (contour.length > 50) contours.add(contour);
      }
    }
    return contours;
  }

  static List<Offset> _findLargestQuadrilateral(List<List<Offset>> contours, int w, int h) {
    if (contours.isEmpty) return _defaultCorners(w, h);
    
    contours.sort((a, b) => b.length.compareTo(a.length));
    List<Offset> hull = _convexHull(contours[0]);
    List<Offset> simplified = _douglasPeucker(hull, 10.0); // Epsilon değeri
    
    if (simplified.length < 4) return _defaultCorners(w, h);
    return _findFourCorners(simplified, w, h);
  }

  static List<Offset> _convexHull(List<Offset> points) {
    if (points.length < 3) return points;
    Offset start = points.reduce((a, b) => a.dy < b.dy || (a.dy == b.dy && a.dx < b.dx) ? a : b);
    List<Offset> sorted = List.from(points);
    sorted.sort((a, b) {
      double angleA = math.atan2(a.dy - start.dy, a.dx - start.dx);
      double angleB = math.atan2(b.dy - start.dy, b.dx - start.dx);
      return angleA.compareTo(angleB);
    });
    List<Offset> hull = [sorted[0], sorted[1]];
    for (int i = 2; i < sorted.length; i++) {
      while (hull.length >= 2) {
        Offset p1 = hull[hull.length - 2];
        Offset p2 = hull[hull.length - 1];
        Offset p3 = sorted[i];
        double cross = (p2.dx - p1.dx) * (p3.dy - p1.dy) - (p2.dy - p1.dy) * (p3.dx - p1.dx);
        if (cross <= 0) hull.removeLast(); else break;
      }
      hull.add(sorted[i]);
    }
    return hull;
  }

  static List<Offset> _douglasPeucker(List<Offset> points, double epsilon) {
    if (points.length < 3) return points;
    double maxDist = 0;
    int index = 0;
    for (int i = 1; i < points.length - 1; i++) {
      double dist = _perpendicularDistance(points[i], points[0], points.last);
      if (dist > maxDist) { maxDist = dist; index = i; }
    }
    if (maxDist > epsilon) {
      List<Offset> left = _douglasPeucker(points.sublist(0, index + 1), epsilon);
      List<Offset> right = _douglasPeucker(points.sublist(index), epsilon);
      return [...left.sublist(0, left.length - 1), ...right];
    }
    return [points.first, points.last];
  }

  static double _perpendicularDistance(Offset point, Offset start, Offset end) {
    double dx = end.dx - start.dx;
    double dy = end.dy - start.dy;
    double mag = dx*dx + dy*dy;
    if (mag == 0) return (point - start).distance;
    double u = ((point.dx - start.dx) * dx + (point.dy - start.dy) * dy) / mag;
    u = u.clamp(0.0, 1.0);
    return (point - Offset(start.dx + u*dx, start.dy + u*dy)).distance;
  }

  static List<Offset> _findFourCorners(List<Offset> points, int w, int h) {
    Offset tl = points.reduce((a, b) => a.distance < b.distance ? a : b);
    Offset tr = points.reduce((a, b) => (a - Offset(w.toDouble(), 0)).distance < (b - Offset(w.toDouble(), 0)).distance ? a : b);
    Offset br = points.reduce((a, b) => (a - Offset(w.toDouble(), h.toDouble())).distance < (b - Offset(w.toDouble(), h.toDouble())).distance ? a : b);
    Offset bl = points.reduce((a, b) => (a - Offset(0, h.toDouble())).distance < (b - Offset(0, h.toDouble())).distance ? a : b);
    return [tl, tr, br, bl];
  }

  static List<Offset> _normalizeCorners(List<Offset> corners, int w, int h) {
    return corners.map((c) => Offset((c.dx / w).clamp(0.05, 0.95), (c.dy / h).clamp(0.05, 0.95))).toList();
  }

  static List<Offset> _defaultCorners(int w, int h) {
    return [
      Offset(w * 0.2, h * 0.2), Offset(w * 0.8, h * 0.2),
      Offset(w * 0.8, h * 0.8), Offset(w * 0.2, h * 0.8),
    ];
  }
}