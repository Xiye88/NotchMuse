// Local integration tests: Google requests are intercepted; no live GA data is sent.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const { chromium } = require('playwright');
const url = (process.env.SHOWCASE_URL || 'http://127.0.0.1:8874').replace(/\/$/, '');
const launch = process.env.PLAYWRIGHT_EXECUTABLE_PATH ? { executablePath: process.env.PLAYWRIGHT_EXECUTABLE_PATH } : {};
const key = 'notchmuse.analytics-consent';
(async () => {
  const browser = await chromium.launch({ headless: true, ...launch });
  try {
    for (const [suffix, language] of [['/', 'en'], ['/zh/', 'zh-Hans']]) {
      const context = await browser.newContext();
      const googleRequests = [];
      let downloads = 0;
      await context.route(/https:\/\/[^/]*(?:google-analytics|googletagmanager|analytics\.google)\.com\//, route => {
        googleRequests.push(route.request().url());
        return route.fulfill({ contentType: 'application/javascript', body: 'window.__gaTestLoaded = true;' });
      });
      await context.route('**/NotchMuse.dmg', route => {
        downloads++;
        return route.fulfill({ contentType: 'application/octet-stream', headers: { 'Content-Disposition': 'attachment; filename="test-not-a-real-dmg.txt"' }, body: 'download navigation test' });
      });
      await context.addInitScript(() => localStorage.setItem('notchmuse-language', 'zh-Hans'));
      const page = await context.newPage();
      const errors = [];
      page.on('pageerror', error => errors.push(error.message));
      const configs = () => page.evaluate(() => (window.dataLayer || []).filter(item => item[0] === 'config').length);
      const events = () => page.evaluate(() => (window.dataLayer || []).filter(item => item[0] === 'event').map(item => ({ name: item[1], params: item[2] })));
      const download = placement => Promise.all([
        page.waitForEvent('download'), page.locator(`[data-download-placement="${placement}"]`).click(),
      ]);
      await page.goto(url + suffix, { waitUntil: 'networkidle' });
      assert.equal(await page.locator('html').getAttribute('lang'), language, 'Legacy language storage cannot change the URL language');
      assert.equal(googleRequests.length, 0);
      assert.equal(await configs(), 0);
      await download('hero');
      assert.deepEqual(await events(), []);
      await page.locator('[data-consent-reject]').click();
      await page.reload({ waitUntil: 'networkidle' });
      assert.equal(googleRequests.length, 0, 'Refusal and reload send zero Google requests');
      assert.equal(await page.evaluate(k => localStorage.getItem(k), key), 'denied');
      await download('nav');
      assert.deepEqual(await events(), []);
      await page.locator('.site-footer [data-analytics-settings]').click();
      await page.locator('[data-consent-accept]').click();
      await page.waitForFunction(() => window.__gaTestLoaded);
      assert.equal(googleRequests.length, 1);
      assert.equal(await configs(), 1);
      await page.addScriptTag({ content: fs.readFileSync(`${__dirname}/analytics.js`, 'utf8') });
      await page.locator('.site-footer [data-analytics-settings]').click();
      await page.locator('[data-consent-accept]').click();
      assert.equal(googleRequests.length, 1, 'Repeated consent and duplicate script do not reload the tag');
      assert.equal(await configs(), 1);
      for (const placement of ['nav', 'hero', 'footer']) await download(placement);
      assert.deepEqual(await events(), ['nav', 'hero', 'footer'].map(placement => ({ name: 'download_click', params: { app_version: '0.8.1', placement, page_language: language } })));
      assert.equal(downloads, 5, 'Consent never prevents the native download action');
      await page.locator('.site-header a[href="#faq"]').click();
      assert.equal((await events()).length, 3, 'Ordinary navigation does not send download events');
      await page.reload({ waitUntil: 'networkidle' });
      assert.equal(googleRequests.length, 2, 'Saved consent initializes once on the next page');
      assert.equal(await configs(), 1);
      await page.evaluate(() => { document.cookie = '_ga=test; Path=/'; document.cookie = '_ga_JDBTS8BRKT=test; Path=/'; document.cookie = 'unrelated=keep; Path=/'; });
      await page.locator('.site-footer [data-analytics-settings]').click();
      await Promise.all([page.waitForEvent('load'), page.locator('[data-consent-reject]').click()]);
      await page.waitForLoadState('networkidle');
      assert.equal(googleRequests.length, 2, 'Withdrawal reload sends zero new Google requests');
      assert.equal(await configs(), 0);
      assert.equal(await page.evaluate(k => localStorage.getItem(k), key), 'denied');
      const cookies = await context.cookies();
      assert(!cookies.some(cookie => cookie.name.startsWith('_ga')));
      assert(cookies.some(cookie => cookie.name === 'unrelated'));
      await download('footer');
      assert.deepEqual(await events(), []);
      await page.locator('#language-toggle').click();
      await page.waitForLoadState('networkidle');
      assert.equal(await page.locator('html').getAttribute('lang'), language === 'en' ? 'zh-Hans' : 'en');
      assert.equal(googleRequests.length, 2, 'Refusal persists across both language URLs');
      assert.deepEqual(errors, []);
      console.log(`PASS: ${language} no-consent/refusal/reload, consent once, 3 exact download events, native downloads, withdrawal cookies, static language links`);
      await context.close();
    }
    const blocked = await browser.newContext();
    await blocked.route('https://www.googletagmanager.com/**', route => route.fulfill({ contentType: 'application/javascript', body: 'window.__gaTestLoaded = true;' }));
    await blocked.addInitScript(() => {
      Storage.prototype.getItem = () => { throw Error('blocked storage'); };
      Storage.prototype.setItem = () => { throw Error('blocked storage'); };
    });
    const blockedPage = await blocked.newPage();
    await blockedPage.goto(url);
    await blockedPage.locator('[data-consent-reject]').click();
    await blockedPage.locator('.site-footer [data-analytics-settings]').click();
    await blockedPage.locator('[data-consent-accept]').click();
    await blockedPage.waitForFunction(() => window.__gaTestLoaded);
    assert.equal(await blockedPage.evaluate(() => window.dataLayer.filter(item => item[0] === 'config').length), 1);
    await Promise.all([blockedPage.waitForEvent('load'), blockedPage.locator('.site-footer [data-analytics-settings]').click().then(() => blockedPage.locator('[data-consent-reject]').click())]);
    await blockedPage.waitForLoadState('networkidle');
    assert.equal(await blockedPage.evaluate(() => window.dataLayer?.filter(item => item[0] === 'config').length || 0), 0);
    assert.equal(await blockedPage.locator('[data-analytics-consent]').isVisible(), true, 'Unavailable storage resets to no consent after withdrawal reload');
    assert.equal(await blockedPage.evaluate(() => window.__gaTestLoaded), undefined);
    await blocked.close();

    const shared = await browser.newContext();
    let sharedRequests = 0;
    await shared.route('https://www.googletagmanager.com/**', route => {
      sharedRequests++;
      return route.fulfill({ contentType: 'application/javascript', body: 'window.__gaTestLoaded = true;' });
    });
    const firstTab = await shared.newPage();
    const secondTab = await shared.newPage();
    await firstTab.goto(url);
    await secondTab.goto(url + '/zh/');
    assert.equal(sharedRequests, 0);
    await firstTab.locator('[data-consent-accept]').click();
    await firstTab.waitForFunction(() => window.__gaTestLoaded);
    await secondTab.waitForFunction(() => window.__gaTestLoaded);
    assert.equal(sharedRequests, 2, 'Cross-tab consent initializes each page once');
    await secondTab.evaluate(() => { document.cookie = '_ga=cross-tab; Path=/'; document.cookie = '_ga_JDBTS8BRKT=cross-tab; Path=/'; });
    await firstTab.locator('.site-footer [data-analytics-settings]').click();
    await Promise.all([
      firstTab.waitForEvent('load'), secondTab.waitForEvent('load'),
      firstTab.locator('[data-consent-reject]').click(),
    ]);
    await Promise.all([firstTab.waitForLoadState('networkidle'), secondTab.waitForLoadState('networkidle')]);
    assert.equal(sharedRequests, 2, 'Cross-tab withdrawal reloads with zero new tag requests');
    for (const tab of [firstTab, secondTab]) {
      assert.equal(await tab.evaluate(k => localStorage.getItem(k), key), 'denied');
      assert.equal(await tab.evaluate(() => window.dataLayer?.length || 0), 0);
      assert.equal(await tab.evaluate(() => window.__gaTestLoaded), undefined);
    }
    assert(!(await shared.cookies()).some(cookie => cookie.name.startsWith('_ga')));
    await shared.close();
    console.log('PASS: cross-tab consent and withdrawal stop both pages; blocked-storage withdrawal reload resets to zero analytics');
    const noJs = await browser.newContext({ javaScriptEnabled: false });
    for (const [suffix, expected] of [['/', 'Synced lyrics for your Mac desktop and menu bar.'], ['/zh/', '在 Mac 桌面或菜单栏查看同步歌词']]) {
      const page = await noJs.newPage();
      const response = await page.goto(url + suffix);
      assert.equal(response.status(), 200);
      assert.equal(await page.locator('h1').innerText(), expected);
      assert.equal(await page.locator('.faq details').count(), 7);
      assert(await page.locator('#language-toggle').getAttribute('href'));
      await page.close();
    }
    await noJs.close();
    console.log('PASS: blocked storage consent works; JavaScript-disabled bilingual H1/FAQ/links remain readable');
  } finally { await browser.close(); }
})().catch(error => { console.error(error); process.exitCode = 1; });
