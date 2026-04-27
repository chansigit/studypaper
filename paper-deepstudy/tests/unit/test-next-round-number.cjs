const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');
const { nextRoundNumber } = require('../../scripts/next-round-number.cjs');

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'pds-rn-test-'));
try {
  // Test 1: nonexistent directory → 1
  assert.strictEqual(nextRoundNumber(path.join(tmp, 'nope')), 1);

  // Test 2: empty directory → 1
  fs.mkdirSync(path.join(tmp, 'empty'));
  assert.strictEqual(nextRoundNumber(path.join(tmp, 'empty')), 1);

  // Test 3: directory with one round → 2
  const d3 = path.join(tmp, 'd3');
  fs.mkdirSync(d3);
  fs.writeFileSync(path.join(d3, 'round-01-baseline-fairness.md'), '');
  assert.strictEqual(nextRoundNumber(d3), 2);

  // Test 4: directory with multiple rounds (non-contiguous) → max + 1
  const d4 = path.join(tmp, 'd4');
  fs.mkdirSync(d4);
  fs.writeFileSync(path.join(d4, 'round-01-foo.md'), '');
  fs.writeFileSync(path.join(d4, 'round-03-bar.md'), '');
  fs.writeFileSync(path.join(d4, 'round-07-baz.md'), '');
  assert.strictEqual(nextRoundNumber(d4), 8);

  // Test 5: directory with malformed names is robust (ignores them)
  const d5 = path.join(tmp, 'd5');
  fs.mkdirSync(d5);
  fs.writeFileSync(path.join(d5, 'round-02-ok.md'), '');
  fs.writeFileSync(path.join(d5, 'README.md'), '');                   // ignored
  fs.writeFileSync(path.join(d5, 'round-foo-bad.md'), '');             // ignored
  fs.writeFileSync(path.join(d5, 'round-99.md'), '');                  // ignored (no slug part)
  assert.strictEqual(nextRoundNumber(d5), 3);

  // Test 6: zero-padded numbers > 9 (round-10-...) parsed correctly
  const d6 = path.join(tmp, 'd6');
  fs.mkdirSync(d6);
  fs.writeFileSync(path.join(d6, 'round-09-foo.md'), '');
  fs.writeFileSync(path.join(d6, 'round-10-bar.md'), '');
  fs.writeFileSync(path.join(d6, 'round-11-baz.md'), '');
  assert.strictEqual(nextRoundNumber(d6), 12);

  console.log('next-round-number: all tests passed');
} finally {
  fs.rmSync(tmp, { recursive: true });
}
