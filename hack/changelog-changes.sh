#!/usr/bin/env bash
# Generates the artifacthub.io/changes annotation in Chart.yaml from the
# CHANGELOG.md section of the chart version, so the two never drift.
#
# Each top-level bullet of the "## [<version>]" section becomes one entry. The
# Keep a Changelog heading above it gives the kind (Added, Changed, Deprecated,
# Removed, Fixed, Security). Wrapped lines are joined; markdown links become
# their text and are listed as the entry's links (paths relative to the
# repository root point at main on GitHub). Backticks are kept.
#
# Usage:
#   hack/changelog-changes.sh [VERSION]          print the annotation
#   hack/changelog-changes.sh --write [VERSION]  write it into Chart.yaml
#   hack/changelog-changes.sh --check [VERSION]  fail if Chart.yaml differs
#
# VERSION defaults to the chart version in Chart.yaml. While CHANGELOG.md has
# no section for it (entries still sit under [Unreleased]), --check has
# nothing to compare and exits 0; --write and printing fail.
#
# Requires: yq v4, jq.
set -euo pipefail

CHART="${CHART:-charts/appwrite}"
CHANGELOG="${CHANGELOG:-CHANGELOG.md}"

mode=print
case "${1:-}" in
  --write | --check)
    mode="${1#--}"
    shift
    ;;
  -h | --help)
    sed -n '2,/^set -euo/p' "$0" | sed '$d; s/^# \{0,1\}//'
    exit 0
    ;;
esac
version="${1:-$(yq -r '.version' "$CHART/Chart.yaml")}"

# One "kind<TAB>description" line per top-level bullet of the section.
entries=$(awk -v v="$version" '
  function flush() { if (desc != "") print kind "\t" desc; desc = "" }
  index($0, "## [" v "]") == 1 { insection = 1; found = 1; next }
  insection && /^## / { flush(); insection = 0 }
  !insection { next }
  /^### / {
    flush()
    heading = tolower($2)
    if (heading !~ /^(added|changed|deprecated|removed|fixed|security)$/) {
      printf "%s: unknown heading \"%s\" in [%s]; use Added, Changed, Deprecated, Removed, Fixed or Security\n", FILENAME, substr($0, 5), v > "/dev/stderr"
      bad = 1
    }
    kind = heading
    next
  }
  /^- / {
    flush()
    if (kind == "") {
      printf "%s: entry outside a ### heading in [%s]: %s\n", FILENAME, v, $0 > "/dev/stderr"
      bad = 1
    }
    desc = substr($0, 3)
    next
  }
  /^[ \t]+[^ \t]/ && desc != "" {
    line = $0
    sub(/^[ \t]+/, "", line)
    desc = desc " " line
    next
  }
  /^[^ \t]/ { flush() }  # a paragraph or link reference ends the entry
  END {
    flush()
    if (!found) exit 3
    if (bad) exit 1
  }
' "$CHANGELOG") || status=$?

case "${status:-0}" in
  0) ;;
  3)
    if [[ "$mode" == check ]]; then
      echo "$CHANGELOG has no [$version] section yet: nothing to check artifacthub.io/changes against."
      exit 0
    fi
    echo "$CHANGELOG has no \"## [$version]\" section. Rename [Unreleased] to [$version] first (see RELEASING.md)." >&2
    exit 1
    ;;
  *) exit 1 ;;
esac

if [[ -z "$entries" ]]; then
  echo "The [$version] section of $CHANGELOG has no entries." >&2
  exit 1
fi

# Turn the lines into Artifact Hub change entries (YAML).
repo_url=$(yq -r '.home' "$CHART/Chart.yaml")
changes=$(printf '%s\n' "$entries" | jq -R -s --arg blob "${repo_url%/}/blob/main/" '
  def link_re: "\\[(?<text>[^\\]]+)\\]\\((?<url>[^)\\s]+)\\)";
  split("\n") | map(select(length > 0) | split("\t") | {kind: .[0], raw: .[1]})
  | map(
      [.raw | match(link_re; "g") | {name: .captures[0].string, url: .captures[1].string}
        | select(.url | startswith("#") | not)
        | .url |= (if test("^[a-z]+://") then . else $blob + ltrimstr("./") end)] as $links
      | {kind, description: (.raw | gsub(link_re; "\(.text)") | gsub("\\*\\*"; "") | sub("\\s+$"; ""))}
      + (if ($links | length) > 0 then {links: $links} else {} end)
    )' | yq -P -o yaml '.')

case "$mode" in
  print)
    printf '%s\n' "$changes"
    ;;
  write)
    CHANGES="$changes" yq -i '.annotations["artifacthub.io/changes"] = strenv(CHANGES) + "\n" | .annotations["artifacthub.io/changes"] style="literal"' "$CHART/Chart.yaml"
    echo "Wrote the [$version] section of $CHANGELOG into artifacthub.io/changes in $CHART/Chart.yaml."
    ;;
  check)
    # Compare parsed YAML, so quoting and indentation don't matter.
    current=$(yq -r '.annotations["artifacthub.io/changes"] // ""' "$CHART/Chart.yaml" | yq -o json -I 0 '. // []')
    expected=$(printf '%s\n' "$changes" | yq -o json -I 0 '.')
    if [[ "$current" != "$expected" ]]; then
      echo "artifacthub.io/changes in $CHART/Chart.yaml doesn't match the [$version] section of $CHANGELOG: run 'make changes'."
      diff <(yq -r '.annotations["artifacthub.io/changes"] // ""' "$CHART/Chart.yaml") <(printf '%s\n' "$changes") || true
      exit 1
    fi
    echo "artifacthub.io/changes matches the [$version] section of $CHANGELOG."
    ;;
esac
