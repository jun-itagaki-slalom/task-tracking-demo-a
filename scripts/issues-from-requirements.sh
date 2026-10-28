#!/usr/bin/env bash
# requirements.md から、エピックとユーザーストーリーの Issue を起こす（推奨案 A の流れの 1）。
# 使い方：scripts/issues-from-requirements.sh <機能のフォルダ> <インテントの Issue の番号>
#   例：scripts/issues-from-requirements.sh specs/library/features/F01-book-register 1
# - requirements.md の PR のマージの後に動かす
# - 既にある Issue は、エピックの sub-issue をストーリーの番号で照らして飛ばす（何度動かしてもよい）
# - 最後に、ずれ（Markdown にだけある／Issue にだけある／題が違う）の一覧を出す
source "$(dirname "$0")/lib.sh"

dir="${1:?機能のフォルダを指定してください}"; intent="${2:?インテントの Issue の番号を指定してください}"
req="$dir/requirements.md"
fid="$(meta_value "$req" "機能 ID")"
fname="$(meta_value "$req" "機能名")"
req_url="$(blob_url "$req")"

echo "== $fid $fname（$req）"

# エピック
epic="$(find_epic "$fid")"
if [[ -z "$epic" ]]; then
  body="### 機能
$fname

### 元の文書
- 要件：$req_url
- 機能のフォルダ：$(blob_url "$dir")

### インテント
#$intent"
  read -r epic url < <(create_issue "$fid: $fname" "$body" "type:epic")
  register_item "$url" "$intent" >/dev/null
  echo "作った：#$epic エピック $fid: $fname"
else
  echo "既にある：#$epic エピック $fid"
fi

existing="$(sub_issues "$epic")"
declare -A in_md=()

# ストーリー：「- **US-1（優先度 P1）**：本文」
while IFS= read -r line || [[ -n "$line" ]]; do
  line="${line%$'\r'}"
  [[ "$line" =~ ^-\ \*\*(US-[0-9]+)（優先度\ (P[0-9])）\*\*：(.*)$ ]] || continue
  sid="${BASH_REMATCH[1]}"; prio="${BASH_REMATCH[2]}"; text="${BASH_REMATCH[3]}"
  key="$fid $sid"; title="$key: ${text%%。*}"
  in_md["$key"]=1
  num="$(find_in "$existing" "$key")"
  if [[ -n "$num" ]]; then
    cur="$(echo "$existing" | awk -F'\t' -v n="$num" '$1==n{print $3}')"
    if [[ "$cur" != "$title" ]]; then echo "ずれ（題が違う）：#$num「$cur」→ Markdown は「$title」"; else echo "既にある：#$num $key"; fi
    continue
  fi
  scenario="$(grep -A1 -F -- "**$sid（優先度" "$req" | tail -n1 | tr -d '\r' | sed 's/^ *- 受入シナリオ：//')"
  body="### ストーリー
$text

### 受け入れ条件
- [ ] $scenario

（requirements.md から写した。正は requirements.md）

### 元の文書
$req_url

### 優先度（requirements.md）
$prio

### インテント
#$intent"
  read -r num url < <(create_issue "$title" "$body" "type:user-story")
  add_sub_issue "$epic" "$num"
  register_item "$url" "$intent" >/dev/null
  echo "作った：#$num $title"
done < "$req"

# Issue にだけあるユーザーストーリー（Markdown から消えた、または人が足した）
while IFS=$'\t' read -r num state title; do
  [[ -z "$num" || "$title" != "$fid US-"* ]] && continue
  key="${title%%:*}"
  [[ -z "${in_md[$key]:-}" ]] && echo "ずれ（Issue にだけある）：#$num $title（$state）"
done <<< "$existing"
echo "== 終わり"
