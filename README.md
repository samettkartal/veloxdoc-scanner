# VeloxDoc (Akıllı Belge Tarayıcı)

**VeloxDoc**, Flutter altyapısı ile geliştirilmiş, yapay zeka destekli, yüksek performanslı bir mobil belge tarama ve yönetim uygulamasıdır. Cihaz üzerinde çalışan gelişmiş görüntü işleme algoritmaları sayesinde belgeleri otomatik olarak algılar, perspektif düzeltmesi yapar ve metin haline dönüştürür.

<div align="center">
  <h3>Uygulama Arayüzü & Akış</h3>
  <img src="assets/screenshots/screen_01.jpg" width="200" alt="Ana Ekran" />
  <img src="assets/screenshots/screen_02.jpg" width="200" alt="Kategori/Klasör Yönetimi" />
  <img src="assets/screenshots/screen_03.jpg" width="200" alt="Canlı Belge Algılama" />
  <br>
  <img src="assets/screenshots/screen_edit.png" width="200" alt="Filtre ve Düzenleme" />
  <img src="assets/screenshots/screen_04.jpg" width="200" alt="Perspektif Kırpma" />
  <img src="assets/screenshots/screen_05.jpg" width="200" alt="OCR Sonucu ve Paylaşım" />
</div>

---

## 🚀 Proje Hakkında
Bu proje, mobil cihazları güçlü birer taşınabilir tarayıcıya dönüştürmeyi amaçlar. Sadece fotoğraf çekmekle kalmaz, görüntüyü analiz ederek **belge sınırlarını (edge detection)** belirler ve **perspektif çarpıklığını (perspective warp)** otomatik olarak düzeltir.

### Temel Özellikler
- **Otomatik Belge Algılama:** Kamera akışı üzerinden anlık belge tespiti.
- **Akıllı Kırpma:** Köşe noktalarının yapay zeka ve görüntü işleme ile belirlenmesi.
- **Perspektif Düzeltme:** Açılı çekilen belgelerin düzleştirilmesi.
- **Gelişmiş Filtreler:** Siyah-beyaz, gri tonlama ve "sihirli renk" filtreleri.
- **OCR (Optik Karakter Tanıma):** Taranan belgedeki metinlerin ayıklanması.
- **PDF Dışa Aktarma:** Çoklu sayfaların tek bir PDF dosyası olarak paylaşılması.
- **Kategori Yönetimi:** Belgelerin (Fatura, Kimlik, Ders Notu vb.) klasörlenmesi.

---

## 🛠️ Kullanılan Teknolojiler ve Mimari

Proje, **Clean Architecture** prensiplerine uygun olarak ve performans odaklı kütüphanelerle geliştirilmiştir.

### Core Stack
- **Framework:** [Flutter](https://flutter.dev/) (Dart)
- **State Management:** Provider / Riverpod (Reaktif durum yönetimi)
- **Database:** [Hive](https://docs.hivedb.dev/) (NoSQL, Key-Value, Yüksek performanslı yerel veritabanı)

### 🧠 Yapay Zeka ve Görüntü İşleme (AI & CV)
Uygulamanın "beyni" olan görüntü işleme hattı şu teknolojileri kullanır:

1.  **OpenCV (via `opencv_dart`):**
    -   Görüntü ön işleme (Grayscale, Gaussian Blur).
    -   Kenar tespiti (Canny Edge Detection).
    -   Kontur analizi ve dörtgen tespiti (Contour Approximation).
    -   Perspektif dönüşümleri (Perspective Transform).

2.  **TensorFlow Lite (`tflite_flutter`):**
    -   **Model:** `scan_model_pro.tflite` & `unet_document_scanner.tflite`
    -   **Görev:** Karmaşık zeminlerde belgenin segmentasyonu (U-Net mimarisi). Geleneksel OpenCV yöntemlerinin yetersiz kaldığı düşük kontrastlı durumlarda devreye girer.

3.  **Google ML Kit (`google_mlkit_text_recognition`):**
    -   Cihaz içi (On-device) OCR işlemleri için kullanılır.
    -   Türkçe dahil çoklu dil desteği ile yüksek doğrulukta metin okuma sağlar.

### Diğer Kritik Kütüphaneler
-   **Kamera:** `camera` (Özel kamera arayüzü kontrolü için).
-   **PDF Yönetimi:** `pdf` & `printing` (Vektörel PDF oluşturma).
-   **Depolama:** `path_provider` & `permission_handler`.

---

## ⚙️ Geliştirme Yöntemleri
Proje geliştirilirken aşağıdaki metodolojiler izlenmiştir:
-   **Modular Design:** Kamera, Düzenleme, Galeri ve Ayarlar modülleri birbirinden bağımsız geliştirildi.
-   **Offline-First:** Tüm işlemler (AI, OCR, Kayıt) internet bağlantısı gerektirmeden cihaz üzerinde çalışır.
-   **Performance Optimization:** Görüntü işleme gibi ağır yükler, ana UI thread'ini bloklamamak adına arka planda (Isolate) veya native C++ katmanında (OpenCV/TFLite) çalıştırılır.

---

## 📦 Kurulum

Projeyi yerel ortamınızda çalıştırmak için:

1.  Repoyu klonlayın:
    ```bash
    git clone https://github.com/samettkartal/veloxdoc-scanner.git
    ```
2.  Bağımlılıkları yükleyin:
    ```bash
    flutter pub get
    ```
3.  Uygulamayı çalıştırın:
    ```bash
    flutter run
    ```

---
*Geliştirici: Samet Kartal*
