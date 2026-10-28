#!/usr/bin/env bash
# デモの Project とラベルを用意する（1 回だけ動かす）。
# 使い方：scripts/setup-project.sh "<Project の題>"
# 終わったら、表示された Project の番号を scripts/config.sh の PROJECT に書く。
# 画面でしかできない設定（ビューのグループ分け、Workflow の Auto-add など）は README の手順で行う。
set -euo pipefail
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$LIB_DIR/config.sh"
title="${1:?Project の題を指定してください}"

gql() { gh api graphql "$@"; }

# ---- ラベル（ユーザーのリポジトリでは Org の Issue Type を使えないため、ラベルで種類を表す）
mklabel() { gh label create "$1" -R "$REPO" --color "$2" --description "$3" --force >/dev/null; echo "ラベル：$1"; }
mklabel "type:intent"        "d4a72c" "インテント（何を、なぜ変えたいか）"
mklabel "type:epic"          "8250df" "エピック（機能のまとまり）"
mklabel "type:user-story"    "0969da" "ユーザーストーリー"
mklabel "type:enabler-story" "54aeff" "イネーブラーストーリー（共通の基盤など）"
mklabel "type:task"          "1a7f37" "タスク（PR 1 つ分）"

# ---- Project
owner_id="$(gql -f query='query($l:String!){user(login:$l){id}}' -f l="$OWNER" --jq '.data.user.id')"
read -r pid pnum < <(gql -f query='mutation($o:ID!,$t:String!){createProjectV2(input:{ownerId:$o,title:$t}){projectV2{id number}}}' \
  -f o="$owner_id" -f t="$title" --jq '.data.createProjectV2.projectV2 | "\(.id) \(.number)"')
echo "Project：#$pnum"
repo_id="$(gh api "repos/$REPO" --jq '.node_id')"
gql -f query='mutation($p:ID!,$r:ID!){linkProjectV2ToRepository(input:{projectId:$p,repositoryId:$r}){repository{id}}}' -f p="$pid" -f r="$repo_id" --silent

# ---- 項目
mkfield() { gql -f query="mutation(\$p:ID!,\$n:String!){createProjectV2Field(input:{projectId:\$p,dataType:$2,name:\$n $3}){projectV2Field{... on ProjectV2FieldCommon{id}}}}" -f p="$pid" -f n="$1" --silent; echo "項目：$1"; }
mkfield "Priority"  SINGLE_SELECT ',singleSelectOptions:[{name:"高",color:RED,description:""},{name:"中",color:YELLOW,description:""},{name:"低",color:GRAY,description:""}]'
mkfield "Estimate"  NUMBER ''
mkfield "Due date"  DATE ''
mkfield "インテント" NUMBER ''
mkfield "Sprint"    ITERATION ",iterationConfiguration:{startDate:\"$SPRINT_START\",duration:7,iterations:[{title:\"Sprint 1\",startDate:\"$SPRINT_START\",duration:7},{title:\"Sprint 2\",startDate:\"$SPRINT2_START\",duration:7}]}"

# Status の選択肢をこのリポジトリの運用（Backlog / Ready / In progress / Review / Done）にそろえる
status_id="$(gql -f query='query($p:ID!){node(id:$p){... on ProjectV2{field(name:"Status"){... on ProjectV2SingleSelectField{id}}}}}' -f p="$pid" --jq '.data.node.field.id')"
gql -f query='mutation($f:ID!){updateProjectV2Field(input:{fieldId:$f,singleSelectOptions:[
  {name:"Backlog",color:GRAY,description:"まだ手を付けない"},
  {name:"Ready",color:BLUE,description:"始められる"},
  {name:"In progress",color:YELLOW,description:"作業中"},
  {name:"Review",color:PURPLE,description:"PR のレビュー中"},
  {name:"Done",color:GREEN,description:"完了"}]}){projectV2Field{... on ProjectV2SingleSelectField{id}}}}' -f f="$status_id" --silent
echo "項目：Status の選択肢"

# ---- ビュー
fid() { gql -f query='query($p:ID!,$n:String!){node(id:$p){... on ProjectV2{field(name:$n){... on ProjectV2FieldCommon{id}}}}}' -f p="$pid" -f n="$1" --jq '.data.node.field.id'; }
ids() { local out="" n; for n in "$@"; do out="$out\"$(fid "$n")\","; done; echo "[${out%,}]"; }
mkview() {
  local name="$1" layout="$2" filter="$3"; shift 3
  local vid
  vid="$(gql -f query="mutation(\$p:ID!,\$n:String!){createProjectV2View(input:{projectId:\$p,name:\$n,layout:$layout}){projectV2View{id}}}" -f p="$pid" -f n="$name" --jq '.data.createProjectV2View.projectV2View.id')"
  gql -f query="mutation(\$v:ID!,\$f:String!){updateProjectV2View(input:{viewId:\$v,filter:\$f,configuration:{visibleFieldIds:$(ids "$@")}}){projectV2View{id}}}" -f v="$vid" -f f="$filter" --silent
  echo "ビュー：$name（$filter）"
}
mkview "エピックの階層" TABLE_LAYOUT "no:parent-issue label:type:epic" "Title" "Status" "Sub-issues progress" "Assignees" "Sprint" "Due date" "Labels"
mkview "インテントごと" TABLE_LAYOUT "-label:type:intent" "Title" "インテント" "Status" "Parent issue" "Labels"
mkview "Sprint Planning" BOARD_LAYOUT "label:type:user-story,type:enabler-story,type:task sprint:@current" "Title" "Assignees" "Sprint" "Estimate" "Priority" "Parent issue"
mkview "Daily Standup" TABLE_LAYOUT "no:parent-issue" "Title" "Assignees" "Status" "Sub-issues progress" "Due date"

echo "終わり。scripts/config.sh の PROJECT を $pnum にしてください"
