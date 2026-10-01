import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import assert from 'node:assert/strict';
const entries = execFileSync('git', ['ls-files', '--stage'], {
  encoding: 'utf8',
})
  .trim()
  .split('\n')
  .filter(Boolean);
const rules = [
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/,
  /\b(?:ghp|gho|ghu|ghs|github_pat)_[A-Za-z0-9_]{20,}\b/,
  /\bAKIA[0-9A-Z]{16}\b/,
  /\bsk-[A-Za-z0-9_-]{24,}\b/,
  /\/Users\/[^/]+\//,
];
const errors = [];
for (const entry of entries) {
  const [metadata, file] = entry.split('\t');
  const mode = metadata.split(' ')[0];
  if (mode !== '100644' && mode !== '100755') {
    errors.push(`${file}: unsupported file mode`);
    continue;
  }
  if (
    /(?:^|\/)(?:node_modules|dist|build|test-results|\.private)(?:\/|$)|(?:^|\/)\.env|\.(?:pem|p12|key|mobileprovision|zip|pdf|epub|png|jpe?g|woff2?|ttf|otf)$/i.test(
      file,
    )
  ) {
    errors.push(`${file}: excluded asset`);
    continue;
  }
  const raw = readFileSync(file);
  if (raw.includes(0)) {
    errors.push(`${file}: binary content`);
    continue;
  }
  const text = raw.toString('utf8');
  for (const pattern of rules)
    if (pattern.test(text)) {
      errors.push(`${file}: secret or personal-path pattern`);
      break;
    }
}
assert.equal(
  execFileSync('git', ['hash-object', 'LICENSE'], { encoding: 'utf8' }).trim(),
  'f23ede7e4a57a42d4afea20c01b244991fa344a5',
  'AGPL text must match pinned upstream license verbatim',
);
const lock = JSON.parse(readFileSync('package-lock.json', 'utf8'));
for (const [name, p] of Object.entries(lock.packages))
  if (name) {
    assert(p.integrity, `${name}: missing integrity`);
    assert(
      new URL(p.resolved).hostname === 'registry.npmjs.org',
      `${name}: unexpected registry`,
    );
  }
if (errors.length) {
  console.error(errors.join('\n'));
  process.exitCode = 1;
} else
  console.log(
    `Source review: ${entries.length} tracked/staged text files; no scanned secret/personal-path patterns, excluded binaries or private assets; AGPL and official lock integrity verified.`,
  );
