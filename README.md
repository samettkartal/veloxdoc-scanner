# VeloxDoc: Hibrit Goruntu Isleme ve Dijital Arsivleme Sistemi

VeloxDoc, fiziksel belgelerin mobil cihazlar araciligiyla dijital ortama aktarilmasini saglayan, uctan uca (end-to-end) bir goruntu isleme ve dijital arsivleme cozumudur. Proje, ham goruntu verisini anlamlandirmak icin **Derin Ogrenme (Deep Learning - TFLite)** ve **Bilgisayarli Goru (OpenCV)** kutuphanelerini hibrit bir yapida kullanir.

Asagidaki teknik dokumantasyon, sistemin **gercek** mimarisini ve kod tabanindaki (Codebase) somut isleyisi detaylandirmaktadir.

---

## 1. Sistem Mimarisi ve Veri Yonetimi

Proje, **clean architecture** prensiplerine sadik kalarak; veri (Data), arayuz (Screen) ve servis (Service) katmanlarini birbirinden ayirir. Veri kaliciligi, cihaz uzerinde calisan **Hive NoSQL** veritabani ile saglanir. Belgeler, `FolderModel` yapisi altinda klasorlenebilir ve opsiyonel olarak sifrelenmis (Secure Box) sekilde saklanabilir.

<div align="center">
  <img src="assets/screenshots/screen_01.jpg" width="300" alt="Ana Ekran ve Klasor Yapisi" />
</div>

---

## 2. Dijitalleştirme Pipeline'ı (Teknik Akış)

Sistem, kullanıcı odaklı bir akış izler. Kullanıcı, yapay zekanın sonuçlarını adım adım denetleyebilir.

### **Girdi: İşlenecek Örnek Belge**
Sisteme giren ham görüntü. (Örnek: `ostim_belge_crop.png`)

<div align="center">
  <img src="assets/screenshots/ostim_belge_crop.png" width="450" alt="Ham Girdi" />
</div>

### ADIM 1: Manuel Onay ve Köşe Düzenleme (Manual Corner Adjustment)
Kamera çekimi sonrası (`camera_screen`), elde edilen görüntü ve AI tarafından tahmin edilen 4 köşe noktası (`List<Offset>`) kullanıcıya sunulur. Algoritma %100 her zaman doğru çalışmayabilir; bu yüzden **CropScreen** arayüzünde kullanıcıya "Drag Handles" (Sürüklenebilir Tutamaçlar) sunulur. Kullanıcı, belgenin köşelerini parmağıyla tam oturtarak geometrik hatayı sıfıra indirir. Bu, sistemin en kritik "insan onayı" katmanıdır.

<div align="center">
  <img src="assets/screenshots/screen_edit.png" width="300" alt="Manual Corner Adjustment" />
</div>

### ADIM 2: Klasör ve Belge Yönetimi (Folder Management)
Dijitalleşen belgeler, `FolderScreen` yapısında yönetilir. Kullanıcılar, belgelerini "Fatura", "Kimlik" veya "Ders Notu" gibi kendi oluşturdukları klasörler altında gruplayabilir. Hive veritabanı sayesinde binlerce belge arasında hızlıca listeleme yapılır. Ayrıca hassas belgeler için şifreli giriş özelliği bulunur.

<div align="center">
  <img src="assets/screenshots/screen_02.jpg" width="300" alt="Folder Management" />
</div>

### ADIM 3: Yapay Zeka ile Kenar Regresyonu (Coordinate Regression)
VeloxDoc, belge tespiti için Segmentation (Piksel boyama) yerine, çok daha hızlı ve hedef odaklı olan **Coordinate Regression** (Koordinat Tahmini) yöntemini kullanır.

*   **Model:** `scan_model_pro.tflite`
*   **Girdi:** 224x224 RGB Görüntü.
*   **Çıktı:** [x1, y1, x2, y2, x3, y3, x4, y4] (8 parametreli vektör).

Model, görüntüyü analiz eder ve doğrudan belgenin 4 köşesini tahmin eder. Eğer TFLite modeli başarısız olursa veya confiency düşükse, sistem otomatik olarak **OpenCV Canny Edge Detection + FindContours** algoritmasına ("Fallback Mechanism") geçer.

<div align="center">
  <img src="assets/screenshots/screen_03.jpg" width="300" alt="AI Regression" />
</div>

### ADIM 4: Geometrik Rektifikasyon (Perspective Warp)
Kullanıcının doğruladığı 4 nokta (Kaynak) ve hedef dikdörtgen boyutları kullanılarak **Homografi Matrisi (3x3)** hesaplanır. OpenCV'nin `warpPerspective` fonksiyonu, bu matrisi kullanarak görüntüyü "kuş bakışı" görünüme dönüştürür. Açılı çekilen fotoğraflar bu adımda düzleştirilir.

<div align="center">
  <img src="assets/screenshots/screen_04.jpg" width="300" alt="Perspective Warp" />
</div>

### ADIM 5: Sonuç ve Paylaşım
İşlenen belge, nihai olarak görüntülenir. Kullanıcı buradan PDF çıktısı alabilir veya belgeyi galeriye kaydedebilir.

<div align="center">
  <img src="assets/screenshots/screen_05.jpg" width="300" alt="Final Result" />
</div>

---
*Geliştirici: Samet Kartal*
