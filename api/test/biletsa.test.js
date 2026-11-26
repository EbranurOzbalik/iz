import assert from 'node:assert/strict';
import test from 'node:test';

import { biletsaTheatreCollection } from '../src/biletsa.js';

test('Biletsa theatre import keeps only display fields and paginates', async () => {
  const requests = [];
  const fetcher = async (url, options) => {
    requests.push({ url: String(url), options });
    const page = Number(url.searchParams.get('sayfa'));
    return {
      ok: true,
      json: async () => ({
        veri: page === 1
          ? [{
              id: 12,
              ad: ' Örnek Oyun ',
              kisaAciklama: 'Açıklama',
              gorsel: 'https://biletsa.com/afis.jpg',
              url: 'https://biletsa.com/etkinlik/ornek',
              sure: 90,
              seanslar: [{ tarih: '2026-12-01', mekan: { sehir: 'İstanbul' } }],
            }]
          : [],
        sonSayfa: 2,
      }),
    };
  };
  const items = await biletsaTheatreCollection('secret', fetcher);
  assert.equal(requests.length, 2);
  assert.match(requests[0].url, /kategori=tiyatro/);
  assert.equal(requests[0].options.headers.Authorization, 'Bearer secret');
  assert.deepEqual(items, [{
    id: 980000012,
    source_id: 'biletsa:12',
    title: 'Örnek Oyun',
    original_title: 'Örnek Oyun',
    overview: 'Açıklama',
    poster_url: 'https://biletsa.com/afis.jpg',
    poster_attribution_url: 'https://biletsa.com/etkinlik/ornek',
    year: null,
    runtime: 90,
    directors: [],
    genres: ['Tiyatro'],
    source_url: 'https://biletsa.com/etkinlik/ornek',
  }]);
  assert.equal('seanslar' in items[0], false);
});
