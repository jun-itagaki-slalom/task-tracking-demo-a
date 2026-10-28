#!/usr/bin/env bash
# スクリプトで共通に使う関数。
set -euo pipefail

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=config.sh
source "$LIB_DIR/config.sh"

trim() { local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"; printf '%s' "$s"; }

# 表の「| 項目 | 内容 |」から値を取る。例：meta_value plan.md "機能 ID" → F01
meta_value() {
  local file="$1" key="$2" line
  line="$(grep -m1 "^| $key |" "$file" | tr -d '\r' || true)"
  trim "$(echo "$line" | cut -d'|' -f3)"
}

# リポジトリ上のファイルへのリンク
blob_url() { echo "https://github.com/$REPO/blob/$BRANCH/$1"; }

# Issue を作り「番号 URL」を返す。ラベルはカンマ区切り
create_issue() {
  local title="$1" body="$2" labels="$3" l
  local args=(-f "title=$title" -f "body=$body")
  IFS=, read -ra ls <<< "$labels"
  for l in "${ls[@]}"; do args+=(-f "labels[]=$l"); done
  gh api "repos/$REPO/issues" "${args[@]}" --jq '"\(.number) \(.html_url)"'
}

issue_id()    { gh api "repos/$REPO/issues/$1" --jq '.id'; }
issue_state() { gh api "repos/$REPO/issues/$1" --jq '.state'; }
issue_url()   { echo "https://github.com/$REPO/issues/$1"; }

# ラベルで絞った Issue の一覧：番号<TAB>状態<TAB>タイトル
list_by_label() {
  gh api "repos/$REPO/issues?state=all&per_page=100&labels=$1" --paginate \
    --jq '.[] | select(.pull_request | not) | "\(.number)\t\(.state)\t\(.title)"'
}

# 親の sub-issue の一覧：番号<TAB>状態<TAB>タイトル
sub_issues() {
  gh api "repos/$REPO/issues/$1/sub_issues?per_page=100" --paginate \
    --jq '.[] | "\(.number)\t\(.state)\t\(.title)"'
}

# 一覧（番号<TAB>状態<TAB>タイトル）から「<キー>:」で始まる行を探し、番号を返す
find_in() {
  local list="$1" key="$2" num state title
  while IFS=$'\t' read -r num state title; do
    [[ -z "$num" ]] && continue
    if [[ "$title" == "$key:"* ]]; then echo "$num"; return 0; fi
  done <<< "$list"
  return 0
}

# 機能 ID のエピックの番号（なければ空）
find_epic() { find_in "$(list_by_label type:epic)" "$1"; }

# 子（番号）を親（番号）の sub-issue にする
add_sub_issue() { gh api "repos/$REPO/issues/$1/sub_issues" -F "sub_issue_id=$(issue_id "$2")" --silent; }

# $1 の Issue が $2 の Issue に blocked by される（既にあれば何もしない）
add_blocked_by() {
  local issue="$1" blocker="$2"
  if gh api "repos/$REPO/issues/$issue/dependencies/blocked_by" --jq '.[].number' | grep -qx "$blocker"; then return 0; fi
  gh api "repos/$REPO/issues/$issue/dependencies/blocked_by" -F "issue_id=$(issue_id "$blocker")" --silent
}

# ---- Project ----
PROJECT_ID=""
FIELDS_TSV=""   # 項目名<TAB>項目の ID<TAB>選択肢名<TAB>選択肢の ID
load_project() {
  [[ -n "$PROJECT_ID" ]] && return 0
  PROJECT_ID="$(gh project view "$PROJECT" --owner "$OWNER" --format json --jq '.id')"
  FIELDS_TSV="$(gh project field-list "$PROJECT" --owner "$OWNER" --format json --limit 50 \
    --jq '.fields[] | . as $f | if (.options // []) | length > 0 then (.options[] | "\($f.name)\t\($f.id)\t\(.name)\t\(.id)") else "\($f.name)\t\($f.id)\t\t" end')"
}
field_id()  { load_project; echo "$FIELDS_TSV" | awk -F'\t' -v n="$1" '$1==n{print $2; exit}'; }
option_id() { load_project; echo "$FIELDS_TSV" | awk -F'\t' -v n="$1" -v o="$2" '$1==n && $3==o{print $4; exit}'; }

# Project に足し、項目の ID を返す（既にあれば同じ ID が返る）
add_to_project() { gh project item-add "$PROJECT" --owner "$OWNER" --url "$1" --format json --jq '.id'; }

set_number() { load_project; gh project item-edit --id "$1" --project-id "$PROJECT_ID" --field-id "$(field_id "$2")" --number "$3" >/dev/null; }
set_date()   { load_project; gh project item-edit --id "$1" --project-id "$PROJECT_ID" --field-id "$(field_id "$2")" --date "$3" >/dev/null; }
set_select() { load_project; gh project item-edit --id "$1" --project-id "$PROJECT_ID" --field-id "$(field_id "$2")" --single-select-option-id "$(option_id "$2" "$3")" >/dev/null; }
set_iteration() {
  load_project
  local iid
  iid="$(gh api graphql -f query='query($id:ID!){node(id:$id){... on ProjectV2IterationField{configuration{iterations{id title}}}}}' \
    -f id="$(field_id "$2")" --jq ".data.node.configuration.iterations[] | select(.title==\"$3\") | .id")"
  gh project item-edit --id "$1" --project-id "$PROJECT_ID" --field-id "$(field_id "$2")" --iteration-id "$iid" >/dev/null
}

# Issue を Project に足し、インテントの番号と Status を入れる
register_item() {
  local url="$1" intent="$2" status="${3:-Backlog}" item
  item="$(add_to_project "$url")"
  set_number "$item" "インテント" "$intent"
  set_select "$item" "Status" "$status"
  echo "$item"
}
