# LLMAgentOrg

複数のLLM（Claude, Gemini, LFM）を役割分担させて協調動作させるマルチエージェントシステム。

## コンセプト

Opus -> LFM -> テスト -> レビュー の自動化ワークフロー：

- **Opus (Claude)**: 設計書 + テストケース定義（高い推論能力を活用）
- **LFM (ローカルLLM)**: コード生成（何度でも再生成OK、無料）
- **テスト実行**: ローカルで自動実行
- **レビュー**: Opus/Gemini で最終確認

### なぜこの構成か

| LLM | 特徴 | 適した役割 |
|-----|------|-----------|
| Claude (Opus) | 高い推論能力、正確なコード生成 | 設計、レビュー、QA |
| Gemini | 大規模コンテキスト、高速 | PM、要件分析、ドキュメント |
| LFM | 無料、ローカル実行、高速 | コード実装（何度でも再生成可能） |
| OpenCode | ファイル操作、コード編集、Git統合 | 実装、コードベース分析、自動化 |

## ディレクトリ構成

```
LLMAgentOrg/
├── CLAUDE.md              # Claude Code利用ガイドライン
├── README.md              # このファイル
├── config/
│   ├── llms/              # LLM設定
│   │   ├── claude.yaml    # Claude (Anthropic) 設定
│   │   ├── gemini.yaml    # Gemini (Google) 設定
│   │   ├── lfm.yaml       # LFM (Liquid AI) 設定
│   │   └── opencode.yaml  # OpenCode 設定
│   └── roles/             # 役割定義
│       ├── pm.yaml        # プロジェクトマネージャー
│       ├── architect.yaml # アーキテクト
│       ├── implementer.yaml # 実装者
│       ├── reviewer.yaml  # レビュアー
│       └── qa.yaml        # QAエンジニア
├── projects/
│   └── example/           # サンプルプロジェクト構成
│       ├── project.yaml           # 基本構成
│       ├── project-alt.yaml       # 代替構成（比較用）
│       ├── project-lfm-pm.yaml    # LFM PM構成
│       └── project-lfm-architect.yaml # LFM Architect構成
├── workflow/
│   ├── config.yaml        # ワークフロー設定
│   ├── bin/
│   │   ├── run-workflow.sh   # ワークフロー実行スクリプト
│   │   └── invoke-llm.sh     # LLM呼び出しスクリプト
│   ├── lib/
│   │   ├── __init__.py
│   │   ├── llm_client.py     # Python LLMクライアント
│   │   └── state_manager.py  # 状態管理モジュール
│   └── templates/
│       ├── design_spec.md    # 設計フェーズ用テンプレート
│       ├── implementation.md # 実装フェーズ用テンプレート
│       └── fix_error.md      # エラー修正用テンプレート
├── tasks/                 # タスク定義（要件）
│   └── {task-id}/
│       └── requirement.md
└── runs/                  # 実行結果出力先
    └── {task-id}/
        ├── state.json
        ├── design_spec.md
        └── implementation/
```

## セットアップ

### 前提条件

- macOS (Apple Silicon推奨)
- Python 3.9+
- jq (JSONパーサー)
- Claude CLI (`claude` コマンド) - Claude Pro/Max サブスク
- Gemini CLI (`gemini` コマンド) - Google One AI Premium サブスク
- llama.cpp (LFM実行用)

### Claude CLIのセットアップ

```bash
# インストール
npm install -g @anthropic-ai/claude-code

# 認証（Anthropicアカウントでログイン）
claude auth login

# 必要: Claude Pro または Claude Max サブスクリプション
```

### Gemini CLIのセットアップ

```bash
# インストール
npm install -g @google/gemini-cli

# 認証（Googleアカウントでログイン）
gemini auth login

# 必要: Google One AI Premium サブスクリプション
```

### LFM (llama.cpp) のセットアップ

```bash
# 1. llama.cppをクローンしてビルド
git clone https://github.com/ggml-org/llama.cpp.git local-llm
cd local-llm
cmake -B build
cmake --build build --config Release

# 2. モデルをダウンロード (Hugging Face CLIを使用)
# まずHugging Face CLIをインストール
pip install huggingface-hub

# モデルダウンロード（GGUF形式を選択）
huggingface-cli download LiquidAI/LFM2.5-1.2B-Instruct-GGUF \
  LFM2.5-1.2B-Instruct-Q4_K_M.gguf \
  --local-dir ./models

# 3. サーバーを起動
./build/bin/llama-server -m ./models/LFM2.5-1.2B-Instruct-Q4_K_M.gguf --port 8080
```

