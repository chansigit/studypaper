#!/usr/bin/env bats
# tests/unit/test-normalize-paper-url.bats — verify URL normalization for
# known paper hosts.

setup() {
  SCRIPT="${BATS_TEST_DIRNAME}/../../scripts/normalize-paper-url.sh"
}

@test "normalize-paper-url: arXiv abs/ becomes pdf/" {
  run "$SCRIPT" "https://arxiv.org/abs/1706.03762"
  [ "$status" -eq 0 ]
  [ "$output" = "https://arxiv.org/pdf/1706.03762.pdf" ]
}

@test "normalize-paper-url: arXiv abs/ with version is stripped to bare id" {
  run "$SCRIPT" "https://arxiv.org/abs/2401.12345v2"
  [ "$status" -eq 0 ]
  [ "$output" = "https://arxiv.org/pdf/2401.12345v2.pdf" ]
}

@test "normalize-paper-url: HuggingFace papers redirect to arXiv pdf" {
  run "$SCRIPT" "https://huggingface.co/papers/2401.12345"
  [ "$status" -eq 0 ]
  [ "$output" = "https://arxiv.org/pdf/2401.12345.pdf" ]
}

@test "normalize-paper-url: bioRxiv content page becomes .full.pdf" {
  run "$SCRIPT" "https://www.biorxiv.org/content/10.1101/2024.01.01.123456v1"
  [ "$status" -eq 0 ]
  [ "$output" = "https://www.biorxiv.org/content/10.1101/2024.01.01.123456v1.full.pdf" ]
}

@test "normalize-paper-url: bioRxiv .full suffix is collapsed not double-pdf'd" {
  run "$SCRIPT" "https://www.biorxiv.org/content/10.1101/2024.01.01.123456v1.full"
  [ "$status" -eq 0 ]
  [ "$output" = "https://www.biorxiv.org/content/10.1101/2024.01.01.123456v1.full.pdf" ]
}

@test "normalize-paper-url: medRxiv content page becomes .full.pdf" {
  run "$SCRIPT" "https://www.medrxiv.org/content/10.1101/2024.01.01.999999v1"
  [ "$status" -eq 0 ]
  [ "$output" = "https://www.medrxiv.org/content/10.1101/2024.01.01.999999v1.full.pdf" ]
}

@test "normalize-paper-url: ChemRxiv article-details page passes through unchanged" {
  run "$SCRIPT" "https://chemrxiv.org/engage/chemrxiv/article-details/63051dfe1945ad17cee4202c"
  [ "$status" -eq 0 ]
  [ "$output" = "https://chemrxiv.org/engage/chemrxiv/article-details/63051dfe1945ad17cee4202c" ]
}

@test "normalize-paper-url: OpenReview forum?id= becomes pdf?id=" {
  run "$SCRIPT" "https://openreview.net/forum?id=abc123XYZ"
  [ "$status" -eq 0 ]
  [ "$output" = "https://openreview.net/pdf?id=abc123XYZ" ]
}

@test "normalize-paper-url: ACL Anthology page gets .pdf appended" {
  run "$SCRIPT" "https://aclanthology.org/2023.acl-long.123"
  [ "$status" -eq 0 ]
  [ "$output" = "https://aclanthology.org/2023.acl-long.123.pdf" ]
}

@test "normalize-paper-url: ACL Anthology page with trailing slash also handled" {
  run "$SCRIPT" "https://aclanthology.org/2023.acl-long.123/"
  [ "$status" -eq 0 ]
  [ "$output" = "https://aclanthology.org/2023.acl-long.123.pdf" ]
}

@test "normalize-paper-url: NeurIPS new layout (Conference suffix)" {
  run "$SCRIPT" "https://proceedings.neurips.cc/paper_files/paper/2023/hash/abc123def-Abstract-Conference.html"
  [ "$status" -eq 0 ]
  [ "$output" = "https://proceedings.neurips.cc/paper_files/paper/2023/file/abc123def-Paper-Conference.pdf" ]
}

@test "normalize-paper-url: NeurIPS new layout (no Conference suffix)" {
  run "$SCRIPT" "https://proceedings.neurips.cc/paper_files/paper/2021/hash/xyz999-Abstract.html"
  [ "$status" -eq 0 ]
  [ "$output" = "https://proceedings.neurips.cc/paper_files/paper/2021/file/xyz999-Paper.pdf" ]
}

@test "normalize-paper-url: NeurIPS legacy papers.nips.cc" {
  run "$SCRIPT" "https://papers.nips.cc/paper/2017/hash/3f5ee243547dee91fbd053c1c4a845aa-Abstract.html"
  [ "$status" -eq 0 ]
  [ "$output" = "https://papers.nips.cc/paper/2017/file/3f5ee243547dee91fbd053c1c4a845aa-Paper.pdf" ]
}

@test "normalize-paper-url: PMLR (ICML) page becomes /name/name.pdf" {
  run "$SCRIPT" "https://proceedings.mlr.press/v202/smith23a.html"
  [ "$status" -eq 0 ]
  [ "$output" = "https://proceedings.mlr.press/v202/smith23a/smith23a.pdf" ]
}

@test "normalize-paper-url: unknown URL passes through unchanged" {
  run "$SCRIPT" "https://example.com/some/random/paper.pdf"
  [ "$status" -eq 0 ]
  [ "$output" = "https://example.com/some/random/paper.pdf" ]
}

@test "normalize-paper-url: local path passes through unchanged" {
  run "$SCRIPT" "/Users/me/Downloads/foo.pdf"
  [ "$status" -eq 0 ]
  [ "$output" = "/Users/me/Downloads/foo.pdf" ]
}

@test "normalize-paper-url: empty argument errors" {
  run "$SCRIPT" ""
  [ "$status" -eq 2 ]
}
