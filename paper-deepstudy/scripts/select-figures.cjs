#!/usr/bin/env node
// Pure-logic figure picker. Reads `analysis/06-figures.md`, returns top-N by importance.
const fs = require('node:fs');

function parseFiguresFrontmatter(filePath) {
  const text = fs.readFileSync(filePath, 'utf8');
  const match = text.match(/^---\n([\s\S]*?)\n---/);
  if (!match) throw new Error(`No YAML frontmatter in ${filePath}`);
  const yaml = match[1];

  // Lightweight parse: we only need the `figures:` list.
  const lines = yaml.split('\n');
  const figures = [];
  let current = null;
  for (const line of lines) {
    if (/^\s*-\s+file:\s*/.test(line)) {
      if (current) figures.push(current);
      current = { file: line.replace(/^\s*-\s+file:\s*/, '').trim() };
    } else if (current) {
      const m = line.match(/^\s+(caption|importance|role):\s*(.*)$/);
      if (m) {
        const [, key, raw] = m;
        let val = raw.trim();
        if (val.startsWith('"') && val.endsWith('"')) val = val.slice(1, -1);
        if (key === 'importance') val = parseFloat(val);
        current[key] = val;
      }
    }
  }
  if (current) figures.push(current);
  return figures;
}

function selectFigures(figuresMdPath, n) {
  const figures = parseFiguresFrontmatter(figuresMdPath);
  return figures
    .filter(f => typeof f.importance === 'number' && f.importance > 0.3)
    .sort((a, b) => b.importance - a.importance)
    .slice(0, n);
}

if (require.main === module) {
  const [path, nStr] = process.argv.slice(2);
  if (!path || !nStr) {
    console.error('usage: select-figures.cjs <06-figures.md path> <n>');
    process.exit(1);
  }
  const picks = selectFigures(path, parseInt(nStr, 10));
  console.log(JSON.stringify(picks, null, 2));
}

module.exports = { selectFigures, parseFiguresFrontmatter };
