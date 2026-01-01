# VeloxDoc (Akıllı Belge Tarayıcı)

**VeloxDoc**, derin öğrenme destekli bir mobil belge rektifikasyon (düzeltme) ve dijitalleştirme sistemidir. Fiziksel belgeleri mobil cihaz kamerasıyla algılar, perspektif hatalarını giderir ve yüksek kontrastlı, dijital formatlara dönüştürür.

---

## 🚀 Dijitalleştirme Süreci ve Kullanım Senaryosu

VeloxDoc, karmaşık görüntü işleme adımlarını kullanıcı dostu bir arayüz arkasında otomatikleştirir. Aşağıda, tipik bir belgenin sisteme girişinden dijital çıktıya dönüşüm süreci adım adım gösterilmektedir.

### 1. Ana Ekran ve Organizasyon
Uygulama açıldığında, kullanıcıyı temiz bir arayüz karşılar. Belgeler, "Fatura", "Kimlik", "Ders Notu" gibi akıllı klasörler altında kategorize edilebilir.

<div align="center">
  <img src="assets/screenshots/screen_01.jpg" width="200" alt="Ana Ekran" style="margin-right: 20px;" />
  <img src="assets/screenshots/screen_02.jpg" width="200" alt="Klasör Yönetimi" />
</div>

### 2. Akıllı Tespit ve Çekim (AI Detection)
Kamera açıldığında, **Yapay Zeka** modülü saniyede 30 kare hızında sahneyi tarar. Belge ile zemin arasındaki farkı analiz eder ve belge sınırlarını (mavi çerçeve) otomatik olarak çizer. Kullanıcının manuel odaklama yapmasına gerek kalmaz.

<div align="center">
  <img src="assets/screenshots/screen_03.jpg" width="250" alt="Canlı Belge Tespiti" />
</div>

### 3. Perspektif Düzeltme ve Onay
Yapay zeka bazen milimetrik hatalar yapabilir veya kullanıcı özel bir alanı (örn. sadece bir paragrafı) taramak isteyebilir. Bu aşamada kullanıcı, tespit edilen köşe noktalarını manuel olarak kaydırarak son rötuşları yapabilir.

<div align="center">
  <img src="assets/screenshots/screen_04.jpg" width="250" alt="Perspektif Kırpma Ekranı" />
</div>

### 4. Sonuç ve Dijitalleştirme
Sistem, belirlenen alanı "kuş bakışı" görünüme getirir (Warping). Ardından **Kontrast İyileştirme** algoritmaları devreye girerek gölgeleri temizler ve metni netleştirir. Son olarak **OCR** teknolojisi ile belgedeki metinler ("Tanınan Metin") dijital olarak dışarı aktarılır.

<div align="center">
  <img src="assets/screenshots/screen_05.jpg" width="250" alt="Nihai Taranmış Belge" />
</div>

---

## 🎯 Problem ve Çözüm Yaklaşımı
**Problem:** Standart mobil çekimlerde oluşan perspektif bozukluğu (açılı duruş) ve ışık yetersizliği (gölge), belgelerin okunmasını imkansız kılar.
**Çözüm:** VeloxDoc, **U-Net** tabanlı semantik segmentasyon mimarisi ile belgeyi zeminden kusursuzca ayırır ve matematiksel dönüşümlerle tarayıcı kalitesinde düzleştirir.

---

## 🎨 Kontrast ve Görüntü İyileştirme
Sadece geometriyi düzeltmek yetmez; metnin okunabilirliği de artırılmalıdır.
*   **Adaptif Eşikleme:** Bölgesel ışık analizleri yaparak gölgedeki harfleri kurtarır.
*   **Histogram Eşitleme:** Kağıt beyazı ile mürekkep siyahı arasındaki kontrastı maksimize eder.
*   **Gürültü Giderme:** Kamera sensöründen kaynaklı kumlanmayı temizler.

---

## 🏗️ Sistem Mimarisi (Pipeline)
1.  **Girdi:** Yüksek çözünürlüklü kamera akışı.
2.  **AI Segmentasyon (TFLite):** Belge/Zemin ayrıştırması.
3.  **Kontur Analizi (OpenCV):** Köşe noktalarının matematiksel tespiti.
4.  **Perspektif Dönüşümü:** Görüntünün düz bir düzleme oturtulması.
5.  **OCR (ML Kit):** Metin çıkarımı.

---

## 🛠️ Teknik Altyapı
-   **Framework:** Flutter (Dart)
-   **AI Engine:** TensorFlow Lite
-   **CV Library:** OpenCV
-   **Database:** Hive (NoSQL)
-   **OCR:** Google ML Kit

---
*Geliştirici: Samet Kartal*
