// Local browser checks; analytics and downloads are intercepted.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');
const base = process.env.SHOWCASE_URL || 'http://127.0.0.1:8891';
const output = process.env.SHOWCASE_EVIDENCE;
const topics = ['spotify-lyrics-mac', 'menu-bar-lyrics', 'apple-music-desktop-lyrics-mac', 'macbook-notch-lyrics', 'lyricsx-alternative'];
const urls = ['/', '/zh/', ...topics.flatMap(slug => [`/${slug}/`, `/zh/${slug}/`])];
const sitemap = fs.readFileSync(path.join(__dirname, 'sitemap.xml'), 'utf8');
assert.deepEqual([...sitemap.matchAll(/<loc>([^<]+)<\/loc>/g)].map(m => new URL(m[1]).pathname), urls);
const titles = new Set();
const descriptions = new Set();
for (const suffix of urls) {
  const html = fs.readFileSync(path.join(__dirname, suffix, 'index.html'), 'utf8');
  const title = html.match(/<title>([^<]+)<\/title>/)[1];
  const description = html.match(/<meta name="description" content="([^"]+)"/)[1];
  assert(!titles.has(title), `Repeated title: ${suffix}`);
  assert(!descriptions.has(description), `Repeated description: ${suffix}`);
  titles.add(title); descriptions.add(description);
  // Resolve every local link and fragment against its actual target page.
  for (const match of html.matchAll(/(?:href|src|poster|data-src)="([^"]+)"/g)) {
    const url = new URL(match[1], `https://notchmuse.com${suffix}`);
    if (url.origin !== 'https://notchmuse.com') continue;
    const target = path.join(__dirname, url.pathname, url.pathname.endsWith('/') ? 'index.html' : '');
    assert(fs.existsSync(target), `Missing target ${suffix}: ${match[1]}`);
    if (url.hash) {
      const text = fs.readFileSync(target, 'utf8');
      assert(text.includes(`id="${url.hash.slice(1)}"`), `Missing anchor ${suffix}: ${match[1]}`);
    }
  }
}
(async () => {
  const browser = await chromium.launch({ headless: true, ...(process.env.PLAYWRIGHT_EXECUTABLE_PATH ? { executablePath: process.env.PLAYWRIGHT_EXECUTABLE_PATH } : {}) });
  if (output) fs.mkdirSync(output, { recursive: true });
  try {
    for (const slug of topics) {
      const context = await browser.newContext({ reducedMotion: 'reduce', viewport: { width: 1440, height: 1000 } });
      const google = [], media = [], errors = [];
      await context.route(/https:\/\/[^/]*(?:google-analytics|googletagmanager|analytics\.google)\.com\//, route => {
        google.push(route.request().url());
        return route.fulfill({ contentType: 'application/javascript', body: 'window.__localGATest = true;' });
      });
      await context.route('**/NotchMuse.dmg', route => route.fulfill({ contentType: 'application/octet-stream', headers: { 'Content-Disposition': 'attachment; filename="local-test.txt"' }, body: 'Local download routing test' }));
      const page = await context.newPage();
      page.on('pageerror', error => errors.push(error.message));
      page.on('response', response => { if (response.status() >= 400) errors.push(`${response.status()} ${response.url()}`); });
      page.on('request', request => { if (/\.(webm|mp4)(\?|$)/.test(request.url())) media.push(request.url()); });
      for (const zh of [false, true]) {
        const suffix = `${zh ? '/zh' : ''}/${slug}/`;
        await page.goto(base + suffix, { waitUntil: 'networkidle' });
        assert.equal(await page.locator('h1').count(), 1);
        assert.equal(await page.locator('html').getAttribute('lang'), zh ? 'zh-Hans' : 'en');
        assert.equal(await page.locator('link[rel="canonical"]').getAttribute('href'), 'https://notchmuse.com' + suffix);
        for (const [code, target] of [['en', `/${slug}/`], ['zh-Hans', `/zh/${slug}/`], ['x-default', `/${slug}/`]]) {
          assert.equal(await page.locator(`link[hreflang="${code}"]`).getAttribute('href'), 'https://notchmuse.com' + target);
        }
        assert.equal(await page.locator('#language-toggle').getAttribute('href'), `${zh ? '' : '/zh'}/${slug}/`);
        assert.equal(await page.locator('a[data-download-placement]').count(), 3);
        assert.equal(await page.locator('.guide-related .guide-card').count(), 4);
        assert.equal(await page.locator('script[src*="analytics.js"]').count(), 1);
        assert.equal(await page.locator('.guide-figure .demo-poster').evaluate(img => img.complete && img.naturalWidth > 0), true);
        assert.equal(JSON.parse(await page.locator('script[type="application/ld+json"]').textContent()).itemListElement[1].item, 'https://notchmuse.com' + suffix);
        assert.equal(google.length, 0, 'No analytics before consent');
        for (const width of [360, 768, 1440]) {
          await page.setViewportSize({ width, height: 1000 });
          await page.evaluate(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));
          assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `Overflow ${suffix} ${width}`);
          for (const selector of ['.site-header .brand', '#language-toggle', '.site-header [data-download-placement="nav"]']) {
            const box = await page.locator(selector).boundingBox();
            assert(box && box.x >= 0 && box.x + box.width <= width + 1, `Header clipped ${suffix} ${width}: ${selector}`);
          }
          if (output && ((!zh && width === 1440) || (zh && width === 360))) {
            await page.screenshot({ path: path.join(output, `${slug}-${zh ? 'zh-mobile' : 'en-desktop'}.png`), fullPage: true });
          }
        }
        await page.locator('.guide-content .faq summary').first().click();
        assert.equal(await page.locator('.guide-content .faq details').first().getAttribute('open'), '');
      }
      assert.deepEqual(media, [], 'Reduced motion uses posters only');
      await page.goto(base + `/${slug}/`, { waitUntil: 'networkidle' });
      await page.locator('[data-consent-reject]').click();
      await Promise.all([page.waitForEvent('download'), page.locator('[data-download-placement="hero"]').click()]);
      assert.equal(google.length, 0, 'Download works after refusal without analytics');
      await page.locator('[data-analytics-settings]').click();
      await page.locator('[data-consent-accept]').click();
      await page.waitForFunction(() => window.__localGATest);
      await Promise.all([page.waitForEvent('download'), page.locator('[data-download-placement="hero"]').click()]);
      const events = await page.evaluate(() => (window.dataLayer || []).filter(item => item[0] === 'event' && item[1] === 'download_click').map(item => item[2]));
      assert.equal(events.length, 1);
      assert.equal(events[0].placement, 'hero');
      assert.equal(events[0].page_language, 'en');
      await page.locator('#language-toggle').click();
      await page.waitForURL(base + `/zh/${slug}/`);
      await page.waitForFunction(() => window.__localGATest);
      await Promise.all([page.waitForEvent('download'), page.locator('[data-download-placement="hero"]').click()]);
      assert.equal(await page.evaluate(() => [...window.dataLayer].find(item => item[0] === 'event')[2].page_language), 'zh-Hans');
      assert.deepEqual(errors, []);
      await context.close();
      console.log(`PASS: ${slug} EN/ZH, metadata, mobile/desktop, consent, downloads, language pairing`);
    }
    const noJS = await browser.newContext({ javaScriptEnabled: false });
    const page = await noJS.newPage();
    for (const suffix of urls) {
      await page.goto(base + suffix);
      assert(await page.locator('h1').isVisible());
      assert.equal(await page.locator('a[data-download-placement]').count(), 3);
      if (suffix === '/' || suffix === '/zh/') assert.equal(await page.locator('#guides .guide-card').count(), 5);
      else assert(await page.locator('.guide-content').isVisible());
    }
    await noJS.close();
    console.log('PASS: all 12 pages readable and download links present without JavaScript; sitemap, unique metadata and internal links/anchors valid');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
