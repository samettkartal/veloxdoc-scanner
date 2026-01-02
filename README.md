# VeloxDoc: Hibrit Görüntü İşleme ve Dijital Arşivleme Sistemi

<div align="center">

![Flutter](https://img.shields.io/badge/Flutter-3.19-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.2-0175C2?logo=dart)
![TensorFlow Lite](https://img.shields.io/badge/TFLite-Deep%20Learning-FF6F00?logo=tensorflow)
![OpenCV](https://img.shields.io/badge/OpenCV-Computer%20Vision-5C3EE8?logo=opencv)
![HIVE](https://img.shields.io/badge/Hive-NoSQL%20Database-FFD700)
![License](https://img.shields.io/badge/License-MIT-green)

</div>

**VeloxDoc**, fiziksel belgelerin mobil cihazlar aracılığıyla dijital ortama aktarılmasını sağlayan, uçtan uca (end-to-end) bir görüntü işleme ve dijital arşivleme çözümüdür. Sıradan kamera uygulamalarından farklı olarak, ham görüntü verisini anlamlandırmak ve geometrik bozuklukları gidermek için **Derin Öğrenme (Deep Learning - TFLite)** ve **Bilgisayarlı Görü (OpenCV)** disiplinlerini hibrit bir mimaride birleştirir.

Tüm işlem hattı (Image Processing Pipeline) cihaz üzerinde (on-device) ve internet bağlantısız çalışacak şekilde optimize edilmiştir.

---

## 🚀 Temel Özellikler

| Özellik | Açıklama | Teknoloji Yığını |
| :--- | :--- | :--- |
| **Hibrit Kenar Tespiti** | Dayanıklılık ve hız için yapay zeka (TFLite) ve Klasik CV (OpenCV) arasında dinamik geçiş yapar. | `tflite_flutter`, `opencv_dart` |
| **Perspektif Düzeltme** | Homografi matrisi kullanarak perspektif bozulmalarını (Keystone Effect) otomatik olarak düzeltir. | `Lineer Cebir` |
| **Güvenli Kasa** | Belgeler, AES-256 şifrelemeli yerel bir Hive veritabanında saklanır. | `hive`, `aes_256` |
| **Çevrimdışı Yapı** | Sıfır sunucu bağımlılığı. Tam veri gizliliği için tüm işlemler cihazda gerçekleşir. | `Offline-First` |
| **Akıllı Filtreler** | Görüntü zenginleştirme için uyarlanabilir eşikleme (Adaptive Thresholding) ve siyah-beyaz (Binarization) filtreleri. | `image_editor` |

---

## 🏗️ Proje Mimarisi

VeloxDoc, sürdürülebilirlik ve test edilebilirlik için **Clean Architecture** prensiplerine sıkı sıkıya bağlıdır.

```plaintext
lib/
├── main.dart                 # Uygulama giriş noktası ve bağımlılık enjeksiyonu
├── models/                   # Veri modelleri (Hive Entityleri)
│   ├── document_model.dart   # Taranan belge varlığı
│   ├── folder_model.dart     # Klasörleme yapısı
│   └── theme_manager.dart    # Tema yönetimi state'i
├── screens/                  # UI Katmanı (Flutter Widgetları)
│   ├── dashboard.dart        # Ana kontrol paneli
│   ├── camera_screen.dart    # Canlı kamera ve AI overlay
│   ├── edit_screen.dart      # Kırpma ve düzenleme ekranı
│   └── ...
├── services/                 # İş Mantığı ve Harici Servisler
│   ├── camera_service.dart   # Kamera donanım kontrolü
│   ├── tflite_service.dart   # AI model çıkarımı (Inference)
│   └── hive_service.dart     # Veritabanı işlemleri
└── utils/                    # Yardımcı Fonksiyonlar
    ├── image_utils.dart      # Piksel manipülasyonu
    └── math_utils.dart       # Geometrik hesaplamalar
```

---

## 🧠 Teknik Mimari ve Algoritmik Akış

Sistemin kalbi, milisaniyeler içinde çalışan üç aşamalı bir görüntü işleme motorudur.

### Görüntü İşleme Pipeline'ı (Mermaid Diyagramı)

```mermaid
graph TD
    A[Kamera Akışı (Input Stream)] --> B{AI Model Güven Skoru?}
    
    subgraph "Hibrit İşleme Motoru"
    B -- "Yüksek Güven (>%85)" --> C[TFLite Koordinat Regresyonu]
    C --> D[4 Köşe Noktası Tahmini]
    
    B -- "Düşük Güven (<%85)" --> E[OpenCV Fallback Mekanizması]
    E --> F[Gri Skala & Gaussian Blur]
    F --> G[Canny Kenar Tespiti]
    G --> H[Kontur Analizi & ApproxPolyDP]
    H --> D
    end
    
    D --> I[Homografi Matrisi Hesaplama]
    I --> J[Warp Perspective Dönüşümü]
    J --> K[Görüntü İyileştirme (Post-Processing)]
    K --> L[Dijital Belge Çıktısı]
```

### Algoritmik Detaylar & Karşılaştırma

Neden tek bir yöntem yerine hibrit bir yapı kullanıldı?

| Yöntem | Avantajlar | Dezavantajlar | VeloxDoc Kullanımı |
| :--- | :--- | :--- | :--- |
| **Semantik Segmentasyon (U-Net)** | Çok yüksek doğruluk, piksel seviyesinde hassasiyet. | Yavaş (~5-10 FPS), yüksek işlemci gücü gerektirir. | ❌ Kullanılmadı (Mobil için ağır). |
| **Koordinat Regresyonu (MobileNet)** | **Çok Hızlı (30+ FPS)**, düşük gecikme. | Karmaşık arka planlarda bazen kararsız olabilir. | ✅ **Birincil Yöntem.** |
| **Klasik CV (Canny/Hough)** | Düz, kontrastlı zeminlerde mükemmel matematiksel kesinlik. | Gölge ve gürültüden çok etkilenir. | ✅ **Yedek (Fallback) Sistem.** |

---

### Görsel Pipeline Analizi

Aşağıdaki tablo, VeloxDoc motorunun bir belge karesini işlerken geçtiği gerçek aşamaları göstermektedir:

<table>
  <tr>
    <td align="center" width="33%">
        <img src="assets/pipeline/step_01.png" width="100%" alt="Adım 01" style="border-radius: 8px; border: 1px solid #333;" />
        <br><sub><strong>Aşama 1: Giriş & Gri Ölçek</strong><br>Ham görüntü alınır ve tek kanala (Gri) indirgenir.</sub>
    </td>
    <td align="center" width="33%">
        <img src="assets/pipeline/step_02.png" width="100%" alt="Adım 02" style="border-radius: 8px; border: 1px solid #333;" />
        <br><sub><strong>Aşama 2: Gürültü Azaltma</strong><br>Gaussian Blur ile grenler temizlenir.</sub>
    </td>
    <td align="center" width="33%">
        <img src="assets/pipeline/step_03.png" width="100%" alt="Adım 03" style="border-radius: 8px; border: 1px solid #333;" />
        <br><sub><strong>Aşama 3: Kenar Tespiti (Canny)</strong><br>Sert geçişler ve gradyanlar yakalanır.</sub>
    </td>
  </tr>
  <tr>
    <td align="center">
        <img src="assets/pipeline/step_04.png" width="100%" alt="Adım 04" style="border-radius: 8px; border: 1px solid #333;" />
        <br><sub><strong>Aşama 4: Kontur Çıkarımı</strong><br>Kapalı döngüler ve geometrik şekiller bulunur.</sub>
    </td>
    <td align="center">
        <img src="assets/pipeline/step_05.png" width="100%" alt="Adım 05" style="border-radius: 8px; border: 1px solid #333;" />
        <br><sub><strong>Aşama 5: Köşe Yaklaştırma</strong><br>PolyDP algoritması ile şekil 4 köşeye indirgenir.</sub>
    </td>
    <td align="center">
        <img src="assets/pipeline/step_06.png" width="100%" alt="Adım 06" style="border-radius: 8px; border: 1px solid #333;" />
        <br><sub><strong>Aşama 6: Perspektif Dönüşümü</strong><br>Homografi ile belge kuş bakışı hizalanır.</sub>
    </td>
  </tr>
</table>

---

## 📸 Uygulama Akışı (Visual Workflow)

<table>
  <tr>
    <td align="center" width="33%">
        <h3>1. Dashboard & Kasa</h3>
        <img src="assets/screenshots/screen_01.jpg" width="250" alt="Ana Ekran" style="border-radius: 10px; box-shadow: 0px 4px 10px rgba(0,0,0,0.2);" />
        <br><br>
        <p><em>Güvenli klasör yönetimi ve hızlı erişim.</em></p>
    </td>
    <td align="center" width="33%">
        <h3>2. Akıllı Tarama</h3>
        <img src="assets/screenshots/screen_03.jpg" width="250" alt="Tarama Ekranı" style="border-radius: 10px; box-shadow: 0px 4px 10px rgba(0,0,0,0.2);" />
        <br><br>
        <p><em>AI destekli gerçek zamanlı belge algılama.</em></p>
    </td>
    <td align="center" width="33%">
        <h3>3. Manuel Hassas Ayar</h3>
        <img src="assets/screenshots/screen_04.jpg" width="250" alt="Kırpma Ekranı" style="border-radius: 10px; box-shadow: 0px 4px 10px rgba(0,0,0,0.2);" />
        <br><br>
        <p><em>Otomatik algılama sonrası ince ayar imkanı.</em></p>
    </td>
  </tr>
  <tr>
    <td align="center">
        <h3>4. Rektifikasyon</h3>
        <img src="assets/screenshots/screen_edit.png" width="250" alt="Düzenlenmiş Belge" style="border-radius: 10px; box-shadow: 0px 4px 10px rgba(0,0,0,0.2);" />
        <br><br>
        <p><em>Homografi dönüşümü sonrası hizalanmış çıktı.</em></p>
    </td>
    <td align="center">
        <h3>5. Meta Veri & Kayıt</h3>
        <img src="assets/screenshots/screen_02.jpg" width="250" alt="Kayıt Ekranı" style="border-radius: 10px; box-shadow: 0px 4px 10px rgba(0,0,0,0.2);" />
        <br><br>
        <p><em>Belgelerin etiketlenmesi ve kategorize edilmesi.</em></p>
    </td>
    <td align="center">
        <h3>6. Final Sonuç</h3>
        <img src="assets/screenshots/screen_05.jpg" width="250" alt="Final Çıktı" style="border-radius: 10px; box-shadow: 0px 4px 10px rgba(0,0,0,0.2);" />
        <br><br>
        <p><em>Yüksek kontrastlı, paylaşılabilir dijital belge.</em></p>
    </td>
  </tr>
</table>

---

## 🛠️ Kurulum ve Çalıştırma (Installation)

### Gereksinimler (Prerequisites)
- **Flutter SDK:** >=3.2.3 <4.0.0
- **Dart SDK:** >=3.2.0
- **Android Studio / VS Code** (Flutter eklentileri ile)
- **Android SDK:** Min SDK 21 (Android 5.0 Lollipop)

### 1. Projeyi Klonlayın
```bash
git clone https://github.com/samettkartal/veloxdoc.git
cd veloxdoc
```

### 2. Bağımlılıkları Yükleyin
```bash
flutter pub get
```

### 3. Model Dosyalarını Kontrol Edin
AI modelinin `assets/` klasöründe bulunduğundan emin olun:
```bash
/assets
  ├── scan_model_pro.tflite  # Koordinat regresyon modeli
  └── ...
```

### 4. Uygulamayı Başlatın
```bash
# Debug modunda çalıştırmak için:
flutter run

# Release (Performans) modunda test etmek için:
flutter run --release
```

---

## 📄 Lisans
Bu proje MIT Lisansı altında lisanslanmıştır. Detaylar için [LICENSE](LICENSE) dosyasına bakınız.

---
**Geliştirici:** Samet Kartal
