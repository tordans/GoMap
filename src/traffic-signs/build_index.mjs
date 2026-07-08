#!/usr/bin/env node
/**
 * Build bundled traffic-sign index and iOS asset catalog from @osm-traffic-signs/converter.
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const converterDist = path.join(
  __dirname,
  'node_modules',
  '@osm-traffic-signs',
  'converter',
  'dist',
);

async function loadConverter() {
  // Import granular modules — the package main entry pulls in SVG loaders Node cannot resolve.
  const [
    { countryDefinitions, countries },
    { namedTrafficSignValues },
    { buildRedirectMap },
    { createSvgFilename },
    { trafficSignTagToSigns },
    { signsToTrafficSignTagValue },
  ] = await Promise.all([
    import(pathToFileURL(path.join(converterDist, 'data-definitions/countryDefinitions.js')).href),
    import(pathToFileURL(path.join(converterDist, 'data-definitions/namedTrafficSignValues.js')).href),
    import(pathToFileURL(path.join(converterDist, 'utils/buildRedirectMap.js')).href),
    import(pathToFileURL(path.join(converterDist, 'utils/createSvgFilename.js')).href),
    import(pathToFileURL(path.join(converterDist, 'trafficSignTagToSigns/trafficSignTagToSigns.js')).href),
    import(pathToFileURL(path.join(converterDist, 'signsToTrafficSignTag/signsToTrafficSignTagValue.js')).href),
  ]);
  return {
    countryDefinitions,
    countries,
    namedTrafficSignValues,
    buildRedirectMap,
    createSvgFilename,
    trafficSignTagToSigns,
    signsToTrafficSignTagValue,
  };
}

const {
  countryDefinitions,
  countries,
  namedTrafficSignValues,
  buildRedirectMap,
  trafficSignTagToSigns,
  signsToTrafficSignTagValue,
  createSvgFilename,
} = await loadConverter();
const outDir = __dirname;
const assetsDir = path.join(outDir, 'TrafficSigns.xcassets');

/** Curated frequently-used signs for Germany (osmValuePart without country prefix). */
const FREQUENTLY_USED_DE = [
  '205',
  '206',
  '267',
  '274.1',
  '274.2',
  '277',
  '301',
  '306',
  '325.1',
  '330.1',
  '331.1',
  'city_limit',
  'maxspeed',
  'stop',
  'give_way',
];

const FREQUENT_PATTERNS = [
  /stop/i,
  /yield|give way|vorfahrt gewähren|halt!/i,
  /speed|maxspeed|geschwindigkeit|limit|zone\s*\d/i,
  /no entry|verbot der einfahrt|interdit|sens interdit/i,
  /one.?way|einbahn/i,
  /priority|vorfahrt(?!stra)/i,
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

function findFrequentByPattern(countryCode, limit = 12) {
  const signs = countryDefinitions[countryCode];
  const picked = [];
  const seen = new Set();

  for (const pat of FREQUENT_PATTERNS) {
    for (const sign of signs) {
      if (sign.kind !== 'traffic_sign') continue;
      const text = `${sign.descriptiveName ?? ''} ${sign.name ?? ''} ${sign.osmValuePart}`;
      if (pat.test(text) && !seen.has(sign.osmValuePart)) {
        seen.add(sign.osmValuePart);
        picked.push(sign.osmValuePart);
        if (picked.length >= limit) return picked;
      }
    }
  }

  for (const sign of signs) {
    if (picked.length >= limit) break;
    if (
      sign.kind === 'traffic_sign' &&
      !seen.has(sign.osmValuePart) &&
      !sign.osmValuePart.includes('"')
    ) {
      seen.add(sign.osmValuePart);
      picked.push(sign.osmValuePart);
    }
  }
  return picked;
}

function frequentIdsForCountry(countryCode, entries) {
  const hasEntry = (id) => entries.some((e) => e.osmValuePart === id || e.signId === id);

  let ids;
  if (countryCode === 'DE') {
    ids = FREQUENTLY_USED_DE.filter(hasEntry);
  } else {
    ids = findFrequentByPattern(countryCode).filter(hasEntry);
  }

  const named = namedTrafficSignValues.filter(hasEntry);
  return [...new Set([...named, ...ids])].slice(0, 16);
}

function catalogEntriesForCountry(countryCode) {
  const signs = countryDefinitions[countryCode];
  const entries = signs.map((sign) => ({
    osmValuePart: sign.osmValuePart,
    signId: sign.signId,
    name: sign.name ?? sign.signId,
    // Some signs (e.g. unofficial ones) have no descriptiveName; fall back so
    // every entry decodes with a usable display string.
    descriptiveName: sign.descriptiveName ?? sign.name ?? sign.signId,
    kind: sign.kind,
    imageName: createSvgFilename(countryCode, sign.osmValuePart),
    isNamedValue: false,
    searchTokens: searchTokens(sign),
  }));

  const osmParts = new Set(entries.map((e) => e.osmValuePart));
  for (const named of namedTrafficSignValues) {
    if (!osmParts.has(named)) {
      entries.push({
        osmValuePart: named,
        signId: named,
        name: named,
        descriptiveName: named.replace(/_/g, ' '),
        kind: 'traffic_sign',
        imageName: '',
        isNamedValue: true,
        searchTokens: [named, ...named.split('_')],
      });
    }
  }
  return entries;
}

function buildCountryCatalog(countryCode) {
  const signs = countryDefinitions[countryCode];
  const redirectMap = buildRedirectMap(signs);
  const redirects = Object.fromEntries(redirectMap.entries());
  const entries = catalogEntriesForCountry(countryCode);
  const frequent = frequentIdsForCountry(countryCode, entries);
  return { entries, redirects, frequent };
}

function copySvgsForCountry(countryCode) {
  const svgDir = path.join(converterDist, 'data-svgs', countryCode, 'svgs');
  if (!fs.existsSync(svgDir)) {
    console.warn(`SVG directory not found for ${countryCode}: ${svgDir}`);
    return 0;
  }
  let count = 0;
  for (const file of fs.readdirSync(svgDir)) {
    if (!file.endsWith('.svg')) continue;
    const base = file.replace(/\.svg$/, '');
    writeImageset(base, path.join(svgDir, file));
    count += 1;
  }
  return count;
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
  version: 2,
  countries,
  namedTrafficSignValues,
  catalogs,
};

fs.writeFileSync(path.join(outDir, 'TrafficSignIndex.json'), JSON.stringify(index));

// Rebuild asset catalog from scratch
if (fs.existsSync(assetsDir)) {
  fs.rmSync(assetsDir, { recursive: true, force: true });
}
ensureDir(assetsDir);
fs.writeFileSync(
  path.join(assetsDir, 'Contents.json'),
  JSON.stringify({ info: { author: 'xcode', version: 1 } }, null, 2),
);

let totalSvgs = 0;
for (const countryCode of countries) {
  totalSvgs += copySvgsForCountry(countryCode);
}

const summary = countries
  .map((c) => `${c}:${catalogs[c].entries.length}`)
  .join(', ');
console.log(
  `Built TrafficSignIndex.json (${countries.length} countries: ${summary}) and TrafficSigns.xcassets (${totalSvgs} SVGs)`,
);
