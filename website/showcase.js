(() => {
  const motion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const demos = [...document.querySelectorAll('[data-demo]')];
  const visible = new Set();
  const tabs = [...document.querySelectorAll('[data-demo-tab]')];

  const sync = demo => {
    const video = demo.querySelector('video');
    const active = visible.has(demo) && !demo.closest('[hidden]') && !document.hidden && !motion.matches;
    video.autoplay = active;
    if (!active) {
      video.pause();
      demo.classList.remove('is-playing');
      return;
    }
    if (!video.dataset.loaded) {
      video.querySelectorAll('source').forEach(source => { source.src = source.dataset.src; });
      video.dataset.loaded = 'true';
      video.load();
    }
    video.play().catch(() => { demo.classList.remove('is-playing'); });
  };

  demos.forEach(demo => {
    const video = demo.querySelector('video');
    // Set the DOM property as well as the attribute for Safari autoplay.
    video.muted = true;
    video.addEventListener('playing', () => {
      if (!motion.matches && !demo.closest('[hidden]')) demo.classList.add('is-playing');
    });
    video.addEventListener('error', () => { demo.classList.remove('is-playing'); });
  });

  const select = tab => {
    tabs.forEach(item => {
      const selected = item === tab;
      item.setAttribute('aria-selected', String(selected));
      item.tabIndex = selected ? 0 : -1;
      const panel = document.getElementById(item.getAttribute('aria-controls'));
      panel.hidden = !selected;
      // Tab clicks should play immediately without waiting for the observer.
      const demo = panel.querySelector('[data-demo]');
      const bounds = panel.getBoundingClientRect();
      if (selected && bounds.bottom > 0 && bounds.top < window.innerHeight) visible.add(demo);
      else visible.delete(demo);
      sync(demo);
    });
  };
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => select(tab));
    tab.addEventListener('keydown', event => {
      let next;
      if (event.key === 'ArrowRight') next = tabs[(index + 1) % tabs.length];
      if (event.key === 'ArrowLeft') next = tabs[(index + tabs.length - 1) % tabs.length];
      if (event.key === 'Home') next = tabs[0];
      if (event.key === 'End') next = tabs[tabs.length - 1];
      if (!next) return;
      event.preventDefault();
      select(next);
      next.focus();
    });
  });

  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) visible.add(entry.target);
      else visible.delete(entry.target);
      sync(entry.target);
    });
  }, { threshold: 0.05 });
  demos.forEach(demo => observer.observe(demo));
  motion.addEventListener('change', () => demos.forEach(sync));
  document.addEventListener('visibilitychange', () => demos.forEach(sync));
})();
