const API = 'https://biletsa.com/api/v1/etkinlikler';

export const biletsaTheatreCollection = async (apiKey, fetcher = fetch) => {
  if (typeof apiKey !== 'string' || !apiKey.trim()) return [];
  const items = [];
  const seen = new Set();
  for (let page = 1; ; page += 1) {
    const url = new URL(API);
    url.searchParams.set('kategori', 'tiyatro');
    url.searchParams.set('sayfa', String(page));
    const response = await fetcher(url, {
      headers: {
        Accept: 'application/json',
        Authorization: `Bearer ${apiKey.trim()}`,
      },
    });
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
  return items;
};
