#!/usr/bin/env node
// Pure-logic helper: derive a round-file slug from an objection text.
// Lowercase, alphanumeric + hyphens only, first ~6 words, cap at 40 chars.
// Returns 'untitled' if the result would be empty.

function slugifyObjection(text) {
  if (typeof text !== 'string') return 'untitled';
  // Strip non-alphanumeric, treat all word separators (hyphens, apostrophes, etc.) as spaces
  const ascii = text.replace(/[^A-Za-z0-9]+/g, ' ');
  // Lowercase, normalize whitespace
  const normalized = ascii.toLowerCase().split(/\s+/).filter(w => w.length > 0);

  // Accumulate words up to ~35 chars or 6 words, whichever comes first
  const words = [];
  let slug = '';
  for (const w of normalized) {
    const candidate = words.length === 0 ? w : slug + '-' + w;
    if (candidate.length >= 35 || words.length >= 6) break;
    words.push(w);
    slug = candidate;
  }

  // Strip leading/trailing dashes
  slug = slug.replace(/^-+|-+$/g, '');
  // Collapse repeated dashes
  slug = slug.replace(/-+/g, '-');
  // Final cap at 40 chars (preserve word boundary if possible)
  if (slug.length > 40) {
    slug = slug.slice(0, 40);
    // Trim trailing partial word if cut mid-word
    slug = slug.replace(/-[^-]*$/, '');
  }
  // CJK fallback: if all ASCII has been stripped, derive a stable hash slug
  // from the original text so multi-CJK inputs don't all collide on 'untitled'.
  if (slug.length === 0) {
    // Detect: did the input have any CJK / non-ASCII content worth preserving?
    const hasCJK = /[一-鿿㐀-䶿豈-﫿぀-ゟ゠-ヿ]/.test(text);
    if (hasCJK) {
      // 6-char hex hash of the input text (deterministic, collision-resistant
      // enough for filenames, no new deps).
      const crypto = require('node:crypto');
      const hash = crypto.createHash('sha1').update(text).digest('hex').slice(0, 6);
      return `cjk-${hash}`;
    }
    return 'untitled';
  }
  return slug;
}

if (require.main === module) {
  const input = require('node:fs').readFileSync(0, 'utf8');
  console.log(slugifyObjection(input.trim()));
}

module.exports = { slugifyObjection };
