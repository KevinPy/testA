// Captures d'écran de Barbouille, prises dans l'application réelle (build web
// exécuté dans Chromium). Aucune maquette : ce que montrent ces images est ce
// que le moteur dessine.
//
//   cd app && flutter build web --release --no-web-resources-cdn
//   (cd app/build/web && python3 -m http.server 8099 &)
//   node tools/screenshots.mjs
import { withApp, stroke, tap, outDir } from './shotlib.mjs';
import { parsePages, artwork, seedScript } from './seed.mjs';
import { join } from 'node:path';

const OUT = outDir(new URL('../docs/screenshots', import.meta.url).pathname);
const pages = Object.fromEntries(parsePages().map((p) => [p.id, p]));

// ── Repères mesurés sur la disposition « côtés » en 1194×834 ────────────────
// La feuille carrée occupe toute la hauteur ; les commandes vivent dans les
// bandes latérales, et les outils dans un tiroir.
const T = {
  page: { ox: 180, oy: 0, k: 0.834 },
  home: { x: 38, y: 372 },
  menu: { x: 48, y: 452 },
  right: { x: 1156, magic: 280, undo: 346, redo: 412, clear: 478, capture: 544 },
  drawer: {
    tool: (i) => ({ x: 52 + i * 82, y: 128 }),
    size: (i) => ({ x: 52 + i * 72, y: 246 }),
    swatch: (i) => ({ x: 46 + (i % 5) * 67, y: 358 + Math.floor(i / 5) * 67 }),
    addColor: { x: 46, y: 358 },
  },
};
const P = (x, y) => ({ x: T.page.ox + x * T.page.k, y: T.page.oy + y * T.page.k });

// Index dans kDefaultPalette
const C = {
  rouge: 0, corail: 1, orange: 2, ambre: 3, jaune: 4, citron: 5,
  anis: 6, vert: 7, sapin: 8, turquoise: 9, ciel: 10, bleu: 11,
  outremer: 12, violet: 13, mauve: 14, rose: 15, framboise: 16,
  brun: 17, caramel: 18, sable: 19, noir: 20, gris: 21, argent: 22, blanc: 23,
};

const shot = (page, name) =>
  page.screenshot({ path: join(OUT, name) }).then(() => console.log('✓', name));

const openDrawer = async (page) => {
  await tap(page, T.menu.x, T.menu.y);
  await page.waitForTimeout(600);
};
const closeDrawer = async (page) => {
  await page.keyboard.press('Escape');
  // Le voile du tiroir absorbe les appuis pendant son animation de fermeture :
  // sans cette attente, le premier coup de pot de peinture se perd.
  await page.waitForTimeout(800);
};

/// Choisit un outil, puis une couleur, en une seule ouverture du tiroir.
async function choose(page, { tool, size, color }) {
  await openDrawer(page);
  if (tool !== undefined) await tap(page, T.drawer.tool(tool).x, T.drawer.tool(tool).y);
  if (size !== undefined) await tap(page, T.drawer.size(size).x, T.drawer.size(size).y);
  if (color !== undefined) {
    // La première case du nuancier est le bouton « créer une couleur ».
    const sw = T.drawer.swatch(color + 1);
    await tap(page, sw.x, sw.y);
  }
  await closeDrawer(page);
}

// ═══════════════════════════ TABLETTE ═══════════════════════════════════════

// 1. La galerie, avec quelques coloriages déjà commencés.
await withApp({ width: 1194, height: 834, dsr: 2 }, async (page) => {
  await page.evaluate(
    seedScript([
      ['papillon', artwork(pages.papillon)],
      ['fusee', artwork(pages.fusee, { skip: ['etoile1', 'etoile2', 'etoile3'] })],
      ['maison', artwork(pages.maison, { skip: ['herbe', 'ciel_soleil'] })],
      ['glace', artwork(pages.glace)],
      ['voiture', artwork(pages.voiture, { skip: ['route', 'phare_g', 'phare_d'] })],
    ]),
  );
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => !!document.querySelector('flt-glass-pane'));
  await page.waitForTimeout(4500);
  await shot(page, '01-galerie-tablette.png');

  await tap(page, 903, 128);
  await page.waitForTimeout(700);
  await shot(page, '02-mes-coloriages.png');
});

