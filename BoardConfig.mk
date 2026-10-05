#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

DEVICE_PATH := device/zte/P725A02

# For building with minimal manifest
ALLOW_MISSING_DEPENDENCIES := true

# ------------------------------------------------------------------ A/B
# Hard evidence: stock/config/config.json {"pd_vab":"ab"}; the stock boot ramdisk
# /fstab.qcom carries slotselect on system/product/vendor; the stock 9008 unbrick
# package (stock/rawprogram4.xml) ships _a and _b copies of boot, recovery, dtbo,
# modem, dsp, bluetooth, vbmeta, ...  The updater is plain A/B, NOT virtual A/B
# (no snapshot/COW/super_empty partition anywhere in the package).
AB_OTA_UPDATER := true
AB_OTA_PARTITIONS += \
    boot \
    dtbo \
    odm \
    product \
    recovery \
    system \
    system_ext \
    vbmeta \
    vbmeta_system \
    vendor

# ------------------------------------------------------- Recovery container
# This device has a DEDICATED recovery partition, so recovery must not be folded
# into boot.img.  Evidence:
#   1. User-confirmed device fact.
#   2. stock/rawprogram4.xml:16  recovery_a 24576 x 4096 = 100663296 B
#      stock/rawprogram4.xml:39  recovery_b 24576 x 4096 = 100663296 B
#   3. ~/workdir/twrpgen/recovery.img is an exact 100663296-byte dump of that
#      partition and a genuine signed AVB image (AVBf footer at EOF,
#      original_image_size 0x03A87000) whose kernel is byte-identical to stock
#      boot.img-kernel (sha256 697dd05f...aca3cb).
BOARD_USES_RECOVERY_AS_BOOT := false
# Recovery resources belong in the recovery ramdisk, not in vendor_boot: there is
# no vendor_boot partition in the stock partition table (stock/rawprogram4.xml).
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT :=

# ------------------------------------------------------------------ Arch
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_ABI2 :=
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a76

TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a55
TARGET_SUPPORTS_64_BIT_APPS := true

# ------------------------------------------------------------------ APEX
# The stock vendor partition is Android 11 (SDK 30):
# stock/vendor/build.prop ro.vendor.build.version.sdk=30.
OVERRIDE_TARGET_FLATTEN_APEX := true

# ------------------------------------------------------------- Bootloader
TARGET_BOOTLOADER_BOARD_NAME := lito
TARGET_NO_BOOTLOADER := true

# ---------------------------------------------------------------- Display
# 1080x2460 @ 6.9", panel VISIONOX RM692C9 (10-bit, DSC, command mode).
# Physically ~400 PPI, but the stock ROM ships ro.sf.lcd_density=480 and this
# setting is exactly what produces it
# (build/make/core/sysprop_config.mk:127-129 -> ro.sf.lcd_density), so 480 is
# the device's own density and must not be "corrected" to the physical value.
TARGET_SCREEN_DENSITY := 480

# There is deliberately NO "default refresh rate" knob here.  The generated
# tree carried
#     TARGET_RECOVERY_DEFAULT_REFRESH_RATE := 90
# which is a DEAD variable: a repo-wide grep over the TWRP 16 checkout
# (bootable/, vendor/, build/make/, system/core/, hardware/qcom-caf/, device/)
# finds it only in this device tree and nowhere in any makefile or source file,
# so it could never have affected a build.  Mode selection in the DRM backend is
# driven purely by kernel data:
#   twrpminui/graphics_drm.cpp:1023-1044  find_main_monitor() picks the mode
#       named by video=Virtual-1: on /proc/cmdline, else the first mode with
#       DRM_MODE_TYPE_PREFERRED - it never looks at a refresh rate;
#   twrpminui/graphics_drm.cpp:1291-1294  the chosen mode's hdisplay/vdisplay
#       become the framebuffer size;
#   twrpminui/graphics_drm.cpp:1470       that mode is applied via a DRM
#       property blob.
# The panel actually runs at 90 Hz because the BOOTLOADER selects the 90 Hz
# panel variant, not because of anything in this tree:
#   /proc/cmdline           msm_drm.dsi_display0=qcom,dsi_visionox_rm692c9_10bit_dsc_90hz_cmd_display:
#   dmesg                   Successfully bind display panel 'qcom,dsi_visionox_rm692c9_10bit_dsc_90hz_cmd_display'
#   /sys/class/drm/.../modes  1080x2460x60x63334cmd and 1080x2460x90x88154cmd
# Do not re-add a refresh-rate setting: there is no consumer for one.

