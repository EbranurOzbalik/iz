# Veri güvenliği inceleme notları

Bu dosya Play Console formuna otomatik verilmiş bir beyan değildir. Yayınlanacak paket ve servislerin veri saklama uygulamaları hesap sahibi tarafından doğrulanmalıdır.

| Akış | Cihaz dışına çıkan veri | Amaç / durum |
| --- | --- | --- |
| Günlük, puan, not, sayfa/bölüm, takvim | Uygulama tarafından gönderilmez | Yerel kayıt; uygulama içinden silinebilir |
| Kitap araması | Arama metni, dil, istenen kitap/yazar kimliği; bağlantı sırasında IP gibi ağ bilgileri | Open Library arama ve detay servisi |
| Popüler / öneri rafları, kapaklar | Tür ve görsel/kitap kimlikleri; standart ağ bilgileri | Open Library / kapak sunucusu |
| Film, dizi ve tiyatro araması | Arama metni, eser türü, dil, eser kimliği ve standart ağ bilgileri | Cloudflare üzerindeki İZ Katalog API; Wikidata, Wikimedia Commons, TVmaze ve Biletsa katalog/görselleri |
| Yerel hatırlatıcı | Cihaz dışına çıkmaz | Bildirim cihazda planlanır; sunucuya gönderilmez |
| Destek e-postası | Kullanıcının e-posta uygulamasından kendisinin gönderdiği ileti | İZ otomatik not/cihaz kaydı eklemez; destek yanıtı için |

Reklam SDK'sı, analiz SDK'sı, reklam kimliği veya hesap sistemi yok. Kamera, mikrofon, kişi listesi ve konum izni istenmez. Ağ istekleri HTTPS kullanır. Android uygulama yedekleme ve aktarım kuralları günlük dosyalarını dışlar.

## Play Console için önerilen form cevapları

- Uygulama kullanıcı verisi topluyor veya paylaşıyor mu?: **Evet** — çevrimiçi arama kullanıldığında “Uygulama etkinliği → Uygulama içi arama geçmişi” cihaz dışına gönderilir.
- Veri türü: **Uygulama içi arama geçmişi**.
- Toplanıyor mu?: **Evet**.
- Paylaşılıyor mu?: **Hayır** — istekler uygulama işlevi için hizmet sağlayıcıya veya kullanıcının başlattığı katalog isteğine gider; reklam/analiz amacıyla üçüncü taraflara aktarılmaz.
- Geçici olarak mı işleniyor?: **Evet**. İZ, aramaları kullanıcı hesabına bağlamaz ve arama geçmişi tablosunda saklamaz.
- Zorunlu mu?: **İsteğe bağlı**. Kullanıcı internet araması yapmadan günlüğü ve elle eklemeyi kullanabilir.
- Amaç: **Uygulama işlevselliği**.
- Aktarım sırasında şifreleme: **Evet**, HTTPS.
- Hesap oluşturma: **Yok**; hesap silme URL'si gerekmez.
- Silme: Yerel günlük tek tek veya “Tüm kayıtlarımı sil” ile uygulama içinden kaldırılabilir. Sunucuda kullanıcıya bağlı günlük ya da arama geçmişi tutulmaz.
- Bağımsız güvenlik incelemesi: **Yok**.
- Families Policy taahhüdü: Çocuklara özel hedefleme seçilmedikçe **işaretlenmez**.

**Son kontrol:** Play Console seçeneklerinin metni zamanla değişebilir. Gönderim ekranında son AAB'nin davranışıyla karşılaştırılmalı; ileride reklam veya analiz SDK'sı eklenirse bu dosya, gizlilik politikası ve Console beyanı yayımdan önce birlikte güncellenmelidir.

Kaynaklar:
- [Google Play Veri güvenliği formu](https://support.google.com/googleplay/android-developer/answer/10787469?hl=en)
- [Google Play inceleme ve gizlilik politikası gereksinimleri](https://support.google.com/googleplay/android-developer/answer/9859455?hl=en)
- [Internet Archive gizlilik bilgileri](https://archive.org/about/terms.php)
- [Wikimedia gizlilik bilgileri](https://foundation.wikimedia.org/wiki/Policy:Privacy_policy)
