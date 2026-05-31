#!/usr/bin/env node
/**
 * Build bundled traffic-sign index and iOS asset catalog from @osm-traffic-signs/converter.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import {
  countryDefinitions,
  countries,
  namedTrafficSignValues,
  buildRedirectMap,
  trafficSignTagToSigns,
  signsToTrafficSignTagValue,
  createSvgFilename,
} from '@osm-traffic-signs/converter';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const outDir = __dirname;
const assetsDir = path.join(outDir, 'TrafficSigns.xcassets');

/** Frequently used DE signs (osmValuePart without country prefix). */
const FREQUENTLY_USED_DE = [
  '205',
  '206',
  '267',
  '274.1',
  '274.2',
  '277',
  '283',
  '286',
  '301',
  '306',
  '310',
  '314',
  '314.1',
  '314.2',
  '325.1',
  '330.1',
  '331.1',
  'city_limit',
  'maxspeed',
  'stop',
  'give_way',
];

function searchTokens(sign) {
  const parts = [
    sign.signId,
    sign.osmValuePart,
    sign.name,
    sign.descriptiveName,
    sign.description,
  ];
  return [...new Set(parts.filter(Boolean).flatMap((s) => String(s).toLowerCase().split(/[\s,;/]+/)))];
}

function ensureDir(dir) {
  fs.mkdirSync(dir, { recursive: true });
}

function writeImageset(name, svgPath) {
  const imagesetDir = path.join(assetsDir, `${name}.imageset`);
  ensureDir(imagesetDir);
  const destSvg = path.join(imagesetDir, `${name}.svg`);
  fs.copyFileSync(svgPath, destSvg);
  fs.writeFileSync(
    path.join(imagesetDir, 'Contents.json'),
    JSON.stringify(
      {
        images: [{ filename: `${name}.svg`, idiom: 'universal' }],
        info: { author: 'xcode', version: 1 },
        properties: { 'preserves-vector-representation': true },
      },
      null,
      2,
    ),
  );
}

function buildCountryCatalog(countryCode) {
  const signs = countryDefinitions[countryCode];
  const redirectMap = buildRedirectMap(signs);
  const redirects = Object.fromEntries(redirectMap.entries());

  const entries = signs.map((sign) => {
    const imageName = createSvgFilename(countryCode, sign.osmValuePart);
    return {
      osmValuePart: sign.osmValuePart,
      signId: sign.signId,
      name: sign.name,
      descriptiveName: sign.descriptiveName,
      kind: sign.kind,
      imageName,
      searchTokens: searchTokens(sign),
    };
  });

  const frequent = FREQUENTLY_USED_DE.filter((id) =>
    entries.some((e) => e.osmValuePart === id || e.signId === id),
  );

  return { entries, redirects, frequent };
}

function copySvgs(countryCode) {
  const svgDir = path.join(
    __dirname,
    'node_modules',
    '@osm-traffic-signs',
    'converter',
    'dist',
    'data-svgs',
    countryCode,
    'svgs',
  );
  if (!fs.existsSync(svgDir)) {
    console.error(`SVG directory not found: ${svgDir}`);
    process.exit(1);
  }
  ensureDir(assetsDir);
  fs.writeFileSync(
    path.join(assetsDir, 'Contents.json'),
    JSON.stringify({ info: { author: 'xcode', version: 1 } }, null, 2),
  );
  for (const file of fs.readdirSync(svgDir)) {
    if (!file.endsWith('.svg')) continue;
    const base = file.replace(/\.svg$/, '');
    writeImageset(base, path.join(svgDir, file));
  }
}

// Validate compose/decompose round-trip samples
const samples = ['DE:205', 'DE:310;city_limit', 'DE:244.1,"Kfz-Verkehr frei"'];
for (const sample of samples) {
  for (const cc of countries) {
    const parts = trafficSignTagToSigns(sample, cc);
    const back = signsToTrafficSignTagValue(parts, cc);
    if (back && sample.startsWith(`${cc}:`) && back !== sample && !sample.includes('"')) {
      console.warn(`Round-trip mismatch for ${cc}: ${sample} -> ${back}`);
    }
  }
}

const catalogs = {};
for (const countryCode of countries) {
  catalogs[countryCode] = buildCountryCatalog(countryCode);
}

const index = {
  version: 1,
  countries,
  namedTrafficSignValues,
  catalogs,
};

fs.writeFileSync(path.join(outDir, 'TrafficSignIndex.json'), JSON.stringify(index));

copySvgs('DE');

console.log(
  `Built TrafficSignIndex.json (${countries.length} countries, ${catalogs.DE.entries.length} DE signs) and TrafficSigns.xcassets`,
);
