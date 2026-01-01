# VeloxDoc (Akıllı Belge Tarayıcı)

**VeloxDoc**, derin öğrenme destekli bir mobil belge rektifikasyon (düzeltme) ve dijitalleştirme sistemidir. Fiziksel belgeleri mobil cihaz kamerasıyla algılar, perspektif hatalarını giderir ve yüksek kontrastlı, dijital formatlara dönüştürür.

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

## 🎯 Problem ve Çözüm Yaklaşımı

**Problem:** Fiziksel belgelerin mobil cihazlarla dijitalleştirilmesi sürecinde, **perspektif bozuklukları** (açılı çekim) ve **homojen olmayan aydınlatma** koşulları, elde edilen verinin okunabilirliğini ve işlenebilirliğini doğrudan düşürmektedir. Standart yöntemler, belgeyi arka plandan izole etmekte genellikle yetersiz kalır.

**Çözüm:** VeloxDoc, bu kısıtlamaları aşmak için **semantik segmentasyon** tabanlı bir yapay zeka mimarisi kullanır. Sistem, görüntü üzerindeki belge alanını otonom olarak algılar, geometrik rektifikasyon uygular ve perspektif hatasından arındırılmış, normalize edilmiş dijital bir çıktı üretir.

---

## 🏗️ Sistem Mimarisi ve Görüntü İşleme Hattı (Pipeline)

Uygulama, ham kamera görüntüsünü dijital belgeye dönüştürmek için 5 aşamalı hibrit bir işlem hattı kullanır:

1.  **Girdi (Input):** Yüksek çözünürlüklü ham kamera görüntüsü alınır.
2.  **Ön İşleme (Pre-processing):** Görüntü, AI modelinin gereksinimi olan 256x256 boyutuna indirgenir (Downsampling) ve normalize edilir.
3.  **Yapay Zeka (Inference):** **U-Net** tabanlı TFLite modeli ile piksel tabanlı belge/zemin ayrıştırması (binary segmentation) yapılır.
4.  **Son İşleme (Post-processing):** Oluşturulan maske üzerinde OpenCV ile kontur analizi yapılır ve belgenin 4 köşe koordinatı tespit edilir.
5.  **Dönüşüm (Transformation):** Hesaplanan perspektif matrisleri ile görüntü çarpıtılarak (warping) kuş bakışı (bird's-eye view) forma getirilir.

---

## 🎨 Kontrast ve Görüntü İyileştirme (Image Enhancement)

Belge sınırları düzeltildikten sonra, metin okunabilirliğini maksimize etmek için özel bir **Kontrast Geliştirme** modülü devreye girer. Bu modül, özellikle silik metinlerde ve gölgeli çekimlerde kritik rol oynar.

*   **Adaptif Eşikleme (Adaptive Thresholding):** Görüntü üzerindeki aydınlatma farklarını analiz ederek, her bölge için dinamik bir eşik değeri belirler. Bu sayede gölgede kalan metinler bile net bir şekilde arka plandan ayrıştırılır.
*   **Histogram Eşitleme:** Görüntünün histogram dağılımını genişleterek, siyah (metin) ve beyaz (kağıt) arasındaki kontrast farkını artırır.
*   **Gürültü Giderme (Denoising):** Sensör gürültülerini ve kağıt üzerindeki lekeleri temizleyerek pürüzsüz bir zemin oluşturur.

---

## 📋 Örnek Kullanım Senaryosu

Aşağıda, açılı ve düşük ışıkta çekilmiş bir öğrenci belgesinin VeloxDoc ile nasıl işlendiği görülmektedir. Sistem, belgeyi masadan kusursuz bir şekilde ayırmış ve sanki doğrudan bir tarayıcıdan çıkmış gibi dijitalleştirmiştir.

<div align="center">
  <img src="assets/documents/ostim_belge_crop.png" width="400" alt="İşlenmiş Belge Örneği" />
  <p><i>İşlenmiş ve perspektifi düzeltilmiş çıktı</i></p>
</div>

---

## 🛠️ Teknik Altyapı
-   **Framework:** Flutter (Dart)
-   **AI Engine:** TensorFlow Lite (Custom U-Net Model)
-   **CV Library:** OpenCV (C++ Native) via `opencv_dart`
-   **OCR:** Google ML Kit
-   **Database:** Hive (NoSQL, Encrypted)

---
*Geliştirici: Samet Kartal*
