const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const { parseEnv } = require('node:util');

const DEFAULT_BRAND = Object.freeze({
  name: '澜序',
  nameEn: 'Lansway',
  icon: '/assets/lansway.svg',
  theme: 'gemini',
  colorMode: 'dark',
});

const PUBLIC_FILES = new Set([
  'index.html',
  'style.css',
  'advanced.css',
  'app.js',
  'advanced.js',
  'brand.js',
  'brand.css',
  'icons.js',
  'theme.js',
  'theme.css',
]);

const CONTENT_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.svg': 'image/svg+xml',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.webp': 'image/webp',
  '.avif': 'image/avif',
  '.ico': 'image/x-icon',
};
const IMAGE_EXTENSIONS = new Set([
  '.svg', '.png', '.jpg', '.jpeg', '.gif', '.webp', '.avif', '.ico',
]);

function loadBrandConfig({ rootDir = __dirname, env = process.env } = {}) {
  let fileEnv = {};
  try {
    fileEnv = parseEnv(fs.readFileSync(path.join(rootDir, '.env'), 'utf8'));
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  const value = (key, fallback) => {
    const configured = Object.hasOwn(env, key) ? env[key] : fileEnv[key];
    return typeof configured === 'string' && configured.trim() ? configured : fallback;
  };
  const colorMode = value('APP_COLOR_MODE', DEFAULT_BRAND.colorMode);
  // Only these public branding and appearance fields may leave the server.
  return {
    name: value('APP_NAME', DEFAULT_BRAND.name),
    nameEn: value('APP_NAME_EN', DEFAULT_BRAND.nameEn),
    icon: value('APP_ICON', DEFAULT_BRAND.icon),
    theme: value('APP_THEME', DEFAULT_BRAND.theme),
    colorMode: ['light', 'dark', 'system'].includes(colorMode) ? colorMode : DEFAULT_BRAND.colorMode,
  };
}

function serializeBrandConfig(config) {
  const json = JSON.stringify(config)
    .replace(/</g, '\\u003c')
    .replace(/\u2028/g, '\\u2028')
    .replace(/\u2029/g, '\\u2029');
  return `window.__APP_CONFIG__ = ${json};\n`;
}

function createServer({ rootDir = __dirname, env = process.env } = {}) {
  const root = fs.realpathSync(rootDir);

  return http.createServer(async (req, res) => {
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Cache-Control', 'no-store');
    const send = (status, message, contentType = 'text/plain; charset=utf-8') => {
      res.writeHead(status, { 'Content-Type': contentType });
      res.end(req.method === 'HEAD' ? undefined : message);
    };

    if (req.method !== 'GET' && req.method !== 'HEAD') {
      res.setHeader('Allow', 'GET, HEAD');
      return send(405, 'Method not allowed');
    }

    let pathname;
    try {
      pathname = decodeURIComponent((req.url || '/').split('?')[0]);
    } catch {
      return send(400, 'Invalid path');
    }
    if (!pathname.startsWith('/') || /[\\\u0000-\u001f\u007f]/.test(pathname)) {
      return send(400, 'Invalid path');
    }
    const segments = pathname.slice(1).split('/');
    if (segments.some((segment) => segment.startsWith('.'))) {
      return send(403, 'Forbidden');
    }

    if (pathname === '/brand-config.js') {
      try {
        return send(200, serializeBrandConfig(loadBrandConfig({ rootDir: root, env })), CONTENT_TYPES['.js']);
      } catch {
        return send(500, 'Unable to read brand configuration');
      }
    }

    const relativePath = pathname === '/' ? 'index.html' : pathname.slice(1);
    const extension = path.extname(relativePath).toLowerCase();
    const isAsset = relativePath.startsWith('assets/') && IMAGE_EXTENSIONS.has(extension);
    if (!PUBLIC_FILES.has(relativePath) && !isAsset) return send(404, 'Not found');

    const file = path.resolve(root, relativePath);
    if (!file.startsWith(root + path.sep)) return send(403, 'Forbidden');

    try {
      const realFile = await fs.promises.realpath(file);
      // Public paths must not use symlinks to reveal private files.
      if (realFile !== file) return send(403, 'Forbidden');
      const stat = await fs.promises.stat(realFile);
      if (!stat.isFile()) return send(404, 'Not found');
      const data = req.method === 'HEAD' ? undefined : await fs.promises.readFile(realFile);
      return send(200, data, CONTENT_TYPES[extension]);
    } catch (error) {
      return send(error.code === 'ENOENT' || error.code === 'ENOTDIR' ? 404 : 500, 'Unable to read resource');
    }
  });
}

if (require.main === module) {
  const portText = process.env.PORT || '5173';
  const port = Number(portText);
  if (!/^\d+$/.test(portText) || !Number.isInteger(port) || port < 0 || port > 65535) {
    throw new Error('PORT must be an integer between 0 and 65535');
  }
  const server = createServer();
  server.listen(port, '127.0.0.1', () => {
    console.log(`Preview: http://127.0.0.1:${server.address().port}`);
  });
}

module.exports = { createServer, loadBrandConfig, serializeBrandConfig, DEFAULT_BRAND };
