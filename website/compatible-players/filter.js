(function () {
  'use strict';

  var buttons = Array.prototype.slice.call(document.querySelectorAll('[data-player-filter]'));
  var cards = Array.prototype.slice.call(document.querySelectorAll('[data-player-card]'));
  var countEl = document.getElementById('player-count-status');
  if (!buttons.length || !cards.length) return;

  var isZh = (document.documentElement.lang || '').toLowerCase().indexOf('zh') === 0;

  function applyFilter(filterKey) {
    var shown = 0;
    cards.forEach(function (card) {
      var tags = (card.getAttribute('data-tags') || '').split(/\s+/);
      var match = filterKey === 'all' || tags.indexOf(filterKey) !== -1;
      card.hidden = !match;
      if (match) shown++;
    });

    buttons.forEach(function (btn) {
      var active = btn.getAttribute('data-player-filter') === filterKey;
      btn.setAttribute('aria-pressed', active ? 'true' : 'false');
    });

    if (countEl) {
      countEl.textContent = isZh
        ? '当前显示 ' + shown + ' / ' + cards.length + ' 款兼容播放器'
        : 'Showing ' + shown + ' of ' + cards.length + ' compatible players';
    }
  }

  buttons.forEach(function (btn) {
    btn.addEventListener('click', function () {
      applyFilter(btn.getAttribute('data-player-filter') || 'all');
    });
  });

  // If user arrives via #anchor, ensure all cards are visible so target is never hidden
  if (window.location.hash) {
    applyFilter('all');
  } else {
    applyFilter('all');
  }
})();
