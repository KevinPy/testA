// Utilitaires de capture d'écran : pilote la vraie application (build web) dans
// Chromium. Les captures montrent donc le rendu réel du moteur, pas une maquette.
import { chromium } from 'playwright';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, existsSync, mkdirSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const CHROME = '/opt/pw-browsers/chromium-1194/chrome-linux/chrome';
const cacheDir = mkdtempSync(join(tmpdir(), 'fontcache-'));

/// Le conteneur n'a pas d'accès direct à fonts.gstatic.com, d'où l'absence
/// d'émojis. On les rapatrie via le proxy sortant, uniquement pour la capture :
/// sur iOS et Android la police émoji du système est utilisée nativement.
async function mirrorGoogleFonts(page) {
  await page.route('https://fonts.gstatic.com/**', async (route) => {
    const url = route.request().url();
    const file = join(cacheDir, Buffer.from(url).toString('base64url').slice(-90));
    try {
      if (!existsSync(file)) {
        execFileSync('curl', ['-sS', '--fail', '-o', file, url], { timeout: 60000 });
      }
      await route.fulfill({
        status: 200,
        body: readFileSync(file),
        headers: {
          'content-type': url.endsWith('.woff2') ? 'font/woff2' : 'application/octet-stream',
          'access-control-allow-origin': '*',
        },
      });
    } catch {
      await route.abort();
    }
  });
}

/// `locale` pilote la langue de l'appareil simulé. Sans elle, Chromium annonce
/// `en-US` et l'application — qui suit l'appareil par défaut — basculerait en
/// anglais dans toutes les captures.
export async function withApp(
  { width, height, dsr = 2, locale = 'fr-FR', downloadsPath }, fn) {
  const browser = await chromium.launch({ executablePath: CHROME, downloadsPath });
  const context = await browser.newContext({
    viewport: { width, height },
    deviceScaleFactor: dsr,
    hasTouch: true,
    isMobile: false,
    locale,
    acceptDownloads: true,
  });
  const page = await context.newPage();
  await mirrorGoogleFonts(page);
  await page.goto('http://localhost:8099/', { waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => !!document.querySelector('flt-glass-pane'), null, { timeout: 60000 });
  await page.waitForTimeout(4500);
  try {
    await fn(page, context);
  } finally {
    await browser.close();
  }
}

export function outDir(p) {
  mkdirSync(p, { recursive: true });
  return p;
}

/// Un trait « à la main » : le pointeur suit une courbe, comme un doigt.
export async function stroke(page, pts, { steps = 14 } = {}) {
  await page.mouse.move(pts[0].x, pts[0].y);
  await page.mouse.down();
  for (let i = 1; i < pts.length; i++) {
    const a = pts[i - 1], b = pts[i];
    for (let s = 1; s <= steps; s++) {
      await page.mouse.move(a.x + (b.x - a.x) * s / steps, a.y + (b.y - a.y) * s / steps);
    }
  }
  await page.mouse.up();
  await page.waitForTimeout(120);
}

export async function tap(page, x, y) {
  await page.mouse.click(x, y);
  await page.waitForTimeout(350);
}
