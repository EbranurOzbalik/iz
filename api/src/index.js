import {
  catalogCollection,
  catalogDetails,
  searchCatalog,
} from './catalog.js';
import { bookCollection, bookDetails, searchBooks } from './books.js';
import { biletsaTheatreCollection } from './biletsa.js';
import { privacyHtml } from './privacy.js';
import {
  catalogStatus,
  catalogCount,
  persistentCatalog,
  replaceCatalog,
  replaceSourceCatalog,
  searchStoredCatalog,
  storedCatalog,
  storedCatalogDetails,
} from './storage.js';

const json = (body, status = 200, cache = 'public, max-age=3600') => new Response(
  JSON.stringify(body),
  {
    status,
    headers: {
      'Content-Type': 'application/json; charset=utf-8',
      'Cache-Control': cache,
      'Access-Control-Allow-Origin': '*',
      'X-Content-Type-Options': 'nosniff',
    },
  },
);

const language = (url) => url.searchParams.get('lang') === 'en' ? 'en' : 'tr';

export default {
  async fetch(request, env) {
    if (request.method !== 'GET') return json({ error: 'method_not_allowed' }, 405, 'no-store');
    const url = new URL(request.url);
    if (url.pathname === '/health') {
      return json({ service: 'iz-catalog-api', status: 'ok' }, 200, 'no-store');
    }
    if (url.pathname === '/privacy') {
      return new Response(privacyHtml, {
        headers: {
          'Content-Type': 'text/html; charset=utf-8',
          'Cache-Control': 'public, max-age=3600',
          'X-Content-Type-Options': 'nosniff',
          'Content-Security-Policy': "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'",
        },
      });
    }
    try {
      if (url.pathname === '/v1/catalog/status') {
        return json({ results: await catalogStatus(env.CATALOG_DB) }, 200, 'no-store');
      }
      if (url.pathname === '/v1/books/catalog') {
        const page = Math.max(1, Number.parseInt(url.searchParams.get('page') ?? '1', 10) || 1);
        const limit = Math.min(100, Math.max(1, Number.parseInt(url.searchParams.get('limit') ?? '50', 10) || 50));
        const locale = language(url);
        let total = await catalogCount(env.CATALOG_DB, 'books', locale);
        if (total < 200) {
          await persistentCatalog(
            env.CATALOG_DB,
            'books',
            locale,
            () => bookCollection(locale),
          );
          total = await catalogCount(env.CATALOG_DB, 'books', locale);
        }
        return json({
          page,
          limit,
          total,
          results: await storedCatalog(
            env.CATALOG_DB,
            'books',
            locale,
            { limit, offset: (page - 1) * limit },
          ),
        }, 200, 'public, max-age=21600');
      }
      if (url.pathname === '/v1/books/featured') {
        const items = await persistentCatalog(
          env.CATALOG_DB,
          'books',
          language(url),
          () => bookCollection(language(url)),
        );
        const offset = Math.max(0, Number.parseInt(url.searchParams.get('offset') ?? '0', 10) || 0);
        const start = items.length ? offset % items.length : 0;
        return json({
          results: [...items.slice(start), ...items.slice(0, start)].slice(0, 12),
        }, 200, 'public, max-age=21600');
      }
      if (url.pathname === '/v1/books/search') {
        const query = (url.searchParams.get('q') ?? '').trim();
        if (query.length < 2 || query.length > 100) {
          return json({ error: 'invalid_query' }, 400, 'no-store');
        }
        return json({ results: await searchBooks(query, language(url)) });
      }
      const bookMatch = /^\/v1\/books\/(OL\d+W)$/.exec(url.pathname);
      if (bookMatch) {
        const item = await bookDetails(bookMatch[1], language(url));
        return item ? json(item, 200, 'public, max-age=86400') : json({ error: 'not_found' }, 404);
      }
      const catalogMatch = /^\/v1\/(movies|series|theatre)\/catalog$/.exec(url.pathname);
      if (catalogMatch) {
        const page = Math.max(1, Number.parseInt(url.searchParams.get('page') ?? '1', 10) || 1);
        const limit = Math.min(100, Math.max(1, Number.parseInt(url.searchParams.get('limit') ?? '50', 10) || 50));
        const kind = catalogMatch[1];
        const locale = language(url);
        let total = await catalogCount(env.CATALOG_DB, kind, locale);
        if (total < 200) {
          await persistentCatalog(
            env.CATALOG_DB,
            kind,
            locale,
            () => catalogCollection(kind, locale),
          );
          total = await catalogCount(env.CATALOG_DB, kind, locale);
        }
        return json({
          page,
          limit,
          total,
          results: await storedCatalog(
            env.CATALOG_DB,
            kind,
            locale,
            { limit, offset: (page - 1) * limit },
          ),
        }, 200, 'public, max-age=21600');
      }
      const featuredMatch = /^\/v1\/(movies|series|theatre)\/featured$/.exec(url.pathname);
      if (featuredMatch) {
        const offset = Number.parseInt(url.searchParams.get('offset') ?? '0', 10);
        return json({
          results: await (async () => {
            const items = await persistentCatalog(
              env.CATALOG_DB,
              featuredMatch[1],
              language(url),
              () => catalogCollection(featuredMatch[1], language(url)),
            );
            if (!items.length) return [];
            const start = Math.max(0, Number.isFinite(offset) ? offset : 0) % items.length;
            return [...items.slice(start), ...items.slice(0, start)].slice(0, 12);
          })(),
        }, 200, 'public, max-age=21600');
      }
      const searchMatch = /^\/v1\/(movies|series|theatre)\/search$/.exec(url.pathname);
      if (searchMatch) {
        const query = (url.searchParams.get('q') ?? '').trim();
        if (query.length < 2 || query.length > 100) {
          return json({ error: 'invalid_query' }, 400, 'no-store');
        }
        const kind = searchMatch[1];
        const locale = language(url);
        const stored = await searchStoredCatalog(
          env.CATALOG_DB,
          kind,
          locale,
          query,
        );
        if (stored.length >= 12) return json({ results: stored });
        const remote = await searchCatalog(kind, query, locale);
        const seen = new Set(stored.map((item) => String(item.source_id ?? item.id)));
        return json({
          results: [...stored, ...remote.filter((item) => {
            const id = String(item.source_id ?? item.id);
            if (seen.has(id)) return false;
            seen.add(id);
            return true;
          })].slice(0, 12),
        });
      }
      const match = /^\/v1\/(movies|series|theatre)\/(\d+)$/.exec(url.pathname);
      if (match) {
        const numericId = Number(match[2]);
        const locale = language(url);
        const item = await storedCatalogDetails(
          env.CATALOG_DB,
          match[1],
          locale,
          numericId,
        ) ?? await catalogDetails(match[1], numericId, locale);
        return item ? json(item, 200, 'public, max-age=86400') : json({ error: 'not_found' }, 404);
      }
      return json({ error: 'not_found' }, 404, 'no-store');
    } catch (error) {
      console.error('catalog_error', error instanceof Error ? error.message : 'unknown');
      return json({ error: 'catalog_unavailable' }, 502, 'no-store');
    }
  },
  async scheduled(event, env, ctx) {
    const catalogs = [
      ['books', 'tr'],
      ['books', 'en'],
      ['theatre', 'tr'],
      ['theatre', 'en'],
    ];
    const slot = Math.floor(event.scheduledTime / (6 * 60 * 60 * 1000));
    const [kind, languageCode] = catalogs[slot % catalogs.length];
    ctx.waitUntil((async () => {
      if (env.BILETSA_API_KEY) {
        const events = await biletsaTheatreCollection(env.BILETSA_API_KEY);
        await replaceSourceCatalog(
          env.CATALOG_DB,
          'theatre',
          'tr',
          'biletsa:',
          events,
        );
        await replaceSourceCatalog(
          env.CATALOG_DB,
          'theatre',
          'en',
          'biletsa:',
          events,
        );
      }
      // Large catalogs are imported in controlled batches. Do not let the
      // lightweight periodic refresh shrink them back to 200 items.
      if (await catalogCount(env.CATALOG_DB, kind, languageCode) > 200) return;
      const items = kind === 'books'
        ? await bookCollection(languageCode)
        : await catalogCollection(kind, languageCode);
      await replaceCatalog(env.CATALOG_DB, kind, languageCode, items);
    })());
  },
};
