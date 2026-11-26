const WIKIDATA_API = 'https://www.wikidata.org/w/api.php';
const WIKIDATA_SPARQL = 'https://query.wikidata.org/sparql';
const TVMAZE_API = 'https://api.tvmaze.com';
const CATALOG_SIZE = 200;
const WIKIDATA_CANDIDATE_SIZE = 250;
const FEATURED_SIZE = 12;

// Common film entity types. The generic film item covers most records; the
// additional types keep television and animated films discoverable.
const TYPE_CONFIG = {
  movies: {
    types: new Set(['Q11424', 'Q202866', 'Q29168811', 'Q24869', 'Q506240']),
    creators: ['P57'],
    featured: ['Q83495', 'Q25188', 'Q104123', 'Q464032', 'Q132689'],
  },
  series: {
    types: new Set(['Q5398426', 'Q1259759', 'Q526877', 'Q581714']),
    creators: ['P57', 'P58'],
    featured: [
      'Q1079',
      'Q28443710',
      'Q87131973',
      'Q23572',
      'Q19798734',
      'Q192837',
      'Q20707362',
      'Q558112',
      'Q48741246',
      'Q14944179',
      'Q112761982',
      'Q30599007',
      'Q23831',
      'Q79784',
    ],
    tvmaze: {
      Q1079: 169,
      Q28443710: 17861,
      Q87131973: 46562,
      Q23572: 82,
      Q19798734: 2993,
      Q192837: 335,
      Q20707362: 3594,
      Q558112: 305,
      Q48741246: 30770,
      Q14944179: 269,
      Q112761982: 54198,
      Q30599007: 23470,
      Q23831: 526,
      Q79784: 431,
    },
  },
  theatre: {
    types: new Set(['Q25379', 'Q116476516', 'Q43099500', 'Q1344']),
    creators: ['P50', 'P57', 'P86'],
    featured: [
      'Q41567',
      'Q83186',
      'Q130283',
      'Q26833',
      'Q669694',
      'Q478381',
      'Q830501',
      'Q241077',
      'Q86440',
      'Q181598',
      'Q650063',
      'Q477823',
    ],
  },
};

const claimValue = (entity, property) =>
  entity?.claims?.[property]?.[0]?.mainsnak?.datavalue?.value;

const entityId = (value) =>
  value && typeof value === 'object' && Number.isInteger(value['numeric-id'])
    ? `Q${value['numeric-id']}`
    : null;

const entityIds = (entity, property) =>
  (entity?.claims?.[property] ?? [])
    .map((claim) => entityId(claim?.mainsnak?.datavalue?.value))
    .filter(Boolean);

const localized = (values, language) =>
  values?.[language]?.value ?? values?.tr?.value ?? values?.en?.value ?? '';

const yearFromTime = (value) => {
  const match = typeof value?.time === 'string'
    ? /^[-+](\d{4,})-/.exec(value.time)
    : null;
  return match ? Number(match[1]) : null;
};

const minutesFromQuantity = (value) => {
  const amount = Number(value?.amount);
  if (!Number.isFinite(amount) || amount <= 0) return null;
  // Wikidata normally stores P2047 in minutes. Convert seconds when the unit
  // explicitly identifies them.
  return value.unit?.endsWith('/Q11574') ? Math.round(amount / 60) : Math.round(amount);
};

export const isCatalogItem = (entity, kind = 'movies') =>
  entityIds(entity, 'P31').some((id) => TYPE_CONFIG[kind]?.types.has(id));

export const isFilm = (entity) => isCatalogItem(entity, 'movies');

export const relatedIds = (entities, kind = 'movies') => [
  ...new Set(entities.flatMap((entity) => [
    ...(TYPE_CONFIG[kind]?.creators ?? []).flatMap((property) => entityIds(entity, property)),
    ...entityIds(entity, 'P136'),
  ])),
];

