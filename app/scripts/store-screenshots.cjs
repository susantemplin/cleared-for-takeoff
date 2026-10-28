// Makes App Store screenshots at Apple's exact sizes, in English and Spanish:
//   iPhone Duo inside screen 2007x2853 and outside screen 1398x2034 (these add the
//   "optimized for iPhone Duo" badge, and are required for new submissions from April 2027),
//   plus iPhone 6.9" 1320x2868 and iPad 13" 2064x2752.
// Uses sample practice data and a sample AI review so every screen looks like real use.
// No airline names or logos appear (Apple doesn't allow other companies' trademarks in screenshots).
// Run from the repo root:  node app/scripts/store-screenshots.cjs [outFolder]
// It serves the website files itself on a local port.
const { chromium } = require('playwright');
const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.resolve(process.argv[2] || path.join(ROOT, 'store-screenshots'));
const FONT_CSS = process.env.FONT_CSS || ''; // only for offline previews; the real Barlow fonts load from Google on GitHub

const DEVICES = [
  { id: 'iphone-duo-inside', w: 669, h: 951, scale: 3, ua: 'iphone' },   // 2007 x 2853
  { id: 'iphone-duo-outside', w: 466, h: 678, scale: 3, ua: 'iphone' },  // 1398 x 2034
  { id: 'iphone-6.9', w: 440, h: 956, scale: 3, ua: 'iphone' },          // 1320 x 2868
  { id: 'ipad-13', w: 1032, h: 1376, scale: 2, ua: 'ipad' },             // 2064 x 2752
];
const UA = {
  iphone: 'Mozilla/5.0 (iPhone; CPU iPhone OS 27_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0 Mobile/15E148 Safari/604.1',
  ipad: 'Mozilla/5.0 (iPad; CPU OS 27_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/27.0 Mobile/15E148 Safari/604.1',
};

const SAMPLE = {
  en: {
    answer: 'At the gate one night our flight was delayed three hours and a mom with two tired kids was in tears. I walked over, got the kids water and snacks, and found her a quieter spot near the window. I checked on her every 30 minutes with updates. When we finally boarded she hugged me and said I saved her night.',
    fb: { score: 4, summary: 'Warm, specific, and easy to follow. You clearly owned the moment and ended on a real result.',
      worked: ['You noticed her before she asked for help', 'Clear steps, all told with "I"', 'A strong, human ending'],
      improve: ['Add one line on how you kept the other passengers updated too'],
      stronger: 'One night at my gate, our flight was delayed three hours, and a mom traveling with two tired kids was in tears. I walked over, brought the kids water and snacks, and found her a quieter seat by the window. Then I checked in with her every 30 minutes with updates, while still making announcements for the whole gate. When we finally boarded, she hugged me and said I had saved her night.',
      changes: ['Sets the scene in one sentence', 'Shows you cared for everyone, not just one person', 'Keeps the strong ending'],
      star: { situation: true, task: true, action: true, result: true } },
    story: { title: 'The three-hour delay', s: 'Our flight was delayed three hours and a mom with two tired kids was in tears.', a: 'I brought water and snacks, found her a quieter seat, and gave her updates every 30 minutes.', r: 'She hugged me at boarding and said I saved her night.' },
  },
  es: {
    answer: 'Una noche en la puerta nuestro vuelo se retrasó tres horas y una mamá con dos niños cansados estaba llorando. Me acerqué, les di agua y algo de comer a los niños y le busqué un lugar más tranquilo junto a la ventana. Cada 30 minutos le daba noticias. Cuando por fin abordamos, me abrazó y me dijo que le había salvado la noche.',
    fb: { score: 4, summary: 'Cálida, específica y fácil de seguir. Se nota que tomaste el control del momento y terminaste con un resultado real.',
      worked: ['La notaste antes de que pidiera ayuda', 'Pasos claros, contados con "yo"', 'Un final fuerte y humano'],
      improve: ['Agrega una frase sobre cómo mantuviste informados también a los demás pasajeros'],
      stronger: 'Una noche en mi puerta, nuestro vuelo se retrasó tres horas y una mamá que viajaba con dos niños cansados estaba llorando. Me acerqué, les llevé agua y algo de comer a los niños y le busqué un asiento más tranquilo junto a la ventana. Luego le di noticias cada 30 minutos, sin dejar de hacer los anuncios para toda la puerta. Cuando por fin abordamos, me abrazó y me dijo que le había salvado la noche.',
      changes: ['Presenta la escena en una frase', 'Muestra que cuidaste a todos, no solo a una persona', 'Mantiene el final fuerte'],
      star: { situation: true, task: true, action: true, result: true } },
    story: { title: 'El retraso de tres horas', s: 'Nuestro vuelo se retrasó tres horas y una mamá con dos niños cansados estaba llorando.', a: 'Les llevé agua y algo de comer, le busqué un asiento más tranquilo y le di noticias cada 30 minutos.', r: 'Me abrazó al abordar y me dijo que le había salvado la noche.' },
  },
};

function serve() {
  const types = { '.html': 'text/html', '.js': 'text/javascript', '.png': 'image/png', '.webmanifest': 'application/manifest+json', '.css': 'text/css' };
  const srv = http.createServer((req, res) => {
    let p = decodeURIComponent(req.url.split('?')[0]); if (p.endsWith('/')) p += 'index.html';
    const f = path.join(ROOT, p);
    if (!f.startsWith(ROOT) || !fs.existsSync(f) || fs.statSync(f).isDirectory()) { res.writeHead(404); return res.end(); }
    res.writeHead(200, { 'Content-Type': types[path.extname(f)] || 'application/octet-stream' }); fs.createReadStream(f).pipe(res);
  });
  return new Promise(ok => srv.listen(0, '127.0.0.1', () => ok(srv)));
}

