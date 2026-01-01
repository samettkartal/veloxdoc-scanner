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

### ADIM 1: Kategorizasyon ve Metadata Isleme
Dijitallestirme sureci, verinin dogru siniflandirilmasi ile baslar. Ham goruntu islenmeden once, kullanici tarafindan veya otomatik olarak kategorize edilir. Bu adim, goruntu isleme hattindan cikacak olan sonucun hangi formatta (Siyah-Beyaz, Gri Tonlama veya Renkli) saklanacagina dair ipuclari tasir. Ornegin bir "Kimlik Karti" icin renk dogrulugu kritikken, bir "Ders Notu" icin yuksek kontrast ve siyah-beyaz ayrimi daha onemlidir. Sistem, secilen kategoriye gore post-processing (son isleme) parametrelerini dinamik olarak ayarlar.

<div align="center">
  <img src="assets/screenshots/screen_02.jpg" width="300" alt="Kategorizasyon" />
</div>

### ADIM 2: Yapay Zeka ile Otonom Belge Tespiti (AI Segmentation)
VeloxDoc'un en kritik bilesenlerinden biri, ham kamera goruntusu uzerindeki belgeyi zemin (masa, hali vb.) uzerinden ayirt eden yapay zeka moduludur. Geleneksel yontemler (Canny Edge Detection gibi), goruntu uzerindeki tum keskin kenarlari tespit ettigi icin, karmasik zeminlerde (ornegin ahsap desenli masa veya karisik kablolar) basarisiz olur.

VeloxDoc, bu problemi asmak icin **Semantik Segmentasyon (Semantic Segmentation)** yontemini kullanir. Ozel olarak egitilmis hafifletilmis bir **U-Net** modeli (MobileNetV2 backbone ile), 256x256 cozunurlugune indirgenmis kamera goruntusunu girdi olarak alir. Model, goruntudeki her bir pikseli "Belge" veya "Arkaplan" olarak siniflandirir.

Bu islem sonucunda bir **Olasilik Haritasi (Probability Map)** uretilir. Bu harita, goruntunun hangi bolgelerinin belgeye ait oldugunu gosteren gri tonlamali bir maskedir. Sistem, bu haritayi belirli bir esik degerinden (Thresholding) gecirerek **Binary Mask** (Siyah-Beyaz Maske) elde eder. Bu yontem, gurultulu ve dusuk isikli ortamlarda dahi %98'in uzerinde tespit dogrulugu saglar.

<div align="center">
  <img src="assets/screenshots/screen_03.jpg" width="300" alt="Yapay Zeka Segmentasyonu" />
</div>

### ADIM 3: Geometrik Rektifikasyon ve Perspektif Duzeltme
Yapay zeka tarafindan uretilen Binary Maske, belgenin kabaca nerede oldugunu soyler ancak geometrik duzeltme icin kesin kose koordinatlarina ihtiyac vardir. Bu asamada **OpenCV** kutuphanesi devreye girer.

1.  **Kontur Analizi (Contour Finding):** Maske uzerindeki en dis sinirlar (External Contours) taranir.
2.  **Cokgen Yaklasimi (ApproxPolyDP):** Tespit edilen konturlar genellikle pruzlu kenarlara sahiptir. **Douglas-Peucker Algoritmasi** kullanilarak, bu karmasık şekiller daha az köseye sahip cokgenlere indirgenir. Algoritma, dort koseye sahip en buyuk alani "Belge Dortgeni" olarak kabul eder.
3.  **Warping (Perspektif Donusumu):** Tespit edilen 4 nokta ile ideal dikdortgen arasindaki **Homografi Matrisi** hesaplanir ve goruntu duzlestirilir.

<div align="center">
  <img src="assets/screenshots/screen_04.jpg" width="300" alt="Perspektif Duzeltme" />
</div>

### ADIM 4: Manuel Onay ve Hassas Düzenleme (Manual Adjustment)
Yapay zeka %98 oranında doğru tespit yapsa da, son kontrol her zaman kullanıcıdadır. Kamera çekimi sonrası, tespit edilen köşe noktaları ekranda kullanıcıya sunulur. Eğer sistem belgenin bir köşesini yanlış algıladıysa (örn. masadaki başka bir nesneye takıldıysa), kullanıcı bu adımda müdahale edebilir.

Kullanıcı, köşe noktalarını sürüklerken devreye giren **Büyüteç (Magnifier)** özelliği sayesinde pikselleri yakından görür ve mikroskobik hassasiyette düzeltme yapabilir. Bu aşama, çıktının geometrik olarak kusursuz olmasını garanti eden "İnsan-Makine İşbirliği" katmanıdır. Onay verildiği anda perspektif düzeltme (Warp) işlemi uygulanır.

<div align="center">
  <img src="assets/screenshots/screen_edit.png" width="300" alt="Manual Edge Adjustment" />
</div>

### ADIM 5: Kontrast Iyilestirme ve OCR (Final Sonuç)
Son aşamada, geometrik ve görsel olarak iyileştirilmiş belge elde edilir. **Adaptif Eşikleme** (Adaptive Thresholding) ile gölgeler temizlenir, **Histogram Eşitleme** ile kontrast artırılır. Temizlenen bu görüntü **Google ML Kit OCR** motoruna beslenerek metinler dijital veriye dönüştürülür.

<div align="center">
  <img src="assets/screenshots/screen_05.jpg" width="300" alt="Final Sonuc ve OCR" />
</div>

---
*Geliştirici: Samet Kartal*
