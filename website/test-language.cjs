const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const html = fs.readFileSync(`${__dirname}/index.html`, 'utf8');
const script = html.match(/<script>([\s\S]*?)<\/script>/)[1];
const markup = html.split('<script>')[0];
assert(!/[\u3400-\u9fff]/.test(markup), 'Default markup must be English');
assert.equal((markup.match(/href="https:\/\/github.com\/Xiye88\/NotchMuse\/releases\/download\/v0.8.0-beta.2\/NotchMuse.dmg"/g) || []).length, 3);

for (const stored of [null, 'zh-Hans', 'invalid', 'unavailable']) {
  const elements = [...markup.matchAll(/<([\w-]+)\b([^>]*\bdata-i18n[^>]*)>([^<]*)/g)].map(match => {
    const attrs = Object.fromEntries([...match[2].matchAll(/([\w-]+)="([^"]*)"/g)].map(m => [m[1], m[2]]));
    return { tag: match[1], attrs, dataset: { i18n: attrs['data-i18n'] }, textContent: match[3],
      getAttribute: key => attrs[key], setAttribute: (key, value) => { assert.equal(typeof value, 'string'); attrs[key] = value; } };
  });
  let click;
  let saved;
  const label = {};
  const button = { querySelector: () => label, setAttribute: (_, value) => assert.equal(typeof value, 'string'), addEventListener: (_, fn) => { click = fn; } };
  const document = {
    documentElement: {},
    querySelectorAll: selector => elements.filter(el => selector.slice(1, -1) in el.attrs),
    querySelector: selector => selector === 'title' ? elements.find(el => el.tag === 'title') : button,
  };
  const localStorage = {
    getItem() { if (stored === 'unavailable') throw Error('blocked'); return stored; },
    setItem(_, value) { if (stored === 'unavailable') throw Error('blocked'); saved = value; },
  };
  vm.runInNewContext(script, { document, localStorage });
  const initial = stored === 'zh-Hans' ? 'zh-Hans' : 'en';
  assert.equal(document.documentElement.lang, initial);
  click();
  assert.notEqual(document.documentElement.lang, initial);
  for (const el of elements.filter(el => el.dataset.i18n)) assert.equal(typeof el.textContent, 'string');
  click();
  assert.equal(document.documentElement.lang, initial);
  if (stored !== 'unavailable') assert.equal(saved, initial);
}
console.log('PASS: default English, translation keys/attributes, toggling, saved preference, blocked storage, Beta 2 links');