function ymd(off) { const d = new Date(Date.now() + off * 86400000); return d.getFullYear() + '-' + String(d.getMonth() + 1).padStart(2, '0') + '-' + String(d.getDate()).padStart(2, '0'); }

(async () => {
  const srv = await serve(); const base = 'http://127.0.0.1:' + srv.address().port + '/index.html';
  const browser = await chromium.launch();
  for (const lang of ['en', 'es']) {
    for (const dev of DEVICES) {
      const dir = path.join(OUT, lang, dev.id); fs.mkdirSync(dir, { recursive: true });
      const ctx = await browser.newContext({ viewport: { width: dev.w, height: dev.h }, deviceScaleFactor: dev.scale, isMobile: true, hasTouch: true, userAgent: UA[dev.ua], reducedMotion: 'reduce', colorScheme: 'light' });
      if (FONT_CSS) await ctx.route(/fonts\.googleapis\.com/, r => r.fulfill({ contentType: 'text/css', body: FONT_CSS }));
      await ctx.route(/cloudflareinsights|fonts\.gstatic\.com/, r => FONT_CSS ? r.abort() : r.continue());
      await ctx.route(/workers\.dev/, r => {
        let b = {}; try { b = JSON.parse(r.request().postData() || '{}'); } catch (e) {}
        if (b.type !== 'feedback') return r.fulfill({ status: 204, body: '' });
        return r.fulfill({ contentType: 'application/json', body: JSON.stringify({ remaining: 14, feedback: SAMPLE[lang].fb }) });
      });
      const S = SAMPLE[lang];
      const state = { role: 'fa', set: 'core', welcomed: true, answered: 9, airline: '',
        days: [ymd(-4), ymd(-3), ymd(-2), ymd(-1), ymd(0)], interview: ymd(9), favs: {},
        stories: [{ id: 's1', title: S.story.title, s: S.story.s, t: '', a: S.story.a, r: S.story.r, types: ['upset', 'above'] }],
        seen: {}, history: {} };
      await ctx.addInitScript(([lang, st]) => {
        try { if (sessionStorage.getItem('seeded')) return; sessionStorage.setItem('seeded', '1');
          localStorage.setItem('cft-lang', lang); localStorage.setItem('cft_v1', JSON.stringify(st)); localStorage.removeItem('cft-theme'); } catch (e) {}
      }, [lang, state]);
      const p = await ctx.newPage();
      await p.goto(base, { waitUntil: 'networkidle' });
      await p.evaluate(() => document.fonts && document.fonts.ready);
      await p.waitForTimeout(400);
      // fill in some earlier practice so the header and history look lived-in (English text is the key in any language)
      await p.evaluate(([d1, d2]) => {
        const o = JSON.parse(localStorage.getItem('cft_v1'));
        const qs = ['Tell me about a time you turned around an upset customer.', 'Describe a time you went above and beyond for someone.', 'Tell me about a time you helped a coworker who was struggling.',
          'Tell me about a time plans changed at the last minute. How did you adapt?', 'Describe a stressful day at work and how you stayed calm.', 'Tell me about a mistake you made and how you fixed it.',
          'Why do you want to work for an airline?', 'Tell me about yourself.'];
        qs.forEach(q => { o.seen['core:' + q] = 1; });
        o.history['core:' + qs[0]] = [{ d: d1, score: 3, text: '' }, { d: d2, score: 5, text: '' }];
        o.history['core:' + qs[1]] = [{ d: d1, score: 4, text: '' }];
        o.history['core:' + qs[4]] = [{ d: d2, score: 4, text: '' }];
        localStorage.setItem('cft_v1', JSON.stringify(o));
      }, [ymd(-2), ymd(-1)]);
      await p.reload({ waitUntil: 'networkidle' }); await p.evaluate(() => document.fonts && document.fonts.ready); await p.waitForTimeout(300);
      let n = 0; const shot = async (name) => { await p.waitForTimeout(250); await p.screenshot({ path: path.join(dir, String(++n).padStart(2, '0') + '-' + name + '.png') }); };
      // 1. Question of the day, answer typed in
      await p.fill('#answer', S.answer); await p.evaluate(() => document.activeElement.blur());
      await p.evaluate(() => window.scrollTo(0, 0)); await shot('practice');
      // 2. AI feedback with a stronger version
      await p.click('#btnFeedback'); await p.waitForSelector('#feedback:not([hidden])'); await p.waitForTimeout(300);
      await p.evaluate(() => { const f = document.getElementById('feedback'); if (window.innerWidth < 900) window.scrollTo(0, f.getBoundingClientRect().top + scrollY - document.querySelector('.top').offsetHeight - 10); });
      await shot('feedback');
      // 3. My stories
      await p.click('#t-stories'); await p.evaluate(() => { const l = document.getElementById('storyList'); if (window.innerWidth < 900) window.scrollTo(0, 0); }); await shot('stories');
      // 4. Flight Deck menu
      await p.click('#t-practice'); await p.click('#menuBtn'); await shot('flight-deck');
      // 5. Practice history
      await p.click('[data-act="history"]'); await p.click('.hl summary'); await shot('history');
      // 6. Tips
      await p.click('#sheetX'); await p.waitForTimeout(200); await p.click('#t-tips'); await shot('tips');
      await ctx.close();
      console.log('saved', lang, dev.id, dev.w * dev.scale + 'x' + dev.h * dev.scale);
    }
  }
  await browser.close(); srv.close();
})().catch(e => { console.error(e); process.exit(1); });
