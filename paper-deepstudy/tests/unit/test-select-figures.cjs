const assert = require('node:assert/strict');
const path = require('node:path');
const fs = require('node:fs');
const os = require('node:os');
const { selectFigures } = require('../../scripts/select-figures.cjs');

// Create a temp dir with a fake 06-figures.md
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'pds-test-'));
try {
  const figuresMd = `---
figures:
  - file: figure-1.png
    caption: "Architecture overview"
    importance: 0.95
    role: architecture
  - file: figure-2.png
    caption: "Main results"
    importance: 0.85
    role: main-result
  - file: figure-3.png
    caption: "Ablation"
    importance: 0.6
    role: ablation
  - file: figure-4.png
    caption: "Decorative"
    importance: 0.1
    role: other
---

# Figures
`;
  fs.writeFileSync(path.join(tmp, '06-figures.md'), figuresMd);

  // Test xhs (1 figure): should pick the highest-importance one
  const xhsPicks = selectFigures(path.join(tmp, '06-figures.md'), 1);
  assert.deepEqual(xhsPicks.map(p => p.file), ['figure-1.png']);

  // Test wechat (3 figures): should pick top-3 by importance
  const wechatPicks = selectFigures(path.join(tmp, '06-figures.md'), 3);
  assert.deepEqual(wechatPicks.map(p => p.file), ['figure-1.png', 'figure-2.png', 'figure-3.png']);

  // Test wechat with only 2 high-importance: should pick what's available, dedup low
  const figuresMd2 = `---
figures:
  - file: f1.png
    caption: ""
    importance: 0.9
    role: architecture
  - file: f2.png
    caption: ""
    importance: 0.8
    role: main-result
---
`;
  fs.writeFileSync(path.join(tmp, 'few-figs.md'), figuresMd2);
  const fewPicks = selectFigures(path.join(tmp, 'few-figs.md'), 3);
  assert.deepEqual(fewPicks.map(p => p.file), ['f1.png', 'f2.png']);

  // Test bad path: throws
  assert.throws(() => selectFigures('/no/such/file', 1));

  console.log('select-figures: all tests passed');
} finally {
  fs.rmSync(tmp, { recursive: true });
}
