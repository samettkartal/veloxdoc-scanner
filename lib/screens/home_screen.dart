import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'camera_screen.dart';
import 'crop_screen.dart';
import 'folder_screen.dart';
import 'result_screen.dart';
import 'edit_screen.dart';
import 'pdf_preview_screen.dart';
import '../utils/scan_ai_service.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../models/folder_model.dart';
import '../main.dart';
import '../utils/theme_manager.dart'; // Import ThemeManager

import 'package:google_mobile_ads/google_mobile_ads.dart';
import '../services/ad_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScanAIService _aiService = ScanAIService();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  
  // AdMob
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _aiService.loadModel();
    _initBannerAd();
    
    // Preload Interstitial Ad (Safe place, away from camera resource usage)
    AdService().loadInterstitialAd();
  }

  void _initBannerAd() {
    _bannerAd = AdService().createBannerAd(
      onAdLoaded: (ad) {
        if (mounted) setState(() => _isAdLoaded = true);
      },
      onAdFailedToLoad: (ad, error) {
        if (mounted) setState(() => _isAdLoaded = false);
      },
    );
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _createFolder() async {
    final TextEditingController controller = TextEditingController();
    final isDarkMode = ThemeManager.instance.isDarkMode;
    
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDarkMode 
                ? [const Color(0xFF2E2E3E), const Color(0xFF1A1A2E)] 
                : [Colors.white, const Color(0xFFF0F0F0)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Yeni Klasör",
                style: GoogleFonts.outfit(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                style: GoogleFonts.inter(color: isDarkMode ? Colors.white : Colors.black),
                cursorColor: const Color(0xFF213448),
                decoration: InputDecoration(
                  hintText: "Klasör Adı",
                  hintStyle: GoogleFonts.inter(color: isDarkMode ? Colors.white30 : Colors.black38),
                  filled: true,
                  fillColor: isDarkMode ? Colors.black26 : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF213448)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text("İptal", style: GoogleFonts.inter(color: isDarkMode ? Colors.white54 : Colors.black54)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        if (controller.text.isNotEmpty) {
                          await storageService.createFolder(controller.text, 0xFF9C27B0);
                          if (mounted) Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF213448),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: Text("Oluştur", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFolder(FolderModel folder) async {
    if (folder.isSecure) {
      if (!storageService.isSecretPasswordSet) {
        // Şifre belirlenmemiş, önce şifre belirlesin
        await _showSetPasswordDialog(folder);
      } else {
        // Şifre girsin
        await _showEnterPasswordDialog(folder);
      }
      return; 
    }

    if (!mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FolderScreen(folder: folder)),
    );
  }

  // --- Password Dialogs ---
  Future<void> _showSetPasswordDialog(FolderModel folder) async {
    final TextEditingController _passController = TextEditingController();
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildPasswordDialog(
        context,
        title: "Şifre Belirle",
        controller: _passController,
        isSetMode: true,
        onConfirm: () async {
          if (_passController.text.length >= 4) {
             await storageService.setSecretPassword(_passController.text);
             Navigator.pop(context);
             // Şifre belirlendikten sonra klasörü aç
             if (mounted) {
               Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => FolderScreen(folder: folder)),
               );
             }
          } else {
             ScaffoldMessenger.of(context).showSnackBar(
               const SnackBar(content: Text("Şifre en az 4 karakter olmalı.")),
             );
          }
        },
      ),
    );
  }

  Future<void> _showEnterPasswordDialog(FolderModel folder) async {
     final TextEditingController _passController = TextEditingController();
     await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _buildPasswordDialog(
        context,
        title: "Şifre Girin",
        controller: _passController,
        onConfirm: () {
          if (storageService.checkSecretPassword(_passController.text)) {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FolderScreen(folder: folder)),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Hatalı şifre!")),
            );
          }
        },
      ),
    );
  }

  Future<void> _showChangePasswordDialog() async {
     final TextEditingController _oldPassController = TextEditingController();
     final TextEditingController _newPassController = TextEditingController();
     final isDarkMode = ThemeManager.instance.isDarkMode;
     
     await showDialog(
       context: context,
       builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
               colors: isDarkMode 
                ? [const Color(0xFF2E2E3E), const Color(0xFF1A1A2E)] 
                : [Colors.white, const Color(0xFFF0F0F0)],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20, spreadRadius: 5)],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Şifre Değiştir", style: GoogleFonts.outfit(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(
                controller: _oldPassController,
                obscureText: true,
                style: GoogleFonts.inter(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Eski Şifre",
                  hintStyle: GoogleFonts.inter(color: isDarkMode ? Colors.white30 : Colors.black38),
                  filled: true,
                  fillColor: isDarkMode ? Colors.black26 : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey[300]!)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _newPassController,
                obscureText: true,
                style: GoogleFonts.inter(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "Yeni Şifre",
                  hintStyle: GoogleFonts.inter(color: isDarkMode ? Colors.white30 : Colors.black38),
                  filled: true,
                  fillColor: isDarkMode ? Colors.black26 : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey[300]!)),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: Text("İptal", style: GoogleFonts.inter(color: isDarkMode ? Colors.white54 : Colors.black54)))),
                Expanded(child: ElevatedButton(
                  onPressed: () async {
                    if (storageService.checkSecretPassword(_oldPassController.text)) {
                      if (_newPassController.text.length >= 4) {
                         await storageService.setSecretPassword(_newPassController.text);
                         Navigator.pop(context);
                         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Şifre başarıyla değiştirildi!")));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Yeni şifre en az 4 karakter olmalı.")));
                      }
                    } else {
                       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Eski şifre hatalı!")));
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF213448)),
                  child: Text("Kaydet", style: GoogleFonts.inter(color: Colors.white)),
                )),
              ])
            ],
          ),
        ),
       ),
     );
  }

  Widget _buildPasswordDialog(BuildContext context, {required String title, required TextEditingController controller, required VoidCallback onConfirm, bool isSetMode = false}) {
    final isDarkMode = ThemeManager.instance.isDarkMode;
    
    return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: isDarkMode 
                  ? [const Color(0xFF2E2E3E), const Color(0xFF1A1A2E)] 
                  : [Colors.white, const Color(0xFFF0F0F0)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: isDarkMode ? Colors.white10 : Colors.grey[300]!),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 20)],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(title, style: GoogleFonts.outfit(color: isDarkMode ? Colors.white : Colors.black, fontSize: 20, fontWeight: FontWeight.bold)),
              if (isSetMode) ...[
                const SizedBox(height: 8),
                Text("Klasör erişimi için şifre belirleyin. Bu şifreyi unutmayın!", textAlign: TextAlign.center, style: GoogleFonts.inter(color: isDarkMode ? Colors.white54 : Colors.black54, fontSize: 12)),
              ],
              const SizedBox(height: 20),
              TextField(
                controller: controller,
                obscureText: true,
                keyboardType: TextInputType.number,
                style: GoogleFonts.inter(color: isDarkMode ? Colors.white : Colors.black),
                decoration: InputDecoration(
                  hintText: "******",
                  hintStyle: GoogleFonts.inter(color: isDarkMode ? Colors.white30 : Colors.black38),
                  filled: true, 
                  fillColor: isDarkMode ? Colors.black26 : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey[300]!)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDarkMode ? Colors.white10 : Colors.grey[300]!)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF213448))),
                ),
              ),
              const SizedBox(height: 24),
              Row(children: [
                 Expanded(child: TextButton(onPressed: () => Navigator.pop(context), child: Text("İptal", style: GoogleFonts.inter(color: isDarkMode ? Colors.white54 : Colors.black54)))),
                 Expanded(child: ElevatedButton(
                   onPressed: onConfirm,
                   style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF213448), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                   child: Text("Tamam", style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
                 )),
              ]),
            ],
          ),
        ),
    );
  }

  Future<void> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();

    if (images.isNotEmpty) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfPreviewScreen(imagePaths: images.map((e) => e.path).toList()),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeManager.instance,
      builder: (context, isDarkMode, child) {
        return Scaffold(
          body: Container(
            color: isDarkMode ? const Color(0xFF213448) : const Color(0xFFEAE0CF),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("VeloxDoc",
                                style: GoogleFonts.outfit(
                                    fontSize: 28,
                                    fontWeight: FontWeight.bold,
                                    color: isDarkMode ? const Color(0xFFEAE0CF) : const Color(0xFF213448))),
                            Text("Belgelerinizi yönetin",
                                style: GoogleFonts.inter(
                                    color: isDarkMode ? const Color(0xFF94B4C1) : const Color(0xFF547792),
                                    fontSize: 14)),
                          ],
                        ),
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => ThemeManager.instance.toggleTheme(),
                              icon: Icon(
                                isDarkMode ? Icons.light_mode : Icons.dark_mode,
                                color: isDarkMode ? const Color(0xFFEAE0CF) : const Color(0xFF213448),
                              ),
                              tooltip: isDarkMode ? "Aydınlık Mod" : "Karanlık Mod",
                            ),
                            IconButton(
                              onPressed: _createFolder,
                              icon: Icon(
                                Icons.create_new_folder_outlined,
                                color: isDarkMode ? const Color(0xFFEAE0CF) : const Color(0xFF213448),
                              ),
                              tooltip: "Klasör Oluştur",
                            ),
                          ],
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 30),

                    SizedBox(
                      height: 140,
                      child: ValueListenableBuilder<Box<FolderModel>>(
                        valueListenable: storageService.listenable,
                        builder: (context, box, _) {
                          final folders = box.values.toList();
                          return ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: folders.length,
                            itemBuilder: (context, index) {
                              final folder = folders[index];
                              return GestureDetector(
                                onTap: () => _openFolder(folder),
                                child: Container(
                                  width: 110,
                                  margin: const EdgeInsets.only(right: 16),
                                  padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                    color: isDarkMode
                                        ? const Color(0xFF547792).withOpacity(0.2)
                                        : Colors.white.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                        color: isDarkMode
                                            ? const Color(0xFF94B4C1).withOpacity(0.5)
                                            : const Color(0xFF213448).withOpacity(0.1)),
                                  ),
                                  child: Stack(
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Icon(
                                            folder.isSecure
                                                ? Icons.lock_outline
                                                : Icons.folder_open_rounded,
                                            color: isDarkMode ? const Color(0xFF94B4C1) : const Color(0xFF547792),
                                            size: 32,
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                folder.name,
                                                style: GoogleFonts.outfit(
                                                    color: isDarkMode
                                                        ? const Color(0xFFEAE0CF)
                                                        : const Color(0xFF213448),
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 16),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              Text(
                                                "${folder.documents.length} Belge",
                                                style: GoogleFonts.inter(
                                                    color: isDarkMode
                                                        ? const Color(0xFF94B4C1)
                                                        : const Color(0xFF547792),
                                                    fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      if (folder.isSecure)
                                        Positioned(
                                          top: 0,
                                          right: 0,
                                          child: GestureDetector(
                                            onTap: () {
                                              if (storageService.isSecretPasswordSet) {
                                                _showChangePasswordDialog();
                                              } else {
                                                 ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Önce bir şifre belirleyin.")));
                                              }
                                            },
                                            child: Container(
                                               padding: const EdgeInsets.all(4),
                                               decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)),
                                               child: Icon(Icons.vpn_key, color: isDarkMode ? const Color(0xFFEAE0CF) : const Color(0xFF213448), size: 16),
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
                    ),

                    const Spacer(),
                    
                    if (_isLoading)
                      const Center(child: CircularProgressIndicator(color: Color(0xFF547792)))
                    else
                      Column(
                        children: [
                          _buildMenuButton(
                            context,
                            title: "Belge Tara",
                            subtitle: "Kamerayı başlat",
                            icon: Icons.camera_alt_rounded,
                            color: isDarkMode ? const Color(0xFF94B4C1) : const Color(0xFF213448),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CameraScreen()),
                              );
                            },
                            // Custom logic for colors below
                            textColor: isDarkMode ? const Color(0xFF213448) : const Color(0xFFEAE0CF),
                            subtitleColor: isDarkMode ? const Color(0xFF213448).withOpacity(0.7) : const Color(0xFFEAE0CF).withOpacity(0.7),
                          ),
                          const SizedBox(height: 16),
                          _buildMenuButton(
                            context,
                            title: "Galeriden Seç",
                            subtitle: "Fotoğraf yükle",
                            icon: Icons.photo_library_rounded,
                            color: isDarkMode ? const Color(0xFF547792) : Colors.white,
                            isOutlined: !isDarkMode, // Outlined in Light mode
                            onTap: _pickFromGallery,
                            textColor: isDarkMode ? const Color(0xFFEAE0CF) : const Color(0xFF213448),
                            subtitleColor: isDarkMode ? const Color(0xFFEAE0CF).withOpacity(0.7) : const Color(0xFF547792),
                          ),
                        ],
                      ),
                    const SizedBox(height: 20),
                    
                    // Banner Ad
                    if (_isAdLoaded && _bannerAd != null)
                      Container(
                        width: _bannerAd!.size.width.toDouble(),
                        height: _bannerAd!.size.height.toDouble(),
                        alignment: Alignment.center,
                        child: AdWidget(ad: _bannerAd!),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isOutlined = false,
    Color? textColor,
    Color? subtitleColor,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 24),
          decoration: BoxDecoration(
            color: isOutlined ? Colors.transparent : color,
            borderRadius: BorderRadius.circular(20),
            border: isOutlined ? Border.all(color: const Color(0xFF213448), width: 1) : null,
            boxShadow: isOutlined 
                ? null 
                : [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isOutlined ? const Color(0xFF213448).withOpacity(0.05) : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: textColor ?? Colors.white, size: 28),
              ),
              const SizedBox(width: 20),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor ?? Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: subtitleColor ?? Colors.white70,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Icon(Icons.arrow_forward_ios_rounded, color: textColor?.withOpacity(0.5) ?? Colors.white54, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
