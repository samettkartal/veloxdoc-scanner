import 'dart:ui';

class ScanAIService {
  Future<void> loadModel() async {
    // Web'de model yüklenmez
    print("Web: AI Modeli yüklenmedi (Desteklenmiyor)");
  }

  Future<List<Offset>?> predictCorners(String imagePath) async {
    // Web'de otomatik köşe algılama yok, null dön
    print("Web: Köşe algılama atlandı");
    return null;
  }
}
