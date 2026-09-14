#!/usr/bin/env bats

setup() {
    export PAWLY_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    export MOLE_TEST_NO_AUTH=1 NO_COLOR=1
}

@test "sourcing optimize does not probe, authorize or run tasks" {
    run /bin/bash -c 'source "$PAWLY_ROOT/bin/optimize.sh"; printf "definitions only\n"'
    [[ "$status" -eq 0 && "$output" == 'definitions only' ]]
}

@test "selected maintenance validates every task before any side effects" {
    run /bin/bash << 'EOF'
source "$PAWLY_ROOT/bin/optimize.sh"
log_operation_session_start() { echo UNEXPECTED_LOG; }
ensure_sudo_session() { echo UNEXPECTED_AUTH; }
generate_health_json() { echo UNEXPECTED_PROBE; }
optimize_run_pass cache_refresh unknown_task
EOF
    [[ "$status" -eq 2 ]]
    [[ "$output" == *'Unknown maintenance task: unknown_task'* ]]
    [[ "$output" != *UNEXPECTED* ]]
}

@test "selected maintenance refuses duplicate tasks before authorization" {
    run /bin/bash << 'EOF'
source "$PAWLY_ROOT/bin/optimize.sh"
ensure_sudo_session() { echo UNEXPECTED_AUTH; }
optimize_run_pass cache_refresh cache_refresh
EOF
    [[ "$status" -eq 2 && "$output" == *'Duplicate maintenance task'* && "$output" != *UNEXPECTED* ]]
}

@test "selected maintenance executes only exact reviewed tasks and preserves outcomes" {
    run /bin/bash << 'EOF'
source "$PAWLY_ROOT/bin/optimize.sh"
generate_health_json() { echo '{"memory_used_gb":1,"optimizations":[]}'; }
run_optimize_diagnostics() { :; }
show_system_health() { :; }
ensure_sudo_session() { return 1; }
stop_sudo_session() { :; }
opt_cache_refresh() { echo SELECTED_CACHE; optimize_task_result applied; }
opt_system_maintenance() { echo SELECTED_DNS; optimize_task_result unchanged; }
optimize_run_pass cache_refresh system_maintenance
[[ "$(optimize_outcome_total)" -eq 2 ]]
[[ "${MOLE_OPTIMIZE_RESULT_ACTIONS[*]}" == 'cache_refresh system_maintenance' ]]
[[ "${MOLE_OPTIMIZE_RESULT_OUTCOMES[*]}" == 'applied unchanged' ]]
EOF
    [[ "$status" -eq 0 && "$output" == *SELECTED_CACHE* && "$output" == *SELECTED_DNS* ]]
    [[ "$output" == *'Applied'*'1'*'optimizations'* ]]
}

@test "selected maintenance failed task stays failed in exit and history" {
    run /bin/bash << 'EOF'
source "$PAWLY_ROOT/bin/optimize.sh"
generate_health_json() { echo '{"memory_used_gb":1,"optimizations":[]}'; }
run_optimize_diagnostics() { :; }
show_system_health() { :; }
ensure_sudo_session() { return 1; }
stop_sudo_session() { :; }
opt_cache_refresh() { optimize_task_result failed; }
optimize_run_pass cache_refresh
EOF
    [[ "$status" -eq 1 && "$output" == *'1 failed'* ]]
    run /bin/bash "$PAWLY_ROOT/bin/history.sh" --json
    [[ "$status" -eq 0 && "$output" == *'"failed_tasks": 1'* ]]
}
