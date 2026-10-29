# task-tracking-demo-a

タスク管理の可視化の推奨案 A を、架空の「本の貸し出しツール」で動かしたデモです。

> **推奨案 A**：分解・受け入れ基準・順序は Markdown（ストーリーは `requirements.md`、タスクは作業ごとの `plan.md`）に書いて PR で承認し、担当・Status・期限・Sprint は GitHub の Issues と Projects で持つ。Issue はエピック・ストーリー・タスクの 3 段で作り、Markdown の PR のマージの後にスクリプト（Skill の代わり）で起こす。

- Project：[推奨案 A デモ（タスク管理の可視化）](https://github.com/users/jun-itagaki-slalom/projects/3)（非公開。見られない場合は持ち主に頼む）
- 前の版の推奨（A'：Issue はストーリーまで）のサンプルは [book-lending-sample](https://github.com/jun-itagaki-slalom/book-lending-sample)

## 1. 見どころ

| 見るところ | どこで | わかること |
|---|---|---|
| 3 段の親子と進み具合 | Project の「エピックの階層」ビュー、[#4](../../issues/4) | エピック → ストーリー → タスク。タスクが閉じると、ストーリーの進み具合が進む（#5 は 2/4） |
| タスクの Issue と PR が 1 対 1 | [#21](../../pull/21)・[#22](../../pull/22)・[#23](../../pull/23) | PR の本文の `Closes #<タスク>` でマージ時にタスクが閉じ、Status が Done になる。ブランチ名は閉じるタスクの番号（例：`feature/12-book-register-api`） |
| レビュー中のタスク | [#24](../../pull/24)・[#14](../../issues/14) | PR が開いているタスクは Status が Review |
| 依存と Blocked | [#18](../../issues/18)、[#8](../../issues/8) | `plan.md` の「先行タスク」が blocked by になる（機能をまたぐ `F02 T-2` ← `F01 T-1` も）。先行の Issue を閉じると Blocked が外れる |
| イネーブラーストーリー | [#16](../../issues/16) | 共通の基盤（利用者を見分ける仕組み）を 1 つのストーリーにし、使う側の 3 ストーリーを blocked by にする |
| インテントごとの見え方 | Project の「インテントごと」ビュー | 項目「インテント」にインテントの Issue の番号（1 か 25）が入る。親子・依存は使わない |
| 変更のインテントで、閉じたストーリーを開き直す | [#25](../../issues/25)、[#5](../../issues/5) | I002 の計画で、完了済みの F01 US-1 を開き直し、その下に `I002 T-1`・`I002 T-2` を足した |
| 上流の文書の PR | [#2](../../pull/2)・[#3](../../pull/3)・[#11](../../pull/11)・[#26](../../pull/26)〜[#28](../../pull/28) | 閉じる Issue がないため `Refs #<インテント>`。ブランチ名はインテントの番号（例：`docs/1-design-and-plan`） |

## 2. フォルダ

```
intents/
  I001-initial-build/intent.md          インテントの記録（新規開発）
  I002-isbn-duplicate/intent.md, plan.md  インテントの記録と、変更の計画（記録）
specs/library/
  architecture.md                        技術の設計（plan.md と同じ PR）
  features/F01-book-register/requirements.md, plan.md   機能の要件（正本）と、初回の開発の計画（記録）
  features/F02-lending/requirements.md, plan.md
scripts/                                 Markdown から Issue を起こす、Status を動かすなどのスクリプト
src/                                     デモ用の仮のコード
```

- `requirements.md` のストーリーは `US-1（優先度 P1）` の形、`plan.md` のタスクは `T-1` の形で書く
- `plan.md` のタスク分解の表には、デモで「親ストーリー」の列を足した（タスクを 1 つのストーリーの下に置くため）
- イネーブラーストーリーの置き場所は決まっていないため、デモでは `plan.md` に書いた

## 3. デモでたどった流れ

| # | すること | このデモで |
|---|---|---|
| 0 | 作業をインテントの Issue で受け付け、`intent.md` を PR で承認 | [#1](../../issues/1)、PR [#2](../../pull/2) |
| 1 | `requirements.md` の PR のマージの後に、エピックとストーリーの Issue を起こす | PR [#3](../../pull/3) → `issues-from-requirements.sh` で #4〜#10 |
| 2 | 技術の設計と `plan.md` を 1 つの PR にしてレビュー・マージ | PR [#11](../../pull/11) |
| 3 | `plan.md` のマージの後に、タスクの Issue を起こし、依存を付ける | `issues-from-plan.sh` で #12〜#20 |
| 5 | Sprint Planning で値を入れる（人） | ストーリーに Sprint・Priority・Estimate、タスクに担当・Sprint・期限（デモ用の仮の値） |
| 6・7 | タスクごとに PR を出し、`Closes #<タスク>` でマージ | PR [#21](../../pull/21)〜[#23](../../pull/23)（マージ済み）、[#24](../../pull/24)（レビュー中） |
| 8 | タスクがすべて閉じ、検証で受け入れ基準を満たしたら、ストーリーを人が閉じる | `check-close.sh` で候補を出し、#5・#16 を閉じた（デモでは代わりに閉じた） |
| 変更 | 2 つ目のインテントで要件を直し、変更の計画からタスクを起こす | [#25](../../issues/25)、PR [#26](../../pull/26)〜[#28](../../pull/28) → #5 を開き直し、#29・#30 |

## 4. スクリプト

すべて `scripts/config.sh` の設定（リポジトリ・Project の番号）で動く。Git Bash などの bash と GitHub CLI（`gh`）が要る。

| スクリプト | すること |
|---|---|
| `setup-project.sh "<題>"` | ラベル、Project、項目（Priority・Estimate・Due date・インテント・Sprint）、Status の選択肢、ビューを作る（1 回だけ） |
| `issues-from-requirements.sh <機能のフォルダ> <インテントの番号>` | エピックとユーザーストーリーの Issue を起こす。既にあるものは飛ばし、ずれ（Issue にだけある・題が違う）を出す |
| `issues-from-plan.sh <plan.md> <インテントの番号>` | イネーブラーストーリーとタスクの Issue を起こし、依存を付ける。親のストーリーが閉じていれば開き直す |
| `sync-status.sh` | 閉じた Issue を Done に、PR がレビュー中の Issue を Review にする（Workflow の代わり） |
| `check-close.sh` | 閉じてよいストーリー・エピック・インテントの候補を出す（閉じるのは人） |

## 5. 推奨案と違うところ（デモの都合）

| 推奨案 | このデモ | 理由 |
|---|---|---|
| Issue の種類は Org の Issue Type（エピック・ユーザーストーリー・イネーブラーストーリー・タスク） | ラベル `type:epic` など | 個人のリポジトリでは Org の Issue Type を使えない |
| インテントの番号は Org の Issue fields | Project の項目「インテント」 | 個人のアカウントでは Issue fields を使えない |
| Status は Project の Workflow（Item closed・Pull request merged など）で動かす | `sync-status.sh` で動かす | Workflow を有効にしない判断をした。API で作った Project では、既定で有効なのは「Auto-add sub-issues to project」だけだった |
| Issue を起こすのは Skill | bash のスクリプト | デモのため |
| ストーリーは検証の後に人が閉じる | デモでは作った人が代わりに閉じた | デモのため |

## 6. 画面でしかできない設定

API では、ビューのグループ分けと Workflow を設定できない。必要なら Project の画面で行う。

- 「インテントごと」ビュー：右上の View の設定 → **Group by** → 「インテント」
- 「エピックの階層」ビュー：View の設定で **Show hierarchy** が有効になっていることを確かめる（新しいビューは既定で有効）
- Workflow：Project の「…」→ **Workflows** → 「Item closed」などを選び、**Edit** で Status を選んで **Save and turn on workflow**

## 7. 動かしてわかったこと

- 先行の Issue を閉じると、依存の「開いている先行の数」が 0 になり、Blocked が外れる（#8 は EN-1 を閉じて 1 → 0）
- 「Auto-add sub-issues to project」が有効だと、sub-issue にした Issue が先に Project に入る。スクリプトから足すと「既にある」と断られるため、既にある項目の ID を取り直すようにした
- ストーリーの Issue の受け入れ条件を `requirements.md` から写すと、要件を直したときに Issue の本文が古くなる（#5 は I002 で足したシナリオを持っていない）。写すか、リンクだけにするかは決める必要がある
- 開き直したストーリー（#5）の項目「インテント」は最初のインテント（1）のまま。変更のタスク（#29・#30）は 25 で、インテントごとのビューではタスクの単位で分かれる
