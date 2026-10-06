#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#
# 详细依据与出处见根目录 README.md「设备树逐文件说明 / BoardConfig.mk」。

DEVICE_PATH := device/zte/P725A02

# 允许在最小 manifest 下构建
ALLOW_MISSING_DEPENDENCIES := true

# ---- A/B：普通 A/B，非 virtual A/B（依据见 README）
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

# ---- recovery 是独立分区，不折进 boot.img
BOARD_USES_RECOVERY_AS_BOOT := false
# 无 vendor_boot 分区，recovery 资源留在 recovery ramdisk
BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT :=

# ---- 架构
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

# ---- APEX：vendor 侧是 Android 11（SDK 30）
OVERRIDE_TARGET_FLATTEN_APEX := true

# ---- Bootloader
TARGET_BOOTLOADER_BOARD_NAME := lito
TARGET_NO_BOOTLOADER := true

# ---- 显示：480 是原厂 ro.sf.lcd_density，不要改成物理 PPI
TARGET_SCREEN_DENSITY := 480
# 刻意不设 TARGET_RECOVERY_DEFAULT_REFRESH_RATE（死变量，无消费者）

# ---- 内核镜像头：每个值都抄自原厂镜像
BOARD_BOOTIMG_HEADER_VERSION := 2
BOARD_KERNEL_BASE := 0x00000000
BOARD_KERNEL_PAGESIZE := 4096
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x01000000
BOARD_KERNEL_TAGS_OFFSET := 0x00000100
# 模板从不传它，会静默地以 dtb_offset 0 重打包
BOARD_DTB_OFFSET := 0x01f00000
BOARD_KERNEL_CMDLINE := console=ttyMSM0,115200,n8 earlycon=msm_geni_serial,0x888000 androidboot.hardware=qcom androidboot.console=ttyMSM0 androidboot.memcg=1 lpm_levels.sleep_disabled=1 video=vfb:640x400,bpp=32,memsize=3072000 msm_rtb.filter=0x237 service_locator.enable=1 androidboot.usbcontroller=a600000.dwc3 swiotlb=2048 cgroup.memory=nokmem,nosocket loop.max_part=7 buildvariant=user
BOARD_KERNEL_IMAGE_NAME := Image
# 原厂把设备 DTB 放进镜像，且 prebuilt 必须命名为 *.dtb
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
# 96 MiB 分区塞不下 kernel+ramdisk+dtbo；引导器本来就自己加载 dtbo
BOARD_INCLUDE_RECOVERY_DTBO := false

BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOTIMG_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET)
BOARD_MKBOOTIMG_ARGS += --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_KERNEL_TAGS_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb_offset $(BOARD_DTB_OFFSET)

# ---- 预编译内核：无 in-tree 源码，三个 prebuilt 与原厂逐字节相同
TARGET_FORCE_PREBUILT_KERNEL := true
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_PREBUILT_DTBIMAGE_DIR := $(DEVICE_PATH)/prebuilt
TARGET_PREBUILT_DTB := $(DEVICE_PATH)/prebuilt/dtb.dtb
BOARD_PREBUILT_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/dtbo.img
BOARD_MKBOOTIMG_ARGS += --dtb $(TARGET_PREBUILT_DTB)

# ---- 分区尺寸：来自原厂 9008 包的 GPT，刷前用 fastboot getvar 复核
BOARD_FLASH_BLOCK_SIZE := 262144 # (BOARD_KERNEL_PAGESIZE * 64)
BOARD_BOOTIMAGE_PARTITION_SIZE := 100663296
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 100663296
BOARD_DTBOIMG_PARTITION_SIZE := 25165824
BOARD_HAS_LARGE_FILESYSTEM := true
BOARD_SYSTEMIMAGE_PARTITION_TYPE := ext4
BOARD_USERDATAIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
# TARGET_COPY_OUT_PRODUCT / TARGET_COPY_OUT_ODM 刻意保持不设（会触发守卫）
TARGET_COPY_OUT_VENDOR := vendor
# 原厂 fstab 挂 /metadata，userdata 是 FBE/ICE
BOARD_USES_METADATA_PARTITION := true

# ---- 动态分区：super = 12 GiB（原厂 9008 包与 config.json 一致）
BOARD_SUPER_PARTITION_SIZE := 12884901888
BOARD_SUPER_PARTITION_GROUPS := zte_dynamic_partitions
BOARD_ZTE_DYNAMIC_PARTITIONS_PARTITION_LIST := system system_ext product vendor odm
# AOSP 规则：DYNAMIC_PARTITIONS_SIZE = SUPER_PARTITION_SIZE - 1 MiB
BOARD_ZTE_DYNAMIC_PARTITIONS_SIZE := 12883853312
# system_ext / odm 本仓库无镜像，列在此处无害；是否必需用设备上的 lpdump 确认

# ---- Platform
TARGET_BOARD_PLATFORM := lito

# ---- Recovery
TARGET_RECOVERY_PIXEL_FORMAT := RGBX_8888
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
# TWRP 先找 /etc/twrp.fstab，再找 /etc/recovery.fstab
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/root/system/etc/recovery.fstab
# 让上面的 fstab 成为 /data 与 /metadata 的唯一来源（否则厂商 additional.fstab 会覆盖）
TW_SKIP_ADDITIONAL_FSTAB := true

# ---- Recovery ramdisk 可执行位：构建期修不了，由 init 启动时 chmod
# 不要在这里加 BOARD_RECOVERY_IMAGE_PREPARE chmod（实测无效，理由见 README）

# ---- 安全补丁级别：原厂为 2022-01-01
VENDOR_SECURITY_PATCH := 2022-01-01

# ---- 验证启动（AVB）：保留 AVB，--flags 3 = HASHTREE|VERIFICATION disabled
BOARD_AVB_ENABLE := true
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA2048
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 1
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 1

# ---- Platform 版本：Android 16 起多数为只读，只有 PLATFORM_VERSION 可覆盖
PLATFORM_VERSION := 99.87.36

# ---- TWRP 配置
TW_THEME := portrait_hdpi
TW_FRAMERATE := 90
TW_EXTRA_LANGUAGES := true
TW_SCREEN_BLANK_ON_BOOT := true
TW_USE_TOOLBOX := true
TW_INCLUDE_REPACKTOOLS := true
TW_HAS_EDL_MODE := true
# TW_INPUT_BLACKLIST 刻意不设；背光路径自动发现；振动无需开关（见 README）

# ---- Crypto（FBE）
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
TW_USE_FSCRYPT_POLICY := 2
# 钉住 keymaster 代次，不从会被卸载的 /vendor 推导
TW_FORCE_KEYMASTER_VER := true

# ---- 加密
BOARD_USES_METADATA_PARTITION := true
BOARD_USES_QCOM_FBE_DECRYPTION := true
# 远未来补丁级别/版本：只为满足解密时的 keymaster 比较，非真实补丁级别
PLATFORM_VERSION := 99.87.36
PLATFORM_VERSION_LAST_STABLE := $(PLATFORM_VERSION)
PLATFORM_SECURITY_PATCH := 2099-12-31
VENDOR_SECURITY_PATCH := $(PLATFORM_SECURITY_PATCH)
