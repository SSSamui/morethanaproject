// Renders Pork's poses to PNGs for the widgets, the Live Activity, the
// blocked-app screen and the app icon.
//   node tools/render_art.mjs     (needs Playwright with Chromium)
import { chromium } from 'playwright';
import { readFileSync, mkdirSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const root = join(here, '..');
const art = join(root, 'Shared', 'PorkArt.xcassets');
const appIcon = join(root, 'App', 'Assets.xcassets', 'AppIcon.appiconset');
const porkJs = readFileSync(join(here, 'pork.js'), 'utf8');
const roomHtml = readFileSync(join(root, 'App', 'room.html'), 'utf8');

const exe = process.env.CHROMIUM || undefined;
const browser = await chromium.launch(exe ? { executablePath: exe } : {});

function imageset(name, png) {
  const dir = join(art, name + '.imageset');
  mkdirSync(dir, { recursive: true });
  writeFileSync(join(dir, name + '.png'), png);
  writeFileSync(join(dir, 'Contents.json'), JSON.stringify({
    images: [{ idiom: 'universal', filename: name + '.png' }],
    info: { author: 'xcode', version: 1 }
  }, null, 2) + '\n');
}

const cap = s => s[0].toUpperCase() + s.slice(1);
const poses = ['sleep', 'wait', 'pace', 'door'];

// The whole room, one picture per pose (light colors).
{
  const page = await browser.newPage({ viewport: { width: 360, height: 200 }, deviceScaleFactor: 2, colorScheme: 'light' });
  await page.setContent(roomHtml);
  for (const pose of poses) {
    await page.evaluate(p => {
      const app = document.getElementById('app');
      app.dataset.still = '';
      setPork(p, false);
      if (p === 'pace') document.querySelector('.pupPos').style.transform = 'translate(150px, 112px)';
    }, pose);
    await page.waitForTimeout(100);
    imageset('Room' + cap(pose), await page.locator('#room').screenshot({ omitBackground: true }));
  }
  await page.close();
}

// Pork alone on a transparent background.
const porkPage = (viewBox, pose, w, h, bg = 'transparent') => `<!doctype html><html><head><style>
html,body{margin:0;background:${bg}} svg{display:block;width:${w}px;height:${h}px}
*{animation-play-state:paused!important;transition:none!important}
${PORK_CSS_PLACEHOLDER}
[data-pose="face"] .pork > :not(.head) { display: none; }</style></head><body><div data-pose="${pose}">
<svg viewBox="${viewBox}" xmlns="http://www.w3.org/2000/svg">${PORK_SVG_PLACEHOLDER}</svg></div></body></html>`;

const { PORK_SVG, PORK_CSS } = new Function(porkJs + '; return { PORK_SVG, PORK_CSS };')();
const PORK_CSS_PLACEHOLDER = PORK_CSS;
const PORK_SVG_PLACEHOLDER = PORK_SVG;

async function shot(html, w, h, scale, transparent = true) {
  const page = await browser.newPage({ viewport: { width: w, height: h }, deviceScaleFactor: scale });
  await page.setContent(html);
  await page.waitForTimeout(80);
  const png = await page.screenshot({ omitBackground: transparent, clip: { x: 0, y: 0, width: w, height: h } });
  await page.close();
  return png;
}

// Drawn on a big canvas, then cropped to Pork's outline.
for (const pose of poses) {
  const html = porkPage('-80 -80 280 200', pose, 560, 400);
  const page = await browser.newPage({ viewport: { width: 560, height: 400 }, deviceScaleFactor: 1 });
  await page.setContent(html);
  await page.waitForTimeout(80);
  const r = await page.evaluate(() => {
    const b = document.querySelector('.flip').getBoundingClientRect();
    return { x: b.x, y: b.y, width: b.width, height: b.height };
  });
  const pad = 6;
  const clip = { x: Math.max(0, r.x - pad), y: Math.max(0, r.y - pad), width: r.width + 2 * pad, height: r.height + 2 * pad };
  await page.close();
  const big = await browser.newPage({ viewport: { width: 560, height: 400 }, deviceScaleFactor: 1.6 });
  await big.setContent(html);
  await big.waitForTimeout(80);
  imageset('Pork' + cap(pose), await big.screenshot({ omitBackground: true, clip }));
  await big.close();
}

// Pork's face (Dynamic Island, small widgets).
const face = porkPage('60 -4 50 46', 'face', 100, 92);
imageset('PorkFace', await shot(face, 108, 100, 2));

// App icon: Pork's face on the beige wall color.
{
  const html = porkPage('52 -10 66 66', 'face', 1024, 1024, '#f6e7cf');
  const png = await shot(html, 1024, 1024, 1, false);
  mkdirSync(appIcon, { recursive: true });
  writeFileSync(join(appIcon, 'AppIcon.png'), png);
  writeFileSync(join(appIcon, 'Contents.json'), JSON.stringify({
    images: [{ idiom: 'universal', platform: 'ios', size: '1024x1024', filename: 'AppIcon.png' }],
    info: { author: 'xcode', version: 1 }
  }, null, 2) + '\n');
}

writeFileSync(join(art, 'Contents.json'), JSON.stringify({ info: { author: 'xcode', version: 1 } }, null, 2) + '\n');
await browser.close();
console.log('art done');
