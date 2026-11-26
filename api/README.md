# İZ Katalog API

İZ mobil uygulamasının kitap, film, dizi ve tiyatro katalog servisidir. Servis;
Open Library, Wikidata, Wikimedia Commons ve TVmaze verilerini İZ'in sabit yanıt
biçimine dönüştürür. Katalog yanıtlarında yalnız kapak veya afişi bulunan eserler yer alır.

## Adresler

- `GET /health`
- `GET /v1/catalog/status` (D1 içindeki dil ve tür adetleri)
- `GET /v1/books/catalog?lang=tr&page=1&limit=100` (4.000 kapaklı kayıt)
- `GET /v1/books/featured?lang=en&offset=12`
- `GET /v1/books/search?q=suç%20ve%20ceza&lang=tr`
- `GET /v1/books/OL123W?lang=tr`
- `GET /v1/movies/search?q=matrix&lang=tr`
- `GET /v1/movies/featured?lang=tr`
- `GET /v1/movies/catalog?lang=tr` (13.000+ afişli kayıt)
- `GET /v1/movies/catalog?lang=tr&page=2&limit=50` (sayfalı büyük katalog)
- `GET /v1/movies/83495?lang=tr`
- `GET /v1/series/search?q=breaking%20bad&lang=tr`
- `GET /v1/series/featured?lang=tr`
- `GET /v1/series/catalog?lang=tr&page=1&limit=100` (10.000 afişli kayıt)
- `GET /v1/series/1079?lang=tr`
- `GET /v1/theatre/search?q=romeo%20ve%20juliet&lang=tr`
- `GET /v1/theatre/featured?lang=tr`
- `GET /v1/theatre/catalog?lang=tr&page=1&limit=100` (1.000 görselli kayıt)
- `GET /v1/theatre/83186?lang=tr`

Kimliklerde Wikidata'nın `Q` harfinden sonraki sayısal bölüm kullanılır. Yanıtta
veri kaynağı ve varsa görsel atıf adresi bulunur. Kişisel günlük verileri bu API'ye
gönderilmez.

## Yerelde çalıştırma

```sh
cd api
npm install
npm test
npm run dev
```

## Ücretsiz yayımlama

Cloudflare Workers ücretsiz planı başlangıç için uygundur. Hesap sahibi bir kez
`npx wrangler login` ile giriş yaptıktan sonra `npm run deploy` çalıştırır. Bu
işlem bir `workers.dev` adresi üretir. Uygulama şu ayarla derlenir:

```sh
flutter run --dart-define=IZ_MOVIE_API_URL=https://iz-catalog-api.<hesap>.workers.dev
```

Dağıtım kullanıcının Cloudflare hesabında yapılır; depo hiçbir hesap anahtarı veya
şifre içermez. Trafik büyürse ücretsiz plan limitleri yeniden değerlendirilmelidir.

## Veri ve lisans

Wikidata yapılandırılmış verileri CC0'dır. Commons görsellerinin lisansı dosyaya
göre değişebilir; istemci her görselin atıf sayfasına bağlantı göstermelidir.
İZ API veriyi sahiplenmez ve kaynak bağlantılarını yanıtta korur.

## Kalıcı katalog

Kataloglar Cloudflare D1 içinde tür ve dile göre ayrı saklanır: `books`,
`movies`, `series`, `theatre` × `tr`, `en`. İlk katalog isteği açık veri
kaynağını okuyup 200 görselli kaydı D1'e yazar; sonraki istekler doğrudan İZ
veritabanından döner.

Cloudflare Cron Trigger altı saatte bir çalışır ve küçük kataloglardan birini
yeniler. Büyük kataloglar, ücretsiz Worker'ın işlem sınırını aşmamak için
`node tool/import_books.mjs`, `node tool/import_movies.mjs`,
`node tool/import_series.mjs` ve `node tool/import_theatre.mjs` ile toplu ve
kontrollü olarak genişletilir; API kayıtları sayfalı döndürür.

### Güncel biletli tiyatrolar

Biletsa'nın resmi entegrasyon API'sinden şehir ve tarih alanları alınmadan oyun
adı, afiş, kısa açıklama ve kaynak bağlantısı eklenebilir. Anahtar yalnızca
sunucuda tutulur:

```sh
BILETSA_API_KEY=bs_... node tool/import_biletsa_theatre.mjs
```

Oluşan SQL dosyaları D1'e uygulandığında güncel oyunlar tiyatro kataloğunun
başında yer alır. Bubilet otomatik veri toplamaya izin vermediği için kaynak
olarak kullanılmaz.

Cloudflare'da `BILETSA_API_KEY` secret'ı tanımlandığında Cron Trigger, güncel
Biletsa tiyatrolarını altı saatte bir otomatik yeniler. Şehir ve tarih bilgileri
saklanmaz.
