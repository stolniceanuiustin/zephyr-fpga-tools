# zfpga new <board> <sample> -- register a sample for flashing: create its
# bitstream drop folder and remember the board. Does NOT scaffold a Zephyr app;
# you bring your own zephyr/samples/<sample>.

cmd_new() {
    [ $# -eq 2 ] || die "usage: zfpga new <board> <sample>"
    local board=$1 sample=$2
    load_profile "$board"            # validates board, sets REQUIRED_ARTIFACTS

    local bdir="$WS/bitstreams/$sample"
    [ -e "$bdir" ] && die "bitstream folder already exists: $bdir"

    # --- Bitstream folder + board marker + a README of what to drop in. ---
    mkdir -p "$bdir"
    echo "$board" > "$bdir/.board"          # remembered by 'zfpga flash <sample>'
    cat > "$bdir/README.md" <<EOF
# Boot files for '$sample' ($board)

Put everything this sample needs to boot in THIS folder:

$(for a in $REQUIRED_ARTIFACTS; do echo "- \`$a\`  (your PL design; \`system_top.xsa\` works too, zfpga extracts the .bit)"; done)
- \`BOOT.BIN\`  (your U-Boot build -- see zfpga/docs/boot-chain.md)
$( [ "$BOOT_CHAIN" = spl ] && echo "- \`u-boot.img\`  (SPL second stage)" )

zfpga looks here first for BOOT.BIN$( [ "$BOOT_CHAIN" = spl ] && echo "/u-boot.img"). If you'd rather share one
boot chain across samples, omit it here and set BOOTBIN_$board$( [ "$BOOT_CHAIN" = spl ] && echo "/UBOOT_IMG_$board")
in .flash.local instead.

The Zephyr app is yours: it must live at zephyr/samples/$sample.
Then: \`zfpga flash $sample\`
EOF
    info "registered '$sample' for $board -> $bdir (see its README for the files to add)"

    # A soft nudge if the matching sample isn't there yet (1:1 naming).
    [ -d "$WS/zephyr/samples/$sample" ] || \
        warn "no zephyr/samples/$sample yet -- add your Zephyr app there before flashing."

    echo
    info "next:"
    echo "  1. Put your bitstream in: bitstreams/$sample/  (see its README.md)"
    echo "  2. Make sure your app is at: zephyr/samples/$sample"
    echo "  3. Run 'zfpga init' if you haven't configured this bench yet."
    echo "  4. zfpga flash $sample"
}
