# Shared helpers for zfpga. Sourced by the dispatcher; expects $TOOL_DIR set.

# --- Workspace root: parent of the tool dir, or $ZFPGA_WS. Must be a west
# workspace (has a zephyr/ dir). ---
WS=${ZFPGA_WS:-$(dirname "$TOOL_DIR")}
if [ ! -d "$WS/zephyr" ]; then
    echo "zfpga: no zephyr/ under workspace '$WS' -- set ZFPGA_WS to your west workspace root." >&2
    exit 1
fi

BENCH_CONF="$WS/.flash.local"           # per-bench, git-ignored (see zfpga init)
PROFILE_DIR="$TOOL_DIR/profiles"

info() { echo "zfpga: $*"; }
warn() { echo "zfpga: $*" >&2; }
die()  { echo "zfpga: ERROR: $*" >&2; exit 1; }

list_boards() {
    for f in "$PROFILE_DIR"/*.env; do
        [ -e "$f" ] || continue
        basename "$f" .env
    done
}

# load_profile <board> -- source profiles/<board>.env into the environment.
# Defines: BOARD BOOT_CHAIN BIT_LOAD REQUIRED_ARTIFACTS RESET_HINT
load_profile() {
    local board=$1 pf="$PROFILE_DIR/$1.env"
    [ -f "$pf" ] || die "unknown board '$board' (supported: $(list_boards | paste -sd, -))"
    # shellcheck source=/dev/null
    source "$pf"
}

# load_bench -- source the per-bench config if present (zfpga flash needs it).
load_bench() {
    if [ -f "$BENCH_CONF" ]; then
        # shellcheck source=/dev/null
        source "$BENCH_CONF"
    fi
    MNT=${MNT:-/mnt}
}

# resolve_bootbin <board> <bitstream_dir> -- set BOOTBIN (and UBOOT_IMG for an
# spl chain). Preference: co-located in the sample's bitstream folder, else the
# board-keyed path in .flash.local. BOOT.BIN is a user build, not shipped; see
# docs/boot-chain.md. Requires load_profile (BOOT_CHAIN) + load_bench first.
resolve_bootbin() {
    local board=$1 bdir=$2 kb="BOOTBIN_$1" ku="UBOOT_IMG_$1"

    if [ -f "$bdir/BOOT.BIN" ]; then
        BOOTBIN="$bdir/BOOT.BIN"
    else
        BOOTBIN=${!kb:-${BOOTBIN:-}}
    fi
    [ -n "$BOOTBIN" ] || die "no BOOT.BIN for '$board' -- put one in $bdir/ or set $kb in $BENCH_CONF (build it: $TOOL_DIR/docs/boot-chain.md)"
    [ -f "$BOOTBIN" ] || die "BOOT.BIN not found: $BOOTBIN"

    if [ "$BOOT_CHAIN" = spl ]; then
        if [ -f "$bdir/u-boot.img" ]; then
            UBOOT_IMG="$bdir/u-boot.img"
        else
            UBOOT_IMG=${!ku:-${UBOOT_IMG:-}}
        fi
        [ -n "$UBOOT_IMG" ] || die "spl boot needs u-boot.img -- put one in $bdir/ or set $ku in $BENCH_CONF (see $TOOL_DIR/docs/boot-chain.md)"
        [ -f "$UBOOT_IMG" ] || die "u-boot.img not found: $UBOOT_IMG"
    fi
}
