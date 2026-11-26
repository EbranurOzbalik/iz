import policy from '../../assets/legal/privacy_tr.json' with { type: 'json' };

const escape = (value) => String(value)
  .replaceAll('&', '&amp;')
  .replaceAll('<', '&lt;')
  .replaceAll('>', '&gt;')
  .replaceAll('"', '&quot;')
  .replaceAll("'", '&#39;');

const sections = policy.sections.map((section) =>
  `<section><h2>${escape(section.title)}</h2><p>${escape(section.text)}</p></section>`
).join('');

export const privacyHtml = `<!doctype html>
<html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>İZ — Gizlilik politikası</title>
<style>body{margin:0;background:#faf8f5;color:#29232e;font:17px/1.7 system-ui,sans-serif}main{max-width:760px;margin:auto;padding:48px 24px}h1,h2{font-family:Georgia,serif;font-weight:400;line-height:1.25}h1{font-size:40px}h2{font-size:26px;margin-top:36px}a{color:#755397}footer{margin-top:40px;border-top:1px solid #d7ccd9;padding-top:24px}</style>
</head><body><main><h1>İZ · Gizlilik politikası</h1>
<p>Güncelleme: ${escape(policy.updated)}</p>${sections}
<section><h2>İletişim</h2><p>Ebranur Özbalık</p><p><a href="mailto:ozbalikebranur@gmail.com">ozbalikebranur@gmail.com</a></p></section>
<footer><a href="https://archive.org/about/terms.php">Open Library / Internet Archive</a> · <a href="https://foundation.wikimedia.org/wiki/Policy:Privacy_policy">Wikimedia</a> · <a href="https://www.tvmaze.com/site/privacy">TVmaze</a> · <a href="https://biletsa.com/gizlilik-sozlesmesi">Biletsa</a></footer>
</main></body></html>`;
