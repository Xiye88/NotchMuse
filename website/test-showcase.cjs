// Run against the local static site; uses an existing Playwright installation.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { chromium } = require('playwright');
const url = process.env.SHOWCASE_URL || 'http://127.0.0.1:8765';
const output = process.env.SHOWCASE_EVIDENCE;
const launches = process.env.PLAYWRIGHT_EXECUTABLE_PATH ? { executablePath: process.env.PLAYWRIGHT_EXECUTABLE_PATH } : {};

(async () => {
  const browser = await chromium.launch({ headless: true, ...launches });
  try {
  const page = await browser.newPage({ viewport: { width: 1440, height: 1000 } });
  const errors = [];
  const media = new Set();
  page.on('pageerror', error => errors.push(error.message));
  page.on('response', response => { if (response.status() >= 400) errors.push(`${response.status()} ${response.url()}`); });
  page.on('request', request => { if (/\.(mp4|webm)(\?|$)/.test(request.url())) media.add(request.url()); });
  await page.addInitScript(() => {
    window.showcaseCLS = 0;
    new PerformanceObserver(list => {
      for (const entry of list.getEntries()) if (!entry.hadRecentInput) window.showcaseCLS += entry.value;
    }).observe({ type: 'layout-shift', buffered: true });
  });
  if (output) fs.mkdirSync(output, { recursive: true });
  const screenshot = async name => { if (output) await page.screenshot({ path: path.join(output, `${name}.png`), fullPage: false }); };
  const playing = async selector => page.waitForFunction(sel => {
    const video = document.querySelector(sel);
    return !video.paused && video.readyState >= 2 && video.currentTime > 0;
  }, selector);

  await page.goto(url, { waitUntil: 'networkidle' });
  assert.equal(await page.locator('#status-tab').getAttribute('aria-selected'), 'true');
  await playing('#status-panel video');
  const status = await page.locator('#status-panel video').evaluate(video => ({
    muted: video.muted, loop: video.loop, playsInline: video.playsInline,
    preload: video.preload, width: video.videoWidth, height: video.videoHeight,
    duration: video.duration, poster: video.poster,
  }));
  assert(status.muted && status.loop && status.playsInline);
  assert.equal(status.preload, 'none');
  assert.equal(status.width, 1080);
  assert.equal(status.height, 240);
  assert(status.duration >= 6 && status.duration <= 8);
  assert(status.poster.endsWith('status-bar-poster.webp'));
  assert([...media].every(item => item.includes('status-bar-demo.')), 'Only default Hero video loads initially');
  assert.equal(await page.locator('[data-demo] .demo-poster').first().evaluate(img => img.complete && img.naturalWidth > 0), true);
  await screenshot('website-after-desktop-status');
  // Observe a real loop across the playback boundary, instead of checking only the loop attribute.
  await page.locator('#status-panel video').evaluate(video => { video.currentTime = video.duration - 0.15; });
  await page.waitForFunction(() => { const v = document.querySelector('#status-panel video'); return v.currentTime < 1 && !v.paused; });
  console.log('PASS: default autoplay, silent inline playback, actual looping, poster, deferred video requests');

  await page.locator('#notch-tab').click();
  await playing('#notch-panel video');
  assert(await page.locator('#status-panel video').evaluate(video => video.paused));
  assert.equal(await page.locator('#notch-panel video').evaluate(video => video.duration), 8.5);
  await screenshot('website-after-desktop-notch');
  await page.locator('#notch-tab').press('ArrowLeft');
  assert.equal(await page.locator('#status-tab').getAttribute('aria-selected'), 'true');
  assert.equal(await page.locator('#status-tab').evaluate(button => document.activeElement === button), true);
  await page.locator('#language-toggle').click();
  assert.equal(await page.locator('#status-tab').textContent(), '菜单栏');
  assert.equal(await page.locator('#notch-tab').textContent(), '刘海');
  await screenshot('website-after-desktop-chinese');
  await page.locator('#language-toggle').click();
  console.log('PASS: mode switching, inactive playback paused, keyboard tabs, bilingual showcase');

  await page.emulateMedia({ reducedMotion: 'reduce' });
  await page.waitForFunction(() => { const v = document.querySelector('#status-panel video'); return v.paused && !v.autoplay; });
  assert.equal(await page.locator('#status-panel video').evaluate(video => getComputedStyle(video).display), 'none');
  await screenshot('website-after-reduced-motion');
  await page.emulateMedia({ reducedMotion: 'no-preference' });
  await playing('#status-panel video');
  console.log('PASS: live system motion preference changes pause/resume playback');

  for (const width of [360, 390, 760, 820, 1440]) {
    await page.setViewportSize({ width, height: 1000 });
    await page.locator('#notch-tab').click();
    await playing('#notch-panel video');
    assert(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth), `Overflow at ${width}px`);
    const bounds = await page.locator('#notch-panel').boundingBox();
    assert(bounds.width > width * (width <= 760 ? 0.8 : 0.3));
    if (width <= 760) {
      const copy = await page.locator('.hero-copy').boundingBox();
      assert(bounds.y >= copy.y + copy.height, 'Mobile demo appears below the copy');
    }
    if (width === 390) await screenshot('website-after-mobile-notch');
    await page.locator('#status-tab').click();
    await playing('#status-panel video');
    if (width === 390) await screenshot('website-after-mobile-status');
  }
  assert(await page.evaluate(() => window.showcaseCLS < 0.01), 'No meaningful layout shift');
  console.log('PASS: responsive 360/390/760/820/1440px, no overflow, reserved dimensions, CLS < 0.01');

  await page.locator('.appearance-showcase').scrollIntoViewIfNeeded();
  await playing('.appearance-showcase video');
  assert(await page.locator('#status-panel video').evaluate(video => video.paused));
  await screenshot('website-after-appearance');
  console.log('PASS: appearance video loads in view, offscreen Hero pauses');
  assert.deepEqual(errors, []);

  const reduced = await browser.newPage({ viewport: { width: 390, height: 844 }, reducedMotion: 'reduce' });
  const reducedRequests = [];
  reduced.on('request', request => { if (/\.(mp4|webm)(\?|$)/.test(request.url())) reducedRequests.push(request.url()); });
  await reduced.goto(url, { waitUntil: 'networkidle' });
  await reduced.locator('#notch-tab').click();
  await reduced.locator('.appearance-showcase').scrollIntoViewIfNeeded();
  assert(await reduced.locator('video').evaluateAll(videos => videos.every(video => video.paused && !video.autoplay && !video.currentSrc)));
  assert.deepEqual(reducedRequests, [], 'Reduced motion never requests videos');
  console.log('PASS: initial reduced motion and tab/scroll interactions use only static posters');

  const fallback = await browser.newPage();
  await fallback.route('**/*.webm', route => route.fulfill({ status: 200, contentType: 'video/webm', body: 'unsupported' }));
  await fallback.goto(url);
  await fallback.waitForFunction(() => { const v = document.querySelector('#status-panel video'); return v.currentSrc.endsWith('.mp4') && !v.paused && v.currentTime > 0; });
  console.log('PASS: MP4 fallback when WebM cannot be decoded');
  const failed = await browser.newPage();
  await failed.route(/\.(mp4|webm)$/, route => route.abort());
  await failed.goto(url, { waitUntil: 'networkidle' });
  assert(await failed.locator('#status-panel .demo-poster').evaluate(img => img.complete && img.naturalWidth > 0));
  assert.equal(await failed.locator('#status-panel .live-demo').evaluate(demo => demo.classList.contains('is-playing')), false);
  console.log('PASS: failed autoplay/media keeps the readable poster');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
