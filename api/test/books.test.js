import assert from 'node:assert/strict';
import test from 'node:test';

import {
  bookCollection,
  bookDetails,
  mapBook,
  searchBooks,
} from '../src/books.js';

test('maps only books with a work id and cover', () => {
  const book = mapBook({
    key: '/works/OL1W',
    title: 'Örnek Kitap',
    author_name: ['Yazar', 'Yazar'],
    cover_i: 42,
    first_publish_year: 2020,
    edition_count: 3,
  });
  assert.equal(book.id, 'OL1W');
  assert.equal(book.cover_url, 'https://covers.openlibrary.org/b/id/42-L.jpg');
  assert.deepEqual(book.authors, ['Yazar']);
  assert.equal(mapBook({ key: '/works/OL2W', title: 'Kapaksız' }), null);
});

test('book catalog pages until it collects 200 unique covered books', async () => {
  const offsets = [];
  const fetcher = async (url) => {
    const offset = Number(url.searchParams.get('offset'));
    offsets.push(offset);
    return new Response(JSON.stringify({
      docs: Array.from({ length: 100 }, (_, index) => ({
        key: `/works/OL${offset + index}W`,
        title: `Kitap ${offset + index}`,
        cover_i: offset + index + 1,
      })),
    }));
  };
  const books = await bookCollection('tr', fetcher);
  assert.equal(books.length, 200);
  assert.deepEqual(offsets, [0, 100]);
  assert.ok(books.every((book) => book.cover_url.startsWith('https://')));
});

test('book search and details keep the requested language', async () => {
  const requests = [];
  const fetcher = async (url) => {
    requests.push(url);
    return new Response(JSON.stringify({
      docs: [{ key: '/works/OL7W', title: 'İz', cover_i: 7 }],
    }));
  };
  assert.equal((await searchBooks('iz', 'tr', fetcher))[0].id, 'OL7W');
  assert.equal(requests[0].searchParams.get('language'), 'tur');
  assert.equal(requests[0].searchParams.get('lang'), 'tr');
  assert.equal((await bookDetails('OL7W', 'en', fetcher)).title, 'İz');
  assert.equal(requests[1].searchParams.get('lang'), 'en');
});