# ----------------------------------------------------------------- Kernel
# Every value below is copied from the STOCK images, not guessed:
#   stock/boot/split_img/boot.img-{header_version,base,pagesize,kernel_offset,
#     ramdisk_offset,second_offset,tags_offset,dtb_offset,cmdline,imgtype,
#     ramdiskcomp,hashtype,origsize}
#   ~/workdir/twrpgen/recovery.img - raw v2 header of the stock recovery image
# Stock boot.img: header v2, base 0x00000000, pagesize 4096, kernel_offset
#   0x00008000, ramdisk_offset 0x01000000, second_offset 0x00000000,
#   tags_offset 0x00000100, dtb_offset 0x01f00000, AOSP, sha1, gzip,
#   origsize 100663296.
# Stock recovery.img: identical layout plus a 12733035-byte dtb block in the
#   header dtb_size field, holding the same DTBO data as prebuilt/dtbo.img.
BOARD_BOOTIMG_HEADER_VERSION := 2
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x01000000
BOARD_KERNEL_TAGS_OFFSET := 0x00000100
# The stock dtb_offset is 0x01f00000.  The generated tree never passed it, which
# silently repacks every image with dtb_offset 0.
BOARD_DTB_OFFSET := 0x01f00000
BOARD_KERNEL_CMDLINE := console=ttyMSM0,115200,n8 earlycon=msm_geni_serial,0x888000 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 cgroup.memory=nokmem,nosocket loop.max_part=7 buildvariant=user
BOARD_KERNEL_IMAGE_NAME := Image
# The stock boot/recovery images keep the device DTB inside the image, so it has
# to stay enabled; with a prebuilt dtb the file also has to be named *.dtb
# because INSTALLED_DTBIMAGE_TARGET cats BOARD_PREBUILT_DTBIMAGE_DIR/*.dtb.
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
# The stock recovery image does carry a dtb in its header, but TWRP's recovery
# ramdisk is far larger than the 32 KiB stock one and
# kernel(42 MiB) + ramdisk + dtbo(24 MiB) does not fit the 96 MiB partition.
# The bootloader loads dtbo from the dtbo partition anyway, so keep this off and
# only enable it if a device test proves it is required.
BOARD_INCLUDE_RECOVERY_DTBO := false

BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOTIMG_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)

# -------------------------------------------------------- Kernel - prebuilt
# There is no in-tree kernel source, so the prebuilt path is the only valid one.
# The prebuilts are byte-identical to the stock artifacts:
#   prebuilt/kernel  sha256 697dd05f...aca3cb == stock boot.img-kernel (42035216 B)
#   prebuilt/dtb.dtb sha256 df33dddc...0f1e34 == stock boot.img-dtb (2027715 B)
#   prebuilt/dtbo.img (DTBO table magic 0xd7b7ab1e, 21 overlays) == device dtbo
TARGET_FORCE_PREBUILT_KERNEL := true
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb.dtb
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img
BOARD_MKBOOTIMG_ARGS += --dtb $(TARGET_PREBUILT_DTB)

