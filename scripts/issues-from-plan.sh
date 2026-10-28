#!/usr/bin/env bash
# plan.md から、イネーブラーストーリーと Task の Issue を起こし、依存（blocked by）を付ける（推奨案 A の流れの 3）。
# 使い方：scripts/issues-from-plan.sh <plan.md> <インテントの Issue の番号>
#   例：scripts/issues-from-plan.sh specs/library/features/F02-lending/plan.md 1
#       scripts/issues-from-plan.sh intents/I002-isbn-duplicate/plan.md 12
# - plan.md（技術の設計と同じ PR）のマージの後に動かす
# - Task のタイトルは「<計画の ID> T-n: <タスク>」（例：F01 T-1、I002 T-1）。機能をまたいで番号が重ならないようにするため
# - 既にある Issue は、親のストーリーの sub-issue を番号で照らして飛ばす（何度動かしてもよい）
# - 親のストーリーが閉じていたら、開き直してコメントを残す（変更のインテントで Task を足すとき）
source "$(dirname "$0")/lib.sh"

plan="${1:?plan.md を指定してください}"; intent="${2:?インテントの Issue の番号を指定してください}"
fid="$(meta_value "$plan" "機能 ID")"
pid="$(meta_value "$plan" "計画の ID")"; pid="${pid%%（*}"
plan_url="$(blob_url "$plan")"
echo "== 計画 $pid（$plan）"

epic_of() { local e; e="$(find_epic "$1")"; [[ -z "$e" ]] && { echo "エピック $1 がありません。先に issues-from-requirements.sh を動かしてください" >&2; exit 1; }; echo "$e"; }

# 「US-1」「EN-1」→「F02 US-1」。既に機能 ID が付いていればそのまま
qualify() { local s; s="$(trim "$1")"; [[ "$s" == F[0-9]*\ * ]] && echo "$s" || echo "$fid $s"; }

# 「F02 US-1」→ Issue の番号（エピックの sub-issue から探す）
story_number() {
  local key="$1" f="${1%% *}"
  find_in "$(sub_issues "$(epic_of "$f")")" "$key"
}

declare -A made=()   # キー → 番号（この実行で作った・見つけたもの）

# ---- イネーブラーストーリー：| EN-1 | 題 | 使う側のストーリー |
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^\|\ (EN-[0-9]+)\ \|([^|]*)\|([^|]*)\|$ ]] || continue
  eid="${BASH_REMATCH[1]}"; etitle="$(trim "${BASH_REMATCH[2]}")"; users="$(trim "${BASH_REMATCH[3]}")"
  key="$fid $eid"; epic="$(epic_of "$fid")"
  num="$(find_in "$(sub_issues "$epic")" "$key")"
  if [[ -z "$num" ]]; then
    body="### ストーリー（イネーブラー）
$etitle

### 使う側のストーリー
$users

### 元の文書
$plan_url

### インテント
#$intent"
    read -r num url < <(create_issue "$key: $etitle" "$body" "type:enabler-story")
    add_sub_issue "$epic" "$num"
    register_item "$url" "$intent" >/dev/null
    echo "作った：#$num $key: $etitle"
  else
    echo "既にある：#$num $key"
  fi
  made["$key"]="$num"
  IFS=, read -ra us <<< "$users"
  for u in "${us[@]}"; do
    s="$(story_number "$(qualify "$u")")"
    [[ -n "$s" ]] && add_blocked_by "$s" "$num" && echo "  依存：#$s $(qualify "$u") は #$num $key に blocked by"
  done
done < "$plan"

# ---- Task：| T-1 | タスク | 親ストーリー | 対応要件・設計 | 先行タスク |
declare -a deps_rows=()
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^\|\ (T-[0-9]+)\ \|([^|]*)\|([^|]*)\|([^|]*)\|([^|]*)\|$ ]] || continue
  tid="${BASH_REMATCH[1]}"; ttext="$(trim "${BASH_REMATCH[2]}")"; parent="$(qualify "${BASH_REMATCH[3]}")"
  reqs="$(trim "${BASH_REMATCH[4]}")"; deps="$(trim "${BASH_REMATCH[5]}")"
  key="$pid $tid"
  pnum="${made[$parent]:-}"; [[ -z "$pnum" ]] && pnum="$(story_number "$parent")"
  [[ -z "$pnum" ]] && { echo "親のストーリー $parent の Issue がありません（$key を飛ばす）" >&2; continue; }

  if [[ "$(issue_state "$pnum")" == "closed" ]]; then
    gh issue reopen "$pnum" -R "$REPO" -c "インテント #$intent の計画（$pid）で Task を足すため、開き直しました。計画：$plan_url" >/dev/null
    item="$(add_to_project "$(issue_url "$pnum")")"; set_select "$item" "Status" "Ready"
    echo "開き直した：#$pnum $parent（Task を足すため）"
  fi

  num="$(find_in "$(sub_issues "$pnum")" "$key")"
  if [[ -z "$num" ]]; then
    ac="$(grep -E "^- \*\*AC-[0-9]+\*\*（[^）]*$tid[・）]" "$plan" | tr -d '\r' | sed 's/^- /- [ ] /' || true)"
    body="### やること
$ttext

### 成果物
PR 1 つ（\`Closes #<この Issue>\`）

### 完了条件
${ac:-- [ ] plan.md の受入基準を満たす}

### 対応要件・設計
$reqs

### 元の文書
$plan_url

### インテント
#$intent"
    read -r num url < <(create_issue "$key: $ttext" "$body" "type:task")
    add_sub_issue "$pnum" "$num"
    register_item "$url" "$intent" >/dev/null
    echo "作った：#$num $key: $ttext（親 #$pnum $parent）"
  else
    echo "既にある：#$num $key"
  fi
  made["$key"]="$num"
  deps_rows+=("$key	$deps")
done < "$plan"

# ---- 依存：先行タスクに blocked by を付ける
for row in "${deps_rows[@]}"; do
  key="${row%%	*}"; deps="${row#*	}"
  [[ "$deps" == "なし" || -z "$deps" ]] && continue
  IFS=, read -ra ds <<< "$deps"
  for d in "${ds[@]}"; do
    d="$(trim "$d")"; [[ "$d" == T-* ]] && d="$pid $d"
    bnum="${made[$d]:-}"
    if [[ -z "$bnum" ]]; then bnum="$(find_in "$(list_by_label type:task)" "$d")"; fi
    if [[ -z "$bnum" ]]; then echo "先行タスク $d の Issue がありません（$key の依存を飛ばす）" >&2; continue; fi
    add_blocked_by "${made[$key]}" "$bnum"
    echo "依存：#${made[$key]} $key は #$bnum $d に blocked by"
  done
done
echo "== 終わり"