### OpenCode のセットアップ

```bash
# インストール
npm install -g @opencode-ai/opencode

# 認証（必要な場合）
opencode auth login
```

利用可能なLFMモデル：
- `LFM2.5-1.2B-Instruct` - 英語版（推奨）
- `LFM2.5-1.2B-JP-Instruct` - 日本語版
- `LFM2.5-3B-Instruct` - 大きいモデル

量子化オプション：
- `Q4_K_M` - 推奨（バランス良い）
- `Q8_0` - 高精度
- `F16` - フル精度

## 使い方

### ワークフロー実行

```bash
# 基本的な使い方
./workflow/bin/run-workflow.sh <task-id>

# 例: test-001 タスクを実行
./workflow/bin/run-workflow.sh test-001

# 設計フェーズをスキップ（既存の設計仕様を使用）
./workflow/bin/run-workflow.sh test-001 --skip-design
```

#### ワークフローの流れ

1. **Phase 0: 初期化**
   - タスクディレクトリ作成
   - state.json 初期化

2. **Phase 1: 設計 (Claude)**
   - `tasks/{task-id}/requirement.md` を読み込み
   - Claude に設計仕様書を生成させる
   - 出力: `runs/{task-id}/design_spec.md`

3. **Phase 2: 実装 (LFM)**
   - 設計仕様書を読み込み
   - LFM にコードを生成させる
   - 出力: `runs/{task-id}/implementation/attempt_1/output.md`

4. **Phase 3: 完了**
   - 状態を COMPLETED に更新

### 個別LLM呼び出し

```bash
# Claude を呼び出し
./workflow/bin/invoke-llm.sh claude prompt.txt output.txt

# Gemini を呼び出し
./workflow/bin/invoke-llm.sh gemini prompt.txt output.txt

# LFM を呼び出し（llama-serverが起動している必要あり）
./workflow/bin/invoke-llm.sh lfm prompt.txt output.txt

# OpenCode を呼び出し
./workflow/bin/invoke-llm.sh opencode prompt.txt output.txt

# タイムアウトを指定（デフォルト: 300秒）
./workflow/bin/invoke-llm.sh claude prompt.txt output.txt --timeout=600
```

### Pythonからの利用

```python
from workflow.lib.llm_client import LLMClient, create_claude_client, create_lfm_client

# Claude クライアント
claude = create_claude_client()
response = claude.invoke("Hello, world!")

# システムプロンプト付き
response = claude.invoke(
    "Explain AI",
    system="You are a teacher"
)

# LFM クライアント（カスタム設定）
lfm = LLMClient("lfm", config={
    "url": "http://localhost:8080/v1/chat/completions",
    "temperature": 0.5,
    "max_tokens": 2048
})
response = lfm.invoke("Write a simple function")

# ファイルをコンテキストとして渡す
from pathlib import Path
response = claude.invoke_with_files(
    "Review this code",
    [Path("src/main.py"), Path("tests/test_main.py")]
)
```

## 設定

### LLM設定 (config/llms/)

#### Claude (claude.yaml)
```yaml
llm: claude
models:
  - claude-opus-4-5
  - claude-sonnet-4
  - claude-haiku-3-5
default_model: claude-sonnet-4
invocation:
  type: cli
  cli: claude
```

#### Gemini (gemini.yaml)
```yaml
llm: gemini
models:
  - gemini-2.5-pro
  - gemini-2.5-flash
default_model: gemini-2.5-pro
invocation:
  type: cli
  cli: gemini
```

#### LFM (lfm.yaml)
```yaml
llm: lfm
models:
  - LFM2.5-1.2B-Instruct
  - LFM2.5-1.2B-JP-Instruct
  - LFM2.5-3B-Instruct
runtime:
  engine: llama.cpp
invocation:
  server: ./local-llm/build/bin/llama-server -m ./local-llm/models/LFM2.5-1.2B-Instruct-Q4_K_M.gguf --port 8080
  api_endpoint: http://localhost:8080/v1/chat/completions
performance:
  prompt_eval: "156 t/s"  # Apple M4での参考値
  generation: "117 t/s"
```

