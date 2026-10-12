// Builds app/www from the website files one folder up, so the website and the app
// always run the same code. Run from the app folder: node scripts/prepare-www.mjs
import fs from 'node:fs';
import path from 'node:path';

const APP = path.resolve(path.dirname(new URL(import.meta.url).pathname), '..');
const SITE = path.resolve(APP, '..');
const WWW = path.join(APP, 'www');

const FILES = ['index.html', 'privacy.html', 'terms.html', 'manifest.webmanifest',
  'icon-192.png', 'icon-512.png', 'maskable-512.png', 'apple-touch-icon.png', 'favicon-32.png'];

fs.rmSync(WWW, { recursive: true, force: true });
fs.mkdirSync(WWW, { recursive: true });
for (const f of FILES) {
  const src = path.join(SITE, f);
  if (!fs.existsSync(src)) throw new Error('Missing website file: ' + f);
  fs.copyFileSync(src, path.join(WWW, f));
}

// Capacitor's runtime, loaded before the app's own script so plugins are ready.
const core = path.join(APP, 'node_modules/@capacitor/core/dist/capacitor.js');
if (!fs.existsSync(core)) throw new Error('Run npm install first (missing @capacitor/core).');
fs.copyFileSync(core, path.join(WWW, 'capacitor.js'));

// Download the Barlow fonts into the app so it looks right with no signal.
const FONT_CSS = 'https://fonts.googleapis.com/css2?family=Barlow+Condensed:wght@500;600;700&family=Barlow:wght@400;500;600&display=swap';
let localFonts = false;
try {
  const css = await (await fetch(FONT_CSS, { headers: { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0 Safari/537.36' } })).text();
  const urls = [...new Set([...css.matchAll(/url\((https:[^)]+\.woff2)\)/g)].map(m => m[1]))];
  if (!urls.length) throw new Error('no font files found');
  fs.mkdirSync(path.join(WWW, 'fonts'), { recursive: true });
  let out = css;
  for (const [i, u] of urls.entries()) {
    const name = 'f' + i + '.woff2';
    const buf = Buffer.from(await (await fetch(u)).arrayBuffer());
    fs.writeFileSync(path.join(WWW, 'fonts', name), buf);
    out = out.split(u).join('fonts/' + name);
  }
  fs.writeFileSync(path.join(WWW, 'fonts.css'), out);
  localFonts = true;
  console.log('Fonts saved into the app: ' + urls.length + ' files');
} catch (e) {
  console.warn('Could not download fonts, the app will use Google Fonts online: ' + e.message);
}

for (const f of ['index.html', 'terms.html']) {
  const p = path.join(WWW, f);
  let html = fs.readFileSync(p, 'utf8');
  if (localFonts) {
    html = html.replace(/<link rel="preconnect" href="https:\/\/fonts\.googleapis\.com">\s*/g, '')
               .replace(/<link href="https:\/\/fonts\.googleapis\.com\/css2[^"]*" rel="stylesheet">/g, '<link href="fonts.css" rel="stylesheet">');
  }
  if (f === 'index.html') {
    if (!html.includes('<meta charset="UTF-8">')) throw new Error('index.html layout changed: no charset meta');
    html = html.replace('<meta charset="UTF-8">', '<meta charset="UTF-8">\n<script src="capacitor.js"></script>');
    html = html.replace(/<link rel="manifest"[^>]*>\s*/g, '');
  }
  fs.writeFileSync(p, html);
}
console.log('www ready: ' + fs.readdirSync(WWW).join(', '));
