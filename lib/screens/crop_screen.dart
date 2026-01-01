import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:opencv_dart/opencv_dart.dart' as cv;
import '../utils/platform_utils.dart';
import '../utils/theme_manager.dart';

enum CropMode { perspective, rectangular }

class CropScreen extends StatefulWidget {
  final String imagePath;
  final List<Offset>? initialCorners;
  final CropMode mode;

  const CropScreen({
    super.key, 
    required this.imagePath, 
    this.initialCorners,
    this.mode = CropMode.perspective, // Default to perspective as per user request
  });

  @override
  State<CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<CropScreen> {
  ui.Image? _uiImage;
  bool _isImageLoaded = false;
  bool _isProcessing = false;
  
  // Perspective Textures
  List<Offset> _corners = [];
  final double _handleRadius = 10.0;
  bool _isMagicFilterActive = false;

  // Rectangular Variables
  double _l = 0.1, _t = 0.1, _r = 0.9, _b = 0.9;
  int _activeHandle = -1;
  final double _handleHitSize = 30.0;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    try {
      final data = await PlatformUtils.readBytes(widget.imagePath);
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      setState(() {
        _uiImage = frame.image;
        _isImageLoaded = true;

        if (widget.mode == CropMode.perspective) {
             if (widget.initialCorners != null && widget.initialCorners!.length == 4) {
               _corners = List.from(widget.initialCorners!);
             } else {
               _corners = [
                 const Offset(0.1, 0.1), const Offset(0.9, 0.1),
                 const Offset(0.9, 0.9), const Offset(0.1, 0.9),
               ];
             }
        }
      });
    } catch (e) {
      debugPrint("Resim yükleme hatası: $e");
    }
  }

  // --- PERSPECTIVE LOGIC ---
  void _onPanUpdatePerspective(DragUpdateDetails details, Size size, Rect imageRect) {
    if (_corners.isEmpty) return;
    final Offset localPos = details.localPosition;
    
    int closestIndex = -1;
    double minDistance = double.infinity;
    
    for (int i = 0; i < 4; i++) {
      final Offset cornerPos = _toScreen(_corners[i], imageRect);
      final double dist = (cornerPos - localPos).distance;
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }
    
    if (closestIndex != -1 && minDistance < 50) {
      double newDx = (localPos.dx - imageRect.left) / imageRect.width;
      double newDy = (localPos.dy - imageRect.top) / imageRect.height;
      
      setState(() {
        _corners[closestIndex] = Offset(newDx.clamp(0.0, 1.0), newDy.clamp(0.0, 1.0));
      });
    }
  }

  Future<void> _applyPerspectiveCrop() async {
     setState(() => _isProcessing = true);
     try {
       final data = await PlatformUtils.readBytes(widget.imagePath);
       final srcMat = cv.imdecode(data, cv.IMREAD_COLOR);
       
       final srcPoints = cv.VecPoint2f.fromList(
         _corners.map((c) => cv.Point2f(c.dx * srcMat.cols, c.dy * srcMat.rows)).toList()
       );

       final double widthA = _dist(_corners[0], _corners[1]);
       final double widthB = _dist(_corners[2], _corners[3]);
       final double maxWidth = math.max(widthA, widthB) * srcMat.cols;

       final double heightA = _dist(_corners[0], _corners[3]);
       final double heightB = _dist(_corners[1], _corners[2]);
       final double maxHeight = math.max(heightA, heightB) * srcMat.rows;

       final dstPoints = cv.VecPoint2f.fromList([
         cv.Point2f(0, 0), cv.Point2f(maxWidth, 0),
         cv.Point2f(maxWidth, maxHeight), cv.Point2f(0, maxHeight),
       ]);

       final M = cv.getPerspectiveTransform2f(srcPoints, dstPoints);
       final dstMat = cv.warpPerspective(srcMat, M, (maxWidth.toInt(), maxHeight.toInt()));
       
       final success = cv.imwrite(widget.imagePath, dstMat);
       
       // Cleanup
       srcMat.dispose(); dstMat.dispose(); srcPoints.dispose(); dstPoints.dispose(); M.dispose();

       if (success && mounted) Navigator.pop(context, widget.imagePath);
       else throw Exception("Save failed");
       
     } catch (e) {
       debugPrint("Perspective error: $e");
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Kırpma başarısız")));
     } finally {
       if(mounted) setState(() => _isProcessing = false);
     }
  }

  // --- RECTANGULAR LOGIC ---
  void _onPanStartRect(DragStartDetails details, Rect imageRect) {
     final handles = _getHandlePositions(imageRect);
     final pos = details.localPosition;
     int found = -1;
     for(int i=0; i<handles.length; i++) {
         if((handles[i] - pos).distance < _handleHitSize) { found = i; break; }
     }
     setState(() => _activeHandle = found);
  }

