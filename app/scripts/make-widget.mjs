// Copies the iPhone widget into the generated Xcode project folder and writes Questions.swift
// from the 30 shared questions in index.html (English) and lang/es.js (Spanish), so the widget
// always shows exactly the app's question of the day. Run from the app folder after `npx cap add ios`.
import fs from 'node:fs';
import path from 'node:path';
import vm from 'node:vm';
import { fileURLToPath } from 'node:url';

const APP = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const ROOT = path.dirname(APP);
const OUT = process.argv[2] || path.join(APP, 'ios', 'App', 'TakeoffWidget');

const html = fs.readFileSync(path.join(ROOT, 'index.html'), 'utf8');
const start = html.indexOf('var SHARED=[');
const end = html.indexOf('\n];', start);
if (start < 0 || end < 0) throw new Error('Could not find the SHARED questions in index.html');
const shared = vm.runInNewContext(html.slice(start + 'var SHARED='.length, end + 3));
const en = shared.map(q => q[1]);
if (en.length < 7 || en.some(q => typeof q !== 'string' || !q)) throw new Error('Unexpected question list');

const ctx = { window: {} };
vm.runInNewContext(fs.readFileSync(path.join(ROOT, 'lang', 'es.js'), 'utf8'), ctx);
const strings = (ctx.window.CFT_LANG_ES && ctx.window.CFT_LANG_ES.strings) || {};
const es = en.map(q => strings[q] || q);
const missing = en.filter(q => !strings[q]).length;

const lit = s => JSON.stringify(s); // JSON strings are valid Swift string literals for this text
const swift = `// Made by app/scripts/make-widget.mjs from index.html and lang/es.js. Don't edit by hand.
let qodEnglish: [String] = [
${en.map(q => '    ' + lit(q)).join(',\n')}
]

let qodSpanish: [String] = [
${es.map(q => '    ' + lit(q)).join(',\n')}
]
`;
fs.mkdirSync(OUT, { recursive: true });
for (const f of ['TakeoffWidget.swift', 'Info.plist']) fs.copyFileSync(path.join(APP, 'ios-widget', f), path.join(OUT, f));
fs.writeFileSync(path.join(OUT, 'Questions.swift'), swift);
console.log(`widget: ${en.length} questions written to ${OUT} (${missing} without a Spanish translation)`);
