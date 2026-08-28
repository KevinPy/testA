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

// ── Repères de mise en page, mesurés sur la disposition tablette 1194×834 ────
const T = {
  page: { ox: 195, oy: 82, k: 0.736 },            // page 1000×1000 → écran
  tool: { x: 64, crayon: 222, feutre: 303, pot: 383, gomme: 464 },
  size: { x: 64, petit: 557, moyen: 621, grand: 685 },
  top: { home: 44, magic: 872, undo: 1014, redo: 1082, clear: 1150, y: 40 },
  addColor: { x: 1096, y: 118 },
  swatch: (i) => ({ x: 1045 + (i % 3) * 50, y: 178 + Math.floor(i / 3) * 50 }),
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

  await tap(page, 903, 128); // catégorie « Mes coloriages »
  await page.waitForTimeout(700);
  await shot(page, '02-mes-coloriages.png');
});

// 2. Une séance de coloriage en cours, faite au pointeur comme au doigt.
await withApp({ width: 1194, height: 834, dsr: 2 }, async (page) => {
  await tap(page, 207, 390); // « Le chat câlin »
  await page.waitForTimeout(1200);

  await tap(page, T.tool.x, T.tool.pot);
  for (const [color, pts] of [
    [C.ambre, [[330, 650], [500, 300], [800, 770], [370, 862], [630, 862]]],
    [C.sable, [[450, 480], [500, 730]]],
    [C.rose, [[310, 165], [690, 165], [500, 462]]],
    [C.vert, [[415, 355], [585, 355]]],
  ]) {
    await tap(page, T.swatch(color).x, T.swatch(color).y);
    for (const [x, y] of pts) {
      const s = P(x, y);
      await tap(page, s.x, s.y);
    }
  }

  // Le crayon de cire par-dessus l'aplat : grain visible, couleur qui se dépose.
  await tap(page, T.tool.x, T.tool.crayon);
  await tap(page, T.swatch(C.corail).x, T.swatch(C.corail).y);
  await tap(page, T.size.x, T.size.moyen);
  await stroke(page, [P(430, 700), P(470, 780), P(540, 700), P(575, 790)]);
  await stroke(page, [P(430, 760), P(500, 690), P(560, 780)]);
  await page.waitForTimeout(400);
  await shot(page, '03-coloriage-en-cours.png');

  // 3. Démonstration des zones magiques : un gribouillage volontairement
  //    débordant. Le trait ne quitte pas la zone touchée au premier contact.
  await tap(page, T.tool.x, T.tool.feutre);
  await tap(page, T.swatch(C.ciel).x, T.swatch(C.ciel).y);
  await tap(page, T.size.x, T.size.grand);
  await stroke(page, [P(430, 560), P(900, 420), P(300, 640), P(880, 700), P(360, 500)]);
  await page.waitForTimeout(400);
  await shot(page, '04-zones-magiques.png');

  await tap(page, T.top.undo, T.top.y);
  await page.waitForTimeout(400);

  // 4. Le même geste en mode libre : la couleur va partout — mais toujours
  //    SOUS le trait noir, qui reste net.
  await tap(page, T.top.magic, T.top.y);
  await page.waitForTimeout(300);
  await stroke(page, [P(430, 560), P(900, 420), P(300, 640), P(880, 700), P(360, 500)]);
  await page.waitForTimeout(400);
  await shot(page, '05-mode-libre.png');

  await tap(page, T.top.undo, T.top.y);
  await tap(page, T.top.magic, T.top.y);
  await page.waitForTimeout(400);

  // 5. La modale RVB.
  await tap(page, T.addColor.x, T.addColor.y);
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
  await tap(page, 157, 640);   // « Le hibou de nuit », 2e rangée
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

  await tap(page, 100, 300); // 1re carte
  await page.waitForTimeout(1400);
  await shot(page, '09-coloriage-telephone.png');
});

// ═══════════════════════════ RÉGLAGES ══════════════════════════════════════
// L'espace parents, derrière l'appui maintenu, et la même galerie en anglais.
await withApp({ width: 1194, height: 834, dsr: 2 }, async (page) => {
  await tap(page, 1148, 44);                      // bouton réglages
  await page.waitForTimeout(900);
  await shot(page, '12-controle-parental.png');

  await page.mouse.move(652, 471);                // appui maintenu 2 s
  await page.mouse.down();
  await page.waitForTimeout(2400);
  await page.mouse.up();
  await page.waitForTimeout(900);
  await shot(page, '13-reglages-langue.png');
});

// Appareil réglé en anglais : l'application suit, titres des dessins compris.
await withApp({ width: 1194, height: 834, dsr: 2, locale: 'en-US' }, async (page) => {
  await shot(page, '14-galerie-anglais.png');
  await tap(page, 157, 320);                      // « The cuddly cat »
  await page.waitForTimeout(1300);
  await tap(page, T.addColor.x, T.addColor.y);    // modale RVB en anglais
  await page.waitForTimeout(900);
  await shot(page, '15-modale-rvb-anglais.png');
});

// ═══════════════════════════ ATELIER ═══════════════════════════════════════
// Un dessin fait à la main, puis le coloriage qui en est déduit.
const AT = (x, y) => ({ x: 313 + x * 0.568, y: 76 + y * 0.568 });
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
  await page.waitForTimeout(1200);
  await stroke(page, ring(500, 300, 190), { steps: 2 });
  await stroke(page, ring(500, 700, 250), { steps: 2 });
  await stroke(page, [AT(430, 260), AT(440, 300)], { steps: 6 });
  await stroke(page, [AT(570, 260), AT(580, 300)], { steps: 6 });
  await stroke(page, [AT(430, 360), AT(500, 400), AT(570, 360)], { steps: 8 });
  await shot(page, '16-atelier-dessin.png');

  await tap(page, 596, 788);                       // « En faire un coloriage »
  await page.waitForTimeout(3500);

  await tap(page, T.tool.x, T.tool.pot);
  for (const [color, pt] of [[3, P(500, 300)], [10, P(500, 700)], [6, P(90, 930)]]) {
    await tap(page, T.swatch(color).x, T.swatch(color).y);
    await tap(page, pt.x, pt.y);
  }
  await page.waitForTimeout(400);
  await shot(page, '17-atelier-coloriage.png');

  await tap(page, T.top.home, T.top.y);            // retour galerie
  await page.waitForTimeout(1000);
  await shot(page, '18-mes-dessins.png');
});

console.log('\nCaptures écrites dans docs/screenshots/');
