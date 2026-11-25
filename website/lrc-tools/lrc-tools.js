(function () {
  'use strict';

  var SAMPLE_LRC_EN = [
    '[ti:Midnight Harbor (Original Demo)]',
    '[ar:NotchMuse Studio]',
    '[al:Local Browser Sample]',
    '[00:00.50]Lantern light across the quiet bay',
    '[00:04.20]Footsteps echo down the wooden pier',
    '[00:08.10]Every chorus finds its steady pace',
    '[00:12.40]Softly glowing while you work right here',
    '[00:16.80]Keep the rhythm floating out of sight',
    '[00:21.00]Simple lines aligned from start to end'
  ].join('\n');

  var SAMPLE_LRC_ZH = [
    '[ti:午夜港湾（原创演示）]',
    '[ar:NotchMuse Studio]',
    '[al:纯本地浏览器示例]',
    '[00:00.50]微光照亮安静的港湾水面',
    '[00:04.20]脚步声轻轻回荡在木质码头',
    '[00:08.10]每一句旋律都踩准自己的节拍',
    '[00:12.40]专注工作时歌词也在视野边缘',
    '[00:16.80]让节奏自然融入日常的屏幕里',
    '[00:21.00]简洁的时间轴从头到尾稳稳对齐'
  ].join('\n');

  var SAMPLE_SRT_EN = [
    '1',
    '00:00:00,500 --> 00:00:04,200',
    'Lantern light across the quiet bay',
    '',
    '2',
    '00:00:04,200 --> 00:00:08,100',
    'Footsteps echo down the wooden pier',
    '',
    '3',
    '00:00:08,100 --> 00:00:12,400',
    'Every chorus finds its steady pace'
  ].join('\n');

  var TIME_TAG_RE = /\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]/g;
  var META_LINE_RE = /^\s*\[(?:ti|ar|al|by|offset|re|ve|length):[^\]]*\]\s*$/i;

  function pad2(n) {
    return String(Math.floor(n)).padStart(2, '0');
  }

  function pad3(n) {
    return String(Math.floor(n)).padStart(3, '0');
  }

  function parseTagMs(minStr, secStr, fracStr) {
    var m = parseInt(minStr, 10) || 0;
    var s = parseInt(secStr, 10) || 0;
    var ms = 0;
    if (fracStr) {
      if (fracStr.length === 1) ms = parseInt(fracStr, 10) * 100;
      else if (fracStr.length === 2) ms = parseInt(fracStr, 10) * 10;
      else ms = parseInt(fracStr.slice(0, 3), 10);
    }
    return (m * 60 + s) * 1000 + ms;
  }

  function formatSrtTime(ms) {
    var clamped = Math.max(0, Math.round(ms));
    var hours = Math.floor(clamped / 3600000);
    var mins = Math.floor((clamped % 3600000) / 60000);
    var secs = Math.floor((clamped % 60000) / 1000);
    var millis = clamped % 1000;
    return pad2(hours) + ':' + pad2(mins) + ':' + pad2(secs) + ',' + pad3(millis);
  }

  function formatLrcTime(ms) {
    var clamped = Math.max(0, Math.round(ms));
    var mins = Math.floor(clamped / 60000);
    var secs = Math.floor((clamped % 60000) / 1000);
    var centis = Math.floor((clamped % 1000) / 10);
    return '[' + pad2(mins) + ':' + pad2(secs) + '.' + pad2(centis) + ']';
  }

  function parseLrcEntries(lrcText) {
    var lines = String(lrcText || '').replace(/\r\n?/g, '\n').split('\n');
    var entries = [];
    for (var i = 0; i < lines.length; i++) {
      var raw = lines[i];
      if (!raw.trim() || META_LINE_RE.test(raw)) continue;
      TIME_TAG_RE.lastIndex = 0;
      var tags = [];
      var match;
      while ((match = TIME_TAG_RE.exec(raw)) !== null) {
        tags.push(parseTagMs(match[1], match[2], match[3]));
      }
      if (!tags.length) continue;
      var text = raw.replace(TIME_TAG_RE, '').replace(/<\d{1,3}:\d{2}(?:[.:]\d{1,3})?>/g, '').trim();
      if (!text) continue;
      for (var j = 0; j < tags.length; j++) {
        entries.push({ timeMs: tags[j], text: text });
      }
    }
    entries.sort(function (a, b) { return a.timeMs - b.timeMs; });
    return entries;
  }

  function lrcToSrt(lrcText, lastDurationSec) {
    var durMs = Math.max(500, Math.round((Number(lastDurationSec) || 4) * 1000));
    var entries = parseLrcEntries(lrcText);
    if (!entries.length) return { srt: '', count: 0 };
    var blocks = [];
    for (var i = 0; i < entries.length; i++) {
      var start = entries[i].timeMs;
      var end = i + 1 < entries.length
        ? Math.max(start + 200, entries[i + 1].timeMs)
        : start + durMs;
      blocks.push(
        String(i + 1) + '\n' +
        formatSrtTime(start) + ' --> ' + formatSrtTime(end) + '\n' +
        entries[i].text
      );
    }
    return { srt: blocks.join('\n\n') + '\n', count: entries.length };
  }

  function shiftLrc(lrcText, offsetMs) {
    var delta = Math.round(Number(offsetMs) || 0);
    var lines = String(lrcText || '').replace(/\r\n?/g, '\n').split('\n');
    var shiftedCount = 0;
    var clampedCount = 0;
    var out = lines.map(function (line) {
      TIME_TAG_RE.lastIndex = 0;
      return line.replace(TIME_TAG_RE, function (_full, m, s, f) {
        shiftedCount++;
        var next = parseTagMs(m, s, f) + delta;
        if (next < 0) {
          clampedCount++;
          next = 0;
        }
        return formatLrcTime(next);
      });
    });
    return { lrc: out.join('\n'), shiftedCount: shiftedCount, clampedCount: clampedCount };
  }

  function srtToLrc(srtText) {
    var blocks = String(srtText || '').replace(/\r\n?/g, '\n').trim().split(/\n{2,}/);
    var out = [];
    var timeRe = /(\d{2}):(\d{2}):(\d{2})[,.](\d{3})\s*-->\s*(\d{2}):(\d{2}):(\d{2})[,.](\d{3})/;
    for (var i = 0; i < blocks.length; i++) {
      var lines = blocks[i].split('\n').map(function (s) { return s.trim(); }).filter(Boolean);
      if (!lines.length) continue;
      var timeIdx = -1;
      var match = null;
      for (var k = 0; k < lines.length; k++) {
        match = lines[k].match(timeRe);
        if (match) { timeIdx = k; break; }
      }
      if (timeIdx === -1 || !match) continue;
      var startMs =
        parseInt(match[1], 10) * 3600000 +
        parseInt(match[2], 10) * 60000 +
        parseInt(match[3], 10) * 1000 +
        parseInt(match[4], 10);
      var textLines = lines.slice(timeIdx + 1);
      var text = textLines.join(' ').replace(/<[^>]+>/g, '').trim();
      if (text) out.push(formatLrcTime(startMs) + text);
    }
    return { lrc: out.join('\n') + (out.length ? '\n' : ''), count: out.length };
  }

  function stripTimestamps(rawText) {
    var lines = String(rawText || '').replace(/\r\n?/g, '\n').split('\n');
    var out = [];
    var srtTimeLine = /^\s*\d{2}:\d{2}:\d{2}[,.]\d{3}\s*-->\s*\d{2}:\d{2}:\d{2}[,.]\d{3}/;
    var srtIndexLine = /^\s*\d+\s*$/;
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i];
      if (META_LINE_RE.test(line)) continue;
      if (srtTimeLine.test(line)) continue;
      if (srtIndexLine.test(line) && i + 1 < lines.length && srtTimeLine.test(lines[i + 1])) continue;
      var cleaned = line
        .replace(TIME_TAG_RE, '')
        .replace(/<\d{1,3}:\d{2}(?:[.:]\d{1,3})?>/g, '')
        .trim();
      if (cleaned) out.push(cleaned);
    }
    return { text: out.join('\n') + (out.length ? '\n' : ''), count: out.length };
  }

  if (typeof module !== 'undefined' && module.exports) {
    module.exports = { lrcToSrt: lrcToSrt, shiftLrc: shiftLrc, srtToLrc: srtToLrc, stripTimestamps: stripTimestamps };
  }

  if (typeof document === 'undefined') return;

  var isZh = (document.documentElement.lang || '').toLowerCase().indexOf('zh') === 0;
  var msg = isZh ? {
    srtReady: function (n) { return '已实时转换 ' + n + ' 条字幕，可直接复制或导出 .srt 文件。'; },
    srtEmpty: '未检测到带时间轴的 [mm:ss.xx] 歌词行。请粘贴或拖入 .lrc 文件。',
    shiftReady: function (n, c, delta) {
      var sign = delta > 0 ? '+' : '';
      return '已调整 ' + n + ' 个时间标签（偏移 ' + sign + delta + ' ms）' + (c > 0 ? '，其中 ' + c + ' 个负时间戳已自动归零至 [00:00.00]。' : '。');
    },
    shiftEmpty: '未检测到可偏移的 [mm:ss.xx] 时间标签。',
    convLrcReady: function (n) { return '已将 ' + n + ' 条 SRT 字幕转为标准 .lrc 格式。'; },
    convTxtReady: function (n) { return '已清除全部时间轴，提取出 ' + n + ' 行纯文本歌词。'; },
    convEmpty: '请输入 .srt 或 .lrc 内容以开始转换。',
    copied: '已复制到剪贴板',
    copyFail: '复制失败，请手动全选复制',
    loadedFile: function (name) { return '已加载本地文件：' + name; }
  } : {
    srtReady: function (n) { return 'Converted ' + n + ' subtitle cues locally. Ready to copy or export .srt.'; },
    srtEmpty: 'No [mm:ss.xx] timed lyric lines found. Paste or drop an .lrc file.',
    shiftReady: function (n, c, delta) {
      var sign = delta > 0 ? '+' : '';
      return 'Shifted ' + n + ' timestamps (' + sign + delta + ' ms)' + (c > 0 ? '; ' + c + ' negative timestamps clamped to [00:00.00].' : '.');
    },
    shiftEmpty: 'No [mm:ss.xx] timestamps detected to shift.',
    convLrcReady: function (n) { return 'Converted ' + n + ' SRT cues into standard .lrc lines.'; },
    convTxtReady: function (n) { return 'Stripped all timestamps and extracted ' + n + ' clean text lines.'; },
    convEmpty: 'Paste or drop .srt or .lrc content to convert.',
    copied: 'Copied to clipboard',
    copyFail: 'Copy failed — select and copy manually',
    loadedFile: function (name) { return 'Loaded local file: ' + name; }
  };

  function downloadFile(filename, content) {
    var blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    var url = URL.createObjectURL(blob);
    var a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    a.remove();
    setTimeout(function () { URL.revokeObjectURL(url); }, 1000);
  }

  function copyText(text, btn) {
    if (!text) return;
    var orig = btn.textContent;
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(function () {
        btn.textContent = msg.copied;
        setTimeout(function () { btn.textContent = orig; }, 1600);
      }).catch(function () {
        btn.textContent = msg.copyFail;
        setTimeout(function () { btn.textContent = orig; }, 1600);
      });
    }
  }

  function bindDropzone(zoneId, fileInputId, onText) {
    var zone = document.getElementById(zoneId);
    var input = document.getElementById(fileInputId);
    if (!zone || !input) return;

    function readFile(file) {
      if (!file) return;
      var reader = new FileReader();
      reader.onload = function (e) {
        onText(String(e.target.result || ''), file.name);
      };
      reader.readAsText(file);
    }

    input.addEventListener('change', function () {
      if (input.files && input.files[0]) readFile(input.files[0]);
      input.value = '';
    });

    zone.addEventListener('dragover', function (e) {
      e.preventDefault();
      zone.classList.add('is-dragover');
    });
    zone.addEventListener('dragleave', function () {
      zone.classList.remove('is-dragover');
    });
    zone.addEventListener('drop', function (e) {
      e.preventDefault();
      zone.classList.remove('is-dragover');
      if (e.dataTransfer && e.dataTransfer.files && e.dataTransfer.files[0]) {
        readFile(e.dataTransfer.files[0]);
      }
    });
  }

  // Tab switching
  var tabButtons = Array.prototype.slice.call(document.querySelectorAll('[data-lrc-tab]'));
  var tabPanels = Array.prototype.slice.call(document.querySelectorAll('[data-lrc-panel]'));
  function activateTab(id) {
    tabButtons.forEach(function (btn) {
      var active = btn.getAttribute('data-lrc-tab') === id;
      btn.setAttribute('aria-selected', active ? 'true' : 'false');
      btn.setAttribute('tabindex', active ? '0' : '-1');
    });
    tabPanels.forEach(function (panel) {
      panel.hidden = panel.getAttribute('data-lrc-panel') !== id;
    });
  }
  tabButtons.forEach(function (btn) {
    btn.addEventListener('click', function () {
      activateTab(btn.getAttribute('data-lrc-tab'));
    });
  });

  // Tool 1: LRC -> SRT
  var lrc2srtIn = document.getElementById('lrc2srt-input');
  var lrc2srtOut = document.getElementById('lrc2srt-output');
  var lrc2srtDur = document.getElementById('lrc2srt-last-duration');
  var lrc2srtStat = document.getElementById('lrc2srt-stats');
  var lrc2srtBaseName = 'lyrics';

  function updateLrc2Srt() {
    if (!lrc2srtIn || !lrc2srtOut) return;
    var res = lrcToSrt(lrc2srtIn.value, lrc2srtDur ? lrc2srtDur.value : 4);
    lrc2srtOut.value = res.srt;
    if (lrc2srtStat) lrc2srtStat.textContent = res.count > 0 ? msg.srtReady(res.count) : msg.srtEmpty;
  }

  if (lrc2srtIn) {
    lrc2srtIn.value = isZh ? SAMPLE_LRC_ZH : SAMPLE_LRC_EN;
    lrc2srtIn.addEventListener('input', updateLrc2Srt);
    if (lrc2srtDur) lrc2srtDur.addEventListener('input', updateLrc2Srt);
    updateLrc2Srt();

    bindDropzone('lrc2srt-dropzone', 'lrc2srt-file', function (text, name) {
      lrc2srtBaseName = name.replace(/\.[^.]+$/, '') || 'lyrics';
      lrc2srtIn.value = text;
      updateLrc2Srt();
      if (lrc2srtStat) lrc2srtStat.textContent = msg.loadedFile(name) + ' · ' + lrc2srtStat.textContent;
    });

    var sampleBtn1 = document.getElementById('lrc2srt-sample');
    if (sampleBtn1) sampleBtn1.addEventListener('click', function () {
      lrc2srtBaseName = 'midnight-harbor-demo';
      lrc2srtIn.value = isZh ? SAMPLE_LRC_ZH : SAMPLE_LRC_EN;
      updateLrc2Srt();
    });
    var clearBtn1 = document.getElementById('lrc2srt-clear');
    if (clearBtn1) clearBtn1.addEventListener('click', function () {
      lrc2srtIn.value = '';
      updateLrc2Srt();
    });
    var copyBtn1 = document.getElementById('lrc2srt-copy');
    if (copyBtn1) copyBtn1.addEventListener('click', function () { copyText(lrc2srtOut.value, copyBtn1); });
    var dlBtn1 = document.getElementById('lrc2srt-download');
    if (dlBtn1) dlBtn1.addEventListener('click', function () {
      if (lrc2srtOut.value) downloadFile(lrc2srtBaseName + '.srt', lrc2srtOut.value);
    });
  }

  // Tool 2: LRC Time Shifter
  var shiftIn = document.getElementById('shift-input');
  var shiftOut = document.getElementById('shift-output');
  var shiftAmount = document.getElementById('shift-amount');
  var shiftUnit = document.getElementById('shift-unit');
  var shiftStat = document.getElementById('shift-stats');
  var shiftBaseName = 'shifted-lyrics';

  function getShiftDeltaMs() {
    var val = parseFloat(shiftAmount ? shiftAmount.value : '0') || 0;
    var unit = shiftUnit ? shiftUnit.value : 'ms';
    return unit === 's' ? Math.round(val * 1000) : Math.round(val);
  }

  function updateShift() {
    if (!shiftIn || !shiftOut) return;
    var delta = getShiftDeltaMs();
    var res = shiftLrc(shiftIn.value, delta);
    shiftOut.value = res.lrc;
    if (shiftStat) {
      shiftStat.textContent = res.shiftedCount > 0
        ? msg.shiftReady(res.shiftedCount, res.clampedCount, delta)
        : msg.shiftEmpty;
    }
  }

  if (shiftIn) {
    shiftIn.value = isZh ? SAMPLE_LRC_ZH : SAMPLE_LRC_EN;
    shiftIn.addEventListener('input', updateShift);
    if (shiftAmount) shiftAmount.addEventListener('input', updateShift);
    if (shiftUnit) shiftUnit.addEventListener('change', updateShift);
    updateShift();

    Array.prototype.slice.call(document.querySelectorAll('[data-shift-preset]')).forEach(function (btn) {
      btn.addEventListener('click', function () {
        var ms = parseInt(btn.getAttribute('data-shift-preset'), 10) || 0;
        if (shiftUnit) shiftUnit.value = 'ms';
        if (shiftAmount) shiftAmount.value = String((parseFloat(shiftAmount.value) || 0) + ms);
        updateShift();
      });
    });

    bindDropzone('shift-dropzone', 'shift-file', function (text, name) {
      shiftBaseName = name.replace(/\.[^.]+$/, '') + '-shifted';
      shiftIn.value = text;
      updateShift();
      if (shiftStat) shiftStat.textContent = msg.loadedFile(name) + ' · ' + shiftStat.textContent;
    });

    var resetShiftBtn = document.getElementById('shift-reset');
    if (resetShiftBtn) resetShiftBtn.addEventListener('click', function () {
      if (shiftAmount) shiftAmount.value = '0';
      updateShift();
    });
    var copyBtn2 = document.getElementById('shift-copy');
    if (copyBtn2) copyBtn2.addEventListener('click', function () { copyText(shiftOut.value, copyBtn2); });
    var dlBtn2 = document.getElementById('shift-download');
    if (dlBtn2) dlBtn2.addEventListener('click', function () {
      if (shiftOut.value) downloadFile(shiftBaseName + '.lrc', shiftOut.value);
    });
  }

  // Tool 3: SRT -> LRC & Strip Timestamps
  var convIn = document.getElementById('conv-input');
  var convOut = document.getElementById('conv-output');
  var convMode = document.getElementById('conv-mode');
  var convStat = document.getElementById('conv-stats');
  var convBaseName = 'converted-lyrics';

  function updateConv() {
    if (!convIn || !convOut) return;
    var mode = convMode ? convMode.value : 'srt2lrc';
    if (mode === 'strip') {
      var resTxt = stripTimestamps(convIn.value);
      convOut.value = resTxt.text;
      if (convStat) convStat.textContent = resTxt.count > 0 ? msg.convTxtReady(resTxt.count) : msg.convEmpty;
    } else {
      var resLrc = srtToLrc(convIn.value);
      convOut.value = resLrc.lrc;
      if (convStat) convStat.textContent = resLrc.count > 0 ? msg.convLrcReady(resLrc.count) : msg.convEmpty;
    }
  }

  if (convIn) {
    convIn.value = SAMPLE_SRT_EN;
    convIn.addEventListener('input', updateConv);
    if (convMode) convMode.addEventListener('change', updateConv);
    updateConv();

    bindDropzone('conv-dropzone', 'conv-file', function (text, name) {
      convBaseName = name.replace(/\.[^.]+$/, '') || 'converted-lyrics';
      convIn.value = text;
      updateConv();
      if (convStat) convStat.textContent = msg.loadedFile(name) + ' · ' + convStat.textContent;
    });

    var copyBtn3 = document.getElementById('conv-copy');
    if (copyBtn3) copyBtn3.addEventListener('click', function () { copyText(convOut.value, copyBtn3); });
    var dlBtn3 = document.getElementById('conv-download');
    if (dlBtn3) dlBtn3.addEventListener('click', function () {
      if (!convOut.value) return;
      var ext = (convMode && convMode.value === 'strip') ? '.txt' : '.lrc';
      downloadFile(convBaseName + ext, convOut.value);
    });
  }
})();