// 2. Une séance de coloriage, et le tiroir d'outils.
await withApp({ width: 1194, height: 834, dsr: 2 }, async (page) => {
  await tap(page, 157, 320);                      // « Le chat câlin »
  await page.waitForTimeout(1300);

  await choose(page, { tool: 2, color: C.ambre }); // pot de peinture
  for (const [x, y] of [[330, 650], [500, 300], [800, 770], [370, 862], [630, 862]]) {
    await tap(page, P(x, y).x, P(x, y).y);
  }
  await choose(page, { color: C.sable });
  for (const [x, y] of [[450, 480], [500, 730]]) {
    await tap(page, P(x, y).x, P(x, y).y);
  }
  await choose(page, { color: C.rose });
  for (const [x, y] of [[310, 165], [690, 165], [500, 462]]) {
    await tap(page, P(x, y).x, P(x, y).y);
  }
  await choose(page, { color: C.vert });
  for (const [x, y] of [[415, 355], [585, 355]]) {
    await tap(page, P(x, y).x, P(x, y).y);
  }

  // Le crayon de cire par-dessus l'aplat : grain visible.
  await choose(page, { tool: 0, size: 1, color: C.corail });
  await stroke(page, [P(430, 700), P(470, 780), P(540, 700), P(575, 790)]);
  await stroke(page, [P(430, 760), P(500, 690), P(560, 780)]);
  await page.waitForTimeout(400);
  await shot(page, '03-coloriage-en-cours.png');

  await openDrawer(page);
  await shot(page, '20-tiroir-outils.png');
  await closeDrawer(page);

  // 3. Zones magiques : un gribouillage volontairement débordant.
  await choose(page, { tool: 1, size: 2, color: C.ciel });
  await stroke(page, [P(430, 560), P(900, 420), P(300, 640), P(880, 700), P(360, 500)]);
  await page.waitForTimeout(400);
  await shot(page, '04-zones-magiques.png');

  await tap(page, T.right.x, T.right.undo);
  await page.waitForTimeout(400);

  // 4. Le même geste en mode libre.
  await tap(page, T.right.x, T.right.magic);
  await page.waitForTimeout(300);
  await stroke(page, [P(430, 560), P(900, 420), P(300, 640), P(880, 700), P(360, 500)]);
  await page.waitForTimeout(400);
  await shot(page, '05-mode-libre.png');

  await tap(page, T.right.x, T.right.undo);
  await tap(page, T.right.x, T.right.magic);
  await page.waitForTimeout(400);

  // 5. La modale RVB, depuis le tiroir.
  await openDrawer(page);
  await tap(page, T.drawer.addColor.x, T.drawer.addColor.y);
  await page.waitForTimeout(900);
  await shot(page, '06-modale-rvb.png');
});

// 6. Une œuvre terminée, plein cadre.
await withApp({ width: 1194, height: 834, dsr: 2 }, async (page) => {
  await page.evaluate(seedScript([['hibou', artwork(pages.hibou)]]));
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => !!document.querySelector('flt-glass-pane'));
  await page.waitForTimeout(4500);
  await tap(page, 218, 128);   // catégorie « Animaux »
  await page.waitForTimeout(700);
  await tap(page, 157, 640);   // « Le hibou de nuit »
  await page.waitForTimeout(1400);
  await shot(page, '07-oeuvre-terminee.png');
});

// ═══════════════════════════ TÉLÉPHONE ══════════════════════════════════════
await withApp({ width: 390, height: 844, dsr: 3 }, async (page) => {
  await page.evaluate(
    seedScript([
      ['papillon', artwork(pages.papillon)],
      ['fusee', artwork(pages.fusee, { skip: ['etoile1', 'etoile2', 'etoile3'] })],
    ]),
  );
  await page.reload({ waitUntil: 'domcontentloaded' });
  await page.waitForFunction(() => !!document.querySelector('flt-glass-pane'));
  await page.waitForTimeout(4500);
  await shot(page, '08-galerie-telephone.png');

  await tap(page, 100, 300);
  await page.waitForTimeout(1400);
  await shot(page, '09-coloriage-telephone.png');
});

