import { readFile, writeFile } from 'node:fs/promises';
const lock = JSON.parse(await readFile('package-lock.json', 'utf8'));
const entries = Object.entries(lock.packages)
  .filter(([name]) => name)
  .map(([location, p]) => ({
    name: location.split('node_modules/').at(-1),
    version: p.version,
    license: p.license ?? 'VERIFY',
    resolved: p.resolved ?? null,
    dev: p.dev ?? false,
  }))
  .sort((a, b) => a.name.localeCompare(b.name));
await writeFile(
  'docs/dependency-inventory.json',
  JSON.stringify(
    { lockfileVersion: lock.lockfileVersion, packages: entries },
    null,
    2,
  ) + '\n',
);
const names = new Set(entries.map((p) => p.license));
console.log(
  `Recorded ${entries.length} locked dependency entries; license values: ${[...names].join(', ')}`,
);
if (entries.some((p) => p.license === 'VERIFY')) process.exitCode = 1;