# ------------------------------------------------------------- Partitions
BOARD_FLASH_BLOCK_SIZE := 262144 # (BOARD_KERNEL_PAGESIZE * 64)
# Sizes come from the stock 9008 unbrick package partition table
# (stock/rawprogram4.xml), i.e. from the vendor's own GPT.  They describe the
# factory layout; a modified device can differ, so re-read them with
# `fastboot getvar partition-size:<name>` before flashing anything.
#   rawprogram4.xml:13/:36  boot_a/boot_b         24576 x 4096 = 100663296
#   rawprogram4.xml:16/:39  recovery_a/recovery_b 24576 x 4096 = 100663296
#   rawprogram4.xml:19/:42  dtbo_a/dtbo_b          6144 x 4096 =  25165824
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 25165824
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_SYSTEMIMAGE_PARTITION_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
# TARGET_COPY_OUT_PRODUCT / TARGET_COPY_OUT_ODM are deliberately NOT set.
# AOSP defaults are system/product and vendor/odm.  Setting them to the
# standalone values 'product'/'odm' activates the check_image_config guard in
# build/make/core/board_config.mk:404-414, which then requires
# BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE / BOARD_ODMIMAGE_FILE_SYSTEM_TYPE (or
# prebuilt images) and makes lunch fail with:
#   "If TARGET_COPY_OUT_PRODUCT is 'product', either BOARD_PREBUILT_PRODUCTIMAGE
#    or BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE must be set."
# This device does not build product.img/odm.img, so the standalone dirs are
# simply not wanted.  BoardConfig.mk:713-716/822-826 confirms the defaults.
TARGET_COPY_OUT_VENDOR := vendor
# The stock boot ramdisk fstab.qcom mounts /metadata and userdata is FBE/ICE
# (fileencryption=ice,wrappedkey,keydirectory=/metadata/vold/metadata_encryption).
BOARD_USES_METADATA_PARTITION := true

# ----------------------------------------------------- Dynamic partitions
# RESOLVED (previously unknown).  stock/rawprogram0.xml:10
#   label="super" num_partition_sectors="3145728" SECTOR_SIZE_IN_BYTES="4096"
#   -> 3145728 * 4096 = 12884901888 B = 12 GiB
# which agrees with stock/config/config.json {"supersize":"12884901888"} and
# {"repack_fz":"qti_dynamic_partitions"}.  The generated 9126805504 (8.5 GiB)
# value was wrong and is corrected here.
BOARD_SUPER_PARTITION_SIZE := 12884901888
BOARD_SUPER_PARTITION_GROUPS := zte_dynamic_partitions
BOARD_ZTE_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext product vendor odm
# AOSP rule: DYNAMIC_PARTITIONS_SIZE = SUPER_PARTITION_SIZE - 1 MiB (metadata slot).
BOARD_ZTE_DYNAMIC_PARTITIONS_SIZE := 12883853312
# NOTE: system_ext and odm are listed although this repo has no such images and
# the stock boot fstab has no /system_ext entry.  They are harmless in an
# AOSP/TWRP build (the partitions are simply not generated) and are required if
# the real super_metadata groups contain them - confirm with `lpdump` on device.

# --------------------------------------------------------------- Platform
TARGET_BOARD_PLATFORM := lito

# --------------------------------------------------------------- Recovery
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
# TWRP resolves the fstab at /etc/twrp.fstab first and /etc/recovery.fstab
# second (bootable/recovery/twrp.cpp:441-446), i.e. /system/etc/... in the
# recovery ramdisk, and build/make/core/Makefile:2821 copies this file there.
# Pointing at the same conventional device-tree path the reference trees use
# (e.g. device/xiaomi/munch) keeps that unambiguous; the Makefile fallback at
# :2645 ($(TARGET_DEVICE_DIR)/recovery.fstab) is deliberately NOT used - the
# generated tree had its fstab in the wrong place and it was moved here.
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab

# --------------------------------------------------------- Security patch
# stock/vendor/build.prop ro.vendor.build.security_patch=2022-01-01 and
# stock boot.img-os_patch_level=2022-01 both say 2022-01-01; the generated tree
# carried 2021-08-01, which is wrong.
VENDOR_SECURITY_PATCH := 2022-01-01

