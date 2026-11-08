# İZ

Kitap, film, dizi ve tiyatro için kişisel bir kültür günlüğü.

- **Günlüğüm:** Kapak odaklı arşiv, devam ettiğin eserler ve sayfanın altındaki İz takvimi.
- **Popüler kitaplar:** Open Library'nin haftalık ilgi gören kitapları; yatay kapak rafından detay ve arşive ekleme.
- **Keşfetmen için:** Roman, bilim kurgu ve psikoloji türlerinde Türkçe baskısı bulunan kitaplar. Okuma listelerine eklenme sırasına göre gelen sonuçlardan arşivindeki kitaplar çıkarılır; kişisel öneri modeli kullanılmaz.
- **Keşfet:** Kitaplar ve Filmler arasında geçiş. Open Library üzerinden kitap/yazar araması, sıralama, sayfalama ve baskı bilgileri; TMDB üzerinden film araması ve detaydan arşive ekleme.
- **Arşivim:** Tür ve duruma göre filtreleme; not, 5 üzerinden puan, sayfa/bölüm ilerlemesi.
- **Yeni bir iz:** Kitap türünde ad yazarken kapaklı katalog sonuçları açılır. Seçim, kitap adını ve yazarını doldurur; kayıtta kapak ve varsa baskının sayfa sayısı saklanır. Eşleşme yoksa elle kayıt yapılabilir.
- **Kitap dili:** Yeni kayıt ve Keşfet aramasında Türkçe / İngilizce seçilebilir; varsayılan Türkçedir. Seçim, o dilde baskısı olan kitapları filtreler ve eşleşen baskının adını/kapağını gösterir. Dil değişince arama yenilenir; eski dilde seçilen baskı temizlenir.
- **Filmler:** Yeni kayıt ekranında film adı yazarken afişli sonuçlar açılır. Seçilen filmin yönetmeni, yılı, süresi, türleri ve özeti varsa kayda eklenir. Aynı TMDB filmi farklı bir ad/dille seçilse de arşivde tekrar oluşturulmaz. İzleme durumu, puan ve not günlükte saklanır.
- **Film bilgilerinin dili:** Türkçe / İngilizce seçimi film adının ve açıklamasının gösterim dilidir; filmleri yapım ülkesine veya özgün diline göre filtrelemez. Çeviri bulunmadığında katalog özgün adı gösterebilir.
- Film kataloğu aşağıdaki TMDB ayarını gerektirir. Anahtar yokken uygulama bunu belirtir ve elle film ekleme çalışır. Dizi ve tiyatro kayıtları elle eklenir.

Kayıtlar cihazda yerel olarak saklanır; hesap veya bulut eşitleme yoktur. İlk açılışta örnek kayıt eklenmez. Yalnızca listeye eklemek takvimi renklendirmez. İlerleme, durum ve not/puan değişiklikleri o günün izlerini oluşturur; aynı eser ve kayıt türü aynı gün tekrar güncellendiğinde tek iz olarak kalır.

Çevrimiçi raflar bağlantı gerektirir. Her raf bağımsız yüklenir ve yeniden denenebilir; yenileme başarısız olursa ekrandaki kitaplar korunur. Tür seçimi sırasında yüklenen sonuçlar sayfa açık kaldığı sürece tutulur. Kitap rafları ana sayfada Tümü ve Kitap filtrelerinde görünür, İz takvimi en altta kalır.

## Çalıştırma

```sh
flutter pub get
flutter run
```

### Film kataloğunu etkinleştirme

1. [TMDB hesap ayarlarından](https://www.themoviedb.org/settings/api) uygulaman için **API Read Access Token** al. Bu, kısa API anahtarından farklı olan uzun erişim belirtecidir.
2. `config/tmdb.example.json` dosyasını `config/tmdb.local.json` adıyla kopyala ve `TMDB_READ_ACCESS_TOKEN` değerini kendi erişim belirtecinle doldur. Bu yerel dosya Git tarafından dışlanır; belirteci kodda veya sohbette paylaşma.
3. Uygulamayı bu ayarla başlat:

```sh
flutter run --dart-define-from-file=config/tmdb.local.json
```

Ayar değişince uygulamayı durdurup bu komutla yeniden başlat; hot reload yeterli değildir. Ayarsız `flutter run` kitapları ve elle kayıtları kullanmaya devam eder. Film araması ilk sonuç sayfasını getirir; daha belirgin bir ad yazarak sonuçları daraltabilirsin.

Film bilgileri ve afişler [TMDB](https://www.themoviedb.org) tarafından sağlanır. Uygulamadaki “Film bilgileri: TMDB” bağlantısı kaynak bilgisini ve logoyu gösterir. This product uses the TMDB API but is not endorsed or certified by TMDB.

## Kontroller

```sh
flutter test
flutter analyze
```

Testler kitap arama ve baskı bilgilerine ek olarak yerel kayıtları yeniden yükleme, yinelenen günlük kayıtları, hatalı depolama, kaydetme hatasında taslağı koruma ve küçük ekranda büyük yazı kullanımını kapsar. Film testleri sahte katalog yanıtlarıyla arama, dil değişiminde eski isteğin iptali, detay seçimi, arşive kaydetme, tekrar deneme ve anahtarsız elle kayıt akışını doğrular; canlı TMDB erişimi için yerel belirteç gerekir.
