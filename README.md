# Pişir - Akıllı Yemek Asistanı

Pişir, kullanıcıların ellerindeki malzemelere göre lezzetli yemek tarifleri keşfetmelerine yardımcı olmak için tasarlanmış modern, Flutter tabanlı bir mobil uygulamadır. Şık kullanıcı arayüzü ve güçlü özellikleriyle Pişir, yemek yapmayı erişilebilir ve eğlenceli hale getirir.

## 📱 Özellikler

- **Akıllı Tarif Keşfi**: Elinizdeki malzemelerle eşleşen tarifleri bulun.
- **Kullanıcı Kimlik Doğrulama**: E-posta ve Google ile Giriş Yapma ile güvenli giriş.
- **Zengin Tarif Detayları**: Kapsamlı tarif talimatları, malzeme listeleri ve görseller.
- **Malzeme Yönetimi**: Kolay seçim için kategorize edilmiş geniş malzeme veritabanı (Sebzeler, Meyveler, Bakliyat, Etler, Süt Ürünleri vb.).
- **Karanlık Mod**: Rahat gece kullanımı için tam destekli karanlık tema.
- **Çevrimdışı Öncelikli**: İnternet bağlantısı olmasa bile favori tariflerinize erişim sağlamak için çevrimdışı özelliklerle oluşturulmuştur.
- **Favoriler**: Hızlı erişim için favori tariflerinizi kaydedin.

## 🛠 Teknoloji Yığını

- **Framework**: [Flutter](https://flutter.dev/) (Dart)
- **Backend & Kimlik Doğrulama**: [Firebase](https://firebase.google.com/)
  - Firebase Authentication
  - Cloud Firestore
- **Durum Yönetimi (State Management)**: [Provider](https://pub.dev/packages/provider)
- **Yerel Depolama**: [Shared Preferences](https://pub.dev/packages/shared_preferences) & [Flutter Secure Storage](https://pub.dev/packages/flutter_secure_storage)
- **Diğer Önemli Paketler**:
  - `cached_network_image`: Verimli resim yükleme için.
  - `image_picker`: Resim yükleme işlemleri için.
  - `webview_flutter`: Uygulama içinde web içeriği görüntülemek için.

## 🚀 Başlarken

Yerel bir kopyayı çalışır hale getirmek için aşağıdaki adımları izleyin.

### Ön Koşullar

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Sürüm >=3.10.0)
- Dart SDK (Sürüm >=2.18.0 <4.0.0)
- Flutter eklentileri yüklü bir IDE (VS Code veya Android Studio).

### Kurulum

1. **Depoyu klonlayın**
   ```bash
   git clone https://github.com/kullaniciadiniz/pisir.git
   cd pisir/pisir
   ```

2. **Bağımlılıkları yükleyin**
   ```bash
   flutter pub get
   ```

3. **Firebase Kurulumu**
   - [Firebase Konsolu](https://console.firebase.google.com/)'nda yeni bir proje oluşturun.
   - Firebase projenize Android ve iOS uygulamalarını ekleyin.
   - `google-services.json` (Android için) ve `GoogleService-Info.plist` (iOS için) dosyalarını indirin.
   - Bu dosyaları sırasıyla `android/app/` ve `ios/Runner/` dizinlerine yerleştirin.

4. **Uygulamayı çalıştırın**
   ```bash
   flutter run
   ```

## 📂 Proje Yapısı

```
pisir/
├── lib/
│   ├── animations/      # Özel animasyonlar ve geçişler
│   ├── models/          # Veri modelleri
│   ├── providers/       # Durum yönetimi sağlayıcıları
│   ├── screens/         # Arayüz Ekranları (Giriş, Ana Ekran, Detay vb.)
│   ├── services/        # API ve Firebase servisleri
│   └── main.dart        # Uygulamanın giriş noktası
├── assets/              # Resimler, ikonlar ve veri dosyaları
└── ...
```