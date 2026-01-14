#!/bin/bash
#
# run-workflow.sh - Workflow orchestration script (Phase 1 MVP)
#
# Usage: ./run-workflow.sh <task-id> [--skip-design]
#
# This script controls the entire workflow:
#   1. Initialize task state
#   2. Design phase (Claude)
#   3. Implementation phase (LFM)
#   4. Complete
#

set -euo pipefail

# =============================================================================
# Configuration
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
WORKFLOW_DIR="$PROJECT_ROOT/workflow"
TASKS_DIR="$PROJECT_ROOT/tasks"
RUNS_DIR="$PROJECT_ROOT/runs"
TEMPLATES_DIR="$WORKFLOW_DIR/templates"
BIN_DIR="$WORKFLOW_DIR/bin"

# =============================================================================
# Logging Functions
# =============================================================================

log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[SUCCESS]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERROR]\033[0m $1"; }
log_step() { echo -e "\033[0;35m[STEP]\033[0m $1"; }

# =============================================================================
# Helper Functions
# =============================================================================

usage() {
    cat <<EOF
Usage: $0 <task-id> [--skip-design]

Arguments:
    task-id        Task identifier (must have tasks/{task-id}/requirement.md)

Options:
    --skip-design  Skip the design phase (use existing design_spec.md)

Examples:
    $0 task-001
    $0 task-002 --skip-design
EOF
    exit 1
}

# Update state using Python state_manager
update_state() {
    local status="$1"
    python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT')
from workflow.lib.state_manager import StateManager, Status
from pathlib import Path
sm = StateManager(Path('$RUNS_DIR'), '$TASK_ID')
sm.update_status(Status.$status)
"
}

# Initialize state using Python state_manager
init_state() {
    python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT')
from workflow.lib.state_manager import StateManager
from pathlib import Path
sm = StateManager(Path('$RUNS_DIR'), '$TASK_ID')
sm.init_state()
"
}

# =============================================================================
# Argument Parsing
# =============================================================================

if [[ $# -lt 1 ]]; then
    usage
fi

# Check for help flag first
case "$1" in
    -h|--help)
        usage
        ;;
esac

TASK_ID="$1"
SKIP_DESIGN=false

shift
for arg in "$@"; do
    case "$arg" in
        --skip-design)
            SKIP_DESIGN=true
            ;;
        -h|--help)
            usage
            ;;
        *)
            log_error "Unknown option: $arg"
            usage
            ;;
    esac
done

# =============================================================================
# Directory Setup
# =============================================================================

TASK_DIR="$TASKS_DIR/$TASK_ID"
RUN_DIR="$RUNS_DIR/$TASK_ID"
REQUIREMENT_FILE="$TASK_DIR/requirement.md"
DESIGN_SPEC_FILE="$RUN_DIR/design_spec.md"
IMPL_DIR="$RUN_DIR/implementation/attempt_1"

# =============================================================================
# Phase 0: Initialization
# =============================================================================

log_step "=== Phase 0: Initialization ==="

# Validate requirement file exists
if [[ ! -f "$REQUIREMENT_FILE" ]]; then
    log_error "Requirement file not found: $REQUIREMENT_FILE"
    log_error "Please create tasks/$TASK_ID/requirement.md before running the workflow."
    exit 1
fi

log_info "Task ID: $TASK_ID"
log_info "Requirement file: $REQUIREMENT_FILE"

# Create run directory
mkdir -p "$RUN_DIR"
mkdir -p "$IMPL_DIR"

log_info "Created run directory: $RUN_DIR"

# Initialize state
log_info "Initializing task state..."
init_state
log_success "State initialized."

# =============================================================================
# Phase 1: Design Phase (Claude)
# =============================================================================

if [[ "$SKIP_DESIGN" == true ]]; then
    log_step "=== Phase 1: Design Phase (SKIPPED) ==="

    if [[ ! -f "$DESIGN_SPEC_FILE" ]]; then
        log_error "Design spec not found: $DESIGN_SPEC_FILE"
        log_error "Cannot skip design phase without existing design_spec.md"
        exit 1
    fi

    log_info "Using existing design spec: $DESIGN_SPEC_FILE"
