const OPEN_LIBRARY_SEARCH = 'https://openlibrary.org/search.json';
const CATALOG_SIZE = 200;
const PAGE_SIZE = 100;

const text = (value) =>
  typeof value === 'string' && value.trim() ? value.trim() : null;

export const mapBook = (row) => {
  const title = text(row?.title);
  const coverId = Number.isInteger(row?.cover_i) && row.cover_i > 0
    ? row.cover_i
    : null;
  if (!title || !coverId) return null;
  const rawKey = text(row.key);
  const workId = rawKey?.match(/(?:\/works\/)?(OL\d+W)$/)?.[1] ?? null;
  if (!workId) return null;
  return {
    id: workId,
    source_id: workId,
    title,
    authors: Array.isArray(row.author_name)
      ? [...new Set(row.author_name.map(text).filter(Boolean))]
      : [],
    year: Number.isInteger(row.first_publish_year)
      ? row.first_publish_year
      : null,
    edition_count: Number.isInteger(row.edition_count) ? row.edition_count : null,
    cover_url: `https://covers.openlibrary.org/b/id/${coverId}-L.jpg`,
    cover_attribution_url: `https://openlibrary.org/works/${workId}`,
    source_url: `https://openlibrary.org/works/${workId}`,
  };
};

export const bookCollection = async (language, fetcher = fetch) => {
  const books = [];
  const seen = new Set();
  for (let offset = 0; books.length < CATALOG_SIZE && offset < 500; offset += PAGE_SIZE) {
    const url = new URL(OPEN_LIBRARY_SEARCH);
    url.searchParams.set('q', `language:${language === 'en' ? 'eng' : 'tur'} AND cover_i:[1 TO *]`);
    url.searchParams.set('lang', language);
    url.searchParams.set('sort', 'readinglog');
    url.searchParams.set('limit', String(PAGE_SIZE));
    url.searchParams.set('offset', String(offset));
    url.searchParams.set(
      'fields',
      'key,title,author_name,first_publish_year,edition_count,cover_i',
    );
    const response = await fetcher(url, {
      headers: {
        Accept: 'application/json',
        'User-Agent': 'IZ-Catalog/1.0 (https://github.com/EbranurOzbalik/iz)',
      },
    });
    if (!response.ok) throw new Error(`Open Library ${response.status}`);
    const data = await response.json();
    const rows = Array.isArray(data?.docs) ? data.docs : [];
    for (const row of rows) {
      const book = mapBook(row);
      if (book && !seen.has(book.id)) {
        seen.add(book.id);
        books.push(book);
      }
      if (books.length === CATALOG_SIZE) break;
    }
    if (rows.length < PAGE_SIZE) break;
  }
  return books;
};

const openLibrarySearch = async (parameters, fetcher) => {
  const url = new URL(OPEN_LIBRARY_SEARCH);
  for (const [key, value] of Object.entries(parameters)) {
    url.searchParams.set(key, value);
  }
  url.searchParams.set(
    'fields',
    'key,title,author_name,first_publish_year,edition_count,cover_i',
  );
  const response = await fetcher(url, {
    headers: {
      Accept: 'application/json',
      'User-Agent': 'IZ-Catalog/1.0 (https://github.com/EbranurOzbalik/iz)',
    },
  });
  if (!response.ok) throw new Error(`Open Library ${response.status}`);
  const data = await response.json();
  return (Array.isArray(data?.docs) ? data.docs : []).map(mapBook).filter(Boolean);
};

export const searchBooks = async (query, language, fetcher = fetch) =>
  (await openLibrarySearch({
    title: query,
    language: language === 'en' ? 'eng' : 'tur',
    lang: language,
    limit: '20',
  }, fetcher)).slice(0, 12);

export const bookDetails = async (workId, language, fetcher = fetch) => {
  const results = await openLibrarySearch({
    q: `key:${workId}`,
    lang: language,
    limit: '5',
  }, fetcher);
  return results.find((book) => book.id === workId) ?? null;
};
