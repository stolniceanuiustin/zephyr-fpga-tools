---
name: zfpga
description: Use or teach the zfpga CLI to flash a Zephyr sample onto an FPGA board (zynqmp_apu / ZCU102, zedboard / Zynq-7000) with its PL bitstream loaded, or to scaffold a new board sample. Use when the user wants to flash/bring up a Zephyr sample on an FPGA SD card, scaffold a sample for a board, or set up/configure zfpga.
---

# zfpga

`zfpga` is a bash CLI that (1) scaffolds a Zephyr sample for an FPGA board and
(2) flashes a sample to the board's SD card **with the PL bitstream loaded first**
(so PL/AXI peripherals are alive before Zephyr runs). It lives at the west
workspace root, in `zfpga/`; invoke as `./zfpga/zfpga <cmd>` (or `zfpga` if the
user symlinked it onto PATH).

Supported boards: **zynqmp_apu** (ZCU102, single-stage boot) and **zedboard**
(Zynq-7000, two-stage SPL boot). Add a board = drop `profiles/<board>.env` (no
code edits).

## The three commands

- `zfpga init` — interactive; asks the per-bench facts (SD target + console) and
  writes `<workspace>/.flash.local`. Run once per machine.
- `zfpga new <board> <sample>` — registers a sample: creates the
  `bitstreams/<sample>/` drop folder + `.board` marker. It does NOT scaffold a
  Zephyr app; the user provides `zephyr/samples/<sample>` themselves.
- `zfpga flash [-p auto|always|never] [-b <board>] <sample>` — builds with west,
  loads the PL bitstream, and copies the boot payload to the SD card. `-p`/`-b`
  mirror west (pristine, board); board also falls back to the `.board` marker
  `new` wrote. A trailing positional board still works.

## Config model (do not conflate these)

- **profiles/<board>.env** — shared board constants (boot chain, BIT_LOAD). Ships
  with zfpga, identical for everyone.
- **<workspace>/.flash.local** — per-bench, git-ignored: `SD_MUX`, `SD_PART`,
  `SD_DIR`, `MNT`, `CONSOLE_HINT`, and the user's `BOOTBIN_<board>` paths.
- **<workspace>/bitstreams/<sample>/** — the user's own `system_top.bit` (or
  `.xsa`), plus optionally `BOOT.BIN` (+ `u-boot.img` for an spl board)
  co-located here. Never shipped or committed. `zfpga flash` looks here first for
  the boot chain, then falls back to `BOOTBIN_<board>` in `.flash.local`.

BOOT.BIN is a **user build**, never shipped — see `zfpga/docs/boot-chain.md`.

## How to help the user

1. **Confirm zfpga is present**: `ls <workspace>/zfpga/zfpga`. If not, the tool
   isn't installed here.
2. **Bench config**: if `<workspace>/.flash.local` is missing, tell the user to
   run `zfpga init` (it is interactive — the user must answer, you cannot). Do not
   fabricate their SD device paths.
3. **BOOT.BIN**: it may sit in `bitstreams/<sample>/BOOT.BIN` (checked first) or
   come from `BOOTBIN_<board>=` in `.flash.local`. If neither exists, point to
   `zfpga/docs/boot-chain.md` and have the user supply it. Do not invent a path.
4. **Bitstream**: check `bitstreams/<sample>/system_top.bit` (or `.xsa`) exists.
   If missing, tell the user to drop their PL design there (see that folder's
   README). zfpga does not produce bitstreams.
5. **Flash**: run `zfpga flash <sample> [board]`. It builds and copies; the actual
   board reset is physical — relay the reset hint zfpga prints.

## Guardrails

- The flash step drives real hardware (SD mux, mounts, `sudo`). Confirm with the
  user before running `zfpga flash`.
- `init` and any bitstream/BOOT.BIN paths are the user's to provide. Never guess
  device nodes, COM ports, or file paths — ask or have the user run `init`.
- The SD target is chosen by a fallback ladder in `.flash.local`:
  `SD_MUX`+`SD_PART` → `SD_PART` (host reader, zfpga mounts) → `SD_DIR` (already
  mounted) → none (files staged in `build/sdcard/` for manual copy).
- zfpga assumes `samples/<name>` and `bitstreams/<name>` share the name (1:1). A
  sample whose dir differs from its bitstream folder is not supported as-is.

## Teach-only mode

If the user just wants to learn (not run anything), walk them through the three
commands and the config model above with concrete commands for their board, and
stop — do not execute `flash`.