export const mapCatalogItem = (entity, labels = {}, language = 'tr', kind = 'movies') => {
  const numericId = Number(entity.id?.slice(1));
  const title = localized(entity.labels, language);
  if (!Number.isInteger(numericId) || numericId <= 0 || !title) return null;
  const image = claimValue(entity, 'P18');
  const originalTitleValue = claimValue(entity, 'P1476');
  const originalTitle = typeof originalTitleValue?.text === 'string'
    ? originalTitleValue.text
    : '';
  const names = (property) => entityIds(entity, property)
    .map((id) => labels[id])
    .filter(Boolean);
  const posterUrl = typeof image === 'string' && image.trim()
    ? `https://commons.wikimedia.org/wiki/Special:Redirect/file/${encodeURIComponent(image.trim())}?width=500`
    : null;
  return {
    id: numericId,
    source_id: entity.id,
    title,
    original_title: originalTitle,
    overview: localized(entity.descriptions, language),
    poster_url: posterUrl,
    poster_attribution_url: posterUrl
      ? `https://commons.wikimedia.org/wiki/File:${encodeURIComponent(image.replaceAll(' ', '_'))}`
      : null,
    year: yearFromTime(claimValue(entity, 'P577')),
    runtime: minutesFromQuantity(claimValue(entity, 'P2047')),
    directors: [...new Set((TYPE_CONFIG[kind]?.creators ?? []).flatMap(names))],
    genres: names('P136'),
    source_url: `https://www.wikidata.org/wiki/${entity.id}`,
  };
};

export const mapMovie = (entity, labels = {}, language = 'tr') =>
  mapCatalogItem(entity, labels, language, 'movies');

const wikidata = async (parameters, fetcher = fetch) => {
  const url = new URL(WIKIDATA_API);
  for (const [key, value] of Object.entries({
    format: 'json',
    origin: '*',
    ...parameters,
  })) url.searchParams.set(key, value);
  const response = await fetcher(url, {
    headers: {
      Accept: 'application/json',
      'User-Agent': 'IZ-Catalog/1.0 (https://github.com/EbranurOzbalik/iz)',
    },
  });
  if (!response.ok) throw new Error(`Wikidata ${response.status}`);
  return response.json();
};

const loadEntities = async (ids, language, fetcher) => {
  if (!ids.length) return {};
  const chunks = [];
  for (let index = 0; index < ids.length; index += 50) {
    chunks.push(ids.slice(index, index + 50));
  }
  const responses = await Promise.all(chunks.map((chunk) => wikidata({
      action: 'wbgetentities',
      ids: chunk.join('|'),
      props: 'labels|descriptions|claims',
      languages: `${language}|tr|en`,
      languagefallback: '1',
    }, fetcher)));
  return Object.assign({}, ...responses.map((data) => data.entities ?? {}));
};

const loadLabels = async (ids, language, fetcher) => {
  const entities = await loadEntities(ids, language, fetcher);
  return Object.fromEntries(Object.entries(entities).map(([id, entity]) => [
    id,
    localized(entity.labels, language),
  ]));
};

export const searchCatalog = async (kind, query, language, fetcher = fetch) => {
  if (!TYPE_CONFIG[kind]) throw new Error('Unknown catalog kind');
  const search = await wikidata({
    action: 'wbsearchentities',
    search: query,
    language,
    uselang: language,
    type: 'item',
    limit: '20',
  }, fetcher);
  const ids = (search.search ?? []).map((row) => row.id).filter((id) => /^Q\d+$/.test(id));
  const entities = Object.values(await loadEntities(ids, language, fetcher))
    .filter((entity) => isCatalogItem(entity, kind));
  const labels = await loadLabels(relatedIds(entities, kind), language, fetcher);
  return entities
    .map((entity) => mapCatalogItem(entity, labels, language, kind))
    .filter(Boolean)
    .slice(0, 12);
};

