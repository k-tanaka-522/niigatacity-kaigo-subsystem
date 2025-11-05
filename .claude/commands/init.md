# Init Command - プロジェクト初期化

## 概要

このコマンドは、AI開発ファシリテーターのプロジェクトを初期化します。
新規プロジェクト開始時、または既存プロジェクトの再開時に実行してください。

## 実行タイミング

- **新規プロジェクト**: 最初に必ず実行
- **既存プロジェクト**: セッション開始時に実行（任意だが推奨）

## 処理内容

### 1. 必須ドキュメントの読み込み

以下のファイルを**必ず**読み込んでください：

#### コア原則
\`\`\`
.claude/docs/00_core-principles.md                              # 基本原則（最重要）
\`\`\`

#### ファシリテーション（フェーズ別INDEX）
\`\`\`
.claude/docs/10_facilitation/2.1_企画フェーズ/INDEX.md          # 企画プロセス
.claude/docs/10_facilitation/2.2_要件定義フェーズ/INDEX.md      # 要件定義プロセス
.claude/docs/10_facilitation/2.3_設計フェーズ/INDEX.md          # 設計プロセス
.claude/docs/10_facilitation/2.4_実装フェーズ/INDEX.md          # 実装プロセス
.claude/docs/10_facilitation/2.5_テストフェーズ/INDEX.md        # テストプロセス
.claude/docs/10_facilitation/2.6_納品フェーズ/INDEX.md          # 納品プロセス
\`\`\`

#### ヘルパー
\`\`\`
.claude/helpers/state-manager.md                        # 状態管理方法
.claude/helpers/review-task-generator.md                # レビュータスク生成方法
.claude/helpers/directory-structure-helper.md           # ディレクトリ構成決定方法
.claude/helpers/implementation-checker.md               # 実装チェッカー
\`\`\`

#### 技術標準（プロジェクト開始時は概要のみ、技術選定時に詳細を読み込む）
\`\`\`
# 初期化時は読み込み不要（技術選定時に必要なものを読み込む）
# 以下は参照用リスト：
# - .claude/docs/40_standards/41_python.md
# - .claude/docs/40_standards/42_typescript.md
# - .claude/docs/40_standards/43_csharp.md
# - .claude/docs/40_standards/44_go.md
# - .claude/docs/40_standards/45_cloudformation.md
# - .claude/docs/40_standards/46_terraform.md
# - .claude/docs/40_standards/49_security.md (設計フェーズで必須)
\`\`\`

**注意**: 技術標準は設計フェーズで技術スタックを選定した後に読み込みます。
初期化時点では読み込む必要はありません。

### 2. CLAUDE.md の確認とセットアップ

プロジェクトルートの \`CLAUDE.md\` の存在を確認：

**存在しない場合:**
- テンプレートからのコピーを提案:
  \`\`\`
  ⚠️ CLAUDE.md が見つかりません。

  CLAUDE.mdはプロジェクトメモリのエントリーポイントです。
  テンプレートからコピーしますか？

  【Windowsの場合】
  copy .claude\templates\CLAUDE.md.template CLAUDE.md

  【Mac/Linuxの場合】
  cp .claude/templates/CLAUDE.md.template CLAUDE.md

  コピー後、以下を編集してください：
  1. {PROJECT_NAME} を実際のプロジェクト名に置換
  2. プロジェクトの目的と背景を記述
  3. 必要に応じて技術スタック情報を追加
  \`\`\`

**存在する場合:**
- 確認メッセージのみ表示:
  \`\`\`
  ✅ CLAUDE.md を確認しました
  \`\`\`

### 3. プロジェクト状態の確認

\`.claude-state/project-state.json\` の存在を確認：

**存在する場合（継続プロジェクト）:**
- ファイルを読み込み
- 現在のフェーズを確認
- 前回の続きから再開準備
- ユーザーに状況を報告:
  \`\`\`
  📂 既存プロジェクトを検出しました

  プロジェクト名: {name}
  現在のフェーズ: {phase}
  最終更新: {updated_at}

  前回の続きから始めますか？
  それとも \`/status\` で状況を確認しますか？
  \`\`\`

**存在しない場合（新規プロジェクト）:**
- \`.claude-state/\` ディレクトリを作成
- 初期状態の \`project-state.json\` を生成
- \`tasks.json\` を生成
- \`decisions.json\` を生成
- ユーザーに報告:
  \`\`\`
  🆕 新規プロジェクトを初期化しました

  .claude-state/ ディレクトリを作成しました。
  プロジェクト状態の記録を開始します。

  何を作りたいですか？
  \`\`\`

### 4. 初期化完了メッセージ

\`\`\`
✅ 初期化完了

AI開発ファシリテーターの準備ができました。
システム開発プロセス全体をサポートします。

【対話の基本】
- 一問一答形式で進めます
- ビジネス背景を最優先で伺います
- 技術標準に従ったコードを生成します
- 安全性を最優先します

【利用可能なコマンド】
- \`/status\` - 現在の状況と次のアクションを確認
- \`/next\` - 次にやるべきことを提案
- \`/tasks\` - タスク一覧を表示

さあ、始めましょう！
\`\`\`

## 実装詳細

### project-state.json の初期状態

\`\`\`json
{
  "project": {
    "name": null,
    "type": null,
    "phase": "planning",
    "created_at": "{現在時刻}",
    "updated_at": "{現在時刻}"
  },
  "phases": {
    "planning": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "requirements": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "design": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "implementation": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "testing": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    },
    "deployment": {
      "status": "pending",
      "started_at": null,
      "completed_at": null,
      "document": null
    }
  },
  "requirements": {
    "business_background": {},
    "tech_stack": {},
    "functional_requirements": [],
    "non_functional_requirements": {},
    "constraints": {}
  },
  "design": {
    "architecture": null,
    "tech_stack": {},
    "infrastructure": {},
    "cicd_strategy": {}
  },
  "implementation": {
    "directory_structure": null,
    "coding_standards_applied": false
  },
  "metadata": {
    "version": "1.0.0",
    "last_command": "/init"
  }
}
\`\`\`

### tasks.json の初期状態

\`\`\`json
{
  "tasks": [],
  "issues": []
}
\`\`\`

### decisions.json の初期状態

\`\`\`json
{
  "decisions": []
}
\`\`\`

## エラーハンドリング

### ケース1: .claude/docs/ が存在しない

\`\`\`
❌ エラー: .claude/docs/ ディレクトリが見つかりません。

このプロジェクトはAI開発ファシリテーター用に設定されていない可能性があります。
以下を確認してください:
1. 正しいディレクトリにいるか
2. .claude/ ディレクトリが存在するか
\`\`\`

### ケース2: 権限エラー

\`\`\`
❌ エラー: .claude-state/ の作成に失敗しました。

書き込み権限を確認してください。
\`\`\`

## 注意事項

1. **このコマンドは必須ではありません**
   - 実行しなくても対話は可能
   - ただし、実行することで最適な動作が保証されます

2. **複数回実行可能**
   - 既存の状態は上書きされません
   - 安全に再実行できます

3. **\`.claude-state/\` はGit管理外**
   - \`.gitignore\` で除外されています
   - プロジェクト固有の状態を保存します

4. **技術標準は段階的に読み込む**
   - 初期化時: フェーズ別INDEXのみ
   - 設計フェーズ: 技術スタックに応じた標準を読み込む
   - 理由: コンテキストの肥大化を防ぐため
