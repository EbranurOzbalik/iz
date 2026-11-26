import assert from 'node:assert/strict';
import test from 'node:test';

import { privacyHtml } from '../src/privacy.js';

test('gizlilik sayfasi magaza icin gerekli bilgileri icerir', () => {
  assert.match(privacyHtml, /İZ · Gizlilik politikası/);
  assert.match(privacyHtml, /Ebranur Özbalık/);
  assert.match(privacyHtml, /ozbalikebranur@gmail\.com/);
  assert.match(privacyHtml, /Saklama, silme ve güvenlik/);
  assert.doesNotMatch(privacyHtml, /taslak/i);
});
