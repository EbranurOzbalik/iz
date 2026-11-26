import { writeFile } from 'node:fs/promises';

import { mapBook } from '../src/books.js';

const TARGET = Number.parseInt(process.argv[2] ?? '2000', 10);
const APPEND = process.argv.includes('--append');
const PAGE_SIZE = 100;
const API = 'https://openlibrary.org/search.json';
const SUBJECT_API = 'https://openlibrary.org/subjects';
const ENGLISH_SUBJECTS = [
  'fiction', 'classics', 'fantasy', 'science_fiction', 'mystery', 'romance',
  'history', 'biography', 'philosophy', 'psychology', 'science', 'art',
  'poetry', 'drama', 'young_adult',
];
const headers = {
  Accept: 'application/json',
  'User-Agent': 'IZ-Catalog/1.0 (https://github.com/EbranurOzbalik/iz)',
};

const escape = (value) => String(value).replaceAll("'", "''");
const fetchWithRetry = async (url, attempts = 6) => {
  let response;
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    response = await fetch(url, { headers });
    if (response.ok) return response;
    if (attempt < attempts) {
      await new Promise((resolve) => setTimeout(resolve, attempt * 1500));
    }
  }
  return response;
};

for (const [language, sourceLanguage] of [['tr', 'tur'], ['en', 'eng']]) {
  const items = [];
  const seen = new Set();
  if (language === 'en') {
    for (const subject of ENGLISH_SUBJECTS) {
      const url = new URL(`${SUBJECT_API}/${subject}.json`);
      url.searchParams.set('limit', '400');
      url.searchParams.set('details', 'false');
      const response = await fetchWithRetry(url);
      if (!response.ok) throw new Error(`Open Library subject ${response.status}`);
      const data = await response.json();
      for (const work of data?.works ?? []) {
        const item = mapBook({
          key: work.key,
          title: work.title,
          author_name: (work.authors ?? []).map((author) => author.name),
          first_publish_year: work.first_publish_year,
          edition_count: work.edition_count,
          cover_i: work.cover_id,
        });
        if (!item || seen.has(item.source_id)) continue;
        seen.add(item.source_id);
        items.push(item);
        if (items.length === TARGET) break;
      }
      if (items.length === TARGET) break;
      await new Promise((resolve) => setTimeout(resolve, 250));
    }
  }
  for (let offset = 0; language !== 'en' && items.length < TARGET; offset += PAGE_SIZE) {
    const url = new URL(API);
    url.searchParams.set('q', `language:${sourceLanguage} AND cover_i:[1 TO *]`);
    url.searchParams.set('lang', language);
    url.searchParams.set('sort', 'readinglog');
    url.searchParams.set('limit', String(PAGE_SIZE));
    url.searchParams.set('offset', String(offset));
    url.searchParams.set('fields', 'key,title,author_name,first_publish_year,edition_count,cover_i');
    const response = await fetchWithRetry(url);
    if (!response.ok) throw new Error(`Open Library ${response.status}`);
    const data = await response.json();
    const rows = Array.isArray(data?.docs) ? data.docs : [];
    for (const row of rows) {
      const item = mapBook(row);
      if (!item || seen.has(item.source_id)) continue;
      seen.add(item.source_id);
      items.push(item);
      if (items.length === TARGET) break;
    }
    if (rows.length < PAGE_SIZE) break;
    await new Promise((resolve) => setTimeout(resolve, 250));
  }

  const lines = APPEND
    ? []
    : [`DELETE FROM catalog_items WHERE kind='books' AND language='${language}';`];
  items.forEach((item, position) => {
    const insert = APPEND ? 'INSERT OR IGNORE' : 'INSERT';
    lines.push(`${insert} INTO catalog_items(kind,language,source_id,position,payload,updated_at) VALUES('books','${language}','${escape(item.source_id)}',${position},'${escape(JSON.stringify(item))}',CURRENT_TIMESTAMP);`);
  });
  const path = `/tmp/iz-books-${language}-${items.length}.sql`;
  await writeFile(path, `${lines.join('\n')}\n`);
  console.log(`${language}: ${items.length} kayıt -> ${path}`);
}
