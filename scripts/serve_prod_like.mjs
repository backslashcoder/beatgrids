// Serves build/web with the rewrites and headers from vercel.json, so you can
// check routing, caching and the Content-Security-Policy before deploying.
//   node scripts/serve_prod_like.mjs [port]      (default 8090)
import { createServer } from 'node:http';
import { readFile, stat } from 'node:fs/promises';
import { extname, join, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = fileURLToPath(new URL('../build/web/', import.meta.url));
const config = JSON.parse(await readFile(new URL('../vercel.json', import.meta.url), 'utf8'));
const port = Number(process.argv[2] ?? 8090);

const types = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8',
  '.json': 'application/json', '.wasm': 'application/wasm', '.png': 'image/png',
  '.ico': 'image/x-icon', '.otf': 'font/otf', '.ttf': 'font/ttf', '.css': 'text/css',
  '.map': 'application/json', '.md': 'text/markdown', '.txt': 'text/plain',
};

// Vercel anchors `source` patterns to the whole path.
const rewrites = (config.rewrites ?? []).map((r) => ({ re: new RegExp(`^${r.source}$`), to: r.destination }));
const headerRules = (config.headers ?? []).map((h) => ({ re: new RegExp(`^${h.source}$`), headers: h.headers }));

async function fileFor(path) {
  const full = normalize(join(root, path));
  if (!full.startsWith(normalize(root))) return null;
  try {
    const s = await stat(full);
    return s.isFile() ? full : null;
  } catch {
    return null;
  }
}

createServer(async (req, res) => {
  const path = decodeURIComponent(new URL(req.url, 'http://x').pathname);
  let file = await fileFor(path === '/' ? '/index.html' : path);
  let status = 200;
  if (!file) {
    const rule = rewrites.find((r) => r.re.test(path));
    if (rule) file = await fileFor(rule.to);
  }
  for (const rule of headerRules) {
    if (rule.re.test(path)) for (const { key, value } of rule.headers) res.setHeader(key, value);
  }
  if (!file) {
    status = 404;
    res.writeHead(status, { 'content-type': 'text/plain' });
    return res.end('Not found');
  }
  res.writeHead(status, { 'content-type': types[extname(file)] ?? 'application/octet-stream' });
  res.end(await readFile(file));
}).listen(port, () => console.log(`Serving build/web like Vercel on http://localhost:${port}`));
