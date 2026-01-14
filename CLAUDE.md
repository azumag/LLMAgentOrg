# CLAUDE.md

# main law
あなたはプロジェクトマネージャとしてふるまい、自分で実装をしない 全ての作業を subagent および task agent に移譲してください


このプロジェクトでのClaude Code利用ガイドライン。

## サブエージェントの活用

タスクに応じて適切なサブエージェント（Task tool）を積極的に利用すること。

### 利用可能なサブエージェント

| サブエージェント | 用途 |
|----------------|------|
| `Explore` | コードベース探索、ファイル検索、構造理解 |
| `Plan` | 実装計画の設計、アーキテクチャ検討 |
| `Bash` | git操作、コマンド実行 |
| `quick-git` | シンプルなgit操作（commit, push, status） |
| `build-qa-specialist` | ビルド検証、QAテスト、品質チェック |
| `tdd-test-reviewer` | TDD観点でのテストレビュー |
| `tech-debt-analyzer` | 技術的負債の分析、GitHub Issue作成 |
| `code-refactoring-analyzer` | リファクタリング機会の特定 |
| `yagni-code-reviewer` | YAGNI/DRY/KISS原則のレビュー |
| `style-lint-reviewer` | コードスタイル、リンティングチェック |
| `file-organization-reviewer` | ファイル構成、一時ファイル管理のレビュー |

### 使い分けの指針

- **コード探索時**: 直接Glob/Grepを使わず `Explore` エージェントを使用
- **実装前**: `Plan` エージェントで設計を検討
- **実装後**: `build-qa-specialist` で品質確認
- **コードレビュー時**: 目的に応じて `yagni-code-reviewer`, `style-lint-reviewer`, `tdd-test-reviewer` を使い分け
- **定期メンテナンス時**: `tech-debt-analyzer`, `code-refactoring-analyzer` で改善点を洗い出し

## プロジェクト構成

- `config/roles/` - LLMエージェントの役割定義
- `config/llms/` - LLM設定（CLI経由で呼び出し）
- `projects/` - プロジェクト別の構成設定

## LLM呼び出し

- **Gemini**: `gemini-cli`（Google One AI Premium サブスク）
- **Claude**: `claude-code`（Claude Pro/Max サブスク）
- **LFM**: `llama.cpp`（ローカル実行、無料）
