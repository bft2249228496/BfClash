// Appearance preferences are real and local. Proxy operations remain a prototype.
(() => {
  const storageKey = 'proxy-concept.appearance.v1';
  const themes = {
    gemini: {
      name: 'Gemini', subtitle: '星夜蓝紫',
      dark: { bg: '#18191e', card: '#202127', elevated: '#292b33', text: '#dce0eb', muted: '#969daf', subtle: '#71798b', line: '#2d303a', tint: '#252c3d', accent: '#a7baf2', button: '#a7baf2', onAccent: '#1b2644', companion: '#b8a1de', stage: '#141519', preview: '#191b21', dots: '#30343e' },
      light: { bg: '#f4f5fa', card: '#ffffff', elevated: '#e9ecf5', text: '#29314a', muted: '#747c93', subtle: '#9298aa', line: '#e4e7f0', tint: '#e9edfa', accent: '#5b70b8', button: '#5b70b8', onAccent: '#ffffff', companion: '#9a80c5', stage: '#f0f2f9', preview: '#e5e9f4', dots: '#bfc7dd' }
    },
    slate: {
      name: 'Slate', subtitle: '雾灰留白',
      dark: { bg: '#191b1e', card: '#222529', elevated: '#2c3036', text: '#dee2e8', muted: '#9bA3af', subtle: '#757e8b', line: '#31363e', tint: '#2b323d', accent: '#b6c5dc', button: '#b6c5dc', onAccent: '#222d3e', companion: '#9fa9bb', stage: '#15171b', preview: '#1d2025', dots: '#353b44' },
      light: { bg: '#f5f6f8', card: '#ffffff', elevated: '#e9ecf1', text: '#303847', muted: '#788293', subtle: '#939ba9', line: '#e3e7ed', tint: '#e9edf4', accent: '#566d8d', button: '#566d8d', onAccent: '#ffffff', companion: '#8997ae', stage: '#f0f2f5', preview: '#e5e9ee', dots: '#c4ccd7' }
    },
    dracula: {
      name: 'Dracula', subtitle: '午夜紫调',
      dark: { bg: '#1e1d28', card: '#292734', elevated: '#33313f', text: '#e9e3f3', muted: '#aaa0bb', subtle: '#837991', line: '#3b354c', tint: '#352c49', accent: '#bd9ce9', button: '#bd9ce9', onAccent: '#2f2047', companion: '#df98bb', stage: '#191721', preview: '#211d2c', dots: '#3d3450' },
      light: { bg: '#f7f4fa', card: '#ffffff', elevated: '#eee7f6', text: '#3c304e', muted: '#8b7b9d', subtle: '#aa9eb8', line: '#e9e0f1', tint: '#eee4f8', accent: '#8a60b7', button: '#8a60b7', onAccent: '#ffffff', companion: '#bd779e', stage: '#f3eef8', preview: '#eae1f3', dots: '#cfc0df' }
    },
    rose: {
      name: '樱霞', subtitle: '柔和玫瑰',
      dark: { bg: '#211c20', card: '#2c242a', elevated: '#372c34', text: '#eee0e7', muted: '#b39aa8', subtle: '#8e7886', line: '#3e303b', tint: '#3d2c38', accent: '#e3a9c5', button: '#e3a9c5', onAccent: '#452536', companion: '#c6ade0', stage: '#1b171b', preview: '#271e25', dots: '#47323f' },
      light: { bg: '#faf4f7', card: '#ffffff', elevated: '#f4e7ee', text: '#523441', muted: '#a08191', subtle: '#b69da9', line: '#f0e2e9', tint: '#f8e6ef', accent: '#b35c85', button: '#b35c85', onAccent: '#ffffff', companion: '#a382bd', stage: '#f8eff4', preview: '#f0e1ea', dots: '#dfc2d1' }
    },
    ember: {
      name: '日落', subtitle: '暖橘余晖',
      dark: { bg: '#211d1b', card: '#2b2522', elevated: '#382f29', text: '#eee4dc', muted: '#b1a094', subtle: '#8c7c71', line: '#3e332e', tint: '#3f3028', accent: '#e8b18e', button: '#e8b18e', onAccent: '#472e20', companion: '#d3bd88', stage: '#1b1816', preview: '#26201c', dots: '#45372c' },
      light: { bg: '#faf6f2', card: '#ffffff', elevated: '#f3ebe2', text: '#513c31', muted: '#9a8475', subtle: '#b2a092', line: '#eee4d9', tint: '#faecde', accent: '#ab6940', button: '#ab6940', onAccent: '#ffffff', companion: '#a58a50', stage: '#f7f1e9', preview: '#efe4d7', dots: '#dbc6af' }
    },
    ocean: {
      name: '海盐', subtitle: '清透海蓝',
      dark: { bg: '#171e24', card: '#202932', elevated: '#2a3540', text: '#dce7ef', muted: '#96acbd', subtle: '#728a9d', line: '#2e3c49', tint: '#253949', accent: '#94c5e8', button: '#94c5e8', onAccent: '#16364d', companion: '#aaaee0', stage: '#131a21', preview: '#18232d', dots: '#2a4053' },
      light: { bg: '#f2f7fa', card: '#ffffff', elevated: '#e4eff5', text: '#2a4254', muted: '#7490a3', subtle: '#97acba', line: '#dfebf2', tint: '#e2f0fa', accent: '#357ea7', button: '#357ea7', onAccent: '#ffffff', companion: '#7e8cc2', stage: '#edf4f9', preview: '#dfeef6', dots: '#b7d2e3' }
    }
  };
  const modes = ['light', 'dark', 'system'];
  const config = window.__APP_CONFIG__ || {};
  const defaults = {
    theme: Object.hasOwn(themes, config.theme) ? config.theme : 'gemini',
    colorMode: modes.includes(config.colorMode) ? config.colorMode : 'dark'
  };
  let saved = {};
  let storageAvailable = true;
  try {
    const parsed = JSON.parse(localStorage.getItem(storageKey) || '{}');
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      if (Object.hasOwn(themes, parsed.theme)) saved.theme = parsed.theme;
      if (modes.includes(parsed.colorMode)) saved.colorMode = parsed.colorMode;
    }
  } catch { /* A corrupt or unavailable store must never block the interface. */ }
  const systemDark = window.matchMedia('(prefers-color-scheme: dark)');
  const state = () => {
    const theme = saved.theme || defaults.theme;
    const colorMode = saved.colorMode || defaults.colorMode;
    return { theme, colorMode, name: themes[theme].name, resolvedMode: colorMode === 'system' ? (systemDark.matches ? 'dark' : 'light') : colorMode, isDefault: !Object.keys(saved).length, storageAvailable };
  };
  function apply() {
    const current = state();
    const root = document.documentElement;
    root.dataset.theme = current.theme;
    root.dataset.colorMode = current.resolvedMode;
    root.style.colorScheme = current.resolvedMode;
    for (const [key, value] of Object.entries(themes[current.theme][current.resolvedMode])) {
      root.style.setProperty(`--theme-${key.replace(/[A-Z]/g, letter => '-' + letter.toLowerCase())}`, value);
    }
    document.querySelector('.phone')?.classList.toggle('dark', current.resolvedMode === 'dark');
    // app.js currently keeps its mode in a shared classic-script lexical variable.
    if (typeof dark !== 'undefined') dark = current.resolvedMode === 'dark';
    const version = document.querySelector('.version span');
    if (version) version.textContent = `03 / ${current.name} · ${current.resolvedMode === 'dark' ? '深色' : '浅色'}`;
    const toggle = document.querySelector('#theme');
    if (toggle) {
      toggle.setAttribute('aria-label', `切换为${current.resolvedMode === 'dark' ? '浅色' : '深色'}外观`);
      toggle.title = `${current.name} · ${current.resolvedMode === 'dark' ? '深色' : '浅色'}`;
    }
    return current;
  }
  function refresh() {
    const screen = document.querySelector('#screen');
    const scrollTop = screen?.scrollTop || 0;
    const focus = document.activeElement;
    const focusSelector = focus?.dataset.themeChoice ? `[data-theme-choice="${focus.dataset.themeChoice}"]` : focus?.dataset.colorModeChoice ? `[data-color-mode-choice="${focus.dataset.colorModeChoice}"]` : focus?.hasAttribute('data-theme-reset') ? '[data-theme-reset]' : null;
    apply();
    if (typeof render === 'function') render();
    if (screen) screen.scrollTop = scrollTop;
    if (focusSelector) screen?.querySelector(focusSelector)?.focus({ preventScroll: true });
  }
  function persist() {
    try {
      if (Object.keys(saved).length) localStorage.setItem(storageKey, JSON.stringify(saved));
      else localStorage.removeItem(storageKey);
      storageAvailable = true;
    } catch { storageAvailable = false; }
  }
  function selectTheme(value) {
    if (!Object.hasOwn(themes, value)) return;
    saved.theme = value;
    persist();
    refresh();
  }
  function selectMode(value) {
    if (!modes.includes(value)) return;
    saved.colorMode = value;
    persist();
    refresh();
  }
  function reset() { saved = {}; persist(); refresh(); }
  function toggleMode() { selectMode(state().resolvedMode === 'dark' ? 'light' : 'dark'); }
  const modeName = mode => ({ light: '浅色', dark: '深色', system: '跟随系统' })[mode];
  const symbols = {
    light: '<circle cx="12" cy="12" r="4"/><path d="M12 2v2m0 16v2M2 12h2m16 0h2M5 5l1.4 1.4m11.2 11.2L19 19M5 19l1.4-1.4M17.6 6.4 19 5"/>',
    dark: '<path d="M20 14a8.4 8.4 0 0 1-10-10A8.5 8.5 0 1 0 20 14Z"/>',
    system: '<rect x="3" y="4" width="18" height="13" rx="2"/><path d="M8 21h8m-4-4v4"/>'
  };
  function renderPage() {
    const current = state();
    const encode = value => String(value).replace(/[&<>"']/g, char => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[char]);
    const preferences = typeof groups !== 'undefined' ? groups.appearance[1].slice(1).map(([label, value], i) => {
      const key = `appearance:${i + 1}`;
      if (typeof value === 'boolean') {
        const on = advancedState.toggles[key] ?? value;
        return `<button class="setting-row" data-toggle="${key}" role="switch" aria-checked="${on}"><b>${encode(label)}</b><span class="switch ${on ? 'on' : ''}"></span></button>`;
      }
      return `<button class="setting-row" data-option="${key}"><b>${encode(label)}</b><small>${encode(advancedState.options[key] ?? value)}</small><span class="chevron">›</span></button>`;
    }).join('') : '';
    return `<div class="subheading appearance-heading"><button data-page="settings" aria-label="返回设置"><svg viewBox="0 0 24 24" aria-hidden="true"><path d="m14 5-7 7 7 7"/></svg></button><h2>外观与体验</h2><span class="badge">PERSONALIZE</span></div>
      <p class="appearance-caption">为每一次连接，选一种心情。</p>
      <div class="appearance-current"><div class="appearance-spark" aria-hidden="true"><svg viewBox="0 0 32 32"><path d="M16 3c1.5 8 5 11.5 13 13-8 1.5-11.5 5-13 13C14.5 21 11 17.5 3 16c8-1.5 11.5-5 13-13Z"/></svg></div><div><b>${current.name}</b><span>${themes[current.theme].subtitle} <i>·</i> ${modeName(current.colorMode)}${current.colorMode === 'system' ? `（当前${modeName(current.resolvedMode)}）` : ''}</span></div><span class="appearance-current-label">当前外观</span></div>
      <div class="section-label appearance-section">显示模式</div>
      <div class="segmented appearance-modes" role="group" aria-label="显示模式">${modes.map(value => `<button data-color-mode-choice="${value}" class="${current.colorMode === value ? 'active' : ''}" aria-pressed="${current.colorMode === value}"><svg viewBox="0 0 24 24" aria-hidden="true">${symbols[value]}</svg>${modeName(value)}</button>`).join('')}</div>
      <div class="section-label appearance-section">主题配色<small>每款都有深浅两种外观</small></div>
      <div class="theme-grid" role="group" aria-label="主题配色">${Object.entries(themes).map(([id, theme]) => {
        const colors = theme[current.resolvedMode];
        const active = current.theme === id;
        return `<button class="theme-choice ${active ? 'selected' : ''}" data-theme-choice="${id}" aria-pressed="${active}" aria-label="${theme.name}，${theme.subtitle}" style="--sample-bg:${colors.bg};--sample-card:${colors.card};--sample-line:${colors.line};--sample-tint:${colors.tint};--sample-accent:${colors.accent};--sample-companion:${colors.companion}"><span class="theme-miniature" aria-hidden="true"><span class="miniature-top"><i></i><b></b><em></em></span><span class="miniature-hero"><span><i></i><b></b></span><em></em></span><span class="miniature-bottom"><i></i><i></i><i></i></span></span><span class="theme-choice-label"><span><b>${theme.name}</b><small>${theme.subtitle}</small></span><span class="theme-check" aria-hidden="true">${active ? '<svg viewBox="0 0 20 20"><path d="m5 10 3 3 7-7"/></svg>' : ''}</span></span></button>`;
      }).join('')}</div>
      <div class="appearance-footer"><span>${!current.storageAvailable ? '浏览器存储不可用，选择仅保留在本次访问。' : current.isDefault ? '正在使用应用默认外观' : '外观已自动保存在此设备'}</span><button data-theme-reset>恢复默认</button></div>
      ${window.Brand.renderPicker()}
      <div class="section-label appearance-section">界面偏好</div><div class="card settings-card">${preferences}</div><p class="note">主题、显示模式与应用图标立即生效；其余偏好为交互预览。</p>`;
  }
  function handleClick(event) {
    const button = event.target.closest('button');
    if (!button) return false;
    if (button.dataset.themeChoice) { selectTheme(button.dataset.themeChoice); return true; }
    if (button.dataset.colorModeChoice) { selectMode(button.dataset.colorModeChoice); return true; }
    if (button.hasAttribute('data-theme-reset')) { reset(); return true; }
    return false;
  }
  window.Theme = Object.freeze({ apply, renderPage, handleClick, toggleMode, selectTheme, selectMode, reset, state, defaults: Object.freeze({ ...defaults }), label: () => `${state().name} · ${modeName(state().colorMode)}` });
  document.addEventListener('click', handleClick);
  const onSystemChange = () => { if (state().colorMode === 'system') refresh(); };
  if (systemDark.addEventListener) systemDark.addEventListener('change', onSystemChange);
  else systemDark.addListener(onSystemChange);
  window.addEventListener('storage', event => {
    if (event.key !== storageKey && event.key !== null) return;
    try {
      const next = JSON.parse(event.newValue || '{}');
      saved = {};
      if (next && typeof next === 'object') {
        if (Object.hasOwn(themes, next.theme)) saved.theme = next.theme;
        if (modes.includes(next.colorMode)) saved.colorMode = next.colorMode;
      }
      refresh();
    } catch { /* Keep the current appearance if another tab writes invalid data. */ }
  });
  apply();
})();
