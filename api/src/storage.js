const TARGET_SIZE = 200;

export const storedCatalog = async (
  db,
  kind,
  language,
  { limit = TARGET_SIZE, offset = 0 } = {},
) => {
  if (!db) return [];
  const result = await db.prepare(
    `SELECT payload FROM catalog_items
     WHERE kind = ? AND language = ?
     ORDER BY position LIMIT ? OFFSET ?`,
  ).bind(kind, language, limit, offset).all();
  return (result.results ?? []).flatMap((row) => {
    try {
      return [JSON.parse(row.payload)];
    } catch (_) {
      return [];
    }
  });
};

export const catalogCount = async (db, kind, language) => {
  if (!db) return 0;
  const row = await db.prepare(
    'SELECT COUNT(*) AS count FROM catalog_items WHERE kind = ? AND language = ?',
  ).bind(kind, language).first();
  return Number(row?.count ?? 0);
};

export const searchStoredCatalog = async (db, kind, language, query, limit = 12) => {
  if (!db) return [];
  const result = await db.prepare(
    `SELECT payload FROM catalog_items
     WHERE kind = ? AND language = ?
       AND LOWER(json_extract(payload, '$.title')) LIKE LOWER(?)
     ORDER BY position LIMIT ?`,
  ).bind(kind, language, `%${query}%`, limit).all();
  return (result.results ?? []).flatMap((row) => {
    try {
      return [JSON.parse(row.payload)];
    } catch (_) {
      return [];
    }
  });
};

export const storedCatalogDetails = async (db, kind, language, numericId) => {
  if (!db) return null;
  const row = await db.prepare(
    `SELECT payload FROM catalog_items
     WHERE kind = ? AND language = ?
       AND CAST(json_extract(payload, '$.id') AS INTEGER) = ?
     LIMIT 1`,
  ).bind(kind, language, numericId).first();
  if (!row?.payload) return null;
  try {
    return JSON.parse(row.payload);
  } catch (_) {
    return null;
  }
};

export const saveCatalog = async (db, kind, language, items) => {
  if (!db || !items.length) return;
  const statements = items.slice(0, TARGET_SIZE).map((item, position) =>
    db.prepare(
      `INSERT INTO catalog_items
       (kind, language, source_id, position, payload, updated_at)
       VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
       ON CONFLICT(kind, language, source_id) DO UPDATE SET
         position = excluded.position,
         payload = excluded.payload,
         updated_at = CURRENT_TIMESTAMP`,
    ).bind(
      kind,
      language,
      String(item.source_id ?? item.id),
      position,
      JSON.stringify(item),
    ));
  for (let index = 0; index < statements.length; index += 50) {
    await db.batch(statements.slice(index, index + 50));
  }
};

export const replaceCatalog = async (db, kind, language, items) => {
  if (!db || !items.length) return;
  await db.prepare(
    'DELETE FROM catalog_items WHERE kind = ? AND language = ?',
  ).bind(kind, language).run();
  await saveCatalog(db, kind, language, items);
};

export const replaceSourceCatalog = async (
  db,
  kind,
  language,
  sourcePrefix,
  items,
  startPosition = -10000,
) => {
  if (!db) return;
  await db.prepare(
    'DELETE FROM catalog_items WHERE kind = ? AND language = ? AND source_id LIKE ?',
  ).bind(kind, language, `${sourcePrefix}%`).run();
  const statements = items.map((item, index) => db.prepare(
    `INSERT INTO catalog_items
     (kind, language, source_id, position, payload, updated_at)
     VALUES (?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
  ).bind(
    kind,
    language,
    String(item.source_id ?? item.id),
    startPosition + index,
    JSON.stringify(item),
  ));
  for (let index = 0; index < statements.length; index += 50) {
    await db.batch(statements.slice(index, index + 50));
  }
};

export const persistentCatalog = async (
  db,
  kind,
  language,
  loader,
) => {
  const stored = await storedCatalog(db, kind, language);
  if (stored.length >= TARGET_SIZE) return stored;
  const loaded = await loader();
  await saveCatalog(db, kind, language, loaded);
  return loaded;
};

export const catalogStatus = async (db) => {
  if (!db) return [];
  const result = await db.prepare(
    `SELECT kind, language, COUNT(*) AS count, MAX(updated_at) AS updated_at
     FROM catalog_items GROUP BY kind, language ORDER BY kind, language`,
  ).all();
  return result.results ?? [];
};
