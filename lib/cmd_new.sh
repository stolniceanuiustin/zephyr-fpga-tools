# zfpga new <board> <sample> -- scaffold a hello-world sample for <board> and
# prepare its bitstream folder. Deterministic templating; no build, no flash.

cmd_new() {
    [ $# -eq 2 ] || die "usage: zfpga new <board> <sample>"
    local board=$1 sample=$2
    load_profile "$board"            # validates board, sets REQUIRED_ARTIFACTS

    local sdir="$WS/zephyr/samples/$sample"
    local bdir="$WS/bitstreams/$sample"
    [ -e "$sdir" ] && die "sample already exists: $sdir"

    # --- Scaffold the sample from the template, substituting @SAMPLE@/@BOARD@. ---
    cp -r "$TOOL_DIR/templates/hello-world" "$sdir"
    mv "$sdir/boards/BOARD.overlay" "$sdir/boards/$board.overlay"
    local f
    while IFS= read -r -d '' f; do
        sed -i "s/@SAMPLE@/$sample/g; s/@BOARD@/$board/g" "$f"
    done < <(find "$sdir" -type f -print0)
    info "scaffolded sample -> $sdir"

    # --- Prepare the bitstream folder + a per-board README of what to drop in. ---
    mkdir -p "$bdir"
    echo "$board" > "$bdir/.board"          # remembered by 'zfpga flash <sample>'
    cat > "$bdir/README.md" <<EOF
# Bitstream files for '$sample' ($board)

Drop the PL design you built (Vivado/no-OS) into THIS folder:

$(for a in $REQUIRED_ARTIFACTS; do echo "- \`$a\`"; done)

You may drop \`system_top.xsa\` instead of \`system_top.bit\`; zfpga extracts the
\`.bit\` from it automatically.

The boot chain (BOOT.BIN$( [ "$BOOT_CHAIN" = spl ] && echo " + u-boot.img")) is a
U-Boot build you supply -- set BOOTBIN_$board$( [ "$BOOT_CHAIN" = spl ] && echo " and UBOOT_IMG_$board") in
.flash.local. Build instructions: zfpga/docs/boot-chain.md.

Then: \`zfpga flash $sample\`
EOF
    info "prepared $bdir (see its README for the files to add)"

    echo
    info "next:"
    echo "  1. Put your bitstream in: bitstreams/$sample/  (see its README.md)"
    echo "  2. Run 'zfpga init' if you haven't configured this bench yet."
    echo "  3. zfpga flash $sample"
}
