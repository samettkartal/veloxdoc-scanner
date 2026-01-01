import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/home_screen.dart';
import 'services/storage_service.dart';
import 'utils/theme_manager.dart';

List<CameraDescription> cameras = [];
final StorageService storageService = StorageService();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Kamera hatası: $e');
  }

  await storageService.init(); // Veritabanını başlat
  await MobileAds.instance.initialize(); // Initialize AdMob

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: ThemeManager.instance,
      builder: (context, isDarkMode, child) {
        return MaterialApp(
          title: 'VeloxDoc',
          debugShowCheckedModeBanner: false,
          themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
          theme: ThemeData(
            brightness: Brightness.light,
            primaryColor: const Color(0xFF213448), // Dark Slate
            scaffoldBackgroundColor: const Color(0xFFEAE0CF), // Cream
            useMaterial3: true,
            fontFamily: GoogleFonts.inter().fontFamily,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF213448), // Dark Slate
              secondary: Color(0xFF547792), // Medium Slate
              tertiary: Color(0xFF94B4C1), // Light Blue
              surface: Color(0xFFFFFFFF), // White
              onSurface: Color(0xFF213448), // Dark Text
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFEAE0CF),
              foregroundColor: Color(0xFF213448),
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF94B4C1), // Light Blue
            scaffoldBackgroundColor: const Color(0xFF213448), // Dark Slate
            useMaterial3: true,
            fontFamily: GoogleFonts.inter().fontFamily,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF94B4C1), // Light Blue
              secondary: Color(0xFFEAE0CF), // Cream
              tertiary: Color(0xFF547792), // Medium Slate
              surface: Color(0xFF2A3D52), // Slightly Lighter Dark Slate for contrast
              onSurface: Color(0xFFEAE0CF), // Cream Text
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF213448),
              foregroundColor: Color(0xFFEAE0CF),
              elevation: 0,
            ),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
