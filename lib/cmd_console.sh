# zfpga console -- attach to the board UART and tee a timestamped boot log.
# Keeps logs diffable across reflashes (one file per boot); backend is
# auto-detected, preferring tio (auto-reconnects across board resets).

# Pick a serial terminal that can attach AND write a logfile. Sets CON_BACKEND.
_pick_backend() {
    if   command -v tio     >/dev/null 2>&1; then CON_BACKEND=tio
    elif command -v screen  >/dev/null 2>&1; then CON_BACKEND=screen
    elif command -v picocom >/dev/null 2>&1; then CON_BACKEND=picocom
    elif command -v cat     >/dev/null 2>&1; then CON_BACKEND=cat   # read-only fallback
    else die "no serial terminal found -- install tio, screen, or picocom"
    fi
}

cmd_console() {
    local dev="" baud="" do_log=1 sample=""
    while [ $# -gt 0 ]; do
        case $1 in
            -d) dev=$2;  shift 2 ;;
            -b) baud=$2; shift 2 ;;
            --no-log) do_log=0; shift ;;
            -*) die "console: unknown flag '$1'" ;;
            *)  sample=$1; shift ;;
        esac
    done

    load_bench                       # CONSOLE_DEV CONSOLE_BAUD CONSOLE_HINT
    dev=${dev:-${CONSOLE_DEV:-}}
    baud=${baud:-${CONSOLE_BAUD:-115200}}

    [ -n "$dev" ] || die "no console device -- pass -d /dev/ttyUSB0 or set CONSOLE_DEV in $BENCH_CONF (zfpga init).${CONSOLE_HINT:+ Hint: $CONSOLE_HINT}"
    [ -e "$dev" ] || die "console device not found: $dev${CONSOLE_HINT:+ (bench hint: $CONSOLE_HINT)}"
    [ -c "$dev" ] || die "not a character device: $dev"
    if [ ! -r "$dev" ] || [ ! -w "$dev" ]; then
        warn "no rw access to $dev -- may need sudo or the dialout group."
    fi

    _pick_backend

    local log=""
    if [ "$do_log" = 1 ]; then
        local dir="$WS/logs" ts sha tag
        mkdir -p "$dir"
        ts=$(date +%Y%m%d-%H%M%S)
        sha=$(git -C "$WS/zephyr" rev-parse --short HEAD 2>/dev/null || true)
        tag=${sample:-console}${sha:+-$sha}
        log="$dir/$tag-$ts.log"
        info "logging to $log"
    fi

    info "attaching $dev @ ${baud} 8N1 via $CON_BACKEND"
    # Drop an empty logfile on exit -- a failed/aborted attach shouldn't litter logs/.
    [ -n "$log" ] && trap '[ -s "$log" ] || { rm -f "$log"; info "removed empty log"; }' EXIT

    case "$CON_BACKEND" in
        tio)     info "exit: Ctrl-t q"
                 tio -b "$baud" ${log:+-l --log-file "$log" --log-strip} "$dev" ;;
        screen)  info "exit: Ctrl-a k (detach: Ctrl-a d)"
                 if [ -n "$log" ]; then screen -L -Logfile "$log" "$dev" "$baud"
                 else screen "$dev" "$baud"; fi ;;
        picocom) info "exit: Ctrl-a Ctrl-x"
                 picocom -b "$baud" ${log:+--logfile "$log"} "$dev" ;;
        cat)     warn "read-only ($CON_BACKEND); no keyboard input to the board. Exit: Ctrl-c"
                 stty -F "$dev" "$baud" cs8 -cstopb -parenb raw -echo
                 if [ -n "$log" ]; then tee "$log" < "$dev"
                 else cat "$dev"; fi ;;
    esac
}
