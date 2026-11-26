import { writeFile } from 'node:fs/promises';

import { mapCatalogItem } from '../src/catalog.js';

const TARGET = Number.parseInt(process.argv[2] ?? '14000', 10);
const SPARQL = 'https://query.wikidata.org/sparql';
const API = 'https://www.wikidata.org/w/api.php';
const headers = {
  Accept: 'application/json',
  'User-Agent': 'IZ-Catalog/1.0 (https://github.com/EbranurOzbalik/iz)',
};

const fetchWithRetry = async (url, options, attempts = 5) => {
  let response;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    response = await fetch(url, options);
    if (response.ok) return response;
    if (attempt < attempts) {
      await new Promise((resolve) => setTimeout(resolve, attempt * 2000));
    }
  }
  return response;
};

const query = `SELECT DISTINCT ?item WHERE {
  VALUES ?type { wd:Q11424 wd:Q202866 wd:Q29168811 wd:Q24869 wd:Q506240 }
  ?item wdt:P31 ?type; wdt:P18 ?image.
} LIMIT ${TARGET}`;

const sparqlResponse = await fetchWithRetry(
  `${SPARQL}?${new URLSearchParams({ query, format: 'json' })}`,
  { headers: { ...headers, Accept: 'application/sparql-results+json' } },
);
if (!sparqlResponse.ok) throw new Error(`Wikidata SPARQL ${sparqlResponse.status}`);
const sparql = await sparqlResponse.json();
const ids = sparql.results.bindings
  .map((row) => /Q\d+$/.exec(row.item?.value ?? '')?.[0])
  .filter(Boolean);

const chunks = [];
for (let index = 0; index < ids.length; index += 50) {
  chunks.push(ids.slice(index, index + 50));
}

const entities = [];
let cursor = 0;
const worker = async () => {
  while (cursor < chunks.length) {
    const chunk = chunks[cursor++];
    const url = new URL(API);
    for (const [key, value] of Object.entries({
      action: 'wbgetentities',
      ids: chunk.join('|'),
      props: 'labels|descriptions|claims',
      languages: 'tr|en',
      languagefallback: '1',
      format: 'json',
      origin: '*',
    })) url.searchParams.set(key, value);
    const response = await fetchWithRetry(url, { headers });
    if (!response.ok) throw new Error(`Wikidata API ${response.status}`);
    const data = await response.json();
    entities.push(...Object.values(data.entities ?? {}));
  }
};
await Promise.all(Array.from({ length: 6 }, worker));

const escape = (value) => String(value).replaceAll("'", "''");
for (const language of ['tr', 'en']) {
  const items = entities
    .map((entity) => mapCatalogItem(entity, {}, language, 'movies'))
    .filter((item) => item?.poster_url);
  const lines = [
    `DELETE FROM catalog_items WHERE kind='movies' AND language='${language}';`,
  ];
  items.forEach((item, position) => {
    const payload = escape(JSON.stringify(item));
    lines.push(
      `INSERT INTO catalog_items(kind,language,source_id,position,payload,updated_at) VALUES('movies','${language}','${escape(item.source_id)}',${position},'${payload}',CURRENT_TIMESTAMP);`,
    );
  });
  const path = `/tmp/iz-movies-${language}-${items.length}.sql`;
  await writeFile(path, `${lines.join('\n')}\n`);
  console.log(`${language}: ${items.length} kayıt -> ${path}`);
}
