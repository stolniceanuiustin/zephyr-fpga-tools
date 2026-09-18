# zfpga

Zephyr-on-FPGA bring-up CLI: scaffold a board sample and flash it to the SD card
with its PL bitstream loaded first, so PL/AXI peripherals are alive before Zephyr
touches them. Pure bash — clone it, no build step.
Uses U-BOOT for loading the FPGA. Loading from Zephyr is not an option at this time 
due to design-constraints on Zephyr's part. 

This can be used with or without an USBSDMUX - An SD Mux makes your live much easier 
but you can use this with just an SD Card. 

Supported boards: **zynqmp_apu** (ZCU102 / ZynqMP-A53), **zedboard** (Zynq-7000-A9).

## Install

Clone this repo into your west workspace root (next to `zephyr/`):

```
cd ~/Zephyr                # your west workspace
git clone https://github.com/stolniceanuiustin/zephyr-fpga-tools zfpga
ln -s "$PWD/zfpga/zfpga" ~/.local/bin/zfpga   # optional: put it on PATH
```
Your workspace should look like this:
```
Zephyr/zephyr
Zephyr/zfpga
Zephyr/.venv
Zephyr/.west
etc.
```
`zfpga` treats its parent dir as the workspace. Override with `ZFPGA_WS`.

## Use

### Init, register sample, build, flash 
```
zfpga init                     # once per bench: SD mux, partition, console
zfpga new zynqmp_apu myapp     # register myapp: make bitstreams/myapp + board marker
# ... put your app in zephyr/samples/myapp, your bitstream in bitstreams/myapp/ ...
zfpga flash myapp              # build + flash (board remembered from 'new')
zfpga flash -p always -b zynqmp_apu myapp   # west-style flags: pristine + board
zfpga flash myapp -- -DEXTRA_CONF_FILE=debug.conf  # args after -- go to west build (CMake -D)
zfpga console myapp            # launch a console with automatic logging at the end 
```

No usbsdmux? Leave the mux blank in `zfpga init`; `flash` stages the SD-card
files and prints manual copy instructions instead.

Anything after `--` on `zfpga flash` is passed straight to `west build`, so you
can add CMake defines or extra config — e.g. `-- -DEXTRA_CONF_FILE=debug.conf` or
`-- -DMY_OPTION=/path/to/file`. Paths with spaces are preserved.

## SD card

The card needs **one FAT32 boot partition** (the standard Zynq/ZynqMP first
partition). `zfpga` does **not** partition or format the card — do that once
yourself (`mkfs.vfat`), then point `zfpga init` at that partition.

It does **not** need to be empty. `flash` only copies files into that partition;
it overwrites `BOOT.BIN`, `boot.scr`, `system.bit`, and `zephyr.bin`, and backs
up any existing `boot.scr` to `boot.scr.linux` (so a stock PetaLinux card can be
restored). Everything else on the card is left untouched.

## What ships vs. what's yours

- **Shared, versioned** — `profiles/<board>.env` (board constants) only. No
  binaries are committed.
- **Per-bench, git-ignored** — `../.flash.local` (SD mux/partition/console **and**
  your `BOOTBIN_<board>` paths), written by `zfpga init`.
- **Yours to build/supply**, all per sample in `bitstreams/<sample>/` — the PL
  bitstream (`system_top.bit` or `.xsa`) **and** the boot chain (`BOOT.BIN`,
  +`u-boot.img` for zedboard) built from U-Boot (see `docs/boot-chain.md`).
  `zfpga flash` looks in that folder first; to share one boot chain across
  samples instead, set `BOOTBIN_<board>` in `.flash.local`.

## Claude Code skill (optional)

`skills/` ships Claude Code skills: `zfpga` (drive/explain the tool) and
per-board sample skills (e.g. `zynqmp-sample`). Activate any of them by copying
into your skills dir:

```
cp -r zfpga/skills/zfpga         .claude/skills/
cp -r zfpga/skills/zynqmp-sample .claude/skills/
```

## Add a board

Data only, no script edits: add `profiles/<board>.env` and `boot/<board>/`.
Boot chain is `single` (one combined BOOT.BIN) or `spl` (BOOT.BIN + u-boot.img).

## Notes

- Finding `SD_MUX` / `SD_PART` (and fixing them when the device node moves): see
  `docs/sd-setup.md`.
- Build BOOT.BIN from U-Boot with `fatload` + cache control (`CONFIG_CMD_CACHE`) +
  `boot.scr` autoboot, or the boot hangs — see `docs/boot-chain.md`.
- Requires on PATH: `west`, `mkimage`, `unzip`, `readelf`, (or
  `aarch64-zephyr-elf-readelf`), `tio`, `usbsdmux` + `sudo` for the mux path.