  void _onPanUpdateRect(DragUpdateDetails details, Rect imageRect) {
      if (_activeHandle == -1) return;
      final dx = details.delta.dx / imageRect.width;
      final dy = details.delta.dy / imageRect.height;
      setState(() {
        if ([0, 3, 4].contains(_activeHandle)) _l = (_l + dx).clamp(0.0, _r - 0.05);
        if ([1, 2, 6].contains(_activeHandle)) _r = (_r + dx).clamp(_l + 0.05, 1.0);
        if ([0, 1, 5].contains(_activeHandle)) _t = (_t + dy).clamp(0.0, _b - 0.05);
        if ([2, 3, 7].contains(_activeHandle)) _b = (_b + dy).clamp(_t + 0.05, 1.0);
      });
  }

  Future<void> _applyRectCrop() async {
      setState(() => _isProcessing = true);
      try {
        final bytes = await File(widget.imagePath).readAsBytes();
        final srcImage = img.decodeImage(bytes);
        if (srcImage != null) {
          final x = (_l * srcImage.width).toInt();
          final y = (_t * srcImage.height).toInt();
          final w = ((_r - _l) * srcImage.width).toInt();
          final h = ((_b - _t) * srcImage.height).toInt();
          
          final cropped = img.copyCrop(srcImage, x: x, y: y, width: w, height: h);
          await File(widget.imagePath).writeAsBytes(img.encodeJpg(cropped));
          if(mounted) Navigator.pop(context, widget.imagePath);
        }
      } catch(e) {
         debugPrint("Rect crop error: $e");
      } finally {
         if(mounted) setState(() => _isProcessing = false);
      }
  }

  List<Offset> _getHandlePositions(Rect r) {
      final l = r.left + _l * r.width;
      final t = r.top + _t * r.height;
      final ri = r.left + _r * r.width;
      final b = r.top + _b * r.height;
      final cx = l + (ri - l) / 2;
      final cy = t + (b - t) / 2;
      return [Offset(l, t), Offset(ri, t), Offset(ri, b), Offset(l, b), Offset(l, cy), Offset(cx, t), Offset(ri, cy), Offset(cx, b)];
  }

  // --- HELPERS ---
  double _dist(Offset p1, Offset p2) => math.sqrt(math.pow(p1.dx - p2.dx, 2) + math.pow(p1.dy - p2.dy, 2));
  Offset _toScreen(Offset norm, Rect r) => Offset(r.left + norm.dx * r.width, r.top + norm.dy * r.height);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeManager.instance,
      builder: (context, isDarkMode, child) {
        const ColorFilter greyscale = ColorFilter.matrix(<double>[0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0.2126, 0.7152, 0.0722, 0, 0, 0, 0, 0, 1, 0]);
        return Scaffold(
          backgroundColor: isDarkMode ? Colors.black : const Color(0xFFF5F5F5),
          appBar: AppBar(
            title: Text(widget.mode == CropMode.perspective ? "Perspektif Düzelt" : "Kırp", style: TextStyle(color: isDarkMode ? Colors.white : Colors.black)),
            backgroundColor: isDarkMode ? Colors.black : Colors.white,
            iconTheme: IconThemeData(color: isDarkMode ? Colors.white : Colors.black),
            elevation: 0,
            actions: [
               if(widget.mode == CropMode.perspective)
                   IconButton(icon: Icon(Icons.auto_fix_high, color: _isMagicFilterActive ? const Color(0xFF94B4C1) : (isDarkMode ? Colors.grey : Colors.grey[400])), onPressed: () { setState(() => _isMagicFilterActive = !_isMagicFilterActive); }),
               IconButton(
                 onPressed: _isProcessing ? null : (widget.mode == CropMode.perspective ? _applyPerspectiveCrop : _applyRectCrop), 
                 icon: _isProcessing 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF94B4C1), strokeWidth: 2)) 
                    : const Icon(Icons.check, color: Color(0xFF94B4C1), size: 30)
               )
            ],
          ),
          body: !_isImageLoaded 
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF94B4C1))) 
            : LayoutBuilder(
              builder: (context, constraints) {
                // Calculate Image Rect
                final Size size = Size(constraints.maxWidth, constraints.maxHeight);
                final double imageAspect = _uiImage!.width / _uiImage!.height;
                final double screenAspect = size.width / size.height;
                
                double drawW, drawH;
                if (imageAspect > screenAspect) {
                  drawW = size.width;
                  drawH = size.width / imageAspect;
                } else {
                  drawH = size.height;
                  drawW = size.height * imageAspect;
                }
                
                final double drawX = (size.width - drawW) / 2;
                final double drawY = (size.height - drawH) / 2;
                final Rect imageRect = Rect.fromLTWH(drawX, drawY, drawW, drawH);
                
                final handles = _getHandlePositions(imageRect);

                return GestureDetector(
                   onPanUpdate: (d) => widget.mode == CropMode.perspective ? _onPanUpdatePerspective(d, size, imageRect) : _onPanUpdateRect(d, imageRect),
                   onPanStart: (d) => widget.mode == CropMode.rectangular ? _onPanStartRect(d, imageRect) : null,
                   onPanEnd: (_) => setState(() => _activeHandle = -1),
                   child: Stack(
                     children: [
                        // Arka plan resmi
                        Positioned.fromRect(
                             rect: imageRect, 
                             child: RawImage(image: _uiImage, fit: BoxFit.fill)
                        ),
                        
                        // Kırpma Çerçevesi ve Maske
                        if (widget.mode == CropMode.perspective) ...[
                            CustomPaint(size: size, painter: PerspectiveCropPainter(corners: _corners.map((c) => _toScreen(c, imageRect)).toList(), imageRect: imageRect)),
                            ..._corners.map((c) { final Offset pos = _toScreen(c, imageRect); return Positioned(left: pos.dx - _handleRadius, top: pos.dy - _handleRadius, child: Container(width: _handleRadius * 2, height: _handleRadius * 2, decoration: BoxDecoration(color: const Color(0xFF94B4C1).withOpacity(0.5), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)))); })
                        ] else ...[
                            CustomPaint(
                               size: size, 
                               painter: RectCropPainter(
                                   rect: Rect.fromLTRB(
                                       imageRect.left + _l * imageRect.width, 
                                       imageRect.top + _t * imageRect.height, 
                                       imageRect.left + _r * imageRect.width, 
                                       imageRect.top + _b * imageRect.height
                                   ),
                                   screenSize: size,
                               )
                            ),
                            ...List.generate(_getHandlePositions(imageRect).length, (index) {
                                final h = _getHandlePositions(imageRect)[index];
                                return Positioned(
                                    left: handles[index].dx - 10,
                                    top: handles[index].dy - 10,
                                    child: Container(
                                        width: 20, height: 20,
                                        decoration: BoxDecoration(
                                            color: Colors.white,
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFF94B4C1), width: 2),
                                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
                                        ),
                                    ),
                                );
                            })
                        ]
                     ],
                   ),
                );
              },
            ),
        );
      }
    );
  }
}