#### OpenCode (opencode.yaml)
```yaml
llm: opencode
models:
  - opencode-default
default_model: opencode-default
invocation:
  type: cli
  cli: opencode
```

### 役割定義 (config/roles/)

| 役割 | 説明 | 主な責務 |
|-----|------|---------|
| **PM** | プロジェクトマネージャー | 要件定義、タスク分解、優先順位付け |
| **Architect** | システムアーキテクト | システム設計、技術選定、設計ドキュメント作成 |
| **Implementer** | 実装者 | コード実装、ユニットテスト作成 |
| **Reviewer** | レビュアー | コードレビュー、品質チェック、改善提案 |
| **QA** | QAエンジニア | 結合/E2Eテスト、受入テスト、リリース判定 |

### プロジェクト構成 (projects/)

役割とLLMの割り当てパターンを定義：

#### 基本構成 (project.yaml)
```yaml
role_assignments:
  pm: gemini           # Gemini が PM
  architect: claude    # Claude がアーキテクト
  implementer: opencode  # OpenCode が実装
  implementer_assistant: lfm  # LFM が実装補助
  reviewer: claude     # Claude がレビュー
  qa: gemini           # Gemini が QA
```

#### 代替構成 (project-alt.yaml)
```yaml
role_assignments:
  pm: claude           # Claude が PM
  architect: gemini    # Gemini がアーキテクト
  implementer: opencode  # OpenCode が実装
  implementer_assistant: lfm  # LFM が実装補助
  reviewer: gemini     # Gemini がレビュー
  qa: claude           # Claude が QA
```

## ワークフロー詳細

### 状態遷移

```
INIT -> DESIGNING -> DESIGNED -> IMPLEMENTING -> TESTING -> REVIEWING -> COMPLETED
                          |            |             |           |
                          |            v             v           v
                          |        RETRYING -> ESCALATING -> FAILED
                          |            ^
                          |            |
                          +------------+
```

| 状態 | 説明 |
|-----|------|
| `INIT` | 初期状態 |
| `DESIGNING` | 設計フェーズ実行中 |
| `DESIGNED` | 設計完了 |
| `IMPLEMENTING` | 実装フェーズ実行中 |
| `TESTING` | テスト実行中 |
| `RETRYING` | エラー修正のため再試行中 |
| `ESCALATING` | 複雑なエラーのためエスカレーション中 |
| `REVIEWING` | レビュー実行中 |
| `COMPLETED` | 正常完了 |
| `FAILED` | 失敗（最大リトライ回数超過） |

### テンプレート (workflow/templates/)

#### design_spec.md
設計フェーズで使用。要件から設計仕様書を生成：
- 機能概要
- データ構造
- API/インターフェース仕様
- ファイル構成
- 実装詳細
- テストケース

#### implementation.md
実装フェーズで使用。設計仕様からコードを生成：
- 設計仕様に忠実な実装
- テストケースをパスする実装
- 適切なエラーハンドリング
- コメント付きコード

#### fix_error.md
エラー修正フェーズで使用。テスト失敗時のコード修正：
- 前回の実装内容
- エラー詳細
- 修正ガイドライン

### エスカレーションロジック

```yaml
escalation:
  minor_errors:    # LFMで自動修正を試みる
    - syntax_error
    - import_error
    - type_error
    - name_error
  complex_errors:  # Claude/Geminiにエスカレーション
    - logic_error
    - design_mismatch
    - test_ambiguity
    - runtime_error
```

## 今後の拡張予定

- **Phase 2**: テスト自動実行、結果に基づく分岐
- **Phase 3**: 再試行・エスカレーションロジックの実装
- **Phase 4**: 複数言語対応、CI/CD統合
- **Phase 5**: Web UI、リアルタイム進捗表示

## テスト実行設定

```yaml
testing:
  timeout: 60
  languages:
    python:
      test_command: pytest -v
      setup_command: pip install -r requirements.txt
    javascript:
      test_command: npm test
      setup_command: npm install
    typescript:
      test_command: npm test
      setup_command: npm install
```

## ライセンス

MIT
