# TWRP device tree for ZTE P725A02 (ZTE A2121, lito / SM7250)

TWRP 3.7.1_16 (Android 16 / TWRP-Test `lvgl` manifest) device tree for the
ZTE P725A02.  Derived from the generated SebaUbuntu template and repaired
against the stock firmware in `stock/` and the real TWRP sources.

## Status

| Area | State |
|---|---|
| fstab / partition layout | repaired from stock evidence |
| product inheritance / lunch | repaired for TWRP 16 |
| boot+recovery header layout | matched to stock byte layout |
| super / A/B partition sizes | resolved from the stock 9008 package |
| kernel / DTB / DTBO prebuilts | byte-identical to stock, verified |
| build (compile) verification | **not run in this task** - see *Verification* |
| FBE / metadata decryption | **not supported yet**, deliberately not claimed |
| on-device (real hardware) verification | **not done**, requires the phone |

## Device facts and where they come from

| Fact | Value | Evidence |
|---|---|---|
| SoC / platform | lito (SM7250) | `stock/vendor/build.prop` `ro.board.platform=lito`; kernel `Linux version 4.19.157-perf+` |
| Android / vendor API | 11 / SDK 30 | `stock/vendor/build.prop` `ro.vendor.build.version.sdk=30` |
| Fingerprint | `ZTE/CN_P725A02/P725A02:11/RKQ1.220125.001/20221021.173842:user/release-keys` | `stock/vendor/build.prop`, stock `prop.default` |
| Security patch | 2022-01-01 | `stock/vendor/build.prop` `ro.vendor.build.security_patch`, `boot.img-os_patch_level=2022-01` |
| Boot storage | UFS `1d84000.ufshc` | stock `fstab.qcom`, stock DTB |
| A/B | yes, plain (not virtual) A/B | `stock/config/config.json` `{"pd_vab":"ab"}`, `_a`/`_b` partitions in `stock/rawprogram4.xml`, no snapshot/COW partition |
| Dynamic partitions | yes, 12 GiB super | `stock/rawprogram0.xml:10` 3145728 x 4096 = 12884901888; `stock/config/config.json` `supersize` |
| boot_a / boot_b | 100663296 B each | `stock/rawprogram4.xml:13`, `:36` (24576 x 4096) |
| recovery_a / recovery_b | 100663296 B each | `stock/rawprogram4.xml:16`, `:39` (24576 x 4096) |
| dtbo_a / dtbo_b | 25165824 B each | `stock/rawprogram4.xml:19`, `:42` (6144 x 4096) |
| Boot header | v2, AOSP, pagesize 4096, base 0, kernel_offset 0x8000, ramdisk_offset 0x01000000, dtb_offset 0x01f00000, tags 0x00000100, gzip ramdisk | `stock/boot/split_img/*` |
| Keymaster | HIDL `android.hardware.keymaster@4.0` (qti) | `stock/vendor/etc/init/android.hardware.keymaster@4.0-service-qti.rc` |
| Boot control HAL | HIDL `android.hardware.boot@1.1` | `stock/vendor/etc/init/android.hardware.boot@1.1-service.rc` |
| Data encryption | FBE + ICE + wrappedkey, `/metadata/vold/metadata_encryption` | stock `fstab.qcom` userdata entry |

## Layout decisions

### Recovery lives on its own partition

`BOARD_USES_RECOVERY_AS_BOOT := false`; the build target is `recoveryimage`,
producing `out/target/product/P725A02/recovery.img`.

Evidence: the stock 9008 package declares `recovery_a`/`recovery_b`
(`stock/rawprogram4.xml:16`, `:39`) and the stock recovery image dump at
`~/workdir/twrpgen/recovery.img` is exactly 100663296 bytes with a genuine AVB
footer (`AVBf`, `original_image_size` 0x03A87000).  Its kernel is byte-identical
to the stock `boot.img` kernel.

### Prebuilts

| File | sha256 | Identity |
|---|---|---|
| `prebuilt/kernel` | `697dd05f4b7af136542e9224e5fa87cafb93a3bb50a22966cf24dc32d5aca3cb` | stock `boot.img-kernel` (42035216 B) |
| `prebuilt/dtb.dtb` | `df33dddc39c6d0b732149229f25f003e9548618f05b608be092bb5b5c10f1e34` | stock `boot.img-dtb` (2027715 B) |
| `prebuilt/dtbo.img` | `8683beb6efaab11f15a9f7108a31955c55b3d28f6301f0001bee542df40b3a0b` | DTBO table, magic `0xd7b7ab1e`, 21 overlays (4561933 B) |

