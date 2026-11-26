import assert from 'node:assert/strict';
import test from 'node:test';
import {
  isCatalogItem,
  isFilm,
  mapCatalogItem,
  mapMovie,
  relatedIds,
} from '../src/catalog.js';

const entity = {
  id: 'Q42',
  labels: { tr: { value: 'Örnek Film' }, en: { value: 'Example Film' } },
  descriptions: { tr: { value: 'Örnek açıklama' } },
  claims: {
    P31: [{ mainsnak: { datavalue: { value: { 'numeric-id': 11424 } } } }],
    P57: [{ mainsnak: { datavalue: { value: { 'numeric-id': 7 } } } }],
    P136: [{ mainsnak: { datavalue: { value: { 'numeric-id': 8 } } } }],
    P18: [{ mainsnak: { datavalue: { value: 'Poster Example.jpg' } } }],
    P577: [{ mainsnak: { datavalue: { value: { time: '+2024-01-01T00:00:00Z' } } } }],
    P2047: [{ mainsnak: { datavalue: { value: { amount: '+123', unit: 'http://www.wikidata.org/entity/Q7727' } } } }],
  },
};

test('maps a Wikidata film to the public İZ response', () => {
  assert.equal(isFilm(entity), true);
  assert.deepEqual(relatedIds([entity]), ['Q7', 'Q8']);
  const movie = mapMovie(entity, { Q7: 'Yönetmen', Q8: 'Drama' }, 'tr');
  assert.equal(movie.id, 42);
  assert.equal(movie.title, 'Örnek Film');
  assert.equal(movie.year, 2024);
  assert.equal(movie.runtime, 123);
  assert.deepEqual(movie.directors, ['Yönetmen']);
  assert.deepEqual(movie.genres, ['Drama']);
  assert.match(movie.poster_url, /^https:\/\/commons\.wikimedia\.org\//);
});

test('rejects a non-film entity', () => {
  const person = structuredClone(entity);
  person.claims.P31[0].mainsnak.datavalue.value['numeric-id'] = 5;
  assert.equal(isFilm(person), false);
});

test('recognizes series and theatre works with their creator fields', () => {
  const series = structuredClone(entity);
  series.claims.P31[0].mainsnak.datavalue.value['numeric-id'] = 5398426;
  series.claims.P58 = [
    { mainsnak: { datavalue: { value: { 'numeric-id': 9 } } } },
  ];
  assert.equal(isCatalogItem(series, 'series'), true);
  assert.deepEqual(relatedIds([series], 'series'), ['Q7', 'Q9', 'Q8']);
  assert.deepEqual(
    mapCatalogItem(series, { Q7: 'Yönetmen', Q9: 'Senarist' }, 'tr', 'series').directors,
    ['Yönetmen', 'Senarist'],
  );

  const theatre = structuredClone(entity);
  theatre.claims.P31[0].mainsnak.datavalue.value['numeric-id'] = 116476516;
  theatre.claims.P50 = [
    { mainsnak: { datavalue: { value: { 'numeric-id': 10 } } } },
  ];
  assert.equal(isCatalogItem(theatre, 'theatre'), true);
  assert.deepEqual(
    mapCatalogItem(theatre, { Q10: 'Oyun Yazarı' }, 'tr', 'theatre').directors,
    ['Oyun Yazarı'],
  );
});
