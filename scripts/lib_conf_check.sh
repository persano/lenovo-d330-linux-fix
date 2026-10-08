#!/usr/bin/env bash
# Shared PASS/FAIL assertion helpers for the Phase 38 PipeWire config validators
# (scripts/test_audio_dsp.sh, scripts/test_mic_rnnoise.sh). Sourced, never run.
#
# Both callers run a validator function that declares `local pass=0 fail=0` and
# then calls ck/ckn. Bash locals are dynamically scoped, so these helpers mutate
# the caller's pass/fail counters directly without any extra plumbing.

# ck DESC CMD [ARGS...]: PASS when CMD succeeds.
ck() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  [PASS] $desc"; pass=$((pass + 1))
    else
        echo "  [FAIL] $desc"; fail=$((fail + 1))
    fi
}

# ckn DESC CMD [ARGS...]: PASS when CMD FAILS (negative assertion).
ckn() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        echo "  [FAIL] $desc (unexpected match)"; fail=$((fail + 1))
    else
        echo "  [PASS] $desc"; pass=$((pass + 1))
    fi
}
