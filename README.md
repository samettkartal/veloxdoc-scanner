# VeloxDoc: Derin Ogrenme Destekli Belge Rektifikasyon Sistemi

VeloxDoc, fiziksel belgelerin mobil cihazlar araciligiyla dijital ortama aktarilmasini saglayan, derin ogrenme (Deep Learning) tabanli gelismis bir goruntu isleme uygulamasidir. Bu proje, standart mobil tarama uygulamalarindan farkli olarak, goruntudeki perspektif bozukluklarini otonom olarak algilar ve matematiksel rektifikasyon yontemleri ile hatasiz dijital ciktilar uretir.

---

## Projenin Amaci ve Cozum Yaklasimi

Fiziksel belgelerin dijitallestirilmesi surecinde karsilasilan en buyuk zorluk, kullanicinin cekim acisindan kaynaklanan geometrik bozukluklar (perspektif hatasi) ve degisken isik kosullaridir. Standart yontemler genellikle belge sinirlarini karmasik arka planlardan ayirt etmekte yetersiz kalir.

VeloxDoc, bu problemi asmak icin Semantik Segmentasyon tabanli ozel bir yapay zeka mimarisi kullanir. Sistem, piksel tabanli analiz yaparak belgeyi zeminden ayirir ve goruntuyu normalize ederek tarayici kalitesinde duzlestirir.

---

## Sistem Mimarisi ve Calisma Prensipleri

VeloxDoc, ham kamera goruntusunu anlamli bir dijital belgeye donusturmek icin cok katmanli bir islem hatti (pipeline) kullanir.

### 1. Ana Arayuz ve Veri Yonetimi

Uygulamanin giris ekrani, kullanicinin belgelerini organize edebilecegi klasor tabanli bir yapi sunar. Veriler cihaz uzerinde sifreli bir NoSQL veritabani (Hive) icerisinde saklanir. Bu yapi, internet baglantisi gerektirmeden hizli erisim ve yuksek guvenlik saglar.

<div align="center">
  <img src="assets/screenshots/screen_01.jpg" width="300" alt="Ana Ekran Arayuzu" />
</div>

### 2. Yapay Zeka ile Otomatik Belge Tespiti

Kamera modulu aktif edildiginde, arkaplanda calisan TFLite (TensorFlow Lite) modeli devreye girer. Bu model, U-Net mimarisi temel alinarak mobil cihazlar icin optimize edilmistir. Saniyede 30 kare hizinda (30 FPS) gelen goruntuyu analiz eder ve belge sinirlarini tespit eder. Mavi cerceve ile gosterilen alan, yapay zekanin %90'in uzerinde dogrulukla belirledigi belge alanidir.

<div align="center">
  <img src="assets/screenshots/screen_03.jpg" width="300" alt="Yapay Zeka Destekli Tespit" />
</div>

### 3. Geometrik Rektifikasyon ve Kullanici Onayi

Otomatik tespit sonrasinda, sistem kullaniciya bir onizleme sunar. Bu asamada OpenCV kutuphanesi kullanilarak goruntu uzerindeki dort kose noktasi matematiksel olarak hesaplanir. Kullanici, gerekli gordugu durumlarda bu kose noktalarini milimetrik olarak kaydirarak secim alanini ozellestirebilir. Bu hibrit yapi (Otonom AI + Insan Onayi), hatasiz bir sonuc icin kritik oneme sahiptir.

<div align="center">
  <img src="assets/screenshots/screen_04.jpg" width="300" alt="Perspektif Duzeltme ve Kirpma" />
</div>

### 4. Dijitallestirme ve Goruntu Iyilestirme

Kullanici onayi ile birlikte "Perspective Warp" (Perspektif Carpma) algoritmasi calisir. Acili duran belge, piksel piksel islenerek karsidan bakiliyormus gibi 2D duzleme oturtulur. Ardindan Adaptif Esikleme (Adaptive Thresholding) ve Histogram Esitleme filtreleri uygulanarak kagit uzerindeki golgeler temizlenir, metin kontrasti artirilir. Sonuc olarak, sanki profesyonel bir tarayicidan cikmiscasina net ve temiz bir belge elde edilir.

<div align="center">
  <img src="assets/screenshots/screen_05.jpg" width="300" alt="Nihai Taranmis Belge ve OCR" />
</div>

---

## Kullanilan Teknolojiler

Proje, performans ve surdurulebilirlik odakli modern teknolojiler ile gelistirilmistir.

*   **Flutter (Dart):** UI ve uygulama mantigi icin kullanilan ana cerceve.
*   **TensorFlow Lite:** Belge segmentasyonu icin egitilmis derin ogrenme modeli.
*   **OpenCV:** Kontur analizi ve geometrik donusumler icin kullanilan C++ tabanli goruntu isleme kutuphanesi.
*   **Google ML Kit:** Cihaz ici (On-device) metin tanima (OCR) islemleri.
*   **Hive:** Yuksek performansli, sifreli yerel veri depolama cozumu.

---
*Geliştirici: Samet Kartal*
