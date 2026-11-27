(() => {
  'use strict';

  const motion = matchMedia('(prefers-reduced-motion: reduce)');
  const isZh = document.documentElement.lang.toLowerCase().startsWith('zh');
  const soundKey = 'notchmuse.website.sound';
  let soundOn = true;
  let audio;
  try { soundOn = localStorage.getItem(soundKey) !== 'off'; } catch {}

  // Short oscillator envelopes adapted from the Bencho sound gestures.
  const sounds = {
    tick: [[196, 130, 80, .07]],
    step: [[227, 114, 115, .07]],
    dial: [[620, 890, 34, .043, 0, 'triangle']],
    plop: [[480, 300, 55, .064], [600, 900, 60, .025, 12]],
    landed: [[330, 510, 75, .04], [784, 784, 95, .04, 46], [1047, 1047, 120, .037, 90]],
    bump: [[208, 165, 105, .065]],
    latch: [[256, 176, 58, .045, 0, 'triangle']],
    hush: [[330, 247, 88, .055]]
  };

  function prepareSound(event) {
    if (!soundOn || !event?.isTrusted) return false;
    const Audio = window.AudioContext || window.webkitAudioContext;
    if (!Audio) return false;
    try {
      audio ??= new Audio();
      if (audio.state !== 'running') audio.resume().catch(() => {});
    } catch { return false; }
    return true;
  }

  function play(name, event) {
    if (!prepareSound(event)) return;
    const volume = .32;
    const now = audio.currentTime;
    for (const [from, to, duration, level, delay = 0, type = 'sine'] of sounds[name]) {
      const start = now + delay / 1000;
      const end = start + duration / 1000;
      const oscillator = audio.createOscillator();
      const gain = audio.createGain();
      oscillator.type = type;
      oscillator.frequency.setValueAtTime(from, start);
      oscillator.frequency.exponentialRampToValueAtTime(to, end);
      gain.gain.setValueAtTime(.0001, start);
      gain.gain.exponentialRampToValueAtTime(level * volume, start + .006);
      gain.gain.exponentialRampToValueAtTime(.0001, end);
      oscillator.connect(gain).connect(audio.destination);
      oscillator.start(start);
      oscillator.stop(end);
    }
  }

  const soundNav = document.querySelector('.site-footer nav');
  if (soundNav) {
    const toggle = document.createElement('button');
    toggle.type = 'button';
    toggle.className = 'footer-link-btn bencho-sound-toggle';
    toggle.setAttribute('aria-label', isZh ? '交互音效' : 'Interaction sound');
    function renderSound() {
      toggle.setAttribute('aria-pressed', String(soundOn));
      toggle.textContent = isZh ? (soundOn ? '音效：开' : '音效：关') : (soundOn ? 'Sound On' : 'Sound Off');
    }
    toggle.addEventListener('click', event => {
      if (soundOn) play('hush', event);
      soundOn = !soundOn;
      renderSound();
      if (soundOn) play('tick', event);
      try { localStorage.setItem(soundKey, soundOn ? 'on' : 'off'); } catch {}
    });
    renderSound();
    soundNav.append(toggle);
  }

  document.addEventListener('click', event => {
    const button = event.target.closest('.button');
    // LRC exports use their result sound in place of the CTA sound.
    if (button && !button.matches('[id$="-download"]')) play('latch', event);
  });

  for (const group of document.querySelectorAll('.demo-tabs, .lrc-tabs')) {
    const pill = document.createElement('span');
    pill.className = 'bencho-tab-pill is-init';
    pill.setAttribute('aria-hidden', 'true');
    function alignPill() {
      const tab = group.querySelector('[aria-selected="true"]');
      if (!tab) return;
      pill.style.width = tab.offsetWidth + 'px';
      pill.style.height = tab.offsetHeight + 'px';
      pill.style.transform = `translate(${tab.offsetLeft}px, ${tab.offsetTop}px)`;
    }
    group.prepend(pill);
    group.classList.add('bencho-tabs');
    alignPill();
    requestAnimationFrame(() => pill.classList.remove('is-init'));
    new MutationObserver(alignPill).observe(group, { subtree: true, attributeFilter: ['aria-selected'] });
    const resize = new ResizeObserver(alignPill);
    group.querySelectorAll('[role="tab"]').forEach(tab => resize.observe(tab));
  }

  const canTilt = matchMedia('(hover: hover) and (pointer: fine)');
  for (const card of document.querySelectorAll('.mode-card, .workflow-step')) {
    card.addEventListener('pointermove', event => {
      if (motion.matches || !canTilt.matches || event.pointerType !== 'mouse') return;
      const rect = card.getBoundingClientRect();
      const clamp = value => Math.max(-.5, Math.min(.5, value));
      const x = clamp((event.clientX - rect.left) / rect.width - .5);
      const y = clamp((event.clientY - rect.top) / rect.height - .5);
      card.style.setProperty('--bencho-tilt-axis', `${-y}, ${x}, 0`);
      card.style.setProperty('--bencho-tilt-angle', `${Math.min(Math.hypot(x, y) * 3.5, 2.5)}deg`);
      card.classList.add('bencho-tilting');
    });
    const resetTilt = () => card.classList.remove('bencho-tilting');
    card.addEventListener('pointerleave', resetTilt);
    card.addEventListener('pointercancel', resetTilt);
    motion.addEventListener('change', resetTilt);
    canTilt.addEventListener('change', resetTilt);
  }

  const shift = document.getElementById('shift-amount');
  const toastStack = document.createElement('div');
  if (shift) {
    toastStack.className = 'bencho-toast-stack';
    toastStack.setAttribute('aria-live', 'polite');
    document.body.append(toastStack);
  }
  function toast(message) {
    while (toastStack.childElementCount >= 3) toastStack.firstElementChild.remove();
    const pill = document.createElement('div');
    pill.className = 'bencho-toast';
    toastStack.append(pill);
    pill.textContent = message;
    setTimeout(() => {
      pill.classList.add('is-leaving');
      setTimeout(() => pill.remove(), 190);
    }, 2400);
  }

  function shake(button) {
    if (motion.matches) return;
    button.animate([
      { translate: '0' }, { translate: '-4px' }, { translate: '3px' },
      { translate: '-2px' }, { translate: '0' }
    ], { duration: 210, easing: 'ease-out' });
  }

  if (shift) {
    const unit = document.getElementById('shift-unit');
    let drag;
    let lastDial = -Infinity;
    shift.addEventListener('pointerdown', event => {
      if (!event.isPrimary || event.button !== 0) return;
      // Keep native number steppers usable on mouse input.
      if (event.pointerType === 'mouse' && shift.getBoundingClientRect().right - event.clientX < 22) return;
      prepareSound(event);
      drag = { id: event.pointerId, x: event.clientX, value: shift.valueAsNumber || 0 };
    });
    window.addEventListener('pointermove', event => {
      if (drag?.id !== event.pointerId) return;
      const steps = Math.trunc((event.clientX - drag.x) / 9);
      if (!steps && !shift.classList.contains('is-scrubbing')) return;
      if (!shift.hasPointerCapture(drag.id)) shift.setPointerCapture(drag.id);
      shift.classList.add('is-scrubbing');
      const seconds = unit.value === 's';
      const value = Number((drag.value + steps * (seconds ? .1 : 50)).toFixed(seconds ? 3 : 0));
      if (value === shift.valueAsNumber) return;
      shift.value = value;
      shift.dispatchEvent(new Event('input', { bubbles: true }));
      if (event.timeStamp - lastDial >= 65) {
        lastDial = event.timeStamp;
        play('dial', event);
      }
    });
    const stopScrub = event => {
      if (drag?.id !== event.pointerId) return;
      drag = undefined;
      shift.classList.remove('is-scrubbing');
    };
    for (const type of ['pointerup', 'pointercancel', 'lostpointercapture']) {
      window.addEventListener(type, stopScrub);
    }
  }

  window.benchoUX = { play, prepareSound, toast, shake, motion };
})();