else
    log_step "=== Phase 1: Design Phase (Claude) ==="

    # Update status to DESIGNING
    log_info "Updating status to DESIGNING..."
    update_state "DESIGNING"

    # Read requirement content
    REQUIREMENT_CONTENT=$(cat "$REQUIREMENT_FILE")

    # Create prompt from template
    DESIGN_PROMPT_FILE="$RUN_DIR/design_prompt.md"
    log_info "Creating design prompt from template..."

    # Use a temporary file for multiline sed replacement
    TEMP_REQUIREMENT_FILE=$(mktemp)
    echo "$REQUIREMENT_CONTENT" > "$TEMP_REQUIREMENT_FILE"

    # Read template and substitute {requirement} with actual content
    python3 -c "
import sys
template_path = '$TEMPLATES_DIR/design_spec.md'
output_path = '$DESIGN_PROMPT_FILE'
requirement_path = '$TEMP_REQUIREMENT_FILE'

with open(template_path, 'r') as f:
    template = f.read()

with open(requirement_path, 'r') as f:
    requirement = f.read()

result = template.replace('{requirement}', requirement)

with open(output_path, 'w') as f:
    f.write(result)
"
    rm -f "$TEMP_REQUIREMENT_FILE"

    log_info "Design prompt created: $DESIGN_PROMPT_FILE"

    # Invoke Claude
    log_info "Invoking Claude for design..."
    "$BIN_DIR/invoke-llm.sh" claude "$DESIGN_PROMPT_FILE" "$DESIGN_SPEC_FILE" --timeout=600

    if [[ ! -s "$DESIGN_SPEC_FILE" ]]; then
        log_error "Design spec generation failed (empty output)"
        exit 1
    fi

    # Update status to DESIGNED
    log_info "Updating status to DESIGNED..."
    update_state "DESIGNED"

    log_success "Design phase completed. Output: $DESIGN_SPEC_FILE"
fi

# =============================================================================
# Phase 2: Implementation Phase (LFM)
# =============================================================================

log_step "=== Phase 2: Implementation Phase (LFM) ==="

# Update status to IMPLEMENTING
log_info "Updating status to IMPLEMENTING..."
update_state "IMPLEMENTING"

# Read design spec content
DESIGN_SPEC_CONTENT=$(cat "$DESIGN_SPEC_FILE")

# Create prompt from template
IMPL_PROMPT_FILE="$RUN_DIR/implementation_prompt.md"
IMPL_OUTPUT_FILE="$IMPL_DIR/output.md"

log_info "Creating implementation prompt from template..."

# Use Python for template substitution (handles multiline content properly)
TEMP_DESIGN_FILE=$(mktemp)
echo "$DESIGN_SPEC_CONTENT" > "$TEMP_DESIGN_FILE"

python3 -c "
import sys
template_path = '$TEMPLATES_DIR/implementation.md'
output_path = '$IMPL_PROMPT_FILE'
design_path = '$TEMP_DESIGN_FILE'

with open(template_path, 'r') as f:
    template = f.read()

with open(design_path, 'r') as f:
    design_spec = f.read()

result = template.replace('{design_spec}', design_spec)

with open(output_path, 'w') as f:
    f.write(result)
"
rm -f "$TEMP_DESIGN_FILE"

log_info "Implementation prompt created: $IMPL_PROMPT_FILE"

# Invoke LFM
log_info "Invoking LFM for implementation..."
"$BIN_DIR/invoke-llm.sh" lfm "$IMPL_PROMPT_FILE" "$IMPL_OUTPUT_FILE" --timeout=600

if [[ ! -s "$IMPL_OUTPUT_FILE" ]]; then
    log_error "Implementation generation failed (empty output)"
    exit 1
fi

log_success "Implementation phase completed. Output: $IMPL_OUTPUT_FILE"

# =============================================================================
# Phase 3: Completion (MVP: Skip Testing)
# =============================================================================

log_step "=== Phase 3: Completion ==="

# Update status to COMPLETED
log_info "Updating status to COMPLETED..."
update_state "COMPLETED"

# =============================================================================
# Summary
# =============================================================================

log_step "=== Workflow Summary ==="
log_info "Task ID: $TASK_ID"
log_info "Status: COMPLETED"
log_info ""
log_info "Generated files:"
log_info "  - State:          $RUN_DIR/state.json"
log_info "  - Design Spec:    $DESIGN_SPEC_FILE"
log_info "  - Implementation: $IMPL_OUTPUT_FILE"
log_info ""
log_success "Workflow completed successfully!"

exit 0