export const catalogDetails = async (kind, numericId, language, fetcher = fetch) => {
  if (!TYPE_CONFIG[kind]) throw new Error('Unknown catalog kind');
  const id = `Q${numericId}`;
  const entities = await loadEntities([id], language, fetcher);
  const entity = entities[id];
  if (!entity || entity.missing !== undefined || !isCatalogItem(entity, kind)) return null;
  const labels = await loadLabels(relatedIds([entity], kind), language, fetcher);
  return mapCatalogItem(entity, labels, language, kind);
};

export const catalogCollection = async (kind, language, fetcher = fetch) => {
  if (!TYPE_CONFIG[kind]) throw new Error('Unknown catalog kind');
  if (kind === 'series') {
    const shows = [];
    for (let page = 0; shows.length < CATALOG_SIZE && page < 6; page += 1) {
      const response = await fetcher(`${TVMAZE_API}/shows?page=${page}`, {
        headers: {
          Accept: 'application/json',
          'User-Agent': 'IZ-Catalog/1.0 (https://github.com/EbranurOzbalik/iz)',
        },
      });
      if (!response.ok) break;
      const rows = await response.json();
      if (!Array.isArray(rows)) break;
      for (const show of rows) {
        const poster = show?.image?.original ?? show?.image?.medium;
        if (!Number.isInteger(show?.id) || typeof show?.name !== 'string' ||
            typeof poster !== 'string' || !poster.startsWith('https://')) continue;
        shows.push({
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
        if (shows.length === CATALOG_SIZE) break;
      }
      if (!rows.length) break;
    }
    return shows;
  }
  let featuredIds = TYPE_CONFIG[kind].featured;
  if (kind === 'movies' || kind === 'theatre') {
    const types = kind === 'movies'
      ? 'wd:Q11424 wd:Q202866 wd:Q29168811 wd:Q24869 wd:Q506240'
      : 'wd:Q25379 wd:Q116476516 wd:Q43099500 wd:Q1344';
    const query = `SELECT DISTINCT ?item WHERE {
      VALUES ?type { ${types} }
      ?item wdt:P31 ?type; wdt:P18 ?image.
    } LIMIT ${WIKIDATA_CANDIDATE_SIZE}`;
    const response = await fetcher(
      `${WIKIDATA_SPARQL}?query=${encodeURIComponent(query)}&format=json`,
      {
        headers: {
          Accept: 'application/sparql-results+json',
          'User-Agent': 'IZ-Catalog/1.0 (https://github.com/EbranurOzbalik/iz)',
        },
      },
    );
    if (response.ok) {
      const data = await response.json();
      const ids = (data?.results?.bindings ?? [])
        .map((row) => /Q\d+$/.exec(row?.item?.value ?? '')?.[0])
        .filter(Boolean);
      if (ids.length) featuredIds = ids;
    }
  }
  const entities = Object.values(
    await loadEntities(featuredIds, language, fetcher),
  ).filter((entity) => isCatalogItem(entity, kind));
  const labels = await loadLabels(relatedIds(entities, kind), language, fetcher);
  const items = entities
    .map((entity) => mapCatalogItem(entity, labels, language, kind))
    .filter(Boolean);
  return items
    .filter((item) => typeof item.poster_url === 'string')
    .slice(0, CATALOG_SIZE);
};

export const featuredCatalog = async (
  kind,
  language,
  offset = 0,
  fetcher = fetch,
) => {
  const items = await catalogCollection(kind, language, fetcher);
  if (!items.length) return [];
  const start = Math.max(0, offset) % items.length;
  return [...items.slice(start), ...items.slice(0, start)].slice(0, FEATURED_SIZE);
};

export const searchMovies = (query, language, fetcher = fetch) =>
  searchCatalog('movies', query, language, fetcher);

export const movieDetails = (numericId, language, fetcher = fetch) =>
  catalogDetails('movies', numericId, language, fetcher);