`dtb.img` was renamed to `dtb.dtb` because `INSTALLED_DTBIMAGE_TARGET` builds
`dtb.img` by concatenating `$(BOARD_PREBUILT_DTBIMAGE_DIR)/*.dtb`
(`build/make/core/Makefile:1030-1035`).

### Super size

`BOARD_SUPER_PARTITION_SIZE := 12884901888` (12 GiB) and
`BOARD_ZTE_DYNAMIC_PARTITIONS_SIZE := 12883853312` (12 GiB - 1 MiB).
The generated 8.5 GiB value was wrong.

## Known gaps / things that still need work

1. **Crypto (FBE) is not enabled.**  `TW_INCLUDE_CRYPTO := false`.
   The Qualcomm qseecom/keymaster stack that the decryption path needs is not in
   this repository, and no decryption has been tested on hardware.  See the
   `proprietary-files.txt` template and the commented service definitions in
   `recovery/root/init.recovery.qcom.rc`.
2. **Touch driver is unknown.**  `TW_INPUT_BLACKLIST` was removed because the
   generated `hbtp_vm` does not exist in the stock kernel or DTB.  Identify the
   real driver with `cat /proc/bus/input/devices` under TWRP and re-add the
   blacklist only if a phantom input device appears.
3. **No kernel modules are shipped.**  The stock kernel is a monolithic
   `Image`; nothing in the stock evidence shows recovery needing external
   modules (`recovery/root/lib/modules` loading is only needed if
   `TW_LOAD_VENDOR_MODULES` gets enabled, which it is not).
4. **`bootctrl.lito` may not resolve.**  It belongs to a Qualcomm bootctrl repo
   that this manifest may not contain; `device.mk` notes how to drop it.
5. **Partition sizes describe the factory GPT.**  A modified device can differ;
   re-read them on hardware before flashing anything.

## Verification

Compile verification (runs against the real sources in WSL, read-only w.r.t.
them) and the evidence checker live in `tools/`.

```powershell
# static evidence check (Windows side, no build; 82 assertions)
powershell -NoProfile -File tools\verify-device-tree.ps1
```

```bash
# real build, inside WSL.  The device tree must be visible as
# device/zte/P725A02 in the checkout first, e.g.
#   cp -r /mnt/d/Projects/Github/yarp_device_zte_P725A02 ~/workdir/TWRP-Test/device/zte/P725A02
cd ~/workdir/TWRP-Test
source build/envsetup.sh
lunch twrp_P725A02-eng
mka recoveryimage
# expected artifact:
#   out/target/product/P725A02/recovery.img
# quick artefacts to inspect afterwards:
#   out/target/product/P725A02/recovery.img          (<= 100663296 B)
#   out/target/product/P725A02/ramdisk-recovery.img  (the TWRP ramdisk)
#   out/target/product/P725A02/dtb.img, dtbo.img
# and inside recovery.img verify the header with, e.g.:
#   magiskboot unpack -h recovery.img
#   -> header v2, pagesize 4096, kernel_offset 0x00008000,
#      ramdisk_offset 0x01000000, dtb_offset 0x01f00000
```

### Build status in this task

The static checker above is the verification that was executed here (82/82
pass).  The full `lunch` + `mka recoveryimage` compile was **not** executed by
this task: staging the tree into the shared `~/workdir/TWRP-Test` checkout was
refused by the execution sandbox, and the task brief explicitly leaves syncing
that directory to the verification task.  Nothing in this device tree has been
proven to compile yet.

## Flashing (informational only - this project never flashes automatically)

```bash
fastboot getvar partition-size:recovery   # confirm the real size first
fastboot flash recovery out/target/product/P725A02/recovery.img
# or, matching the A/B slot the device is on:
fastboot flash recovery_a out/target/product/P725A02/recovery.img
```

Shortest path into recovery is `fastboot boot recovery.img` (does not write
anything) - but note TWRP 16 sets `twrpfastboot=1` in the kernel command line
for recovery-as-boot images only; for a dedicated recovery partition, booting
the image directly is still the safest first test.