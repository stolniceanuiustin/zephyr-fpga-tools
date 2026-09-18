# zfpga doctor -- preflight the bench: host tools, workspace, bench config, and
# which SD-target rung 'flash' would take. Read-only; touches no hardware.

# _have <tool>  -> 0 if on PATH
_have() { command -v "$1" >/dev/null 2>&1; }

# _report_tool <tool> <required|optional> [note]
_report_tool() {
    local t=$1 kind=$2 note=${3:-}
    if _have "$t"; then
        echo "  ok       $t"
    elif [ "$kind" = required ]; then
        echo "  MISSING  $t (required)${note:+ -- $note}"; DOCTOR_RC=1
    else
        echo "  absent   $t (optional)${note:+ -- $note}"
    fi
}

cmd_doctor() {
    DOCTOR_RC=0

    info "host tools:"
    _report_tool west   required "the Zephyr build tool"
    _report_tool mkimage required "u-boot-tools, builds boot.scr"
    _report_tool unzip  required "extracts system_top.bit from an .xsa"
    if _have aarch64-zephyr-elf-readelf || _have readelf; then
        echo "  ok       readelf (aarch64-zephyr-elf-readelf or readelf)"
    else
        echo "  MISSING  readelf / aarch64-zephyr-elf-readelf (required)"; DOCTOR_RC=1
    fi
    _report_tool usbsdmux optional "only needed for the SD-mux flash path"
    _report_tool sudo     optional "needed to mount the card / drive the mux"
    if _have tio || _have screen || _have picocom; then
        echo "  ok       serial terminal ($(for t in tio screen picocom; do _have $t && { echo $t; break; }; done)) for 'zfpga console'"
    else
        echo "  absent   serial terminal (optional) -- install tio/screen/picocom for 'zfpga console'"
    fi

    info "workspace:"
    echo "  ok       zephyr/ at $WS/zephyr"          # validated when common.sh sourced
    echo "  boards   $(list_boards | paste -sd, -)"

    info "bench config ($BENCH_CONF):"
    if [ ! -f "$BENCH_CONF" ]; then
        echo "  MISSING  no .flash.local -- run 'zfpga init'"; DOCTOR_RC=1
    else
        load_bench
        echo "  ok       present"
        # Mirror the flash.sh fallback ladder and check the chosen rung resolves.
        if [ -n "${SD_MUX:-}" ]; then
            echo "  sd path  usbsdmux ($SD_MUX -> mount $SD_PART at $MNT)"
            [ -e "$SD_MUX" ]  || { echo "  WARN     SD_MUX $SD_MUX not present (card unplugged?)"; }
            [ -n "${SD_PART:-}" ] || { echo "  MISSING  SD_MUX set but SD_PART empty -- rerun 'zfpga init'"; DOCTOR_RC=1; }
        elif [ -n "${SD_PART:-}" ]; then
            echo "  sd path  host reader: mount $SD_PART at $MNT"
            case "$SD_PART" in
                LABEL=*|UUID=*|/dev/disk/by-*) echo "  note     stable name -- resolved at mount time" ;;
                *) [ -b "$SD_PART" ] || echo "  WARN     $SD_PART is not a present block device (card unplugged?)" ;;
            esac
        elif [ -n "${SD_DIR:-}" ]; then
            echo "  sd path  already-mounted dir: $SD_DIR"
            [ -d "$SD_DIR" ] || echo "  WARN     SD_DIR $SD_DIR is not a directory (card mounted?)"
        else
            echo "  sd path  none -- 'flash' will stage files in build/sdcard/ for manual copy"
        fi
        if [ -n "${CONSOLE_DEV:-}" ]; then
            echo "  console  $CONSOLE_DEV @ ${CONSOLE_BAUD:-115200}"
            [ -c "$CONSOLE_DEV" ] || echo "  WARN     CONSOLE_DEV $CONSOLE_DEV not present (board off/unplugged?)"
        else
            echo "  console  no CONSOLE_DEV set -- 'zfpga console' needs -d or 'zfpga init'"
        fi
    fi

    echo
    if [ "$DOCTOR_RC" -eq 0 ]; then
        info "doctor: all required checks passed."
    else
        warn "doctor: problems above -- fix the MISSING items before 'zfpga flash'."
    fi
    return "$DOCTOR_RC"
}
