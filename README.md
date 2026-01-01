# VeloxDoc: Derin Ogrenme ile Otonom Belge Rektifikasyonu

VeloxDoc, fiziksel belgelerin mobil cihazlar araciligiyla dijital ortamda **tarayici kalitesinde** (scanner-quality) saklanmasini saglayan, derin ogrenme ve bilgisayarli goru (Computer Vision) tekniklerinin hibrit olarak kullanildigi bir goruntu isleme projesidir.

Proje, klasik kenar tespiti yontemlerinin yetersiz kaldigi "dusuk kontrastli" ve "karmasik zeminli" senaryolarda dahi yuksek basari saglamak uzere **Semantik Segmentasyon** mimarisi uzerine insa edilmistir.

---

## 1. Ana Arayuz ve Teknik Altyapi (Dosya Sistemi)
Uygulama acildiginda kullaniciyi karsilayan arayuz, karmasikligi soyutlayarak (Abstraction) sadece en gerekli fonksiyonlari sunar.
-   **Hive (NoSQL):** Veriler cihaz uzerinde sifreli (AES-256) olarak saklanir.
-   **Repository Pattern:** Veri katmani ve Sunum katmani (UI) birbirinden izole edilerek temiz kod mimarisi (Clean Architecture) uygulanmistir.

<div align="center">
  <img src="assets/screenshots/screen_01.jpg" width="300" alt="Ana Arayuz" />
  <p><i>Clean Interface & Encrypted Storage</i></p>
</div>

---

## 2. Hedeflenen Cikti Kalitesi (Reference Benchmark)
Sistemin nihai amaci, asagida gorulen **ostim_belge_crop** ciktisini uretebilmektir. Bu goruntu, sistemin **Geometrik Rektifikasyon** ve **Goruntu Iyilestirme** (Image Enhancement) algoritmalarindan gectikten sonraki ham sonucudur.
-   **Perspektif Hatasi:** %0 (Tam Kus Bakisi / Bird's-eye View)
-   **Golge ve Gurultu:** Temizlenmis (Denoised)
-   **Metin Kontrasti:** Maksimize edilmis (Binarized/Thresholded)

<div align="center">
  <img src="assets/documents/ostim_belge_crop.png" width="450" alt="Referans Cikti Kalitesi" />
  <p><i>Hedeflenen Rektifiye Edilmis Dijital Cikti</i></p>
</div>

---

## 3. Dijitallestirme Sureci ve Algoritmik Pipeline

Sistem, ham kameradan alinan goruntuyu (Raw Input) yukaridaki referans kaliteye getirmek icin 4 ana asamali bir pipeline kullanir.

### ADIM 1: Veri On Isleme ve Kategorizasyon
Ham goruntu islenmeden once, kullanici belgeyi anlamsal olarak etiketler (Fatura, Kimlik vb.). Bu adim, verinin sadece piksellerden ibaret olmamasini, meta verilerle (Metadata) zenginlesmesini saglar.

<div align="center">
  <img src="assets/screenshots/screen_02.jpg" width="300" alt="Meta Veri Yonetimi" />
</div>

### ADIM 2: Derin Ogrenme ile Otonom Tespit (AI Segmentation)
Klasik `Canny Edge Detection` yontemleri, masadaki baska bir kagit veya kabloyu belge sanabilir. VeloxDoc bu hatayi onlemek icin **U-Net** tabanli bir Yapay Zeka modeli kullanir.

*   **Model Girisi:** 256x256 piksel (Downsampled)
*   **Segmentasyon:** Model, goruntuyu piksel piksel siniflandirir (Pixel-wise Classification). Her piksel icin "Belge" veya "Zemin" olma ihtimalini hesaplayarak bir **Olasilik Haritasi (Probability Map)** uretir.
*   **Binary Mask:** Olasilik haritasi belirli bir esikten (Threshold) gecirilerek siyah-beyaz bir maskeye donusturulur.

<div align="center">
  <img src="assets/screenshots/screen_03.jpg" width="300" alt="AI Tabanli Tespit" />
  <p><i>Gercek zamanli U-Net Segmentasyonu</i></p>
</div>

### ADIM 3: Geometrik Analiz ve Perspektif Matrisi (Warping)
Yapay zeka "belgenin nerede oldugunu" soyler (Maske). Ancak "koselerin tam koordinatlarini" bulmak icin OpenCV devreye girer.

1.  **Kontur Analizi (findContours):** Maske uzerindeki en dis sinirlar tespit edilir.
2.  **Cokgen Indirgeme (approxPolyDP):** Purlu kenarlar, **Douglas-Peucker Algoritmasi** ile sadelestirilir ve belgeyi temsil eden en iyi 4 kose noktasi bulunur.
3.  **Perspektif Donusumu (getPerspectiveTransform):** Bu 4 nokta (Source) ile ideal dikdortgen (Destination) arasindaki iliskiyi kuran **Homografi Matrisi (Homography Matrix)** hesaplanir.

<div align="center">
  <img src="assets/screenshots/screen_04.jpg" width="300" alt="Rektifikasyon Onizleme" />
  <p><i>Kose Noktasi Tespiti ve Homografi Hesabi</i></p>
</div>

### ADIM 4: Sinyal Isleme ve OCR (Final Output)
Hesaplanan matris ile goruntu carpilir (Warp Perspective) ve duzlestirilir. Ancak islem bitmez; metnin okunabilir olmasi icin goruntu iyilestirme uygulanir.

*   **Adaptif Esikleme (Adaptive Thresholding):** Goruntunun tek bir isik degeri yoktur. Algoritma, goruntuyu kucuk bolgelere ayirir ve her bolge icin ayri bir esik degeri hesaplar. Boylece **golgede kalan kisimlar** bile netlesir.
*   **Gama Duzeltme:** Kontrast egrisi (Curve) ayarlanarak murekkep koyulastirilir.
*   **OCR (Optical Character Recognition):** Son olarak Google ML Kit, temizlenen goruntuyu tarar ve icindeki metinleri cikartir.

<div align="center">
  <img src="assets/screenshots/screen_05.jpg" width="300" alt="Goruntu Iyilestirme ve OCR" />
  <p><i>Adaptif Esikleme ve OCR Sonucu</i></p>
</div>

---

## 🛠️ Teknik Stack
-   **AI Model:** TensorFlow Lite (Custom U-Net / MobileNetV2 Backbone)
-   **Image Processing:** OpenCV (C++ Native via FFI)
-   **Mobile Framework:** Flutter 3.x
-   **OCR Engine:** Google ML Kit (On-Device)
-   **Storage:** Hive (NoSQL, Encrypted)

---
*Geliştirici: Samet Kartal*
