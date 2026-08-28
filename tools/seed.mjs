// Fabrique des coloriages « déjà commencés » pour peupler la galerie des
// captures d'écran. Les opérations produites sont exactement celles que
// l'application écrit elle-même (mêmes clés, même schéma de version).
import { readFileSync } from 'node:fs';

const src = readFileSync(new URL('../app/lib/data/pages.g.dart', import.meta.url), 'utf8');

/** @returns {{id: string, regions: {id: string, hint: number|null}[]}[]} */
export function parsePages() {
  const pages = [];
  let current = null;
  for (const line of src.split('\n')) {
    const idm = line.match(/^\s*id: '([^']+)',/);
    if (idm) {
      current = { id: idm[1], regions: [] };
      pages.push(current);
      continue;
    }
    const rm = line.match(/RegionData\('([^']+)',\s*'.*?'(?:,\s*hint:\s*(0x[0-9A-Fa-f]{8}))?\)/);
    if (rm && current) {
      current.regions.push({ id: rm[1], hint: rm[2] ? parseInt(rm[2], 16) : null });
    }
  }
  return pages;
}

/// Coloriage « au modèle » : chaque zone reçoit sa couleur suggérée.
/// `skip` laisse des zones blanches, pour un rendu « en cours ».
export function artwork(page, { skip = [] } = {}) {
  const ops = [];
  page.regions.forEach((r, i) => {
    if (r.hint == null || skip.includes(r.id)) return;
    ops.push({ t: 'f', r: i, c: r.hint });
  });
  return JSON.stringify({ v: 1, page: page.id, ops });
}

export function seedScript(entries) {
  return `(() => { ${entries
    .map(([id, json]) => `localStorage.setItem('flutter.artwork_${id}', ${JSON.stringify(JSON.stringify(json))});`)
    .join(' ')} })()`;
}
