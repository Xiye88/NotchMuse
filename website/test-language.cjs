const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const cases = [
  ['index.html', 'en', 'https://notchmuse.com/', '/zh/',
    'NotchMuse — Synced Desktop Lyrics for Mac and Windows',
    'Synced desktop lyrics for macOS 14+ (Apple Silicon) and Windows 11/10 (portable .exe). Works with 39+ music players. Free and open source.',
    'Synced Desktop Lyrics for Mac and Windows',
    'Follow lyrics in the Mac menu bar, by the notch, or on the Windows taskbar. A click-through overlay keeps lyrics in view on both platforms across 39+ music players.'],
  ['zh/index.html', 'zh-Hans', 'https://notchmuse.com/zh/', '/',
    'NotchMuse｜Mac 与 Windows 同步桌面歌词与菜单栏歌词工具',
    'NotchMuse 为 macOS 14+（Apple 芯片）和 Windows 11/10（免安装 .exe）提供同步桌面歌词，兼容 39+ 款播放器。免费开源，无需注册。',
    'Mac 与 Windows 同步桌面歌词',
    '在 Mac 菜单栏、刘海旁或 Windows 任务栏看同步歌词，两端都支持点击穿透的悬浮歌词。兼容 39+ 款音乐播放器。'],
];
const decode = text => text.replaceAll('&amp;', '&').replaceAll('&quot;', '"');
for (const [file, lang, canonical, alternate, title, description, h1, subtitle] of cases) {
  const html = fs.readFileSync(path.join(__dirname, file), 'utf8');
  assert(html.includes(`<html lang="${lang}">`));
  assert.equal(decode(html.match(/<title>(.*?)<\/title>/)[1]), title);
  assert.equal(decode(html.match(/<meta name="description" content="([^"]*)"/)[1]), description);
  assert.equal((html.match(/<h1\b/g) || []).length, 1);
  assert.equal(decode(html.match(/<h1>(.*?)<\/h1>/)[1].replace(/<[^>]+>/g, '')), h1);
  assert.equal(decode(html.match(/<p class="lead">(.*?)<\/p>/)[1]), subtitle);
  assert(html.includes(`<link rel="canonical" href="${canonical}">`));
  for (const [code, url] of [['en', 'https://notchmuse.com/'], ['zh-Hans', 'https://notchmuse.com/zh/'], ['x-default', 'https://notchmuse.com/']]) {
    assert(html.includes(`<link rel="alternate" hreflang="${code}" href="${url}">`));
  }
  assert(html.includes(`id="language-toggle" href="${alternate}"`));
  assert(!html.includes('notchmuse-language') && !html.includes('data-i18n'));
  assert(!html.includes('noindex') && !html.includes('googletagmanager.com/gtag/js'));
  for (const placement of ['nav', 'hero', 'footer']) assert.equal((html.match(new RegExp(`data-download-placement="${placement}"`, 'g')) || []).length, 1);
  assert.equal((html.match(/<a\b[^>]*href="[^\"]*NotchMuse\.dmg"/g) || []).length, 3);
  assert.equal((html.match(/<details>/g) || []).length, 7, 'Existing FAQ is static and complete');
  assert(html.includes(lang === 'en' ? 'Which music players work with NotchMuse?' : 'NotchMuse 支持哪些音乐平台？'));
  for (const match of html.matchAll(/(?:href|src|data-src|poster)="(\/[^"#?]+)(?:[?#][^"]*)?"/g)) {
    const asset = match[1];
    assert(fs.existsSync(path.join(__dirname, asset, asset.endsWith('/') ? 'index.html' : '')), `Missing ${file}: ${asset}`);
  }
  for (const type of ['og', 'twitter']) {
    assert.equal(decode(html.match(new RegExp(`(?:property|name)="${type}:title" content="([^"]*)"`))[1]), title);
    assert.equal(decode(html.match(new RegExp(`(?:property|name)="${type}:description" content="([^"]*)"`))[1]), description);
    assert(html.includes(`${type}:image" content="https://notchmuse.com/assets/real-notch-mode.png"`));
  }
  assert(html.includes(`og:url" content="${canonical}"`));
  assert(html.includes('og:type" content="website"'));
  assert(html.includes('og:site_name" content="NotchMuse"'));
  assert(html.includes('twitter:card" content="summary_large_image"'));
  assert(html.includes('id="privacy"'));
  assert.equal((html.match(/data-analytics-settings/g) || []).length, 1);
  assert(html.includes('href="#privacy"'));

}
const sitemap = fs.readFileSync(path.join(__dirname, 'sitemap.xml'), 'utf8');
const sitemapURLs = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(m => m[1]);
assert.deepEqual(sitemapURLs.slice(0, cases.length), cases.map(c => c[2]));
assert.equal(new Set(sitemapURLs).size, sitemapURLs.length, 'Sitemap URLs are unique');
assert(fs.readFileSync(path.join(__dirname, 'robots.txt'), 'utf8').includes('Sitemap: https://notchmuse.com/sitemap.xml'));
console.log('PASS: exact bilingual copy, static FAQ, self-canonical, reciprocal hreflang, social tags, local assets, sitemap and 3 DMG placements');
