# Google Play yayın hazırlığı

## Hazırlanan sürüm

- Sürüm: **1.0.0 (1)**; uygulama adı **İZ**.
- Yayın paket kimliği: **com.ebranurozbalik.iz**. Bu kimlik henüz Play Console'da kaydedilmedi. Mevcut bir mağaza kaydı varsa ilk yüklemeden önce onun kimliğiyle eşleştirin.
- Android hedefi: **API 36**, en düşük sürüm **API 24**.
- Geliştirme paketi **com.example.iz** olarak korundu; eski geliştirme kurulumunun günlüğü silinmez. Yayın kurulumu ayrı bir uygulamadır; geliştirme verileri otomatik taşınmaz.
- Çevrimiçi kitap arama/keşif ile İZ Katalog API üzerinden film, dizi ve tiyatro araması hazırdır. API adresi bulunmayan derlemelerde bu üç tür için elle kayıt çalışmaya devam eder.
- Gizlilik ve yardım metinleri uygulama içinden çevrimdışı açılır. Yerel günlüğü silme işlemi onay ister ve yazma hatasında kayıtları korur.
- Android yayınında internet izni, HTTPS kullanımı, uygulama adı ve özel/adaptif simge hazır.

## Mağaza dosyaları

- [Türkçe mağaza metinleri](listing-tr.md)
- [Veri güvenliği inceleme notları](data-safety.md)
- [512 × 512 simge](graphics/icon-512.png)
- [1024 × 500 tanıtım görseli](graphics/feature-1024x500.png)
- [Gizlilik sayfası](site/privacy.html)

Uygulama ve web gizlilik metni `assets/legal/privacy_tr.json` kaynağından üretilir. Herkese açık sürüm `https://iz-catalog-api.iz-katalog.workers.dev/privacy` adresinde yayımlanır. Grafikler `swift tool/render_brand_assets.swift` ile yeniden üretilebilir; simgenin vektör kaynağı `assets/brand/iz-icon.svg` dosyasındadır.

## Yerel ayarlar

`config/release.example.json` dosyasını `config/release.local.json` adıyla kopyalayın. Geliştirici adı, destek e-postası, herkesin açabildiği HTTPS gizlilik adresi ve yayımlanan İZ Katalog API adresini doldurun. Yerel dosyalar Git tarafından dışlanır.

```sh
python3 tool/render_privacy_site.py
```

Bu komut iletişim bilgileriyle gizlilik sayfasını günceller. Sayfayı kullanıcı girişi gerektirmeyen bir web adresinde yayımladıktan sonra bu adresi hem yerel ayara hem Play Console'a girin. Taslak uyarısı içeren sayfayı yayımlamayın.

## Android imzası

Mevcut bir uygulamayı güncelliyorsanız mevcut **yükleme anahtarını** kullanın; yeni anahtar üretmeyin. Yeni bir uygulama için Android Studio'nun **Generate Signed App Bundle** akışıyla yükleme anahtarını oluşturabilirsiniz. Oluşturma parolalarını ve anahtar dosyasını kendi güvenli yedeğinizde saklayın.

`android/key.properties.example` dosyasını `android/key.properties` adıyla kopyalayıp anahtarın konumu ve bilgileriyle doldurun. Anahtar ve parola dosyalarını Git'e eklemeyin. Yayın ayarında geliştirme imzasına otomatik dönüş kaldırıldı.

## Kontrol ve derleme

```sh
python3 tool/build_play_release.py --check
python3 tool/build_play_release.py
```

İkinci komut iletişim/gizlilik/imza ayarlarını doğrular; gizlilik sayfasına erişimi kontrol eder; testleri ve kod analizini çalıştırır; ardından imzalı AAB üretir. **Hiçbir şey yüklemez veya yayımlamaz.**

Çıktı: `build/app/outputs/bundle/release/app-release.aab`.

Yalnız derleme doğrulaması için `flutter build appbundle --release --no-pub` kullanılabilir. Anahtar yoksa bu dosya **imzasızdır** ve Play Console'a yüklemeye hazır değildir. İmzalı sürümü oluşturduktan sonra ilk yüklemede Console'un paket/sürüm/imza doğrulamalarını kontrol edin.

## Gerçek cihaz ve mağaza adımları

23 Kasım 2026 yerel doğrulaması: **106 Flutter testi ve 8 API testi başarılıdır**; Flutter kod analizinde sorun bulunmamıştır. Profil sürümü Android 15 / API 35 Pixel 8 emülatöründe açılmış; günlük, keşfet, arama, detay ve arşive ekleme akışları normal ve dar ekran ölçülerinde kontrol edilmiştir. İZ Katalog API ile gizlilik sayfası Cloudflare Workers üzerinde yayımlanmıştır. Yükleme anahtarı henüz hazırlanmadığı için mağazaya hazır imzalı AAB oluşturulmamıştır. Bu kontroller fiziksel cihaz ve Play Console iç testinin yerine geçmez.

1. Google Play Console hesabını oluşturun veya mevcut hesaba erişin. Hesap doğrulaması ve mağaza sözleşmeleri hesap sahibi tarafından tamamlanır.
2. Destek e-postası, gizlilik adresi, hedef kitle, içerik derecelendirme ve Veri güvenliği formunu son paketin davranışına göre tamamlayın. Taslak cevapları incelemeden göndermeyin.
3. İmzalı paketi önce iç teste yükleyin. Android 7+ ve güncel Android'de kurulum/açılış, kitap araması, film/dizi/tiyatro katalog araması ve elle kayıt, yeniden açmada verilerin korunması, çevrimdışı not düzenleme, silmeden vazgeçme ve büyük yazı/klavye kullanımını deneyin.
4. Gerçek Android sürümünden en az iki telefon ekran görüntüsü hazırlayın. Kişisel notları mağaza görsellerine taşımayın.
5. Play Console'un hesabınız için gösterdiği kapalı test ve üretim erişimi adımlarını tamamlayın; kullanıcı sayısı ve süre koşullarını doğrudan Console'dan doğrulayın.

## Yayından önce açık kalanlar

- Play Console hesabının doğrulanması ve uygulama kaydının oluşturulması.
- Veri güvenliği, hedef kitle ve içerik derecelendirme cevaplarının Console'a girilmesi.
- Hesap sahibinin yükleme anahtarıyla imza; gerçek cihaz / iç test doğrulaması.
- Son sürümün telefon ekran görüntüleri, hedef kitle ve derecelendirme cevapları.
- Play Console form bilgilerinin son AAB davranışıyla karşılaştırılması.

## Resmî kaynaklar

- [Flutter Android yayın rehberi](https://docs.flutter.dev/deployment/android)
- [Google Play uygulama oluşturma](https://support.google.com/googleplay/android-developer/answer/9859152?hl=en)
- [Hedef API şartı](https://support.google.com/googleplay/android-developer/answer/11926878?hl=en)
- [Mağaza görselleri](https://support.google.com/googleplay/android-developer/answer/9866151?hl=en)
- [Yeni kişisel hesaplarda test şartı](https://support.google.com/googleplay/android-developer/answer/14151465?hl=en)
