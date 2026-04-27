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

// Plan 9 I6: CJK-only input should not collapse to "untitled" — must produce
// a stable, distinguishable slug. Two different CJK inputs must produce
// different slugs.
const slug1 = slugifyObjection('对比学习损失推导');
const slug2 = slugifyObjection('注意力机制的推导');
assert.ok(slug1 !== 'untitled', `CJK input "对比学习损失推导" should not slug to "untitled", got "${slug1}"`);
assert.ok(slug2 !== 'untitled', `CJK input "注意力机制的推导" should not slug to "untitled", got "${slug2}"`);
assert.ok(slug1 !== slug2, `Different CJK inputs must produce different slugs, got "${slug1}" === "${slug2}"`);
// CJK-only slug should match the documented form: cjk- followed by 6 hex chars
assert.match(slug1, /^cjk-[a-f0-9]{6}$/, `CJK-only slug should match /^cjk-[a-f0-9]{6}$/, got "${slug1}"`);

console.log('slugify-objection: all tests passed');
