import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../models/document_model.dart';
import '../models/folder_model.dart';

class StorageService {
  static const String _boxName = 'scanhub_box';
  static const String _settingsBoxName = 'scanhub_settings';
  late Box<FolderModel> _box;
  late Box _settingsBox;

  Future<void> init() async {
    await Hive.initFlutter();
    DocumentModel.registerAdapter();
    FolderModel.registerAdapter();
    _box = await Hive.openBox<FolderModel>(_boxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);
    
    // Varsayılan klasörleri oluştur (Eğer yoksa)
    if (_box.isEmpty) {
      await createFolder("Genel", 0xFF213448);
      await createFolder("Faturalar", 0xFF547792);
      await createFolder("Kimlikler", 0xFF94B4C1);
      await createFolder("Gizli", 0xFFEAE0CF, isSecure: true);
    }

    // Yol Düzeltme (Path Correction)
    await _fixDocumentPaths();

    // Bozuk linkleri temizle (Kullanıcı isteği üzerine)
    await _cleanupBrokenLinks();
  }

  // Yolları onar (Absolute path değişirse güncelle)
  Future<void> _fixDocumentPaths() async {
    try {
      final appDir = await getApplicationDocumentsDirectory();
      for (var folder in _box.values) {
        bool folderChanged = false;
        for (int i = 0; i < folder.documents.length; i++) {
          final doc = folder.documents[i];
          final file = File(doc.path);
          if (!file.existsSync()) {
            final fileName = doc.path.split(Platform.pathSeparator).last;
            if (fileName.isEmpty) continue;

            final newPath = "${appDir.path}${Platform.pathSeparator}$fileName";
            final newFile = File(newPath);

            if (newFile.existsSync()) {
              debugPrint("🛠️ Yol onarıldı: $fileName");
              // DocumentModel immutable olduğu için yenisini oluşturup değiştiriyoruz
              folder.documents[i] = DocumentModel(
                id: doc.id,
                path: newPath,
                date: doc.date,
                title: doc.title,
              );
              folderChanged = true;
            }
          }
        }
        if (folderChanged) {
          await folder.save();
        }
      }
    } catch (e) {
      debugPrint("Yol düzeltme hatası: $e");
    }
  }

  // Dosyayı kalıcı hafızaya taşı
  Future<String> saveFilePermanently(File file) async {
    final appDir = await getApplicationDocumentsDirectory();
    final fileName = "${const Uuid().v4()}.${file.path.split('.').last}"; // Benzersiz isim
    final newPath = "${appDir.path}/$fileName";
    
    await file.copy(newPath);
    return newPath;
  }

  // Dosyası silinmiş belgeleri veritabanından temizle
  Future<void> _cleanupBrokenLinks() async {
    int removedCount = 0;
    for (var folder in _box.values) {
      final initialCount = folder.documents.length;
      folder.documents.removeWhere((doc) {
        final file = File(doc.path);
        return !file.existsSync(); // Dosya yoksa listeden sil
      });
      
      if (folder.documents.length != initialCount) {
        removedCount += (initialCount - folder.documents.length);
        await folder.save();
      }
    }
    if (removedCount > 0) {
      debugPrint("🧹 Temizlik: $removedCount adet bozuk dosya kaydı silindi.");
    }
  }

  List<FolderModel> getFolders() {
    return _box.values.toList();
  }

  // Hive kutusunu dinlemek için getter
  ValueListenable<Box<FolderModel>> get listenable => _box.listenable();

  Future<void> createFolder(String name, int color, {bool isSecure = false}) async {
    final folder = FolderModel(
      id: const Uuid().v4(),
      name: name,
      colorValue: color,
      documents: [],
      isSecure: isSecure,
    );
    await _box.put(folder.id, folder);
  }

  Future<void> addDocument(String folderId, DocumentModel doc) async {
    final folder = _box.get(folderId);
    if (folder != null) {
      folder.documents.add(doc);
      await folder.save(); // Hive nesnesini güncelle
    }
  }

  Future<void> deleteDocument(String folderId, String docId) async {
    final folder = _box.get(folderId);
    if (folder != null) {
      // Dosyayı fiziksel olarak da silmeye çalışalım (Opsiyonel ama iyi olur)
      try {
        final doc = folder.documents.firstWhere((d) => d.id == docId);
        final file = File(doc.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        debugPrint("Dosya silme hatası: $e");
      }

      folder.documents.removeWhere((d) => d.id == docId);
      await folder.save();
    }
  }
  
  Future<void> deleteFolder(String folderId) async {
    await _box.delete(folderId);
  }

  // --- Password Management ---
  bool get isSecretPasswordSet => _settingsBox.containsKey('secret_password');

  Future<void> setSecretPassword(String password) async {
    await _settingsBox.put('secret_password', password);
  }

  bool checkSecretPassword(String password) {
    final stored = _settingsBox.get('secret_password');
    return stored == password;
  }
}
