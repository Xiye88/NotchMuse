(function () {
  function setLang(lang) {
    var isZh = lang === 'zh';
    var panelZh = document.getElementById('panel-zh');
    var panelEn = document.getElementById('panel-en');
    var btnZh = document.getElementById('btn-zh');
    var btnEn = document.getElementById('btn-en');
    if (panelZh) panelZh.classList.toggle('hidden', !isZh);
    if (panelEn) panelEn.classList.toggle('hidden', isZh);
    if (btnZh) btnZh.classList.toggle('active', isZh);
    if (btnEn) btnEn.classList.toggle('active', !isZh);
    document.documentElement.lang = isZh ? 'zh-Hans' : 'en';
  }

  var btnZh = document.getElementById('btn-zh');
  var btnEn = document.getElementById('btn-en');
  if (btnZh) btnZh.addEventListener('click', function () { setLang('zh'); });
  if (btnEn) btnEn.addEventListener('click', function () { setLang('en'); });

  var q = new URLSearchParams(location.search).get('lang') || location.hash.replace('#', '');
  if (q === 'zh' || q === 'en') {
    setLang(q);
    return;
  }
  var nav = (navigator.language || 'en').toLowerCase();
  setLang(nav.startsWith('zh') ? 'zh' : 'en');
})();
