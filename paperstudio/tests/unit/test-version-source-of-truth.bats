#!/usr/bin/env bats
# tests/unit/test-version-source-of-truth.bats — `.claude-plugin/plugin.json`
# is the only place a paperstudio version string lives. Repeated version
# strings drift (we got bitten by package.json declaring 0.5.0 while
# plugin.json was at 0.6.0).

setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "package.json has no top-level version field" {
  ! grep -qE '^[[:space:]]*"version"[[:space:]]*:' package.json
}

@test "plugin.json declares a semver version" {
  grep -qE '"version":[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' .claude-plugin/plugin.json
}

@test "marketplace.json plugin entry version matches plugin.json version" {
  plugin_v=$(grep -oE '"version":[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' .claude-plugin/plugin.json | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  market_v=$(grep -oE '"version":[[:space:]]*"[0-9]+\.[0-9]+\.[0-9]+"' ../.claude-plugin/marketplace.json | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
  [ -n "$plugin_v" ]
  [ "$plugin_v" = "$market_v" ] || { echo "drift: plugin.json=$plugin_v, marketplace.json=$market_v"; return 1; }
}
