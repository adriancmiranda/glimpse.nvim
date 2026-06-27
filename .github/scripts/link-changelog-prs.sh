#!/usr/bin/env sh
set -eu

file="${1:-CHANGELOG.md}"
repo="${GITHUB_REPO:-adriancmiranda/glimpse.nvim}"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh not found; skipping pull request links in ${file}" >&2
  exit 0
fi

if [ ! -f "${file}" ]; then
  echo "${file} not found" >&2
  exit 1
fi

tmp="${TMPDIR:-/tmp}/glimpse-changelog-prs.$$"
trap 'rm -f "${tmp}"' EXIT

link_pr_reference() {
  number="${1}"
  url="${2}"
  author="${3:-}"

  if [ -n "${author}" ]; then
    printf '[#%s](%s "PR de @%s")' "${number}" "${url}" "${author}"
  else
    printf '[#%s](%s)' "${number}" "${url}"
  fi
}

pr_metadata() {
  number="${1}"
  gh api \
    -H "Accept: application/vnd.github+json" \
    "repos/${repo}/pulls/${number}" \
    --jq '.html_url + " " + (.user.login // "")' 2>/dev/null || true
}

grep -Eo 'from PR #[0-9]+' "${file}" \
  | sed -E 's/.*#([0-9]+)/\1/' \
  | sort -u >"${tmp}"

while IFS= read -r number; do
  [ -n "${number}" ] || continue

  pr="$(pr_metadata "${number}")"
  [ -n "${pr}" ] || continue

  url="${pr%% *}"
  author="${pr#* }"
  replacement="$(link_pr_reference "${number}" "${url}" "${author}")"

  NUMBER="${number}" REPLACEMENT="${replacement}" perl -0pi -e '
    my $number = quotemeta($ENV{NUMBER});
    my $replacement = $ENV{REPLACEMENT};
    s{from PR #$number}{from $replacement}g;
  ' "${file}"
done <"${tmp}"

grep -Eo "https://github.com/${repo}/commit/[0-9a-f]{40}" "${file}" \
  | sed "s#https://github.com/${repo}/commit/##" \
  | sort -u >"${tmp}"

while IFS= read -r sha; do
  [ -n "${sha}" ] || continue

  if grep -E "https://github.com/${repo}/commit/${sha}.*https://github.com/${repo}/pull/[0-9]+" "${file}" >/dev/null; then
    continue
  fi

  pr=$(
    gh api \
      -H "Accept: application/vnd.github+json" \
      "repos/${repo}/commits/${sha}/pulls" \
      --jq '.[0] | select(.number != null) | "\(.number) \(.html_url) \(.user.login // "")"' 2>/dev/null || true
  )
  [ -n "${pr}" ] || continue

  number="${pr%% *}"
  rest="${pr#* }"
  url="${rest%% *}"
  author="${rest#* }"
  short="$(printf '%s' "${sha}" | cut -c1-7)"
  replacement="$(link_pr_reference "${number}" "${url}" "${author}")"

  REPO="${repo}" SHA="${sha}" SHORT="${short}" REPLACEMENT="${replacement}" perl -0pi -e '
    my $repo = quotemeta($ENV{REPO});
    my $sha = quotemeta($ENV{SHA});
    my $short = quotemeta($ENV{SHORT});
    my $replacement = $ENV{REPLACEMENT};
    s{(- \[`$short`\]\(https://github\.com/$repo/commit/$sha\))(?! \s+\[#\d+\]\()}{${1} $replacement}g;
  ' "${file}"
done <"${tmp}"
