---
name: zedboard-sample
description: Create a Zephyr sample that boots on the Avnet ZedBoard (zedboard, Zynq-7020 Cortex-A9) with a PL bitstream loaded, then flash it with zfpga. Use when the user wants to make/scaffold a new Zephyr sample or app for zedboard, add the boot-safe prj.conf/overlay, or bring up hello-world on that board before layering PL drivers on.
---

# zedboard-sample

Create a Zephyr sample under `zephyr/samples/<name>/` that boots on **zedboard**
(Avnet ZedBoard, Xilinx **XC7Z020**, dual **Cortex-A9**) after U-Boot loads the PL
bitstream and jumps in with caches off. zfpga does the flashing; this skill
produces the app + board-relevant config. It does not invent your PL devicetree.

Board facts (verified from `boards/digilent/zedboard/`):

- `identifier: zedboard`, arch arm, SoC `SOC_XC7Z020`, dual Cortex-A9.
- Console/shell: `uart1` @115200 (`clock-frequency = 50 MHz`).
- RAM: `sram0` at **0x00100000**, size 511 MiB (of the 512 MB DDR3).
- Arch timer (GTC) at 333.333 MHz (CPU_3x2x half of the CPU clock).
- **Two-stage SPL boot** — the boot chain is `BOOT.BIN` (SPL) **+** `u-boot.img`,
  unlike the single-file ZynqMP BOOT.BIN.

## The low-1 MB reserve (boot-via-U-Boot, verified in the board dts)

`sram0` deliberately starts at `0x100000`, not `0x0`: **loading Zephyr at 0x0 was
observed to corrupt GEM (Ethernet) DMA** when booting via U-Boot — U-Boot's
relocated code/heap and leftover GEM DMA descriptors still live in the low 1 MB,
and the vector table at 0x0 sits inside that reserved region. Consequences for a
sample:

- Do NOT relink the image to `0x0`. Leave the board's memory node as-is; the
  Zephyr image links at `0x100000`.
- `zfpga flash` reads the ELF's load address with readelf, so its generated
  `fatload ... zephyr.bin` uses `0x100000` automatically. If you ever see it load
  at `0x0` on this board, the memory node was overridden — fix that, don't fight
  the flasher.

## Sample layout

```
zephyr/samples/<name>/
  CMakeLists.txt          # cmake_minimum_required + find_package(Zephyr) + project(<name>)
  prj.conf                # boot-safe base (below)
  sample.yaml             # platform_allow: zedboard; a harness regex on your log line
  src/main.c              # your app; LOG_INF a line sample.yaml can match
  boards/zedboard.overlay # YOUR PL design: AXI IP nodes, EMIO GPIO, SPI, ...
  boards/zedboard.conf    # board-specific Kconfig (optional)
```

## Boot-safe prj.conf base (ZedBoard A9 + PL bitstream)

```
# Console logging written synchronously, so nothing is lost across the U-Boot
# `go` -> Zephyr handoff. The console is uart1 on this board.
CONFIG_LOG=y
CONFIG_LOG_MODE_IMMEDIATE=y
```

The ZedBoard is a 32-bit Cortex-A9: PL AXI register addresses from devicetree are
used directly (no `KERNEL_DIRECT_MAP` / `MAX_XLAT_TABLES` — those are arm64/ZynqMP
knobs; do not copy them here). Add subsystem/driver enables (`CONFIG_SPI`,
`CONFIG_GPIO`, ...) only when the matching overlay nodes exist. GEM Ethernet
(`gem0`) and PS GPIO (`psgpio`) are already `okay` in the board dts.

## Cortex-A9 gotcha (verified, load-bearing)

With `CONFIG_LOG_MODE_IMMEDIATE=y`, logging **from ISR context** on Cortex-A9 runs
on the ARMv7 banked mode-stacks (IRQ/SVC/etc.). Their defaults are small; a log
call from an ISR can silently overflow and corrupt memory with no crash. If the
app logs from interrupt context, raise the banked mode-stack sizes rather than
chasing phantom corruption. Hello-world that only logs from `main()` is unaffected.

## Steps

1. **Scaffold** the files above. Keep `src/main.c` minimal — one `LOG_INF()` line
   that `sample.yaml`'s `harness_config.regex` matches.
2. **prj.conf**: start from the boot-safe base; add enables only when the overlay
   backs them with a devicetree node.
3. **Overlay** (`boards/zedboard.overlay`): YOUR PL design's mapping — derive AXI
   base addresses / EMIO GPIO from the bitstream or board DTS. Omit it for a plain
   hello-world with no PL peripherals.
4. **Register + flash** with zfpga (note the SPL second stage):
   ```
   zfpga new zedboard <name>       # makes bitstreams/<name>/ + board marker
   # drop into bitstreams/<name>/ : system_top.bit (or .xsa), BOOT.BIN, u-boot.img
   zfpga flash <name>
   ```
   Then power-cycle the ZedBoard and watch uart1 @115200.

## Guardrails

- Never fabricate devicetree nodes or register addresses — they come from the
  user's bitstream. Ask for the .xsa / board DTS if the PL mapping is unknown.
- Do NOT relink to 0x0 or copy ZynqMP-only options (`KERNEL_DIRECT_MAP`,
  `MAX_XLAT_TABLES`) into a ZedBoard sample; wrong arch, and 0x0 corrupts GEM DMA.
- SPL boot needs BOTH `BOOT.BIN` and `u-boot.img` present (co-located in
  `bitstreams/<name>/` or via `BOOTBIN_zedboard` / `UBOOT_IMG_zedboard` in
  `.flash.local`). zfpga errors if `u-boot.img` is missing.
- Flashing (PL load, cache handling, SD copy) is zfpga's job — hand off to it.
  See the `zfpga` skill.
