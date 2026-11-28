(() => {
  'use strict';

  const buttons = [...document.querySelectorAll('[data-player-filter]')];
  const cards = [...document.querySelectorAll('[data-player-card]')];
  if (!buttons.length || !cards.length) return;

  const search = document.getElementById('player-search-input');
  const seek = search.closest('.bencho-seek');
  const count = document.getElementById('player-count-value');
  const status = document.getElementById('player-count-status');
  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  const isZh = document.documentElement.lang.toLowerCase().startsWith('zh');
  const normalize = text => text.normalize('NFKC').toLowerCase();
  const entries = cards.map(card => ({
    card,
    tags: card.dataset.tags.split(/\s+/),
    searchText: normalize([
      card.querySelector('h3').textContent,
      card.querySelector('.player-card-cat')?.textContent,
      card.dataset.tags,
      card.id.replace(/-/g, ' ')
    ].join(' '))
  }));
  let filterKey = 'all';
  let previousCount = cards.length;
  let counterAnimations = [];

  function updateCount(shown) {
    if (previousCount === shown) return;
    const from = previousCount;
    const direction = Math.sign(shown - from);
    for (const animation of counterAnimations) animation.cancel();
    count.textContent = shown;
    status.textContent = isZh
      ? '当前显示 ' + shown + ' / ' + cards.length + ' 款兼容播放器'
      : 'Showing ' + shown + ' of ' + cards.length + ' compatible players';
    previousCount = shown;
    if (motion.matches) return;

    const outgoing = document.createElement('span');
    const incoming = document.createElement('span');
    outgoing.className = 'bencho-count-outgoing';
    outgoing.textContent = from;
    incoming.textContent = shown;
    count.replaceChildren(outgoing, incoming);
    const timing = { duration: 220, easing: 'cubic-bezier(.2,.7,.3,1)' };
    const exit = outgoing.animate([
      { transform: 'translateY(0)' },
      { transform: `translateY(${-direction * 100}%)`, opacity: 0 }
    ], timing);
    exit.onfinish = exit.oncancel = () => outgoing.remove();
    counterAnimations = [exit, incoming.animate([
      { transform: `translateY(${direction * 100}%)`, opacity: 0 },
      { transform: 'translateY(0)', opacity: 1 }
    ], timing)];
  }

  const fades = new Map();
  function applyFilter() {
    const words = normalize(search.value).trim().split(/\s+/).filter(Boolean);
    seek.classList.toggle('has-query', Boolean(search.value));
    const matches = new Set(entries.filter(({ tags, searchText }) =>
      (filterKey === 'all' || tags.includes(filterKey)) && words.every(word => searchText.includes(word))
    ).map(({ card }) => card));
    const changed = cards.some(card => card.hidden === matches.has(card));
    if (changed) {
      for (const card of cards) {
        fades.get(card)?.cancel();
        card.hidden = !matches.has(card);
        if (!card.hidden && !motion.matches) {
          const fade = card.animate([{ opacity: .55 }, { opacity: 1 }], { duration: 140, easing: 'ease-out' });
          fades.set(card, fade);
          fade.onfinish = fade.oncancel = () => {
            if (fades.get(card) === fade) fades.delete(card);
          };
        }
      }
    }
    updateCount(matches.size);
  }

  for (const button of buttons) {
    button.addEventListener('click', event => {
      if (filterKey === button.dataset.playerFilter) return;
      filterKey = button.dataset.playerFilter;
      for (const chip of buttons) chip.setAttribute('aria-pressed', String(chip === button));
      window.benchoUX?.play('step', event);
      applyFilter();
    });
  }
  search.addEventListener('input', applyFilter);
  search.addEventListener('keydown', event => {
    if (event.key !== 'Escape' || event.isComposing) return;
    if (search.value) {
      event.preventDefault();
      search.value = '';
      applyFilter();
    } else {
      search.blur();
    }
  });
  motion.addEventListener('change', () => {
    if (!motion.matches) return;
    for (const animation of counterAnimations) animation.cancel();
    for (const fade of fades.values()) fade.cancel();
  });
  seek.classList.add('bencho-seek-ready');
  applyFilter();
})();
