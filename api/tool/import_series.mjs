import { writeFile } from 'node:fs/promises';

const TARGET = Number.parseInt(process.argv[2] ?? '10000', 10);
const TVMAZE = 'https://api.tvmaze.com/shows';
const headers = {
  Accept: 'application/json',
  'User-Agent': 'IZ-Catalog/1.0 (https://github.com/EbranurOzbalik/iz)',
};

const items = [];
const seen = new Set();
for (let page = 0; items.length < TARGET; page += 1) {
  const response = await fetch(`${TVMAZE}?page=${page}`, { headers });
  if (response.status === 404) break;
  if (!response.ok) throw new Error(`TVmaze ${response.status}`);
  const shows = await response.json();
  if (!Array.isArray(shows) || !shows.length) break;
  for (const show of shows) {
    const poster = show?.image?.original ?? show?.image?.medium;
    if (!Number.isInteger(show?.id) ||
        typeof show?.name !== 'string' ||
        typeof poster !== 'string' ||
        !poster.startsWith('https://') ||
        seen.has(show.id)) continue;
    seen.add(show.id);
    items.push({
      id: 900000000 + show.id,
      source_id: `tvmaze:${show.id}`,
      title: show.name,
      original_title: show.name,
      overview: typeof show.summary === 'string'
        ? show.summary.replace(/<[^>]*>/g, '').trim()
        : '',
      poster_url: poster,
      poster_attribution_url: show.url ?? 'https://www.tvmaze.com',
      year: Number.parseInt(show.premiered?.slice(0, 4), 10) || null,
      runtime: Number.isInteger(show.runtime) ? show.runtime : null,
      directors: [],
      genres: Array.isArray(show.genres) ? show.genres : [],
      source_url: show.url ?? 'https://www.tvmaze.com',
    });
    if (items.length === TARGET) break;
  }
}

const escape = (value) => String(value).replaceAll("'", "''");
for (const language of ['tr', 'en']) {
  const lines = [
    `DELETE FROM catalog_items WHERE kind='series' AND language='${language}';`,
  ];
  items.forEach((item, position) => {
    const payload = escape(JSON.stringify(item));
    lines.push(
      `INSERT INTO catalog_items(kind,language,source_id,position,payload,updated_at) VALUES('series','${language}','${escape(item.source_id)}',${position},'${payload}',CURRENT_TIMESTAMP);`,
    );
  });
  const path = `/tmp/iz-series-${language}-${items.length}.sql`;
  await writeFile(path, `${lines.join('\n')}\n`);
  console.log(`${language}: ${items.length} kayıt -> ${path}`);
}
