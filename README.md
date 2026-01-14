# LLMAgentOrg

LLMが協調して動作する組織の実験的プロジェクト。

複数のLLM（Gemini、Claude、ローカルLLM）に役割を割り当て、プロダクトのコーディングとシステム開発を協調して行う。

## コンセプト

```
┌─────────────────────────────────────────────────────────┐
│                        User                             │
│                    （要件入力）                          │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                    PM (Gemini)                          │
│              要件分析・タスク分解                         │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│               Architect (Claude)                        │
│            システム設計・技術選定                         │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│              Implementer (LFM)                          │
│                 コード実装                               │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│               Reviewer (Claude)                         │
│                コードレビュー                            │
└─────────────────────┬───────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────┐
│                  QA (Gemini)                            │
│         結合テスト・E2Eテスト・リリース判定               │
└─────────────────────┴───────────────────────────────────┘
```

## 役割（Roles）

| 役割 | 説明 | 設定ファイル |
|-----|------|-------------|
| PM | 要件分析、タスク分解、進捗管理 | `config/roles/pm.yaml` |
| Architect | システム設計、技術選定 | `config/roles/architect.yaml` |
| Implementer | コード実装 | `config/roles/implementer.yaml` |
| Reviewer | コードレビュー | `config/roles/reviewer.yaml` |
| QA | 結合テスト、E2Eテスト、リリース判定 | `config/roles/qa.yaml` |

## 利用可能なLLM

| LLM | プロバイダー | 呼び出し方式 | 必要なサブスク | 設定ファイル |
|-----|------------|-------------|--------------|-------------|
| Gemini | Google | gemini-cli | Google One AI Premium | `config/llms/gemini.yaml` |
| Claude | Anthropic | claude-code | Claude Pro/Max | `config/llms/claude.yaml` |
| LFM | Liquid AI | llama.cpp (ローカル) | なし（無料） | `config/llms/lfm.yaml` |

### ローカルLLM（LFM）について

