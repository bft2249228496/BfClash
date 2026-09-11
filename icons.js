// One consistent 24 px icon system. All shapes are local, scalable SVG.
(() => {
  const shapes = {
    home: '<path class="icon-wash" d="m3.5 10 8.5-7 8.5 7v9a2 2 0 0 1-2 2h-13a2 2 0 0 1-2-2z"/><path d="m3 10 9-7 9 7M5 9v10a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V9M9 21v-7h6v7"/>',
    proxy: '<path class="icon-wash" d="M4 7h16v10H4z"/><path d="M5 5v14M12 5v14M19 5v14"/><rect x="2.5" y="7" width="5" height="4" rx="1.4" fill="var(--card, #fff)"/><rect x="9.5" y="13" width="5" height="4" rx="1.4" fill="var(--card, #fff)"/><rect x="16.5" y="8" width="5" height="4" rx="1.4" fill="var(--card, #fff)"/>',
    sub: '<rect class="icon-wash" x="6" y="7" width="13" height="14" rx="3"/><rect x="6" y="7" width="13" height="14" rx="3"/><path d="M15 3H6a3 3 0 0 0-3 3v10M10 12h5M10 16h3"/>',
    settings: '<path class="icon-wash" d="m10 3-1 3-3 1-3 5 3 5 3 1 1 3h4l1-3 3-1 3-5-3-5-3-1-1-3z"/><path d="m9.5 4 .7-1h3.6l.7 1 .4 1.9 1.7 1 1.9-.6 1.3.3 1.8 3.1-.4 1.3-1.5 1.3v1.8l1.5 1.3.4 1.3-1.8 3.1-1.3.3-1.9-.6-1.7 1-.4 1.5h-5l-.4-1.5-1.7-1-1.9.6-1.3-.3-1.8-3.1.4-1.3 1.5-1.3v-1.8L3.3 11 3 9.7l1.8-3.1 1.3-.3 1.9.6 1.7-1z" transform="translate(0 -1) scale(1 .98)"/><circle cx="12" cy="11.7" r="3"/>',
    tools: '<rect class="icon-wash" x="3" y="3" width="7" height="7" rx="2"/><rect class="icon-wash" x="14" y="14" width="7" height="7" rx="2"/><rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/><path d="M17.5 3v7M14 6.5h7"/><rect x="3" y="14" width="7" height="7" rx="2"/>',
    cloud: '<path class="icon-wash" d="M6 18a5 5 0 1 1 0-10 6 6 0 0 1 12-1 5.5 5.5 0 0 1 0 11z"/><path d="M6 18a5 5 0 0 1-1-10 7 7 0 0 1 13-1 5.5 5.5 0 0 1 0 11M12 12v9m-3-6 3-3 3 3"/>',
    shield: '<path class="icon-wash" d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6z"/><path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6zM8.5 12l2.5 2.5 4.5-5"/>',
    globe: '<circle class="icon-wash" cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c-5 5-5 13 0 18 5-5 5-13 0-18"/>',
    clock: '<circle class="icon-wash" cx="12" cy="12" r="9"/><circle cx="12" cy="12" r="9"/><path d="M12 7v5l3 2"/>',
    power: '<path d="M12 3v9M6.2 5.5a9 9 0 1 0 11.6 0"/>',
    bell: '<path class="icon-wash" d="M6 9a6 6 0 0 1 12 0c0 6 2 7 2 7H4s2-1 2-7"/><path d="M6 9a6 6 0 0 1 12 0c0 6 2 7 2 7H4s2-1 2-7M10 20h4"/>',
    moon: '<path class="icon-wash" d="M20 14A9 9 0 0 1 10 3a9 9 0 1 0 10 11"/><path d="M20 14A9 9 0 0 1 10 3a9 9 0 1 0 10 11"/>',
    code: '<rect class="icon-wash" x="2" y="4" width="20" height="16" rx="4"/><path d="m8 8-4 4 4 4m8-8 4 4-4 4m-3-9-2 14"/>',
    rules: '<path class="icon-wash" d="M9 5h12v14H9z"/><path d="m3 6 1 1 2-2m-3 7 1 1 2-2m-3 7 1 1 2-2M10 6h10M10 12h10M10 18h7"/>',
    layers: '<path class="icon-wash" d="m12 3 10 5-10 5L2 8z"/><path d="m12 3 10 5-10 5L2 8zM2 12l10 5 10-5M2 16l10 5 10-5"/>',
    connections: '<path class="icon-wash" d="M4 5h5v5H4zM15 14h5v5h-5z"/><rect x="3" y="3" width="7" height="7" rx="2"/><rect x="14" y="14" width="7" height="7" rx="2"/><path d="M10 6h5a3 3 0 0 1 3 3v5M14 18H9a3 3 0 0 1-3-3v-5"/>',
    logs: '<rect class="icon-wash" x="3" y="4" width="18" height="16" rx="3"/><rect x="3" y="4" width="18" height="16" rx="3"/><path d="m7 9 3 3-3 3m6 0h4"/>',
    core: '<rect class="icon-wash" x="6" y="6" width="12" height="12" rx="3"/><rect x="6" y="6" width="12" height="12" rx="3"/><rect x="10" y="10" width="4" height="4" rx="1"/><path d="M9 3v3m6-3v3m-6 12v3m6-3v3M3 9h3m-3 6h3m12-6h3m-3 6h3"/>',
    refresh: '<path d="M20 10a8 8 0 0 0-14-4L3 9m0-6v6h6m-5 5a8 8 0 0 0 14 4l3-3m0 6v-6h-6"/>',
    chevron: '<path d="m9 5 7 7-7 7"/>',
    back: '<path d="m15 5-7 7 7 7"/>',
    arrow: '<path d="M6 18 18 6M6 6h12v12"/>',
    plus: '<path d="M12 5v14M5 12h14"/>',
    info: '<circle cx="12" cy="12" r="9"/><path d="M12 11v6m0-10h.01"/>'
  };
  window.AppIcons = Object.freeze({render(name) {return `<svg class="ui-icon" viewBox="0 0 24 24" aria-hidden="true">${shapes[name] || shapes.settings}</svg>`;}});
  document.querySelectorAll('[data-ui-icon]').forEach(el => el.innerHTML = window.AppIcons.render(el.dataset.uiIcon));
})();
