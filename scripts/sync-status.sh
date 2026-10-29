#!/usr/bin/env bash
# Project の Status を Issue と PR の状態に合わせる（Workflow を有効にしない場合の代わり）。
# - 閉じた Issue → Done（「Item closed」の Workflow の代わり）
# - 開いている Issue で、それを閉じる予定の PR（本文に Closes #n）が開いている → Review（「Pull request linked to issue」の代わり）
# 使い方：scripts/sync-status.sh        PR のマージや Issue を閉じた後に動かす
source "$(dirname "$0")/lib.sh"
load_project

rows="$(gh api graphql -f query='query($o:String!,$p:Int!){user(login:$o){projectV2(number:$p){items(first:100){nodes{id
  content{... on Issue{number state title closedByPullRequestsReferences(first:5,includeClosedPrs:false){nodes{number state}}}}
  fieldValueByName(name:"Status"){... on ProjectV2ItemFieldSingleSelectValue{name}}}}}}}' \
  -f o="$OWNER" -F p="$PROJECT" \
  --jq '.data.user.projectV2.items.nodes[] | select(.content.number != null) |
        "\(.id)\t\(.content.number)\t\(.content.state)\t\(.fieldValueByName.name // "-")\t\([.content.closedByPullRequestsReferences.nodes[] | select(.state=="OPEN") | .number] | if length == 0 then "-" else join(",") end)\t\(.content.title)"')"
# 空の欄があるとタブ区切りが詰まるため、空は「-」で受け取る

changed=0
while IFS=$'\t' read -r item num state status prs title; do
  [[ -z "$item" ]] && continue
  [[ "$status" == "-" ]] && status=""
  [[ "$prs" == "-" ]] && prs=""
  want=""
  if [[ "$state" == "CLOSED" ]]; then want="Done"
  elif [[ -n "$prs" && "$status" != "Review" ]]; then want="Review"
  fi
  if [[ -n "$want" && "$status" != "$want" ]]; then
    set_select "$item" "Status" "$want"
    echo "#$num $title：$status → $want${prs:+（PR #$prs）}"
    changed=$((changed+1))
  fi
done <<< "$rows"
echo "== 変えた数：$changed"
