import { execFileSync } from 'node:child_process';
import assert from 'node:assert/strict';
const binary = 'native/build/Build/Products/Release/PDFnoBridge';
const result = JSON.parse(
  execFileSync(binary, ['capabilities'], { encoding: 'utf8' }),
);
assert.deepEqual(result, {
  schemaVersion: 1,
  bridgeVersion: '0.1.0',
  platform: 'macOS',
  keychain: 'not-integrated',
  iCloud: 'disabled',
});
let rejected = false;
try {
  execFileSync(binary, ['read-file', '/tmp/example'], { stdio: 'pipe' });
} catch (e) {
  rejected = e.status === 64;
}
assert(rejected, 'arbitrary operations must be rejected');
console.log('Native capability protocol and rejected operation: PASS');
