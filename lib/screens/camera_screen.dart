import 'dart:io';
import 'dart:ui';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart'; 
import 'crop_screen.dart';
import 'pdf_preview_screen.dart';
import '../utils/scan_ai_service.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with TickerProviderStateMixin {
  CameraController? _controller;
  bool _isInitialized = false;
  final List<String> _scannedPages = [];
  final ScanAIService _aiService = ScanAIService();
  bool _isFlashOn = false;

  late AnimationController _shutterAnimationController;
  late Animation<double> _shutterAnimation;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _aiService.loadModel();
    
    _shutterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _shutterAnimation = Tween<double>(begin: 1.0, end: 0.8).animate(
      CurvedAnimation(parent: _shutterAnimationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initCamera() async {
    if (cameras.isEmpty) return;
    _controller = CameraController(
      cameras[0], 
      ResolutionPreset.high, 
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.jpeg : ImageFormatGroup.bgra8888,
    );
    try {
      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.off);
      if (!mounted) return;
      setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint("Kamera hatası: $e");
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _shutterAnimationController.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    try {
      _isFlashOn = !_isFlashOn;
      await _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    } catch (e) {
      debugPrint("Flaş hatası: $e");
    }
  }

  Future<void> _processImage(String path) async {
    // Yükleniyor göstergesi
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => Center(
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: Color(0xFF213448)),
              const SizedBox(height: 16),
              Text(
                "Kenarlar Hesaplanıyor...", 
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14, decoration: TextDecoration.none)
              )
            ],
          ),
        ),
      ),
    );

    List<Offset>? detectedCorners;
    try {
      detectedCorners = await _aiService.predictCorners(path);
    } catch (e) {
      debugPrint("AI Hatası: $e");
    }

    if (!mounted) return;
    Navigator.pop(context);

    final String? croppedImage = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => CropScreen(
        imagePath: path,
        initialCorners: detectedCorners,
        mode: CropMode.perspective,
      )),
    );

    if (croppedImage != null) {
      setState(() {
        _scannedPages.add(croppedImage);
      });
    }
  }

  Future<void> _takePicture() async {
    if (!_controller!.value.isInitialized || _controller!.value.isTakingPicture) return;
    
    try {
      await _shutterAnimationController.forward();
      HapticFeedback.mediumImpact();
      
      final XFile file = await _controller!.takePicture();
      
      await _shutterAnimationController.reverse();
      
      if (!mounted) return;
      await _processImage(file.path);
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      await _processImage(image.path);
    }
  }

  void _deletePage(int index) {
    HapticFeedback.mediumImpact();
    setState(() => _scannedPages.removeAt(index));
  }

  void _goToPdfPreview() {
    if (_scannedPages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen belge ekleyin.")));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PdfPreviewScreen(imagePaths: _scannedPages)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const Scaffold(backgroundColor: Colors.black);

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Kamera Önizleme
          SizedBox.expand(child: CameraPreview(_controller!)),

          // 2. Üst Kontroller (Flaş, Kapat)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, bottom: 20, left: 20, right: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent],
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGlassIconButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Text(
                      "${_scannedPages.length} Sayfa",
                      style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ),
                  _buildGlassIconButton(
                    icon: _isFlashOn ? Icons.flash_on : Icons.flash_off,
                    onTap: _toggleFlash,
                    color: _isFlashOn ? Colors.yellow : Colors.white,
                  ),
                ],
              ),
            ),
          ),

          // 3. Alt Kontrol Paneli (Glassmorphism)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  height: 220, // Increased to accommodate content without overflow
                  padding: const EdgeInsets.only(bottom: 30, top: 16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                    border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Taranan Sayfalar (Thumbnail List)
                      if (_scannedPages.isNotEmpty)
                        Container(
                          height: 70, // Reduced from 80
                          margin: const EdgeInsets.only(bottom: 12), // Reduced margin
                          child: ReorderableListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _scannedPages.length,
                            onReorder: (oldIndex, newIndex) {
                              setState(() {
                                if (oldIndex < newIndex) {
                                  newIndex -= 1;
                                }
                                final String item = _scannedPages.removeAt(oldIndex);
                                _scannedPages.insert(newIndex, item);
                              });
                            },
                            itemBuilder: (context, index) {
                              return Container(
                                key: ValueKey(_scannedPages[index]),
                                margin: const EdgeInsets.only(right: 12),
                                width: 50, // Slightly narrower
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(_scannedPages[index]),
                                        fit: BoxFit.cover,
                                        width: 50,
                                        height: 70, // Match container height
                                      ),
                                    ),
                                    Positioned(
                                      top: -8,
                                      right: -8,
                                      child: GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () => _deletePage(index),
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(Icons.close, size: 12, color: Colors.white),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),

                      // Ana Butonlar
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Galeri Butonu
                          _buildBottomButton(
                            icon: Icons.photo_library_outlined,
                            onTap: _pickFromGallery,
                          ),

                          // Deklanşör Butonu
                          ScaleTransition(
                            scale: _shutterAnimation,
                            child: GestureDetector(
                              onTap: _takePicture,
                              child: Container(
                                width: 72, // Slightly smaller shutter button
                                height: 72,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 4),
                                  color: Colors.transparent,
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.camera_alt, color: Colors.black, size: 28),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // İleri Butonu
                          _scannedPages.isNotEmpty
                              ? GestureDetector(
                                  onTap: _goToPdfPreview,
                                  child: Container(
                                    width: 50,
                                    height: 50,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF94B4C1),
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF94B4C1).withOpacity(0.4),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        )
                                      ],
                                    ),
                                    child: const Icon(Icons.check, color: Colors.white, size: 28),
                                  ),
                                )
                              : const SizedBox(width: 50),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassIconButton({required IconData icon, required VoidCallback onTap, Color color = Colors.white}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  Widget _buildBottomButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}