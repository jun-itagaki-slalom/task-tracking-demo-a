#!/usr/bin/env bash
# デモの設定。別のリポジトリ・Project で試すときは、ここを書き換える。
REPO="${REPO:-jun-itagaki-slalom/task-tracking-demo-a}"
OWNER="${OWNER:-jun-itagaki-slalom}"
PROJECT="${PROJECT:-3}"         # setup-project.sh で作った Project の番号
BRANCH="${BRANCH:-main}"
SPRINT_START="2026-11-01"       # Sprint 1 の初日。1 週間ずつ区切る
SPRINT_COUNT=4                  # 作る Sprint の数
