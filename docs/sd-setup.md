# SD card setup: finding SD_MUX and SD_PART (and fixing them when they change)

`zfpga flash` reaches the SD card via values in `<workspace>/.flash.local`:

- `SD_MUX`  — the usbsdmux control device (e.g. `/dev/sg4`)
- `SD_PART` — the card's FAT boot partition (e.g. `/dev/sde1`)
- `SD_DIR`  — where the card is already mounted, if no mux (e.g. `/media/you/BOOT`)

These are Linux device nodes: **they can change** across reboots, re-plugs, or when
other USB storage is attached. Below is how to find them and how to change them.

## Getting a usbsdmux

The usbsdmux is a hardware SD-card multiplexer (Linux Automation GmbH) that
switches one SD card between the host PC and the device under test, so you can
re-flash without physically moving the card.

- Buy: https://www.linux-automation.com/en/products/usb-sd-mux.html
- Install the CLI: `pip install usbsdmux` (or your distro's package).
- It presents an SCSI generic node (`/dev/sg*`); driving it needs `sudo` (or a
  udev rule granting your user access).

You don't need a usbsdmux — without one, put the card in any USB SD reader and use
`SD_PART` (zfpga mounts it) or `SD_DIR` (already mounted). See the fallback ladder
in the main README.

## Finding SD_MUX (the mux control device)

```
lsusb | grep -i "linux automation\|sd-mux"   # confirm it's attached
lsscsi -g                                     # map it to a /dev/sg* node
```

The usbsdmux is the `/dev/sg*` whose SCSI entry is the mux (not your disks). Verify
by querying its mode:

```
sudo usbsdmux /dev/sgX get         # prints host/dut/off if it's the right node
```

## Finding SD_PART (the card's boot partition)

Switch the card to the host, then look for the new block device:

```
sudo usbsdmux /dev/sgX host
lsblk                              # the newly-appeared disk is the card
```

The FAT **boot** partition is normally the first one (`/dev/sdX1`). Confirm it's
FAT and is the boot partition:

```
lsblk -f /dev/sdX                  # look for vfat / a BOOT label
```

Set `SD_PART=/dev/sdX1`. (No mux: skip the switch step — just `lsblk` after
inserting the card in a reader.)

## When the node changes (the important part)

`/dev/sde1` today can be `/dev/sdb1` tomorrow. Two fixes:

1. **Re-run `zfpga init`** — it shows the current config and rewrites
   `.flash.local` with your new answers. Fastest when several things changed.
2. **Edit `.flash.local` directly** — it's a plain shell file; change the
   `SD_MUX` / `SD_PART` / `SD_DIR` line and save. Fastest for a one-node change.

### Make it survive re-enumeration (recommended)

Address the partition by a **stable** name instead of `/dev/sdX1`, so it never
drifts. `mount` (which zfpga uses) accepts these:

```
SD_PART="LABEL=BOOT"                       # by FAT label (set once, never changes)
# or:
SD_PART="/dev/disk/by-id/usb-...-part1"    # by hardware id; ls /dev/disk/by-id/
```

Label the card once with `sudo fatlabel /dev/sdX1 BOOT`, then `SD_PART="LABEL=BOOT"`
works regardless of which `/dev/sdX` it enumerates as. For the mux control node,
`/dev/sg*` is less stable; if it moves often, add a udev rule giving it a fixed
`/dev/usbsdmux-<serial>` symlink and point `SD_MUX` at that.
