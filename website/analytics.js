(() => {
  if (window.notchMuseAnalyticsInitialized) return;
  window.notchMuseAnalyticsInitialized = true;
  const measurementId = 'G-JDBTS8BRKT';
  const storageKey = 'notchmuse.analytics-consent';
  const disableKey = `ga-disable-${measurementId}`;
  const banner = document.querySelector('[data-analytics-consent]');
  const close = document.querySelector('[data-consent-close]');
  const chinese = document.documentElement.lang === 'zh-Hans';
  let choice;
  let started = false;
  let tag;
  let settingsTrigger;
  try { choice = localStorage.getItem(storageKey); } catch {}
  if (!['granted', 'denied'].includes(choice)) choice = null;
  window[disableKey] = true;

  const update = () => {
    const status = chinese
      ? { granted: '当前选择：已同意统计。', denied: '当前选择：已拒绝统计。', unknown: '当前选择：尚未同意，统计关闭。' }
      : { granted: 'Current choice: analytics allowed.', denied: 'Current choice: analytics rejected.', unknown: 'Current choice: not agreed; analytics is off.' };
    document.querySelectorAll('[data-analytics-status]').forEach(element => {
      element.textContent = status[choice || 'unknown'];
    });
    banner.hidden = choice !== null;
    close.hidden = choice === null;
  };

  const load = () => {
    if (started || choice !== 'granted') return;
    started = true;
    window[disableKey] = false;
    window.dataLayer = window.dataLayer || [];
    window.gtag = function () { window.dataLayer.push(arguments); };
    window.gtag('consent', 'default', {
      analytics_storage: 'denied', ad_storage: 'denied',
      ad_user_data: 'denied', ad_personalization: 'denied',
    });
    window.gtag('consent', 'update', { analytics_storage: 'granted' });
    window.gtag('js', new Date());
    window.gtag('config', measurementId, {
      allow_google_signals: false, allow_ad_personalization_signals: false,
    });
    tag = document.createElement('script');
    tag.async = true;
    tag.src = `https://www.googletagmanager.com/gtag/js?id=${measurementId}`;
    document.head.appendChild(tag);
  };

  const clearAnalyticsCookies = () => {
    const domains = new Set(['', location.hostname, `.${location.hostname}`]);
    if (location.hostname.endsWith('.notchmuse.com')) domains.add('.notchmuse.com');
    document.cookie.split(';').forEach(cookie => {
      const name = cookie.split('=')[0].trim();
      if (!/^(_ga(?:_|$)|_gid$|_gat(?:_|$))/.test(name)) return;
      domains.forEach(domain => {
        document.cookie = `${name}=; Max-Age=0; Path=/;${domain ? ` Domain=${domain};` : ''}`;
      });
    });
  };

  const choose = next => {
    choice = next;
    try { localStorage.setItem(storageKey, choice); } catch {}
    if (choice === 'granted') load();
    else {
      // Removing a script element cannot unload executed JavaScript. Disable
      // sending immediately, then reload with the saved refusal to discard it.
      window[disableKey] = true;
      tag?.remove();
      if (window.dataLayer) window.dataLayer.length = 0;
      clearAnalyticsCookies();
      if (started) { location.reload(); return; }
    }
    update();
    settingsTrigger?.focus();
  };

  document.querySelector('[data-consent-accept]').addEventListener('click', () => choose('granted'));
  document.querySelector('[data-consent-reject]').addEventListener('click', () => choose('denied'));
  document.querySelectorAll('[data-analytics-settings]').forEach(button => {
    button.hidden = false;
    button.addEventListener('click', () => {
      settingsTrigger = button;
      banner.hidden = false;
      close.hidden = choice === null;
      document.querySelector('[data-consent-reject]').focus();
    });
  });
  close.addEventListener('click', () => { banner.hidden = true; settingsTrigger?.focus(); });
  window.addEventListener('storage', event => {
    if (event.key === storageKey && event.newValue !== choice) {
      choose(event.newValue === 'granted' ? 'granted' : 'denied');
    }
  });
  document.addEventListener('click', event => {
    if (choice !== 'granted' || window[disableKey]) return;
    const link = event.target.closest('a[data-download-placement]');
    if (!link || !['nav', 'hero', 'footer'].includes(link.dataset.downloadPlacement)) return;
    const url = new URL(link.href);
    const version = url.pathname.match(/\/releases\/download\/v([^/]+)\/NotchMuse\.dmg$/)?.[1];
    if (url.origin !== 'https://github.com' || !version) return;
    window.gtag('event', 'download_click', {
      app_version: version, placement: link.dataset.downloadPlacement,
      page_language: document.documentElement.lang,
    });
  });
  update();
  if (choice === 'granted') load();
  else if (choice === 'denied') clearAnalyticsCookies();
})();
