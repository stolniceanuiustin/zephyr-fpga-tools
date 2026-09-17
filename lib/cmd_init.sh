# zfpga init -- ask the bench-specific facts once, persist to $BENCH_CONF.
# These differ per desk (SD mux device, SD partition, console), so they live in
# a git-ignored file next to the workspace, NOT in the shared profiles.

cmd_init() {
    [ $# -eq 0 ] || die "init takes no arguments"

    if [ -f "$BENCH_CONF" ]; then
        info "existing bench config at $BENCH_CONF:"
        cat "$BENCH_CONF"
        read -rp "Overwrite it? [y/N] " ans
        [[ "$ans" =~ ^[Yy]$ ]] || { info "kept existing config."; return 0; }
    fi

    echo "Configuring this bench. Blank answers keep the shown default."
    echo

    # How zfpga reaches the SD card, in order of preference:
    #   1. usbsdmux (SD_MUX + SD_PART): auto-switch card host<->DUT, no re-plug.
    #   2. host reader, unmounted (SD_PART): zfpga mounts/copies/unmounts.
    #   3. host reader, auto-mounted (SD_DIR): zfpga copies into the mount.
    #   4. nothing: zfpga stages files and prints manual copy steps.
    local sd_mux="" sd_part="" sd_dir="" mnt="/mnt"

    echo "usbsdmux automates card swapping. Leave blank if you don't have one."
    read -rp "usbsdmux control device (e.g. /dev/sg4, blank = none): " sd_mux

    if [ -n "$sd_mux" ]; then
        read -rp "SD card FAT boot partition (e.g. /dev/sde1): " sd_part
        read -rp "Mount point [/mnt]: " mnt; mnt=${mnt:-/mnt}
    else
        echo
        echo "No mux -- put the card in a host reader to still auto-copy."
        read -rp "Card partition device to mount (e.g. /dev/sdb1, blank if none): " sd_part
        if [ -n "$sd_part" ]; then
            read -rp "Mount point [/mnt]: " mnt; mnt=${mnt:-/mnt}
        else
            read -rp "Or path where the card is already mounted (e.g. /media/you/BOOT, blank = manual copy): " sd_dir
        fi
    fi

    read -rp "Console hint shown after flashing (e.g. COM13 @115200 8N1): " console

    umask 077
    cat > "$BENCH_CONF" <<EOF
# zfpga bench config -- per-desk, git-ignored. Regenerate with 'zfpga init'.
# SD target, tried in order: SD_MUX+SD_PART -> SD_PART -> SD_DIR -> manual.
SD_MUX="$sd_mux"
SD_PART="$sd_part"
SD_DIR="$sd_dir"
MNT="$mnt"
CONSOLE_HINT="$console"

# BOOT.BIN is a user build (not shipped) -- point at yours per board.
# Build instructions: zfpga/docs/boot-chain.md
# BOOTBIN_zynqmp_apu="/path/to/your/zcu102/BOOT.BIN"
# BOOTBIN_zedboard="/path/to/your/zedboard/BOOT.BIN"    # SPL
# UBOOT_IMG_zedboard="/path/to/your/zedboard/u-boot.img"
# Optional: override the DDR scratch address for the bitstream.
# BIT_LOAD=0x2000000
EOF
    info "wrote $BENCH_CONF"
    if [ -n "$sd_mux" ]; then    info "SD target: usbsdmux ($sd_mux)."
    elif [ -n "$sd_part" ]; then info "SD target: mount $sd_part on flash."
    elif [ -n "$sd_dir" ]; then  info "SD target: copy into $sd_dir."
    else                         info "SD target: none -> flash stages files for manual copy."
    fi
    info "before flashing, set BOOTBIN_<board> in $BENCH_CONF (see docs/boot-chain.md)."
}
