#!/usr/bin/env node
// Pure-logic helper: parse a judge-agent's output text and return { verdict, reasoning }.
// Falls back to {verdict: 'partially_holds', reasoning: '<reason>'} on any parse failure.
// The verdict must be one of holds | partially_holds | fails.

const VALID = new Set(['holds', 'partially_holds', 'fails']);
const FALLBACK = (msg) => ({
  verdict: 'partially_holds',
  reasoning: `Judge output unparseable: ${msg} — manual review required.`,
});

function parseJudgeOutput(text) {
  if (typeof text !== 'string' || text.length === 0) {
    return FALLBACK('empty or non-string input');
  }

  const fenceMatch = text.match(/```yaml\s*\n([\s\S]*?)\n```/);
  if (!fenceMatch) {
    return FALLBACK('no yaml-fenced block found');
  }
  const yaml = fenceMatch[1];

  // Lightweight parse — no full YAML library, just verdict + reasoning extraction.
  const verdictMatch = yaml.match(/^verdict:\s*(\S+)\s*$/m);
  if (!verdictMatch) {
    return FALLBACK('verdict key missing in yaml block');
  }
  const verdict = verdictMatch[1];
  if (!VALID.has(verdict)) {
    return FALLBACK(`invalid verdict value '${verdict}'`);
  }

  // reasoning may be a literal block (`|`) or a single line
  let reasoning;
  const literalMatch = yaml.match(/^reasoning:\s*\|\s*\n((?:\s+.*(?:\n|$))*)/m);
  if (literalMatch) {
    reasoning = literalMatch[1].split('\n').map(l => l.replace(/^\s+/, '')).join(' ').trim();
  } else {
    const inlineMatch = yaml.match(/^reasoning:\s*(.+)$/m);
    reasoning = inlineMatch ? inlineMatch[1].trim() : '';
  }

  return { verdict, reasoning };
}

if (require.main === module) {
  const input = require('node:fs').readFileSync(0, 'utf8');
  console.log(JSON.stringify(parseJudgeOutput(input), null, 2));
}

module.exports = { parseJudgeOutput };
