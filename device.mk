#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#
# 详细依据见根目录 README.md「设备树逐文件说明 / device.mk」。

LOCAL_PATH := device/zte/P725A02

# vendor 侧是 Android 11（SDK 30）
PRODUCT_SHIPPING_API_LEVEL := 30

# 动态分区：super = 12 GiB
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# 普通 A/B，非 virtual A/B
AB_OTA_UPDATER := true

# 原厂实现的是 boot@1.1，不是 1.0
PRODUCT_PACKAGES += \
    android.hardware.boot@1.1-impl \
    android.hardware.boot@1.1-service

# 刻意不加 bootctrl.lito：manifest 里没有该模块，TWRP 也不需要

# A/B postinstall
PRODUCT_PACKAGES += \
    otapreopt_script \
    cppreopts.sh \
    update_engine \
    update_verifier \
    update_engine_sideload

AB_OTA_POSTINSTALL_CONFIG += \
    RUN_POSTINSTALL_system=true \
    POSTINSTALL_PATH_system=system/bin/otapreopt_script \
    FILESYSTEM_TYPE_system=ext4 \
    POSTINSTALL_OPTIONAL_system=true

# fastbootd
PRODUCT_PACKAGES += \
    fastbootd \
    android.hardware.fastboot@1.0-impl-mock

# recovery 显示路径需要 libion（msm-4.19/lito）
TARGET_RECOVERY_DEVICE_MODULES += \
    libion

RECOVERY_LIBRARY_SOURCE_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/libion.so

# ro.boot.dynamic_partitions 由引导器设置，无需覆盖
PRODUCT_PROPERTY_OVERRIDES += \
    ro.adb.secure=0 \
    ro.crypto.set_dun=1 \
    keymaster_ver=4.x

# Crypto：userdata 是 metadata 加密的
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
