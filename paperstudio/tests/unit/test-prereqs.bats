#!/usr/bin/env bats

# Ensure tests run from the plugin root regardless of where bats was invoked.
setup() {
  cd "$BATS_TEST_DIRNAME/../.."
}

@test "plugin.json is valid JSON" {
  run python3 -c "import json,sys; json.load(open('.claude-plugin/plugin.json'))"
  [ "$status" -eq 0 ]
}

@test "package.json is valid JSON" {
  run python3 -c "import json,sys; json.load(open('package.json'))"
  [ "$status" -eq 0 ]
}

@test "verify-prereqs.sh exists and is executable" {
  [ -x scripts/verify-prereqs.sh ]
}

@test "verify-prereqs.sh succeeds when all deps present" {
  fake_home="$BATS_TEST_TMPDIR/home"
  fake_skill="$fake_home/.claude/plugins/cache/test-marketplace/claude-paper/1.0.0/skills/study/SKILL.md"
  mkdir -p "$(dirname "$fake_skill")"
  touch "$fake_skill"

  fake_bin="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$fake_bin"
  cat > "$fake_bin/node" <<'EOF'
#!/usr/bin/env bash
if [ "${1:-}" = "-p" ]; then
  echo 18
else
  echo "v18.0.0"
fi
EOF
  chmod +x "$fake_bin/node"
  cat > "$fake_bin/python3" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
  chmod +x "$fake_bin/python3"

  run env HOME="$fake_home" PATH="$fake_bin:$PATH" scripts/verify-prereqs.sh
  [ "$status" -eq 0 ]
}