class PerspectiveCropPainter extends CustomPainter {
  final List<Offset> corners; final Rect imageRect;
  PerspectiveCropPainter({required this.corners, required this.imageRect});
  @override void paint(Canvas canvas, Size size) {
    if(corners.length != 4) return;
    final paintLine = Paint()..color = const Color(0xFF94B4C1)..strokeWidth = 2..style = PaintingStyle.stroke;
    final path = Path()..moveTo(corners[0].dx, corners[0].dy)..lineTo(corners[1].dx, corners[1].dy)..lineTo(corners[2].dx, corners[2].dy)..lineTo(corners[3].dx, corners[3].dy)..close();
    canvas.drawPath(path, paintLine);
    
    final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, size.width, size.height));
    final maskPath = Path.combine(PathOperation.difference, bgPath, path);
    canvas.drawPath(maskPath, Paint()..color = Colors.black.withOpacity(0.6));
  }
  @override bool shouldRepaint(covariant CustomPainter old) => true;
}

class RectCropPainter extends CustomPainter {
    final Rect rect;
    final Size screenSize;
    
    RectCropPainter({required this.rect, required this.screenSize});
    
    @override 
    void paint(Canvas canvas, Size size) {
        // Maske
        final bgPath = Path()..addRect(Rect.fromLTWH(0, 0, screenSize.width, screenSize.height));
        final cropPath = Path()..addRect(rect);
        final maskPath = Path.combine(PathOperation.difference, bgPath, cropPath);
        canvas.drawPath(maskPath, Paint()..color = Colors.black.withOpacity(0.7));
        
        // Çerçeve
        canvas.drawRect(rect, Paint()..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 2);
        
        // Grid (3x3 Rule of Thirds - Optional, helps visuals)
        final p = Paint()..color = Colors.white30..style = PaintingStyle.stroke..strokeWidth = 1;
        canvas.drawLine(Offset(rect.left + rect.width/3, rect.top), Offset(rect.left + rect.width/3, rect.bottom), p);
        canvas.drawLine(Offset(rect.left + 2*rect.width/3, rect.top), Offset(rect.left + 2*rect.width/3, rect.bottom), p);
        canvas.drawLine(Offset(rect.left, rect.top + rect.height/3), Offset(rect.right, rect.top + rect.height/3), p);
        canvas.drawLine(Offset(rect.left, rect.top + 2*rect.height/3), Offset(rect.right, rect.top + 2*rect.height/3), p);
    }
    
    @override bool shouldRepaint(RectCropPainter old) => true;
}