// Paysage sur iPhone : le cas qui a motivé la refonte.
await withApp({ width: 852, height: 393, dsr: 3 }, async (page) => {
  await tap(page, 150, 250);
  await page.waitForTimeout(1500);
  await shot(page, '21-paysage-iphone.png');
});

// ═══════════════════════════ RÉGLAGES ══════════════════════════════════════
await withApp({ width: 1194, height: 834, dsr: 2 }, async (page) => {
  await tap(page, 1148, 44);
  await page.waitForTimeout(900);
  await shot(page, '12-controle-parental.png');

  await page.mouse.move(652, 471);
  await page.mouse.down();
  await page.waitForTimeout(2400);
  await page.mouse.up();
  await page.waitForTimeout(900);
  await shot(page, '13-reglages-langue.png');
});

// Appareil réglé en anglais : l'application suit, titres des dessins compris.
await withApp({ width: 1194, height: 834, dsr: 2, locale: 'en-US' }, async (page) => {
  await shot(page, '14-galerie-anglais.png');
  await tap(page, 157, 320);
  await page.waitForTimeout(1300);
  await openDrawer(page);
  await tap(page, T.drawer.addColor.x, T.drawer.addColor.y);
  await page.waitForTimeout(900);
  await shot(page, '15-modale-rvb-anglais.png');
});

// ═══════════════════════════ CAPTURE ═══════════════════════════════════════
await withApp({ width: 1194, height: 834, dsr: 2 }, async (page) => {
  await tap(page, 157, 320);
  await page.waitForTimeout(1300);
  await choose(page, { tool: 2, color: C.ambre });
  for (const [x, y] of [[330, 650], [500, 300]]) {
    await tap(page, P(x, y).x, P(x, y).y);
  }
  await choose(page, { color: C.rose });
  await tap(page, P(310, 165).x, P(310, 165).y);
  await choose(page, { color: C.vert });
  for (const [x, y] of [[415, 355], [585, 355]]) {
    await tap(page, P(x, y).x, P(x, y).y);
  }
  await choose(page, { color: C.sable });
  await tap(page, P(450, 480).x, P(450, 480).y);

  await tap(page, T.right.x, T.right.capture);
  await page.waitForTimeout(2500);
  await shot(page, '19-capture.png');
});

// ═══════════════════════════ ATELIER ═══════════════════════════════════════
const AT = (x, y) => P(x, y);
function ring(cx, cy, r, n = 44) {
  const pts = [];
  for (let i = 0; i <= n; i++) {
    const a = (i / n) * Math.PI * 2;
    pts.push(AT(cx + Math.cos(a) * r, cy + Math.sin(a) * r));
  }
  return pts;
}

await withApp({ width: 1194, height: 834, dsr: 2 }, async (page) => {
  await tap(page, 1047, 51);                       // Atelier
  await page.waitForTimeout(1300);
  await stroke(page, ring(500, 300, 190), { steps: 2 });
  await stroke(page, ring(500, 700, 250), { steps: 2 });
  await stroke(page, [AT(430, 260), AT(440, 300)], { steps: 6 });
  await stroke(page, [AT(570, 260), AT(580, 300)], { steps: 6 });
  await stroke(page, [AT(430, 360), AT(500, 400), AT(570, 360)], { steps: 8 });
  await shot(page, '16-atelier-dessin.png');

  await tap(page, T.menu.x, T.menu.y + 90);        // « En faire un coloriage »
  await page.waitForTimeout(3500);

  await choose(page, { tool: 2, color: C.ambre });
  await tap(page, P(500, 300).x, P(500, 300).y);
  await choose(page, { color: C.ciel });
  await tap(page, P(500, 700).x, P(500, 700).y);
  await choose(page, { color: C.anis });
  await tap(page, P(90, 930).x, P(90, 930).y);
  await page.waitForTimeout(400);
  await shot(page, '17-atelier-coloriage.png');

  await tap(page, T.home.x, T.home.y);
  await page.waitForTimeout(1000);
  await shot(page, '18-mes-dessins.png');
});

console.log('\nCaptures écrites dans docs/screenshots/');
