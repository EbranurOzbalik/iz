"""Render the same in-app privacy text as a static, publishable HTML page."""
import html
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
policy = json.loads((root / 'assets/legal/privacy_tr.json').read_text())
config_path = root / 'config/release.local.json'
config = json.loads(config_path.read_text()) if config_path.exists() else {}
escape = html.escape
developer = str(config.get('DEVELOPER_NAME', '')).strip()
email = str(config.get('SUPPORT_EMAIL', '')).strip()
draft = not developer or not email
sections = ''.join(
    f'<section><h2>{escape(s["title"])}</h2><p>{escape(s["text"])}</p></section>'
    for s in policy['sections']
)
warning = '<aside>TASLAK — Geliştirici ve destek e-postası tamamlanmadan yayımlamayın.</aside>' if draft else ''
output = root / 'store/google-play/site/privacy.html'
output.parent.mkdir(parents=True, exist_ok=True)
output.write_text(f'''<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>İZ — Gizlilik politikası</title>
<style>body{{margin:0;background:#faf8f5;color:#29232e;font:17px/1.7 system-ui,sans-serif}}main{{max-width:760px;margin:auto;padding:48px 24px}}h1,h2{{font-family:Georgia,serif;font-weight:400;line-height:1.25}}h1{{font-size:40px}}h2{{font-size:26px;margin-top:36px}}a{{color:#755397}}aside{{padding:16px;border:2px solid #755397}}footer{{margin-top:40px;border-top:1px solid #d7ccd9;padding-top:24px}}</style>
</head><body><main>{warning}<h1>İZ · Gizlilik politikası</h1>
<p>Güncelleme: {escape(policy['updated'])}</p>{sections}
<section><h2>İletişim</h2><p>{escape(developer) or 'Geliştirici bilgisi bekleniyor.'}</p>
<p>{('<a href="mailto:' + escape(email, quote=True) + '">' + escape(email) + '</a>') if email else 'Destek e-postası bekleniyor.'}</p></section>
<footer><a href="https://archive.org/about/terms.php">Internet Archive gizlilik bilgileri</a> · <a href="https://foundation.wikimedia.org/wiki/Policy:Privacy_policy">Wikimedia gizlilik bilgileri</a></footer>
</main></body></html>''')
print(f'{"Taslak" if draft else "Hazır"}: {output.relative_to(root)}')
