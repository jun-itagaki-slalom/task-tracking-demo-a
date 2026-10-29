#!/usr/bin/env bash
# 閉じてよい Issue の候補を一覧で出す（推奨案 A の流れの 8）。閉じるのは人が行う。
# - ストーリー：Task（sub-issue）がすべて閉じている。検証の局面で受け入れ基準を満たしたら閉じる
# - エピック：ストーリー（sub-issue）がすべて閉じている
# - インテント：Project の項目「インテント」がその番号の Issue が、すべて閉じている
# 使い方：scripts/check-close.sh
source "$(dirname "$0")/lib.sh"

all_closed() {  # 一覧（番号<TAB>状態<TAB>タイトル）が 1 件以上あり、すべて closed なら真
  local list="$1"
  [[ -n "$list" ]] && ! echo "$list" | awk -F'\t' '$2!="closed"{f=1} END{exit !f}'
}

echo "== ストーリー（検証の後に閉じる）"
for label in type:user-story type:enabler-story; do
  while IFS=$'\t' read -r num state title; do
    [[ -z "$num" || "$state" != "open" ]] && continue
    subs="$(sub_issues "$num")"
    if all_closed "$subs"; then echo "候補：#$num $title（Task $(echo "$subs" | wc -l | tr -d ' ') 件がすべて閉じている）"; fi
  done <<< "$(list_by_label "$label")"
done

echo "== エピック"
while IFS=$'\t' read -r num state title; do
  [[ -z "$num" || "$state" != "open" ]] && continue
  subs="$(sub_issues "$num")"
  if all_closed "$subs"; then echo "候補：#$num $title"; fi
done <<< "$(list_by_label type:epic)"

echo "== インテント"
items="$(gh api graphql -f query='query($o:String!,$p:Int!,$n:String!){user(login:$o){projectV2(number:$p){items(first:100){nodes{content{... on Issue{number state}} fieldValueByName(name:$n){... on ProjectV2ItemFieldNumberValue{number}}}}}}}' \
  -f o="$OWNER" -F p="$PROJECT" -f n="インテント" \
  --jq '.data.user.projectV2.items.nodes[] | select(.fieldValueByName.number != null) | "\(.fieldValueByName.number|floor)\t\(.content.number)\t\(.content.state)"')"
while IFS=$'\t' read -r num state title; do
  [[ -z "$num" || "$state" != "open" ]] && continue
  mine="$(echo "$items" | awk -F'\t' -v n="$num" '$1==n && $2!=n')"
  open="$(echo "$mine" | awk -F'\t' 'NF && $3!="CLOSED"' | wc -l | tr -d ' ')"
  total="$(echo "$mine" | awk 'NF' | wc -l | tr -d ' ')"
  if [[ "$total" -gt 0 && "$open" -eq 0 ]]; then echo "候補：#$num $title（$total 件がすべて閉じている）"; else echo "まだ：#$num $title（$total 件のうち $open 件が開いている）"; fi
done <<< "$(list_by_label type:intent)"
