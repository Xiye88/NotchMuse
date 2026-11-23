(() => {
  const init = () => {
    const form = document.getElementById('lyrics-search-form');
    const input = document.getElementById('lyrics-search-input');
    const searchBtn = document.getElementById('lyrics-search-btn');
    const statusEl = document.getElementById('lyrics-status');
    const workspace = document.getElementById('lyrics-workspace');
    const resultsList = document.getElementById('lyrics-results-list');
    const previewContainer = document.getElementById('lyrics-preview-container');
    const previewTitle = document.getElementById('lyrics-preview-title');
    const previewText = document.getElementById('lyrics-preview-text');
    const downloadLrcBtn = document.getElementById('lyrics-download-lrc-btn');
    const downloadTxtBtn = document.getElementById('lyrics-download-txt-btn');
    const copyBtn = document.getElementById('lyrics-copy-btn');
    if (!form || !input || !resultsList || !previewContainer) return;

    const zh = document.documentElement.lang === 'zh-Hans';
    const copy = zh
      ? {
          searching: '正在检索公共社区歌词库...',
          empty: '未找到相关歌词。请检查拼写或尝试加入歌手名重新搜索。',
          error: '暂时无法连接公共歌词库，请稍后重试。',
          found: n => `找到 ${n} 条结果，点击曲目查看并下载歌词：`,
          synced: '时间轴同步 .LRC',
          plain: '纯文本 .TXT',
          instrumental: '纯音乐',
          noLyricsText: '该条目为纯音乐或暂无歌词文本。',
          copyDefault: '复制歌词',
          copied: '已复制 ✓',
        }
      : {
          searching: 'Searching community lyrics database...',
          empty: 'No lyrics found for this query. Check spelling or try searching with artist name.',
          error: 'Could not reach the community lyrics database right now. Please try again.',
          found: n => `Found ${n} results. Select a track to preview and download:`,
          synced: 'Synced .LRC',
          plain: 'Plain Text',
          instrumental: 'Instrumental',
          noLyricsText: 'This entry is marked instrumental or has no lyric text.',
          copyDefault: 'Copy',
          copied: 'Copied ✓',
        };

    let selectedTrack = null;

    const norm = s => String(s || '').trim().toLowerCase();

    const dedupeMeta = (trackName, artistName, albumName) => {
      const seen = new Set();
      const out = [];
      for (const part of [trackName, artistName, albumName]) {
        const clean = String(part || '').trim();
        if (!clean) continue;
        const key = norm(clean);
        if (seen.has(key)) continue;
        seen.add(key);
        out.push(clean);
      }
      return out;
    };

    const formatDuration = seconds => {
      if (typeof seconds !== 'number' || !Number.isFinite(seconds) || seconds <= 0) return '';
      const total = Math.round(seconds);
      const mins = Math.floor(total / 60);
      const secs = String(total % 60).padStart(2, '0');
      return `${mins}:${secs}`;
    };

    const sanitizeFilename = name =>
      String(name || 'lyrics')
        .replace(/[\\/:*?"<>|\x00-\x1f]/g, '_')
        .replace(/\s+/g, ' ')
        .trim()
        .slice(0, 120) || 'lyrics';

    const triggerDownload = (content, ext) => {
      if (!selectedTrack || !content) return;
      const track = String(selectedTrack.trackName || selectedTrack.name || 'lyrics').trim();
      const artist = String(selectedTrack.artistName || '').trim();
      const base = sanitizeFilename(artist && norm(artist) !== norm(track) ? `${artist} - ${track}` : track);
      const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      a.download = `${base}.${ext}`;
      document.body.appendChild(a);
      a.click();
      a.remove();
      setTimeout(() => URL.revokeObjectURL(url), 1000);
    };

    const stripTimestamps = lrc =>
      String(lrc || '')
        .replace(/\[\d{1,2}:\d{2}(?:\.\d{1,3})?\]\s*/g, '')
        .trim();

    const selectTrack = (track, buttonEl) => {
      selectedTrack = track;
      resultsList.querySelectorAll('.lyrics-result-item').forEach(btn => {
        btn.setAttribute('aria-selected', btn === buttonEl ? 'true' : 'false');
      });
      const title = String(track.trackName || track.name || 'Unknown Track').trim();
      const artist = String(track.artistName || '').trim();
      const album = String(track.albumName || '').trim();
      const showArtist = artist && norm(artist) !== norm(title);
      const showAlbum = album && norm(album) !== norm(title) && norm(album) !== norm(artist);
      previewTitle.textContent =
        (showArtist ? `${title} — ${artist}` : title) + (showAlbum ? ` (${album})` : '');
      const displayContent = track.syncedLyrics || track.plainLyrics || '';
      previewText.textContent = displayContent || copy.noLyricsText;
      downloadLrcBtn.disabled = !track.syncedLyrics;
      downloadTxtBtn.disabled = !(track.plainLyrics || track.syncedLyrics);
      if (copyBtn) {
        copyBtn.disabled = !displayContent;
        copyBtn.textContent = copy.copyDefault;
      }
      previewContainer.hidden = false;
    };

    const renderResults = items => {
      resultsList.textContent = '';
      selectedTrack = null;
      if (!Array.isArray(items) || items.length === 0) {
        if (workspace) workspace.hidden = true;
        previewContainer.hidden = true;
        statusEl.textContent = copy.empty;
        return;
      }
      statusEl.textContent = copy.found(items.length);
      if (workspace) workspace.hidden = false;

      let firstSelectable = null;
      const rendered = [];
      items.slice(0, 20).forEach(item => {
        const btn = document.createElement('button');
        btn.type = 'button';
        btn.className = 'lyrics-result-item';
        btn.setAttribute('role', 'option');
        btn.setAttribute('aria-selected', 'false');

        const title = String(item.trackName || item.name || 'Unknown Track').trim();
        const titleEl = document.createElement('span');
        titleEl.className = 'lyrics-result-title';
        titleEl.textContent = title;

        const [, ...restMeta] = dedupeMeta(title, item.artistName, item.albumName);
        const dur = formatDuration(item.duration);
        if (dur) restMeta.push(dur);
        const metaEl = document.createElement('span');
        metaEl.className = 'lyrics-result-meta';
        metaEl.textContent = restMeta.join(' · ');

        const badgesEl = document.createElement('span');
        badgesEl.className = 'lyrics-badges';
        if (item.syncedLyrics) {
          const b = document.createElement('span');
          b.className = 'badge badge-synced';
          b.textContent = copy.synced;
          badgesEl.appendChild(b);
        }
        if (item.plainLyrics) {
          const b = document.createElement('span');
          b.className = 'badge badge-plain';
          b.textContent = copy.plain;
          badgesEl.appendChild(b);
        }
        if (item.instrumental && !item.syncedLyrics && !item.plainLyrics) {
          const b = document.createElement('span');
          b.className = 'badge badge-plain';
          b.textContent = copy.instrumental;
          badgesEl.appendChild(b);
        }

        btn.append(titleEl);
        if (restMeta.length) btn.append(metaEl);
        btn.append(badgesEl);
        btn.addEventListener('click', () => selectTrack(item, btn));
        resultsList.appendChild(btn);
        rendered.push({ item, btn });

        if (!firstSelectable && (item.syncedLyrics || item.plainLyrics)) {
          firstSelectable = { item, btn };
        }
      });

      resultsList.onkeydown = event => {
        if (event.key !== 'ArrowDown' && event.key !== 'ArrowUp') return;
        const idx = rendered.findIndex(r => r.btn.getAttribute('aria-selected') === 'true');
        if (idx === -1) return;
        event.preventDefault();
        const nextIdx = event.key === 'ArrowDown'
          ? Math.min(rendered.length - 1, idx + 1)
          : Math.max(0, idx - 1);
        const target = rendered[nextIdx];
        selectTrack(target.item, target.btn);
        target.btn.focus();
      };

      if (firstSelectable) {
        selectTrack(firstSelectable.item, firstSelectable.btn);
      } else if (rendered[0]) {
        selectTrack(rendered[0].item, rendered[0].btn);
      }
    };

    const runSearch = async () => {
      const q = input.value.trim();
      if (!q) {
        input.focus();
        return;
      }
      statusEl.textContent = copy.searching;
      if (searchBtn) searchBtn.disabled = true;
      try {
        const res = await fetch(`https://lrclib.net/api/search?q=${encodeURIComponent(q)}`, {
          headers: { Accept: 'application/json' },
        });
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        const data = await res.json();
        renderResults(data);
      } catch {
        if (workspace) workspace.hidden = true;
        previewContainer.hidden = true;
        statusEl.textContent = copy.error;
      } finally {
        if (searchBtn) searchBtn.disabled = false;
      }
    };

    form.addEventListener('submit', event => {
      event.preventDefault();
      runSearch();
    });

    document.querySelectorAll('.example-chip[data-query]').forEach(chip => {
      chip.addEventListener('click', () => {
        input.value = chip.dataset.query || '';
        runSearch();
      });
    });

    downloadLrcBtn.addEventListener('click', () => {
      if (selectedTrack?.syncedLyrics) {
        triggerDownload(selectedTrack.syncedLyrics, 'lrc');
      }
    });

    downloadTxtBtn.addEventListener('click', () => {
      if (!selectedTrack) return;
      const txt = selectedTrack.plainLyrics || stripTimestamps(selectedTrack.syncedLyrics);
      if (txt) triggerDownload(txt, 'txt');
    });

    copyBtn?.addEventListener('click', async () => {
      if (!selectedTrack) return;
      const text = selectedTrack.syncedLyrics || selectedTrack.plainLyrics;
      if (!text) return;
      try {
        await navigator.clipboard.writeText(text);
        copyBtn.textContent = copy.copied;
        setTimeout(() => { copyBtn.textContent = copy.copyDefault; }, 1500);
      } catch {}
    });
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
