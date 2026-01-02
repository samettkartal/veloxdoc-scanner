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
            primaryColor: const Color(0xFF1A3D64), // Medium Navy
            scaffoldBackgroundColor: const Color(0xFFF4F4F4), // Off-White
            useMaterial3: true,
            fontFamily: GoogleFonts.inter().fontFamily,
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1A3D64), // Medium Navy
              secondary: Color(0xFF1D546C), // Teal/Petrol Blue
              tertiary: Color(0xFF0C2B4E), // Dark Navy
              surface: Color(0xFFFFFFFF), // White
              onSurface: Color(0xFF0C2B4E), // Dark Navy Text
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFFF4F4F4),
              foregroundColor: Color(0xFF1A3D64),
              elevation: 0,
            ),
          ),
          darkTheme: ThemeData(
            brightness: Brightness.dark,
            primaryColor: const Color(0xFF1D546C), // Teal/Petrol Blue
            scaffoldBackgroundColor: const Color(0xFF0C2B4E), // Dark Navy
            useMaterial3: true,
            fontFamily: GoogleFonts.inter().fontFamily,
            colorScheme: const ColorScheme.dark(
              primary: Color(0xFF1D546C), // Teal/Petrol Blue
              secondary: Color(0xFF1A3D64), // Medium Navy
              tertiary: Color(0xFFF4F4F4), // Off-White
              surface: Color(0xFF1A3D64), // Medium Navy for contrast
              onSurface: Color(0xFFF4F4F4), // Off-White Text
            ),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF0C2B4E),
              foregroundColor: Color(0xFFF4F4F4),
              elevation: 0,
            ),
          ),
          home: const HomeScreen(),
        );
      },
    );
  }
}
