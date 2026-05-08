#!/usr/bin/env node
// Pure-logic helper: given a directory of round-NN-<slug>.md files,
// return the next round number (max + 1, or 1 if directory empty/nonexistent).
const fs = require('node:fs');

function nextRoundNumber(dirPath) {
  let entries;
  try {
    entries = fs.readdirSync(dirPath);
  } catch (err) {
    if (err.code === 'ENOENT') return 1;
    throw err;
  }

  // Match round-NN-<slug>.md where NN is one or more digits and <slug> is non-empty.
  const re = /^round-(\d+)-[^.\s][^.]*\.md$/;
  let max = 0;
  for (const name of entries) {
    const m = name.match(re);
    if (!m) continue;
    const n = parseInt(m[1], 10);
    if (Number.isFinite(n) && n > max) max = n;
  }
  return max + 1;
}

if (require.main === module) {
  const [dir] = process.argv.slice(2);
  if (!dir) {
    console.error('usage: next-round-number.cjs <review-rounds-dir>');
    process.exit(1);
  }
  console.log(nextRoundNumber(dir));
}

module.exports = { nextRoundNumber };
