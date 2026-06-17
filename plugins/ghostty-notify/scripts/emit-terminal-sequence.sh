#!/bin/bash
# Emits an OSC terminal escape sequence using the best method for the running
# Claude Code version.
#
# Claude Code >= 2.1.141 supports a `terminalSequence` hook-output field, which
# delivers OSC sequences without a controlling terminal. Older versions reject
# unknown fields (the Stop hook validator errors out), so there we write the
# sequence to /dev/tty instead. Unknown version: try /dev/tty, then fall back
# to the structured field.
#
# Usage:
#   source "$(dirname "${BASH_SOURCE[0]}")/emit-terminal-sequence.sh"
#   emit_terminal_sequence "$(printf '\033]777;notify;Title;Body\007')"

TERMINAL_SEQUENCE_MIN_VERSION="2.1.141"

# Extract a bare x.y.z version from a string like "claude 2.1.179" or "2.1.179".
_cc_parse_version() {
    printf '%s' "$1" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1
}

# Returns 0 (true) if $1 >= $2 (dotted versions); base-10 to avoid octal issues.
_cc_version_ge() {
    local a b i av bv
    IFS=. read -ra a <<< "$1"
    IFS=. read -ra b <<< "$2"
    for ((i = 0; i < ${#b[@]}; i++)); do
        av="${a[i]:-0}"; bv="${b[i]:-0}"
        ((10#$av > 10#$bv)) && return 0
        ((10#$av < 10#$bv)) && return 1
    done
    return 0
}

emit_terminal_sequence() {
    local seq="$1"
    [ -z "$seq" ] && return 0

    local ver
    ver=$(_cc_parse_version "${CLAUDE_CODE_VERSION:-}")

    if [ -n "$ver" ]; then
        if _cc_version_ge "$ver" "$TERMINAL_SEQUENCE_MIN_VERSION"; then
            jq -nc --arg seq "$seq" '{terminalSequence: $seq}'
        else
            # Group the redirect so a failure to open /dev/tty (no controlling
            # terminal) is swallowed too, not just printf's own stderr.
            { printf '%s' "$seq" > /dev/tty; } 2>/dev/null || true
        fi
        return 0
    fi

    # Unknown Claude Code version: try the tty, fall back to the structured field.
    { printf '%s' "$seq" > /dev/tty; } 2>/dev/null && return 0
    jq -nc --arg seq "$seq" '{terminalSequence: $seq}'
}
