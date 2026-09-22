#!/usr/bin/env bash
# 为新会话初始化 planning 文件
# 用法: ./init-session.sh [project-name]

set -uo pipefail

PROJECT_NAME="${1:-project}"
DATE=$(date +%Y-%m-%d)
TASK_DIR="Task"
TASK_PLAN_PATH="$TASK_DIR/task_plan.md"
FINDINGS_PATH="$TASK_DIR/findings.md"
PROGRESS_PATH="$TASK_DIR/progress.md"

echo "Initializing planning files for: $PROJECT_NAME"

if [[ ! -d "$TASK_DIR" ]]; then
    mkdir -p "$TASK_DIR"
    echo "Created Task directory"
fi

if [[ ! -f "$TASK_PLAN_PATH" ]]; then
    cat > "$TASK_PLAN_PATH" <<'EOF'
# Task Plan: [Brief Description]

## Goal
[One sentence describing the end state]

## Current Phase
Phase 1

## Phases

### Phase 1: Requirements & Discovery
- [ ] Understand user intent
- [ ] Identify constraints
- [ ] Document in Task/findings.md
- **Status:** in_progress

### Phase 2: Planning & Structure
- [ ] Define approach
- [ ] Create project structure
- **Status:** pending

### Phase 3: Implementation
- [ ] Execute the plan
- [ ] Write to files before executing
- **Status:** pending

### Phase 4: Testing & Verification
- [ ] Verify requirements met
- [ ] Document test results
- **Status:** pending

### Phase 5: Delivery
- [ ] Review outputs
- [ ] Deliver to user
- **Status:** pending

## Decisions Made
| Decision | Rationale |
|----------|-----------|

## Errors Encountered
| Error | Resolution |
|-------|------------|
EOF
    echo "Created Task/task_plan.md"
else
    echo "Task/task_plan.md already exists, skipping"
fi

if [[ ! -f "$FINDINGS_PATH" ]]; then
    cat > "$FINDINGS_PATH" <<'EOF'
# Findings & Decisions

## Requirements
-

## Research Findings
-

## Technical Decisions
| Decision | Rationale |
|----------|-----------|

## Issues Encountered
| Issue | Resolution |
|-------|------------|

## Resources
-
EOF
    echo "Created Task/findings.md"
else
    echo "Task/findings.md already exists, skipping"
fi

if [[ ! -f "$PROGRESS_PATH" ]]; then
    cat > "$PROGRESS_PATH" <<EOF
# Progress Log

## Session: $DATE

### Current Status
- **Phase:** 1 - Requirements & Discovery
- **Started:** $DATE

### Actions Taken
-

### Test Results
| Test | Expected | Actual | Status |
|------|----------|--------|--------|

### Errors
| Error | Resolution |
|-------|------------|
EOF
    echo "Created Task/progress.md"
else
    echo "Task/progress.md already exists, skipping"
fi

echo ""
echo "Planning files initialized!"
echo "Files: Task/task_plan.md, Task/findings.md, Task/progress.md"
