(function () {
  var radioZh = document.getElementById('lang-zh');
  var radioEn = document.getElementById('lang-en');
  if (!radioZh || !radioEn) return;

  function setLang(lang) {
    var isZh = lang === 'zh';
    radioZh.checked = isZh;
    radioEn.checked = !isZh;
    document.documentElement.lang = isZh ? 'zh-Hans' : 'en';
  }

  var q = new URLSearchParams(location.search).get('lang') || location.hash.replace('#', '');
  if (q === 'zh' || q === 'en') {
    setLang(q);
    return;
  }
  var nav = (navigator.language || 'en').toLowerCase();
  setLang(nav.startsWith('zh') ? 'zh' : 'en');
})();