# ----------------------------------------------------------- Verified boot
# The stock recovery is AVB-signed, so keep AVB for recovery.img.
# --flags 3 = HASHTREE_DISABLED | VERIFICATION_DISABLED in vbmeta.
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA2048
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# ------------------------------------------------------------- Platform ver
# PLATFORM_SECURITY_PATCH / PLATFORM_VERSION are Android 16 read-only release
# flags (.KATI_READONLY); setting them from a device tree trips the $(error)
# guards in build/make/core/version_util.mk.  Only PLATFORM_VERSION remains
# overridable.  Recorded stock values: PLATFORM_VERSION=11, patch 2022-01-01.
PLATFORM_VERSION := 99.87.36

# ------------------------------------------------------ TWRP configuration
TW_THEME := portrait_hdpi
TW_FRAMERATE := 90
TW_EXTRA_LANGUAGES := true
TW_SCREEN_BLANK_ON_BOOT := true
TW_USE_TOOLBOX := true
TW_INCLUDE_REPACKTOOLS := true
TW_HAS_EDL_MODE := true
# TW_INPUT_BLACKLIST stays unset, and that is now CONFIRMED on hardware (not
# merely "not proven"): the generated tree blacklisted "hbtp_vm", which does not
# exist here, and of the five registered input devices exactly one is
# touchscreen-class, so there is nothing that needs to be filtered out.
#
# Device-verified facts (read-only adb; raw dumps in log/session-20261005-2150/):
#   /proc/bus/input/devices  raw2/008-input-devices.out, raw/930-input-devices.out
#   ------------------------ ------------------------------------------------
#   goodix_ts   (event4)     THE touchscreen.  ABS=0x0261800000000003 +
#                            BTN_TOUCH + BTN_TOOL_FINGER => protocol-B
#                            multitouch, i.e. TWRP's events.cpp:434-437
#                            has_touch_protocol test passes
#                            (BTN_TOUCH and ABS_MT_POSITION_X/Y both set).
#                            Driver probes clean: goodix_ts_probe OUT r:0,
#                            "input: goodix_ts as .../input4", IRQ 372.
#   gpio-keys   (event3)     KEY=0xc000000000000 = bits 114/115 =
#                            KEY_VOLUMEUP/KEY_VOLUMEDOWN.
#   qpnp_pon    (event0)     KEY=0x14000000000000 = bits 116/118 =
#                            KEY_POWER/KEY_POWER2 (pm8150 pwrkey+resin).
#   ah1898      (event1)     EV=3, KEY bitmap empty => hall sensor, sends only
#                            EV_KEY 0/1 - cannot inject a key press or a touch.
#   goodix_fp   (event2)     fingerprint; not touchscreen-class.
# TWRP reads all of these with ev_get() (events.cpp:1345) after ev_init() scans
# /dev/input (events.cpp:462-470), and the device nodes exist with the expected
# ownership:
#   /dev/input/event*                                      crw-rw---- root input
#   /sys/class/leds/vibrator/{duration,activate}           -rw-rw-r-- root root
#   /sys/class/backlight/panel0-backlight/{brightness,max_brightness}
# The backlight path is auto-discovered - recovery.log prints
#   "Found brightness file at '/sys/class/backlight/panel0-backlight/brightness'"
# which is data.cpp:795 find_first_named_file("brightness", "/sys/class/backlight")
# - so a TW_BRIGHTNESS_PATH override would be redundant and is deliberately NOT
# set.  TWRP's own initial default is tw_brightness = 255/5 = 51 (data.cpp:828),
# and it is only a default: the value actually used comes from the persisted
# twrp settings file, which is why recovery.log shows 100 on this unit (device
# side, not this tree's business).  max_brightness=255 makes any TWRP value
# 0..255 legal, and TW_SCREEN_BLANK_ON_BOOT (gui.cpp:940) writes 0 on boot -
# recovery.log shows exactly that 100 -> 0 sequence.
#
# NO haptics switch either: this device's vibration motor IS reachable through
# the interface TWRP writes (events.cpp:65-68, 352-358 and 380) - the PMIC
# driver registers it as an LED class device
#   /sys/class/leds/vibrator/{duration,activate}   (device -> qcom,vibrator@5300)
# so the "vibrate_with_ff()" route is not needed and "TW_NO_HAPTICS := true"
# would be factually wrong.  A haptic effect can be reproduced without TWRP by
#   echo 200 > /sys/class/leds/vibrator/duration
#   echo 1   > /sys/class/leds/vibrator/activate
# (writing it buzzes the phone; this tree never does it automatically).

