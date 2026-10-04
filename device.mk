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
# NOT enabled on purpose.  Setting TW_INCLUDE_CRYPTO only pulls the TWRP crypto
# plumbing into the ramdisk; the actual FBE/ICE decryption path needs the
# Qualcomm keymaster/qseecom stack that lives in the stock vendor image
# (stock/vendor/lib64/libQSEEComAPI.so, libkeymasterdeviceutils.so,
# libkeymasterutils.so, libqtikeymaster4.so, libStDrvInt.so, libGPreqcancel*.so,
# librpmb.so, libssd.so, libsoc_helper.so, libdrm*.so, libsecureui*.so, and
# stock/vendor/bin/qseecomd) plus the keymaster TA image.  None of those blobs
# is in this repository and no decryption has been tested on hardware, so crypto
# support is NOT claimed.  To enable it later:
#   1. populate proprietary-files.txt (template provided) and run
#      extract-files.sh against the stock vendor image,
#   2. set TW_INCLUDE_CRYPTO := true/false accordingly (BoardConfig.mk) and
#      TW_INCLUDE_CRYPTO_FBE := true / TW_INCLUDE_FBE_METADATA_DECRYPT := true
#      here (BOARD_USES_METADATA_PARTITION is already set),
#   3. ship /vendor/bin/{qseecomd,keymasterd} and the keymaster HIDL service in
#      the ramdisk and start them from init.recovery.qcom.rc (commented
#      templates are already in that file),
#   4. verify decryption on the device.
TW_INCLUDE_CRYPTO := false
TW_INCLUDE_CRYPTO_FBE := false
