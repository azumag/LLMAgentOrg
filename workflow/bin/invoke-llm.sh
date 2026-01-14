#!/bin/bash
#
# invoke-llm.sh - Unified interface for invoking different LLMs
#
# Usage: ./invoke-llm.sh <llm-type> <prompt-file> <output-file> [--timeout=300]
#   llm-type: claude | gemini | lfm
#

set -euo pipefail

# Default timeout in seconds
DEFAULT_TIMEOUT=300

# Print usage information
usage() {
    cat <<EOF
Usage: $0 <llm-type> <prompt-file> <output-file> [--timeout=SECONDS]

Arguments:
    llm-type      LLM to invoke: claude | gemini | lfm
    prompt-file   Path to file containing the prompt
    output-file   Path to write the response

Options:
    --timeout=N   Timeout in seconds (default: $DEFAULT_TIMEOUT)

Examples:
    $0 claude prompt.txt output.txt
    $0 gemini prompt.txt output.txt --timeout=600
    $0 lfm prompt.txt output.txt
EOF
    exit 1
}

# Error handler
error() {
    echo "Error: $1" >&2
    exit 1
}

# Parse arguments
if [[ $# -lt 3 ]]; then
    usage
fi

LLM_TYPE="$1"
PROMPT_FILE="$2"
OUTPUT_FILE="$3"
TIMEOUT="$DEFAULT_TIMEOUT"

# Parse optional arguments
shift 3
for arg in "$@"; do
    case "$arg" in
        --timeout=*)
            TIMEOUT="${arg#*=}"
            if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]]; then
                error "Invalid timeout value: $TIMEOUT"
            fi
            ;;
        *)
            error "Unknown option: $arg"
            ;;
    esac
done

# Validate llm-type
case "$LLM_TYPE" in
    claude|gemini|lfm)
        ;;
    *)
        error "Invalid llm-type: $LLM_TYPE (must be: claude | gemini | lfm)"
        ;;
esac

# Validate prompt file
if [[ ! -f "$PROMPT_FILE" ]]; then
    error "Prompt file not found: $PROMPT_FILE"
fi

if [[ ! -r "$PROMPT_FILE" ]]; then
    error "Prompt file is not readable: $PROMPT_FILE"
fi

# Ensure output directory exists
OUTPUT_DIR=$(dirname "$OUTPUT_FILE")
if [[ ! -d "$OUTPUT_DIR" ]]; then
    mkdir -p "$OUTPUT_DIR" || error "Failed to create output directory: $OUTPUT_DIR"
fi

# Read prompt content
PROMPT_CONTENT=$(cat "$PROMPT_FILE")

if [[ -z "$PROMPT_CONTENT" ]]; then
    error "Prompt file is empty: $PROMPT_FILE"
fi

# Invoke LLM based on type
case "$LLM_TYPE" in
    claude)
        echo "Invoking Claude..." >&2
        timeout "$TIMEOUT" claude -p "$PROMPT_CONTENT" --print > "$OUTPUT_FILE" || {
            exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                error "Claude invocation timed out after ${TIMEOUT}s"
            else
                error "Claude invocation failed with exit code: $exit_code"
            fi
        }
        ;;

    gemini)
        echo "Invoking Gemini..." >&2
        timeout "$TIMEOUT" gemini -p "$PROMPT_CONTENT" > "$OUTPUT_FILE" || {
            exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                error "Gemini invocation timed out after ${TIMEOUT}s"
            else
                error "Gemini invocation failed with exit code: $exit_code"
            fi
        }
        ;;

    lfm)
        echo "Invoking LFM (llama-server)..." >&2
        # Escape prompt content for JSON
        ESCAPED_PROMPT=$(printf '%s' "$PROMPT_CONTENT" | jq -Rs .)

        JSON_PAYLOAD=$(cat <<EOF
{
    "model": "LFM2.5-1.2B-Instruct",
    "messages": [{"role": "user", "content": $ESCAPED_PROMPT}],
    "temperature": 0.7,
    "max_tokens": 4096
}
EOF
)

        timeout "$TIMEOUT" curl -s -X POST http://localhost:8080/v1/chat/completions \
            -H "Content-Type: application/json" \
            -d "$JSON_PAYLOAD" | jq -r '.choices[0].message.content' > "$OUTPUT_FILE" || {
            exit_code=$?
            if [[ $exit_code -eq 124 ]]; then
                error "LFM invocation timed out after ${TIMEOUT}s"
            else
                error "LFM invocation failed with exit code: $exit_code"
            fi
        }

        # Check if output is valid (not null or empty from jq)
        if [[ ! -s "$OUTPUT_FILE" ]] || grep -q '^null$' "$OUTPUT_FILE"; then
            error "LFM returned empty or invalid response. Is llama-server running on localhost:8080?"
        fi
        ;;
esac

echo "Response saved to: $OUTPUT_FILE" >&2
exit 0
