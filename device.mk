#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

LOCAL_PATH := device/zte/P725A02

# --------------------------------------------------------------- API level
# stock/system/build.prop ro.build.version.sdk=30 / ro.board.api_level=30: the
# vendor side of this device is Android 11 (SDK 30).
PRODUCT_SHIPPING_API_LEVEL := 30

# ----------------------------------------------------- Dynamic partitions
# stock prop.default carries ro.boot.dynamic_partitions=true and the stock
# fstab marks system/product/vendor as logical; the super partition itself is
# 3145728 x 4096 = 12 GiB per stock/rawprogram0.xml:10.
PRODUCT_USE_DYNAMIC_PARTITIONS := true

# ------------------------------------------------------------------ A/B
# Plain (non-virtual) A/B: stock/config/config.json {"pd_vab":"ab"} and the
# 9008 package ships _a/_b copies plus an unsparse super.img, but no snapshot /
# COW / super_empty partition - so ENABLE_VIRTUAL_AB must stay off.
AB_OTA_UPDATER := true

# ------------------------------------------------------- Boot control HAL
# The stock vendor implements boot@1.1, not 1.0:
#   stock/vendor/etc/init/android.hardware.boot@1.1-service.rc
#   stock/vendor/etc/vintf -> android.hardware.boot@1.1
# so the generated boot@1.0 pair was wrong for this device.
PRODUCT_PACKAGES += \
    android.hardware.boot@1.1-impl \
    android.hardware.boot@1.1-service

# NOTE: bootctrl.lito (the QTI/CAF boot control implementation) is NOT part of
# this manifest - there is no hardware/qcom-caf/bootctrl in the checkout and
# nothing in-tree provides that module - so requesting it only breaks the
# build.  TWRP itself does not need a boot control HAL: it reads the slot from
# ro.boot.slot_suffix and drives the misc partition directly.  Both
# `PRODUCT_PACKAGES += bootctrl.lito` and PRODUCT_STATIC_BOOT_CONTROL_HAL were
# therefore dropped from the generated template.  Re-add them only after a
# bootctrl implementation is available in the manifest.

# --------------------------------------------------------- A/B postinstall
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

# ---------------------------------------------------------------- fastbootd
PRODUCT_PACKAGES += \
    fastbootd \
    android.hardware.fastboot@1.0-impl-mock

# -------------------------------------------------------------- Recovery
# libion is used by the recovery display path on msm-4.19/lito.
TARGET_RECOVERY_DEVICE_MODULES += \
    libion

RECOVERY_LIBRARY_SOURCE_FILES += \
    $(TARGET_OUT_SHARED_LIBRARIES)/libion.so

# ------------------------------------------------------------- Properties
# ro.boot.dynamic_partitions is set by the bootloader; nothing to override.
PRODUCT_PROPERTY_OVERRIDES += \
    ro.adb.secure=0

# ------------------------------------------------------------------ Crypto
# Build the TWRP FBE and metadata-decryption path.  The raw userdata partition is
# metadata-encrypted, so a plaintext F2FS superblock only becomes visible after
# the key in /metadata/vold/metadata_encryption has been unwrapped and the
# dm-default-key device has been created.  These switches are also set in
# BoardConfig.mk, where the recovery build consumes them.
TW_INCLUDE_CRYPTO := true
TW_INCLUDE_CRYPTO_FBE := true
TW_INCLUDE_FBE_METADATA_DECRYPT := true
