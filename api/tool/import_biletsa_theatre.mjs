import { writeFile } from 'node:fs/promises';

const apiKey = process.env.BILETSA_API_KEY?.trim();
if (!apiKey) {
  throw new Error('BILETSA_API_KEY ortam değişkeni gerekli');
}

const API = 'https://biletsa.com/api/v1/etkinlikler';
const headers = {
  Accept: 'application/json',
  Authorization: `Bearer ${apiKey}`,
};
const items = [];
const seen = new Set();

for (let page = 1; ; page += 1) {
  const url = new URL(API);
  url.searchParams.set('kategori', 'tiyatro');
  url.searchParams.set('sayfa', String(page));
  const response = await fetch(url, { headers });
  if (!response.ok) throw new Error(`Biletsa API ${response.status}`);
  const body = await response.json();
  const rows = Array.isArray(body?.veri) ? body.veri : [];
  for (const row of rows) {
    const sourceId = Number(row?.id);
    const title = typeof row?.ad === 'string' ? row.ad.trim() : '';
    const poster = typeof row?.gorsel === 'string' && row.gorsel.startsWith('https://')
      ? row.gorsel
      : typeof row?.kapak === 'string' && row.kapak.startsWith('https://')
        ? row.kapak
        : null;
    const sourceUrl = typeof row?.url === 'string' && row.url.startsWith('https://')
      ? row.url
      : null;
    if (!Number.isInteger(sourceId) || !title || !poster || !sourceUrl || seen.has(sourceId)) continue;
    seen.add(sourceId);
    items.push({
      id: 980000000 + sourceId,
      source_id: `biletsa:${sourceId}`,
      title,
      original_title: title,
      overview: typeof row?.kisaAciklama === 'string' ? row.kisaAciklama.trim() : '',
      poster_url: poster,
      poster_attribution_url: sourceUrl,
      year: null,
      runtime: Number.isInteger(row?.sure) ? row.sure : null,
      directors: [],
      genres: ['Tiyatro'],
      source_url: sourceUrl,
    });
  }
  const lastPage = Number(body?.sonSayfa ?? body?.son_sayfa ?? page);
  if (!rows.length || page >= lastPage) break;
}

const escape = (value) => String(value).replaceAll("'", "''");
for (const language of ['tr', 'en']) {
  const lines = [];
  items.forEach((item, index) => {
    const position = -10000 + index;
    lines.push(
      `INSERT INTO catalog_items(kind,language,source_id,position,payload,updated_at) VALUES('theatre','${language}','${escape(item.source_id)}',${position},'${escape(JSON.stringify(item))}',CURRENT_TIMESTAMP) ON CONFLICT(kind,language,source_id) DO UPDATE SET position=excluded.position,payload=excluded.payload,updated_at=CURRENT_TIMESTAMP;`,
    );
  });
  const path = `/tmp/iz-biletsa-theatre-${language}-${items.length}.sql`;
  await writeFile(path, `${lines.join('\n')}\n`);
  console.log(`${language}: ${items.length} güncel tiyatro -> ${path}`);
}