このプロジェクトでは、ローカルLLMとして [Liquid Foundation Models (LFM)](https://www.liquid.ai/blog/liquid-foundation-models-v2-our-second-series-of-generative-ai-models) を使用しています。

- **HuggingFace**: https://huggingface.co/collections/LiquidAI/lfm25
- **実行エンジン**: [llama.cpp](https://github.com/ggml-org/llama.cpp)
- **モデル**: LFM2.5-1.2B-Instruct（英語版）/ LFM2.5-1.2B-JP-Instruct（日本語版）

## ディレクトリ構成

```
LLMAgentOrg/
├── config/
│   ├── roles/          # 役割定義
│   │   ├── pm.yaml
│   │   ├── architect.yaml
│   │   ├── implementer.yaml
│   │   ├── reviewer.yaml
│   │   └── qa.yaml
│   └── llms/           # LLM定義
│       ├── gemini.yaml
│       ├── claude.yaml
│       └── lfm.yaml
├── projects/           # プロジェクト設定
│   └── example/
│       ├── project.yaml      # 役割とLLMの割り当て
│       └── project-alt.yaml  # 代替構成（比較用）
├── local-llm/          # ローカルLLM（シンボリックリンク）
│   ├── build -> llama.cpp/build
│   └── models -> llama.cpp/models
└── README.md
```

## セットアップ

### 1. リポジトリのクローン

```bash
git clone https://github.com/your-org/LLMAgentOrg.git
cd LLMAgentOrg
```

### 2. ローカルLLM（llama.cpp + LFM）のセットアップ

#### 2.1 llama.cpp のビルド

```bash
# llama.cpp をクローン
cd ~/work  # または任意のディレクトリ
git clone https://github.com/ggml-org/llama.cpp.git
cd llama.cpp

# ビルド（Apple Silicon Mac の場合）
cmake -B build -DGGML_METAL=ON
cmake --build build --config Release -j
```

#### 2.2 LFM モデルのダウンロード

```bash
cd llama.cpp/models

# Hugging Face CLI でダウンロード（推奨: Q4_K_M量子化版）
huggingface-cli download LiquidAI/LFM2.5-1.2B-Instruct-GGUF \
  LFM2.5-1.2B-Instruct-Q4_K_M.gguf \
  --local-dir .

# 日本語版が必要な場合
huggingface-cli download LiquidAI/LFM2.5-1.2B-JP-GGUF \
  LFM2.5-1.2B-JP-Instruct-Q4_K_M.gguf \
  --local-dir .
```

#### 2.3 シンボリックリンクの作成

```bash
cd /path/to/LLMAgentOrg
mkdir -p local-llm
ln -s /path/to/llama.cpp/build local-llm/build
ln -s /path/to/llama.cpp/models local-llm/models
```

### 3. 動作確認

```bash
# インタラクティブモード
./local-llm/build/bin/llama-cli -m ./local-llm/models/LFM2.5-1.2B-Instruct-Q4_K_M.gguf

# サーバーモード（API）
./local-llm/build/bin/llama-server -m ./local-llm/models/LFM2.5-1.2B-Instruct-Q4_K_M.gguf --port 8080
```

**参考パフォーマンス（Apple M4）**:
- Prompt評価: 156 tokens/s
- 生成: 117 tokens/s

### 4. Gemini CLI のセットアップ

```bash
# インストール
npm install -g @google/gemini-cli

# 認証（Googleアカウントでログイン）
gemini auth login
```

**必要**: Google One AI Premium サブスクリプション

### 5. Claude Code CLI のセットアップ

```bash
# インストール
npm install -g @anthropic-ai/claude-code

# 認証（Anthropicアカウントでログイン）
claude auth login
```

**必要**: Claude Pro または Claude Max サブスクリプション

## プロジェクト設定の作成

新しいプロジェクトを作成する場合は、`projects/` 以下にディレクトリを作成し、`project.yaml` を配置します。

```yaml
# projects/my-project/project.yaml
project: my-project
name: マイプロジェクト
description: プロジェクトの説明

# 役割とLLMの割り当て
role_assignments:
  pm: gemini
  architect: claude
  implementer: lfm
  reviewer: claude
  qa: gemini

# ワークフロー定義
workflow:
  - step: 1
    role: pm
    action: 要件分析
  - step: 2
    role: architect
    action: 設計
  # ...
```

## 役割割り当ての比較

異なる役割割り当てによる品質の違いを比較できます。

### パターン一覧

| パターン | 設定ファイル | LFMの役割 | 検証目的 |
|---------|-------------|----------|---------|
| A（デフォルト） | `project.yaml` | Implementer | 基本構成 |
| B（代替） | `project-alt.yaml` | Implementer | Claude/Gemini入れ替え |
| C（LFM PM） | `project-lfm-pm.yaml` | PM | LFMの要件分析能力 |
| D（LFM Architect） | `project-lfm-architect.yaml` | Architect | LFMの設計能力 |

### パターンA（デフォルト）- LFM Implementer
| 役割 | LLM |
|-----|-----|
| PM | Gemini |
| Architect | Claude |
| Implementer | **LFM** |
| Reviewer | Claude |
| QA | Gemini |

### パターンB（代替）- LFM Implementer
| 役割 | LLM |
|-----|-----|
| PM | Claude |
| Architect | Gemini |
| Implementer | **LFM** |
| Reviewer | Gemini |
| QA | Claude |

### パターンC - LFM PM
| 役割 | LLM |
|-----|-----|
| PM | **LFM** |
| Architect | Claude |
| Implementer | Gemini |
| Reviewer | Claude |
| QA | Gemini |

### パターンD - LFM Architect
| 役割 | LLM |
|-----|-----|
| PM | Gemini |
| Architect | **LFM** |
| Implementer | Claude |
| Reviewer | Gemini |
| QA | Claude |

## モデルバリエーション

### LFM モデル

| モデル | サイズ | 用途 |
|-------|-------|------|
| LFM2.5-1.2B-Instruct-Q4_K_M.gguf | ~700MB | 標準（推奨） |
| LFM2.5-1.2B-Instruct-Q8_0.gguf | ~1.25GB | 高精度 |
| LFM2.5-1.2B-Instruct-F16.gguf | ~2.34GB | フル精度 |
| LFM2.5-1.2B-JP-Instruct-Q4_K_M.gguf | ~700MB | 日本語特化 |
| LFM2.5-3B-Instruct-Q4_K_M.gguf | - | 大規模モデル |

## ライセンス

MIT License
