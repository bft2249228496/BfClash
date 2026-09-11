// Public branding only; the server publishes an explicit environment whitelist.
(() => {
  const config = window.__APP_CONFIG__ || {};
  const clean = (value, fallback) => typeof value === 'string' && value.trim() ? value.trim() : fallback;
  const name = clean(config.name, '澜序');
  const nameEn = clean(config.nameEn, 'Lansway');
  const escape = value => String(value).replace(/[&<>"']/g, char => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[char]));
  const fallbackIcon = '/assets/lansway.svg';
  const configuredIcon = clean(config.icon, fallbackIcon);
  let icon = fallbackIcon;
  try {
    const url = new URL(configuredIcon, location.href);
    if (['http:', 'https:'].includes(url.protocol)) icon = url.href;
  } catch { /* Use the bundled icon for malformed paths. */ }
  const defaultIcon = icon;
  const storageKey = 'lansway.icon.v1';
  const options = [['03', '序列'], ['01', '折潮'], ['02', '潮隙'], ['04', '回澜'], ['05', '航迹'], ['06', '澜印']];
  let preference = null;
  const valid = value => value && (options.some(([id]) => id === value.id) || (value.id === 'custom' && typeof value.data === 'string' && value.data.length < 1500000 && /^data:image\/png;base64,[A-Za-z0-9+/=]+$/.test(value.data)));
  try { const saved = JSON.parse(localStorage.getItem(storageKey)); if (valid(saved)) preference = saved; } catch {}
  const currentIcon = () => preference ? preference.id === 'custom' ? preference.data : `/assets/icon-options/${preference.id}.svg` : defaultIcon;
  icon = currentIcon();
  function applyIcon() {
    icon = currentIcon();
    document.querySelectorAll('[data-brand-icon]').forEach(el => { el.src = icon; });
    document.querySelector('#app-favicon').href = icon;
  }
  function saveIcon(next) {
    try {
      if (next) localStorage.setItem(storageKey, JSON.stringify(next));
      else localStorage.removeItem(storageKey);
    } catch { toast('无法保存图标，请检查浏览器存储空间'); return; }
    preference = next;
    applyIcon();
    const panel = document.querySelector('.brand-picker');
    if (panel) panel.outerHTML = renderPicker();
  }
  function renderPicker() {
    const selected = preference?.id || (defaultIcon.endsWith('/assets/lansway.svg') ? '03' : options.find(([id]) => defaultIcon.endsWith(`/icon-options/${id}.svg`))?.[0]);
    return `<section class="brand-picker"><div class="section-label appearance-section">应用图标<small>选择你喜欢的标识</small></div><div class="brand-options" role="group" aria-label="应用图标">${options.map(([id, label]) => `<button data-icon-choice="${id}" aria-pressed="${selected === id}" class="brand-option ${selected === id ? 'selected' : ''}"><img src="/assets/icon-options/${id}.svg" alt=""><span>${label}</span></button>`).join('')}</div><div class="brand-upload-row"><img src="${escape(currentIcon())}" alt="当前图标"><div><b>${preference?.id === 'custom' ? '自定义图标' : '上传自己的图标'}</b><small>PNG、JPG、WebP 或 SVG · 最大 2 MB</small></div><button data-icon-upload>上传</button><input type="file" data-icon-file accept="image/png,image/jpeg,image/webp,image/svg+xml" hidden aria-label="上传自定义图标"></div><div class="appearance-footer"><span>仅保存在当前浏览器，刷新后保留</span><button data-icon-reset>恢复默认图标</button></div></section>`;
  }
  document.addEventListener('click', event => {
    const button = event.target.closest('button');
    if (!button) return;
    if (options.some(([id]) => id === button.dataset.iconChoice)) saveIcon({ id: button.dataset.iconChoice });
    if (button.hasAttribute('data-icon-reset')) saveIcon(null);
    if (button.hasAttribute('data-icon-upload')) document.querySelector('[data-icon-file]')?.click();
  });
  document.addEventListener('change', async event => {
    if (!event.target.matches('[data-icon-file]')) return;
    const file = event.target.files[0];
    event.target.value = '';
    if (!file) return;
    if (!['image/png', 'image/jpeg', 'image/webp', 'image/svg+xml'].includes(file.type) || file.size > 2 * 1024 * 1024) { toast('请选择 2 MB 以内的 PNG、JPG、WebP 或 SVG 图片'); return; }
    const url = URL.createObjectURL(file);
    try {
      const image = new Image();
      image.src = url;
      await image.decode();
      if (!image.naturalWidth || !image.naturalHeight) throw new Error('Empty image');
      const canvas = document.createElement('canvas');
      canvas.width = canvas.height = 256;
      const scale = Math.min(256 / image.naturalWidth, 256 / image.naturalHeight);
      const width = image.naturalWidth * scale, height = image.naturalHeight * scale;
      canvas.getContext('2d').drawImage(image, (256 - width) / 2, (256 - height) / 2, width, height);
      saveIcon({ id: 'custom', data: canvas.toDataURL('image/png') });
    } catch { toast('图片无法读取，请换一张图片重试'); }
    finally { URL.revokeObjectURL(url); }
  });
  window.addEventListener('storage', event => {
    if (event.key !== storageKey && event.key !== null) return;
    try { const next = JSON.parse(event.newValue); preference = valid(next) ? next : null; applyIcon(); const panel = document.querySelector('.brand-picker'); if (panel) panel.outerHTML = renderPicker(); } catch {}
  });
  window.Brand = Object.freeze({ name, nameEn, html: escape(name), htmlEn: escape(nameEn), get icon() { return icon; }, renderPicker });
  document.title = `${name} · ${nameEn} · Android`;
  document.querySelectorAll('[data-brand-name]').forEach(el => el.textContent = name);
  document.querySelectorAll('[data-brand-english]').forEach(el => el.textContent = nameEn);
  document.querySelectorAll('[data-brand-icon]').forEach(el => {
    el.src = icon;
    el.alt = '';
    el.onerror = () => { el.onerror = null; el.src = fallbackIcon; };
  });
  document.querySelector('[data-brand-link]').setAttribute('aria-label', `${name} ${nameEn}`);
  document.querySelector('#app-favicon').href = icon;
})();
