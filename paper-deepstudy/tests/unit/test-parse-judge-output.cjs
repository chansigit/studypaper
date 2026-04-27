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

console.log('parse-judge-output: all tests passed');
