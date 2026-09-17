# zfpga

Zephyr-on-FPGA bring-up CLI: scaffold a board sample and flash it to the SD card
with its PL bitstream loaded first, so PL/AXI peripherals are alive before Zephyr
touches them. Pure bash — clone it, no build step.

Supported boards: **zynqmp_apu** (ZCU102 / ZynqMP-A53), **zedboard** (Zynq-7000-A9).

## Install

Clone this repo into your west workspace root (next to `zephyr/`):

```
cd ~/Zephyr                # your west workspace
git clone https://github.com/stolniceanuiustin/zephyr-fpga-tools zfpga
ln -s "$PWD/zfpga/zfpga" ~/.local/bin/zfpga   # optional: put it on PATH
```

`zfpga` treats its parent dir as the workspace. Override with `ZFPGA_WS`.

## Use

```
zfpga init                     # once per bench: SD mux, partition, console
zfpga new zynqmp_apu myapp     # register myapp: make bitstreams/myapp + board marker
# ... put your app in zephyr/samples/myapp, your bitstream in bitstreams/myapp/ ...
zfpga flash myapp              # build + flash (board remembered from 'new')
zfpga flash -p always -b zynqmp_apu myapp   # west-style flags: pristine + board
```

No usbsdmux? Leave the mux blank in `zfpga init`; `flash` stages the SD-card
files and prints manual copy instructions instead.

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

`skill/SKILL.md` teaches Claude Code to drive or explain zfpga. To activate it,
copy it into your skills dir:

```
mkdir -p .claude/skills/zfpga && cp zfpga/skill/SKILL.md .claude/skills/zfpga/
```

## Add a board

Data only, no script edits: add `profiles/<board>.env` and `boot/<board>/`.
Boot chain is `single` (one combined BOOT.BIN) or `spl` (BOOT.BIN + u-boot.img).

## Notes

- Finding `SD_MUX` / `SD_PART` (and fixing them when the device node moves): see
  `docs/sd-setup.md`.
- Build BOOT.BIN from U-Boot with `fatload` + cache control (`CONFIG_CMD_CACHE`) +
  `boot.scr` autoboot, or the boot hangs — see `docs/boot-chain.md`.
- Requires on PATH: `west`, `mkimage`, `unzip`, `readelf` (or
  `aarch64-zephyr-elf-readelf`), and `usbsdmux` + `sudo` for the mux path.
