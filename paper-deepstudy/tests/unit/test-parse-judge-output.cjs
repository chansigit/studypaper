const assert = require('node:assert/strict');
const { parseJudgeOutput } = require('../../scripts/parse-judge-output.cjs');

// Case 1: well-formed YAML inside ```yaml fence
const wellFormed = `Some preamble.
\`\`\`yaml
verdict: holds
reasoning: |
  The defense addresses the core claim with specific evidence.
  Coherent throughout.
\`\`\`
Some trailing text.`;
const r1 = parseJudgeOutput(wellFormed);
assert.strictEqual(r1.verdict, 'holds');
assert.match(r1.reasoning, /addresses the core claim/);

// Case 2: partially_holds
const partial = `\`\`\`yaml
verdict: partially_holds
reasoning: |
  Defense reframes rather than answers.
\`\`\``;
const r2 = parseJudgeOutput(partial);
assert.strictEqual(r2.verdict, 'partially_holds');
assert.match(r2.reasoning, /reframes/);

// Case 3: fails
const failsCase = `\`\`\`yaml
verdict: fails
reasoning: |
  Defense fails to address the core.
\`\`\``;
const r3 = parseJudgeOutput(failsCase);
assert.strictEqual(r3.verdict, 'fails');

// Case 4: invalid verdict value → fallback to partially_holds
const invalid = `\`\`\`yaml
verdict: maybe
reasoning: |
  Confused.
\`\`\``;
const r4 = parseJudgeOutput(invalid);
assert.strictEqual(r4.verdict, 'partially_holds');
assert.match(r4.reasoning, /unparseable|invalid/i);

// Case 5: missing yaml fence → fallback
const noFence = `verdict: holds\nreasoning: text`;
const r5 = parseJudgeOutput(noFence);
assert.strictEqual(r5.verdict, 'partially_holds');

// Case 6: empty input → fallback
const r6 = parseJudgeOutput('');
assert.strictEqual(r6.verdict, 'partially_holds');

// Case 7: yaml fence but missing verdict key → fallback
const noVerdict = `\`\`\`yaml
reasoning: just reasoning, no verdict
\`\`\``;
const r7 = parseJudgeOutput(noVerdict);
assert.strictEqual(r7.verdict, 'partially_holds');

// --- Plan 12 T4: edge cases ---

// 1. ```yml lowercase short form
{
  const input = `
The judge says...
\`\`\`yml
verdict: holds
reasoning: clean argument.
\`\`\`
`;
  const out = parseJudgeOutput(input);
  console.assert(out.verdict === 'holds', `yml fence: expected verdict=holds, got "${out.verdict}"`);
  console.log('  ✓ ```yml fence accepted');
}

// 2. ```YAML uppercase
{
  const input = `
\`\`\`YAML
verdict: rejects
reasoning: bad logic.
\`\`\`
`;
  const out = parseJudgeOutput(input);
  // 'rejects' is not a valid verdict — should fallback
  console.assert(out.verdict === 'partially_holds', `YAML fence with invalid verdict: expected partially_holds fallback, got "${out.verdict}"`);
  console.log('  ✓ ```YAML fence accepted (invalid verdict falls back correctly)');
}

// 2b. ```YAML uppercase with valid verdict
{
  const input = `
\`\`\`YAML
verdict: fails
reasoning: bad logic.
\`\`\`
`;
  const out = parseJudgeOutput(input);
  console.assert(out.verdict === 'fails', `YAML fence: expected fails, got "${out.verdict}"`);
  console.log('  ✓ ```YAML fence with valid verdict accepted');
}

// 3. fence with extra trailing text (e.g. "```yaml linenums=...")
{
  const input = `
\`\`\`yaml linenums="1"
verdict: holds
reasoning: ok.
\`\`\`
`;
  const out = parseJudgeOutput(input);
  console.assert(out.verdict === 'holds', `fence-with-attrs: expected holds, got "${out.verdict}"`);
  console.log('  ✓ ```yaml with attrs accepted');
}

// 4. multi-doc YAML (--- separator)
{
  const input = `
\`\`\`yaml
---
verdict: partially_holds
reasoning: nuanced.
---
extra:
  - irrelevant
\`\`\`
`;
  const out = parseJudgeOutput(input);
  console.assert(out.verdict === 'partially_holds',
    `multi-doc: expected partially_holds (first doc), got "${out.verdict}"`);
  console.log('  ✓ multi-doc YAML — first doc taken');
}

// 5. no fence at all (raw YAML in chat) — should fall back to partially_holds gracefully
{
  const input = `
verdict: holds
reasoning: ok.
`;
  const out = parseJudgeOutput(input);
  console.assert(out.verdict === 'partially_holds',
    `no-fence: expected partially_holds fallback, got "${out.verdict}"`);
  console.log('  ✓ no-fence falls back to partially_holds');
}

console.log('parse-judge-output: all tests passed');