# ------------------------------------------------------------- Crypto (FBE)
# /data is metadata-encrypted: the raw userdata block device intentionally has
# no plaintext F2FS superblock.  TWRP must first unwrap the metadata key stored
# under /metadata/vold/metadata_encryption and create the dm-default-key mapping;
# trying to mount /dev/block/sda9 directly always produces a magic mismatch.
# Keep the vendor additional.fstab path because it supplies the stock inlinecrypt
# option.  Qualcomm FBE support and metadata decryption must be compiled in.
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
# The FBE path is on: TW_INCLUDE_CRYPTO_FBE := true above makes
# vendor/twrp/config/BoardConfigSoong.mk:271-272 set TW_INCLUDE_CRYPTO_FBE when
# TW_INCLUDE_CRYPTO is true, and that feeds soong variable include_crypto_fbe
# (BoardConfigSoong.mk:286) -> -DTW_INCLUDE_FBE
# (vendor/twrp/build/soong/Android.bp:295-297).  Verified in the built binary:
#   strings out/target/product/P725A02/ramdisk-recovery.img's
#   /system/bin/recovery | grep -c "misc/vold/user_keys"  ->  1   (only compiled
#   under #ifdef TW_INCLUDE_FBE), while the string that lives in the #else branch
#   ("FBE found but FBE support not present in TWRP", partition.cpp:800+) is 0.
# regression: tools/verify_decrypt_prereqs.mjs check "fbe-macro"
# Pin the keymaster HAL generation instead of deriving it from /vendor.
# Process_Keymaster_Version() (partitionmanager.cpp:265-302) otherwise reads
# <partition>/etc/vintf/manifest.xml, and TWRP unmounts /vendor again before it
# calls Decrypt_Data() (partitionmanager.cpp:453-456 / 561).  The stock vendor
# manifest declares android.hardware.keymaster 4.0 and 4.1
# (stock/vendor/etc/vintf/manifest.xml:87-90), and this device tree ships exactly
# the 4.0 HAL, so 4.x is the correct value here.  Both the macro and the property
# are needed: TW_FORCE_KEYMASTER_VER short-circuits the manifest probe
# (vendor/twrp/build/soong/Android.bp:403-406) and keymaster_ver supplies the
# value (variables.h:161 TW_KEYMASTER_VERSION_PROP).
TW_FORCE_KEYMASTER_VER := true

# Encryption
BOARD_USES_METADATA_PARTITION := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
# Far-future patch level + version, observed to take effect in the TWRP-16
# build of this tree (log/recovery.log shows ro.build.version.security_patch
# = 2099-12-31 and ro.build.version.release = 99.87.36). These are build-time
# props used to satisfy the Keymaster patch-level comparison during FBE
# metadata decryption (README 5.2); they are NOT the device's real patch
# level. VENDOR_SECURITY_PATCH feeds ro.vendor.build.security_patch via
# build/make/core/sysprop_config.mk. If the upstream manifest/branch changes,
# re-verify that these assignments still win (upstream AOSP guards
# PLATFORM_SECURITY_PATCH with ifdef+$(error) in version_util.mk).
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)