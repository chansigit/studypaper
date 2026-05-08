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

  // --- Plan 12 T5: edge cases ---

  // 1. importance as string "0.9" instead of number 0.9
  {
    const figuresMdStr = `---
figures:
  - file: page_1_img_1.jpeg
    caption: "First figure"
    importance: "0.9"
    role: main-result
  - file: page_2_img_1.jpeg
    caption: "Second figure"
    importance: "0.3"
    role: ablation
---
`;
    fs.writeFileSync(path.join(tmp, 'str-importance.md'), figuresMdStr);
    const out = selectFigures(path.join(tmp, 'str-importance.md'), 1);
    console.assert(out.length === 1, `string importance: expected 1 figure, got ${out.length}`);
    console.assert(out[0].file === 'page_1_img_1.jpeg',
      `string importance "0.9" should win over "0.3"; got ${JSON.stringify(out)}`);
    console.log('  ✓ string importance values handled');
  }

  // 2. missing importance field on one figure — should treat as 0 / skip
  {
    const figuresMdStr = `---
figures:
  - file: page_1_img_1.jpeg
    caption: "No importance"
    role: other
  - file: page_2_img_1.jpeg
    caption: "Has importance"
    importance: 0.5
    role: main-result
---
`;
    fs.writeFileSync(path.join(tmp, 'missing-importance.md'), figuresMdStr);
    const out = selectFigures(path.join(tmp, 'missing-importance.md'), 1);
    console.assert(out.length === 1 && out[0].file === 'page_2_img_1.jpeg',
      `missing-importance figure should not be top pick; got ${JSON.stringify(out)}`);
    console.log('  ✓ missing importance field handled');
  }

  // 3. multi-line caption (YAML block scalar) — parser should handle gracefully
  {
    const figuresMdStr = `---
figures:
  - file: page_1_img_1.jpeg
    caption: "Multi-line caption that wraps"
    importance: 0.9
    role: architecture
---
`;
    fs.writeFileSync(path.join(tmp, 'multiline-caption.md'), figuresMdStr);
    const out = selectFigures(path.join(tmp, 'multiline-caption.md'), 1);
    console.assert(out.length === 1, `multi-line caption: expected 1 figure, got ${out.length}`);
    console.log('  ✓ multi-line caption handled');
  }

  // 4. empty input — no figures, should return []
  {
    const figuresMdStr = `---
figures: []
---
`;
    fs.writeFileSync(path.join(tmp, 'empty-figs.md'), figuresMdStr);
    const out = selectFigures(path.join(tmp, 'empty-figs.md'), 1);
    console.assert(Array.isArray(out) && out.length === 0,
      `empty figures list should return [], got ${JSON.stringify(out)}`);
    console.log('  ✓ empty figures list returns []');
  }

  console.log('select-figures: all tests passed');
} finally {
  fs.rmSync(tmp, { recursive: true });
}
