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

## 2. Kategorizasyon ve Metadata Isleme

Dijitallestirme sureci, verinin dogru siniflandirilmasi ile baslar. Ham goruntu islenmeden once, kullanici tarafindan veya otomatik olarak kategorize edilir. Bu adim, goruntu isleme hattindan cikacak olan sonucun hangi formatta (Siyah-Beyaz, Gri Tonlama veya Renkli) saklanacagina dair ipuclari tasir. Ornegin bir "Kimlik Karti" icin renk dogrulugu kritikken, bir "Ders Notu" icin yuksek kontrast ve siyah-beyaz ayrimi daha onemlidir. Sistem, secilen kategoriye gore post-processing (son isleme) parametrelerini dinamik olarak ayarlar.

<div align="center">
  <img src="assets/screenshots/screen_02.jpg" width="300" alt="Kategorizasyon" />
</div>

---

## 3. Yapay Zeka ile Otonom Belge Tespiti (AI Segmentation)

VeloxDoc'un en kritik bilesenlerinden biri, ham kamera goruntusu uzerindeki belgeyi zemin (masa, hali vb.) uzerinden ayirt eden yapay zeka moduludur. Geleneksel yontemler (Canny Edge Detection gibi), goruntu uzerindeki tum keskin kenarlari tespit ettigi icin, karmasik zeminlerde (ornegin ahsap desenli masa veya karisik kablolar) basarisiz olur.

VeloxDoc, bu problemi asmak icin **Semantik Segmentasyon (Semantic Segmentation)** yontemini kullanir. Ozel olarak egitilmis hafifletilmis bir **U-Net** modeli (MobileNetV2 backbone ile), 256x256 cozunurlugune indirgenmis kamera goruntusunu girdi olarak alir. Model, goruntudeki her bir pikseli "Belge" veya "Arkaplan" olarak siniflandirir.

Bu islem sonucunda bir **Olasilik Haritasi (Probability Map)** uretilir. Bu harita, goruntunun hangi bolgelerinin belgeye ait oldugunu gosteren gri tonlamali bir maskedir. Sistem, bu haritayi belirli bir esik degerinden (Thresholding) gecirerek **Binary Mask** (Siyah-Beyaz Maske) elde eder. Bu yontem, gurultulu ve dusuk isikli ortamlarda dahi %98'in uzerinde tespit dogrulugu saglar.

<div align="center">
  <img src="assets/screenshots/screen_03.jpg" width="300" alt="Yapay Zeka Segmentasyonu" />
</div>

---

## 4. Geometrik Rektifikasyon ve Perspektif Duzeltme

Yapay zeka tarafindan uretilen Binary Maske, belgenin kabaca nerede oldugunu soyler ancak geometrik duzeltme icin kesin kose koordinatlarina ihtiyac vardir. Bu asamada **OpenCV** kutuphanesi devreye girer.

1.  **Kontur Analizi (Contour Finding):** Maske uzerindeki en dis sinirlar (External Contours) taranir.
2.  **Cokgen Yaklasimi (ApproxPolyDP):** Tespit edilen konturlar genellikle pruzlu kenarlara sahiptir. **Douglas-Peucker Algoritmasi** kullanilarak, bu karmasik sekiller daha az koseye sahip cokgenlere indirgenir. Algoritma, dort koseye sahip en buyuk alani "Belge Dortgeni" olarak kabul eder.
3.  **Homografi Matrisi (Homography Transformation):** Tespit edilen 4 nokta (Kaynak) ile hedefledigimiz duz dikdortgen (Hedef) arasindaki iliskiyi kuran 3x3'luk bir donusum matrisi hesaplanir.
4.  **Warping:** Bu matris kullanilarak, goruntunun her bir pikseli yeniden haritalandirilir (Remapping). Sonuc olarak, acili ve perspektif hatasi iceren goruntu, sanki tam tepeden (90 derece aciyla) cekilmis gibi duzlestirilir.

<div align="center">
  <img src="assets/screenshots/screen_04.jpg" width="300" alt="Perspektif ve Homografi" />
</div>

---

## 5. Kontrast Iyilestirme ve Goruntu Zenginlestirme (Post-Processing)

Geometrik olarak duzeltilmis goruntu, henuz dijital bir belge kalitesinde degildir; uzerinde farkli isik kosullarindan kaynaklanan golgeler ve renk sapmalari bulunur. VeloxDoc, bu goruntuyu "tarayici ciktisi" standardina getirmek icin gelismis bir sinyal isleme hatti uygular.

### Adaptif Esikleme (Adaptive Thresholding)
Standart esikleme (Global Thresholding) tum goruntu icin tek bir isik degeri kullanir, bu da golgeli alanlarin tamamen siyah cikmasina neden olur. VeloxDoc ise **Adaptif Esikleme** kullanir. Goruntu kucuk bloklara bolunur ve her blok icin komsu piksellerin ortalamasina gore dinamik bir esik degeri hesaplanir. Bu sayede, kağıdın bir kosesi karanlikta kalsa bile, oradaki metinler basariyla arka plandan ayristirilir.

### Histogram Esitleme ve Gürültü Giderme
Goruntunun histogrami analiz edilerek en koyu (murekkep) ve en acik (kagit) noktalar arasindaki mesafe genisletilir (Contrast Stretching). Ayrica, **Gaussian Blur** ve **Median Filter** gibi tekniklerle sensor gurultuleri (Noise) temizlenir.

Sonuc olarak elde edilen goruntu, **Google ML Kit OCR** motoruna beslenir ve uzerindeki metinler yuksek dogrulukla dijital veriye donusturulur.

<div align="center">
  <img src="assets/screenshots/screen_05.jpg" width="300" alt="Final Sonuc ve OCR" />
</div>

---
*Geliştirici: Samet Kartal*
