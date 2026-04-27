const assert = require('node:assert/strict');
const { slugifyObjection } = require('../../scripts/slugify-objection.cjs');

// Basic case
assert.strictEqual(
  slugifyObjection("The baseline comparison in §4 uses a 3x smaller compute budget"),
  'the-baseline-comparison-in-4-uses'
);

// Drops punctuation, keeps alphanumeric only
assert.strictEqual(
  slugifyObjection("Claim 2: zero-shot generalization isn't supported because the test set leaks!"),
  'claim-2-zero-shot-generalization'
);

// Lowercases
assert.strictEqual(
  slugifyObjection("MISSING REPRODUCIBILITY: no random seed reported"),
  'missing-reproducibility-no-random'
);

// Caps at first ~6 words / 40 char
const long = slugifyObjection("This is a very long objection that goes on and on and on and exceeds the cap");
assert.ok(long.length <= 40, `expected length <= 40, got ${long.length}`);
const wordCount = long.split('-').length;
assert.ok(wordCount <= 6, `expected <= 6 words, got ${wordCount}`);

// Empty / whitespace input → 'untitled'
assert.strictEqual(slugifyObjection(''), 'untitled');
assert.strictEqual(slugifyObjection('   '), 'untitled');

// Chinese punctuation / non-ASCII content → strip to ASCII-only or 'untitled'
const chinese = slugifyObjection('实验设计有问题:基线不公平');
// Either 'untitled' (if all stripped) or some ASCII-rendered form is acceptable;
// the test asserts that whatever's returned is purely [a-z0-9-] and non-empty.
assert.match(chinese, /^[a-z0-9-]+$/, 'must be lowercase alphanumeric/hyphen');

// Multi-space and leading/trailing dashes are normalized
assert.strictEqual(
  slugifyObjection("  --leading dashes and    multiple   spaces--  "),
  'leading-dashes-and-multiple-spaces'
);

console.log('slugify-objection: all tests passed');
