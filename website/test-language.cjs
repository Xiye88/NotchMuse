const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const cases = [
  ['index.html', 'en', 'https://notchmuse.com/', '/zh/',
    'NotchMuse — Desktop & Menu Bar Lyrics for Mac',
    'Show synced lyrics on your Mac desktop or in the menu bar. Works with Spotify, Apple Music and more. Free to download. No account required.',
    'Synced lyrics for your Mac desktop and menu bar.',
    'Keep lyrics in view while you work. Supports Spotify, Apple Music, NetEase Cloud Music, QQ Music, and Soda Music.'],
  ['zh/index.html', 'zh-Hans', 'https://notchmuse.com/zh/', '/',
    'NotchMuse｜Mac 桌面歌词与菜单栏歌词工具',
    '用 NotchMuse 在 Mac 桌面或菜单栏显示同步歌词，支持 Spotify、Apple Music、网易云音乐、QQ 音乐和汽水音乐。适用于 macOS 14 及以上的 Apple 芯片 Mac，免费下载，无需注册。',
    '在 Mac 桌面或菜单栏查看同步歌词',
    '工作时也能随时查看歌词。支持 Spotify、Apple Music、网易云音乐、QQ 音乐和汽水音乐。'],
];
const decode = text => text.replaceAll('&amp;', '&').replaceAll('&quot;', '"');
for (const [file, lang, canonical, alternate, title, description, h1, subtitle] of cases) {
  const html = fs.readFileSync(path.join(__dirname, file), 'utf8');
  assert(html.includes(`<html lang="${lang}">`));
  assert.equal(decode(html.match(/<title>(.*?)<\/title>/)[1]), title);
  assert.equal(decode(html.match(/<meta name="description" content="([^"]*)"/)[1]), description);
  assert.equal((html.match(/<h1\b/g) || []).length, 1);
  assert.equal(decode(html.match(/<h1>(.*?)<\/h1>/)[1]), h1);
  assert.equal(decode(html.match(/<p class="lead">(.*?)<\/p>/)[1]), subtitle);
  assert(html.includes(`<link rel="canonical" href="${canonical}">`));
  for (const [code, url] of [['en', 'https://notchmuse.com/'], ['zh-Hans', 'https://notchmuse.com/zh/'], ['x-default', 'https://notchmuse.com/']]) {
    assert(html.includes(`<link rel="alternate" hreflang="${code}" href="${url}">`));
  }
  assert(html.includes(`id="language-toggle" href="${alternate}"`));
  assert(!html.includes('notchmuse-language') && !html.includes('data-i18n'));
  assert(!html.includes('noindex') && !html.includes('googletagmanager.com/gtag/js'));
  for (const placement of ['nav', 'hero', 'footer']) assert.equal((html.match(new RegExp(`data-download-placement="${placement}"`, 'g')) || []).length, 1);
  assert.equal((html.match(/NotchMuse\.dmg"/g) || []).length, 3);
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
  assert(html.includes(lang === 'en'
    ? 'The NotchMuse app does not collect usage analytics or upload audio. With your consent, this website uses Google Analytics to measure visits and download-button clicks. Website analytics are separate from the app.'
    : 'NotchMuse 应用不收集使用分析数据，也不上传音频。经你同意，官网使用 Google Analytics 统计访问和下载按钮点击。官网统计与应用本身相互独立。'));
  assert(html.includes('id="website-analytics"'));
  assert.equal((html.match(/data-analytics-settings/g) || []).length, 2);
  assert(html.includes('href="#website-analytics"'));

}
const sitemap = fs.readFileSync(path.join(__dirname, 'sitemap.xml'), 'utf8');
const sitemapURLs = [...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(m => m[1]);
assert.deepEqual(sitemapURLs.slice(0, cases.length), cases.map(c => c[2]));
assert.equal(new Set(sitemapURLs).size, sitemapURLs.length, 'Sitemap URLs are unique');
assert(fs.readFileSync(path.join(__dirname, 'robots.txt'), 'utf8').includes('Sitemap: https://notchmuse.com/sitemap.xml'));
console.log('PASS: exact bilingual copy, static FAQ, self-canonical, reciprocal hreflang, social tags, local assets, sitemap and 3 DMG placements');
