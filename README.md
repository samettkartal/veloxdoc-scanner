# VeloxDoc: Derin Ogrenme Destekli Belge Rektifikasyon ve Dijitallestirme Sistemi

VeloxDoc, fiziksel belgelerin mobil cihazlar araciligiyla dijital ortama aktarilmasini saglayan, uctan uca (end-to-end) bir goruntu isleme ve dijital arsivleme cozumudur. Proje, siradan kamera uygulamalarindan farkli olarak, ham goruntu verisini anlamlandirmak, geometrik bozukluklari gidermek ve okunabilirligi maksimize etmek icin **Derin Ogrenme (Deep Learning)**, **Bilgisayarli Goru (Computer Vision)** ve **Sinyal Isleme (Signal Processing)** disiplinlerini hibrit bir mimaride birlestirir.

Asagidaki teknik dokumantasyon, sistemin mimarisini, kullanilan algoritmalari ve veri isleme hattini (pipeline) detaylandirmaktadir.

---

## 1. Sistem Mimarisi ve Veri Yonetimi

Modern mobil uygulama gelistirme standartlarina uygun olarak, proje **Clean Architecture** prensiplerine gore tasarlanmistir. Bu mimari, is mantigini (Business Logic), veri katmanini (Data Layer) ve kullanici arayuzunu (Presentation Layer) birbirinden izole eder. Bu sayede sistem, yuksek surdurulebilirlik ve test edilebilirlik sunar.

Veri kaliciligi icin cihaz uzerinde calisan, yuksek performansli ve sifreli bir NoSQL veritabani olan **Hive** tercih edilmistir. Hive, belgelerin meta verilerini (olusturulma tarihi, kategori, etiketler vb.) ve fiziksel dosya yollarini yonetir. AES-256 sifreleme algoritmasi ile korunan bu yapi, hassas belgelerin guvenligini garanti altina alir. Dosya sistemi, binlerce belgeyi milisaniyeler icinde indeksleyebilecek ve sorgulayabilecek sekilde optimize edilmistir.

<div align="center">
  <img src="assets/screenshots/screen_01.jpg" width="300" alt="Ana Ekran ve Mimari" />
</div>

---

## 2. Dijitallestirme Sureci ve Algoritmik Pipeline

Sistem, ham kameradan alinan goruntuyu (Raw Input) yuksek kaliteli bir dijital belgeye donusturmek icin 5 kritik asamadan olusan bir pipeline kullanir.

### **İşlenecek Örnek Belge (Sample Document)**
Aşağıdaki görsel, sistemin işleme kapasitesini göstermek adına referans olarak kullanılan örnek bir öğrenci belgesidir. Sistem, bu belgeyi karmaşık zeminlerden ayırarak dijitalleştirecektir.

<div align="center">
  <img src="assets/screenshots/ostim_belge_crop.png" width="450" alt="İşlenecek Örnek Belge" />
</div>

### ADIM 1: Manuel Onay ve Hassas Düzenleme (Manual Adjustment)
Süreç, kullanıcının belge üzerinde tam kontrol sağlamasıyla başlar. Yapay zeka %98 oranında doğru tespit yapsa da, son söz her zaman kullanıcıdadır. **Büyüteç (Magnifier)** özelliği sayesinde köşe noktaları mikroskobik hassasiyette ayarlanabilir. Bu, "Human-in-the-loop" (Döngüdeki İnsan) yaklaşımının en önemli parçasıdır.

<div align="center">
  <img src="assets/screenshots/screen_edit.png" width="300" alt="Manual Edge Adjustment" />
</div>

### ADIM 2: Kategorizasyon ve Metadata Isleme
Onaylanan belge, anlamsal olarak kategorize edilir (Fatura, Kimlik vb.). Bu adımda kullanıcı, belgenin meta verilerini düzenler. Sistem, seçilen kategoriye göre görüntü işleme parametrelerini (renk uzayı, sıkıştırma oranı) otomatik olarak optimize eder.

<div align="center">
  <img src="assets/screenshots/screen_02.jpg" width="300" alt="Kategorizasyon" />
</div>

### ADIM 3: Yapay Zeka ile Otonom Belge Tespiti (AI Segmentation)
Arka planda çalışan **U-Net** modeli, görüntüdeki belgeyi zemin üzerinden ayrıştırır. Klasik kenar tespitinin aksine, doku ve desen analizi yaparak karmaşık zeminlerde bile (ahşap masa, halı) belgeyi izole eder. Bu adımda üretilen **Olasılık Haritasi (Probability Map)**, belgenin geometrik sınırlarını belirler.

<div align="center">
  <img src="assets/screenshots/screen_03.jpg" width="300" alt="Yapay Zeka Segmentasyonu" />
</div>

### ADIM 4: Geometrik Rektifikasyon (Perspective Correction)
Tespit edilen sınırlar ve kullanıcının onayladığı köşe noktaları kullanılarak **Homografi Matrisi** hesaplanir. **OpenCV** kütüphanesi, bu matrisi kullanarak açılı duran belgeyi "Warp" işlemi ile düzleştirir. Sonuç olarak, perspektif hatası giderilmiş, dikdörtgen formda bir görüntü elde edilir.

<div align="center">
  <img src="assets/screenshots/screen_04.jpg" width="300" alt="Perspektif Duzeltme" />
</div>

### ADIM 5: Kontrast Iyilestirme ve OCR (Final Sonuç)
Son aşamada, geometrik ve görsel olarak iyileştirilmiş belge elde edilir. **Adaptif Eşikleme** (Adaptive Thresholding) ile gölgeler temizlenir, **Histogram Eşitleme** ile kontrast artırılır. Temizlenen bu görüntü **Google ML Kit OCR** motoruna beslenerek metinler dijital veriye dönüştürülür.

<div align="center">
  <img src="assets/screenshots/screen_05.jpg" width="300" alt="Final Sonuc ve OCR" />
</div>

---
*Geliştirici: Samet Kartal*
