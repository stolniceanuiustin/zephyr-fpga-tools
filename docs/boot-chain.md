# Building the boot chain (BOOT.BIN)

zfpga does **not** ship BOOT.BIN — it's a build artifact with its own provenance,
so you build it once and point `.flash.local` at it:

```
BOOTBIN_<board>="/path/to/BOOT.BIN"
UBOOT_IMG_<board>="/path/to/u-boot.img"   # zedboard (spl chain) only
```

## What zfpga's boot flow needs from U-Boot

The generated `boot.scr` loads the PL bitstream, stages `zephyr.bin`, and jumps
with caches off. Your U-Boot **must** therefore have:

- `fatload` (FAT read from the SD card),
- cache control — `dcache`/`icache` commands (`CONFIG_CMD_CACHE=y`); without it
  `go` enters Zephyr with caches dirty and it hangs,
- `boot.scr` autoboot (the default distro-boot `bootcmd` sources `boot.scr`).

A vendor BOOT.BIN built without cache control (e.g. some Vivado/ADI U-Boot 2018.01
images) will hang — build your own with the config above.

## zedboard (Zynq-7000, Cortex-A9) — pure U-Boot

Both stages come from a U-Boot build; no Xilinx FSBL needed (SPL replaces it).
(The origin of the zedboard BOOT.BIN currently in use here isn't recorded; this is
the canonical way to build one.)

```
git clone https://source.denx.de/u-boot/u-boot.git && cd u-boot
export CROSS_COMPILE=arm-none-eabi-        # or your Zynq GCC
make zynq_zed_defconfig
# ensure CONFIG_CMD_CACHE=y (menuconfig -> Command line interface -> Memory)
make -j$(nproc)
```

Outputs:
- `spl/boot.bin`  -> your `BOOT.BIN` (the SPL; FAT-loads u-boot.img as stage 2)
- `u-boot.img`    -> your `UBOOT_IMG_zedboard`

## zynqmp_apu (ZCU102, Cortex-A53)

### Recommended: the Xilinx/AMD prebuilt generic image

The known-good BOOT.BIN used for this port is the **generic ZCU102 image from the
Xilinx/AMD 2025.1 release** (a prebuilt/PetaLinux ZCU102 BSP), not a hand-built
one. Its 2025.1 U-Boot already has the `fatload` + cache-control + `boot.scr`
autoboot this flow needs. Grab it from the AMD ZCU102 prebuilt images (or a
PetaLinux 2025.1 ZCU102 BSP) and point `BOOTBIN_zynqmp_apu` at it. This is enough
for hello-world and SPI bring-up.

### Advanced: build BOOT.BIN from source

Only needed if you want a BOOT.BIN carrying your project's own `psu_init` (see the
note below). BOOT.BIN is **not** just U-Boot; `bootgen` assembles four pieces:

| Component | Source |
|-----------|--------|
| FSBL      | Xilinx (Vivado/XSCT, or a PetaLinux BSP) — not U-Boot |
| PMUFW     | Xilinx (Vivado/XSCT, or a PetaLinux BSP) |
| TF-A / BL31 | ARM Trusted Firmware (`arm-trusted-firmware`, `PLAT=zynqmp`) |
| U-Boot    | `xilinx_zynqmp_virt_defconfig`, with `CONFIG_CMD_CACHE=y` |

Assemble with a `.bif`:

```
the_ROM_image: {
  [bootloader, destination_cpu=a53-0] fsbl.elf
  [pmufw_image] pmufw.elf
  [destination_cpu=a53-0, exception_level=el-3, trustzone] bl31.elf
  [destination_cpu=a53-0, exception_level=el-2] u-boot.elf
}
```

```
bootgen -image boot.bif -arch zynqmp -o BOOT.BIN -w on
```

FSBL/PMUFW are the Xilinx-toolchain parts; the simplest way to get known-good ones
is a PetaLinux/Vivado project for the ZCU102, or Xilinx's prebuilt ZCU102 images.
Point `BOOTBIN_zynqmp_apu` at the resulting `BOOT.BIN`.

> psu_init note: `fpga loadb` reprograms the PL but does not re-run PS init, so a
> generic ZCU102 BOOT.BIN leaves PS clocks/MIO at generic defaults. Fine for
> hello-world and SPI bring-up; a stubborn JESD204 link may need a BOOT.BIN built
> from the project's own `psu_init`.
