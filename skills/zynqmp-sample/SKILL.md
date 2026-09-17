---
name: zynqmp-sample
description: Create a Zephyr sample that boots on the ZCU102 / zynqmp_apu (ZynqMP A53) with a PL bitstream loaded, then flash it with zfpga. Use when the user wants to make/scaffold a new Zephyr sample or app for zynqmp_apu (ZCU102), add the boot-safe prj.conf/overlay, or bring up hello-world on that board before layering PL drivers on.
---

# zynqmp-sample

Create a Zephyr sample under `zephyr/samples/<name>/` that boots on **zynqmp_apu**
(ZCU102, ZynqMP Cortex-A53) after U-Boot loads the PL bitstream and jumps in with
caches off. zfpga does the flashing; this skill produces the app + the
board-relevant config so it boots cleanly. It does not invent your PL devicetree.

## Sample layout

```
zephyr/samples/<name>/
  CMakeLists.txt          # cmake_minimum_required + find_package(Zephyr) + project(<name>)
  prj.conf                # boot-safe base (below)
  sample.yaml             # platform_allow: zynqmp_apu; a harness regex on your log line
  src/main.c              # your app; LOG_INF a line sample.yaml can match
  boards/zynqmp_apu.overlay   # YOUR PL design: AXI IP nodes, EMIO GPIO, SPI, ...
  boards/zynqmp_apu.conf      # board-specific Kconfig (optional)
```

## Boot-safe prj.conf base (ZCU102 A53 + PL bitstream)

These are the board/boot-relevant options; they are why the app survives the
U-Boot `go` handoff and can touch PL pages. Add your driver enables on top.

```
# Console logging written synchronously, so nothing is lost across the U-Boot
# `go` -> Zephyr handoff.
CONFIG_LOG=y
CONFIG_LOG_MODE_IMMEDIATE=y

# Every PL register access uses the physical address from devicetree directly
# (virt == phys). Implied by arm64's `select KERNEL_DIRECT_MAP if MMU`, stated
# explicitly to match the known-good boot environment.
CONFIG_KERNEL_DIRECT_MAP=y

# Headroom for 1:1 device_map() of PL AXI IP-core pages. The default (12) runs
# out once a datapath overlay maps several pages; harmless for hello-world.
CONFIG_MAX_XLAT_TABLES=24
```

## Steps

1. **Scaffold** the files above. Keep `src/main.c` minimal — one `LOG_INF()`
   line that `sample.yaml`'s `harness_config.regex` matches.
2. **prj.conf**: start from the boot-safe base. Add subsystem enables
   (`CONFIG_SPI`, `CONFIG_GPIO`, driver Kconfigs) ONLY when the matching
   devicetree nodes exist in your overlay — an enable without its node fails to
   build or does nothing.
3. **Overlay** (`boards/zynqmp_apu.overlay`): this is YOUR PL design's mapping —
   AXI IP-core base addresses, EMIO GPIO for resets, SPI routing. Do not
   fabricate nodes; derive them from the bitstream / the ADI Linux DTS for the
   board. If the user has no PL peripherals yet, the overlay can be omitted for a
   plain hello-world.
4. **Register + flash** with zfpga:
   ```
   zfpga new zynqmp_apu <name>     # makes bitstreams/<name>/ + board marker
   # drop system_top.bit (or .xsa) and BOOT.BIN into bitstreams/<name>/
   zfpga flash <name>
   ```
   Then reset the ZCU102 (SW40 / POR_B) and watch the console.

## Guardrails

- Never fabricate devicetree nodes or register addresses — they come from the
  user's bitstream. Ask for the .xsa / ADI DTS if the PL mapping is unknown.
- A `CONFIG_*` driver enable needs its devicetree node; don't add enables the
  overlay can't back.
- Flashing (PL load, cache handling, SD copy) is zfpga's job — hand off to it,
  don't hand-roll the U-Boot script. See the `zfpga` skill.
- Generic BOOT.BIN can leave FMC EMIO GPIOs floating (resets undriven). If a chip
  reads dead but the link looks up, suspect an undriven EMIO pin.
