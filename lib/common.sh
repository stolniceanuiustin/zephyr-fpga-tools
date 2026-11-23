# Shared helpers for zfpga. Sourced by the dispatcher; expects $TOOL_DIR set.

# --- Workspace root: $ZFPGA_WS, else the nearest ancestor of the tool dir that
# has a zephyr/ dir. That covers both "zfpga/ next to zephyr/" and zfpga used as
# a submodule nested inside an app repo (ws/app-repo/tools/zfpga). ---
if [ -n "${ZFPGA_WS:-}" ]; then
    WS=$ZFPGA_WS
else
    WS=$(dirname "$TOOL_DIR")
    for _d in "$WS" "$(dirname "$WS")" "$(dirname "$(dirname "$WS")")" "$(dirname "$(dirname "$(dirname "$WS")")")"; do
        [ -d "$_d/zephyr" ] && { WS=$_d; break; }
    done
    unset _d
fi
if [ ! -d "$WS/zephyr" ]; then
    echo "zfpga: no zephyr/ under workspace '$WS' -- set ZFPGA_WS to your west workspace root." >&2
    exit 1
fi

# --- Bitstream drop folders: $ZFPGA_BITSTREAMS, else <superproject>/bitstreams
# when zfpga is a submodule whose parent repo has one, else $WS/bitstreams. ---
SUPER=$(git -C "$TOOL_DIR" rev-parse --show-superproject-working-tree 2>/dev/null || true)
if [ -n "${ZFPGA_BITSTREAMS:-}" ]; then
    BS_DIR=$ZFPGA_BITSTREAMS
elif [ -n "$SUPER" ] && [ -d "$SUPER/bitstreams" ]; then
    BS_DIR=$SUPER/bitstreams
else
    BS_DIR=$WS/bitstreams
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

# resolve_sample <arg> -- set SAMPLE (name, keys $BS_DIR/<name>/) and
# SAMPLE_DIR (app dir, relative to $WS when inside it). <arg> is either:
#   - a path (contains '/'): taken relative to $PWD, else to $WS; the name is
#     its basename, e.g. modules/lib/libiio/zephyr/samples/iiod -> iiod.
#   - a bare name: the path recorded in $BS_DIR/<name>/.sample by
#     'zfpga new', else zephyr/samples/<name>.
resolve_sample() {
    local arg=${1%/} abs=""
    if [[ $arg == */* ]]; then
        if [ -d "$arg" ]; then abs=$(realpath "$arg")
        elif [ -d "$WS/$arg" ]; then abs=$(realpath "$WS/$arg")
        else die "sample dir not found: $arg (relative to $PWD or $WS)"; fi
        SAMPLE=$(basename "$abs")
    else
        SAMPLE=$arg
        if [ -f "$BS_DIR/$SAMPLE/.sample" ]; then
            abs=$(cat "$BS_DIR/$SAMPLE/.sample")
            if [[ $abs != /* ]]; then
                # relative to the workspace, else to the superproject (so a repo
                # can record "app" without knowing its checkout dir name)
                if [ ! -e "$WS/$abs" ] && [ -n "$SUPER" ] && [ -e "$SUPER/$abs" ]; then
                    abs="$SUPER/$abs"
                else
                    abs="$WS/$abs"
                fi
            fi
        else
            abs="$WS/zephyr/samples/$SAMPLE"
        fi
    fi
    SAMPLE_DIR=${abs#"$WS"/}
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
