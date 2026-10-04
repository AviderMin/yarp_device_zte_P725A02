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
TARGET_SCREEN_DENSITY := 480

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
TW_EXTRA_LANGUAGES := true
TW_SCREEN_BLANK_ON_BOOT := true
TW_USE_TOOLBOX := true
TW_INCLUDE_REPACKTOOLS := true
TW_HAS_EDL_MODE := true
# The generated TW_INPUT_BLACKLIST held "hbtp_vm".  That input device does not
# exist here - the stock kernel has zero hits for hbtp/hbtp_vm/hbtp_input and the
# stock DTB never mentions it - so it was removed instead of inventing a driver
# name.  Identify the real touch driver on hardware with
#   cat /proc/bus/input/devices   before setting TW_INPUT_BLACKLIST again.

# ------------------------------------------------------------- Crypto (FBE)
# Deliberately NOT enabled.  See device.mk: turning TW_INCLUDE_CRYPTO on only
# compiles the plumbing; the real FBE/ICE decryption path still needs the
# Qualcomm keymaster/qseecom blobs from the stock vendor partition and has to be
# validated on hardware.  Claiming it from a build flag alone would be false.
TW_INCLUDE_CRYPTO := false