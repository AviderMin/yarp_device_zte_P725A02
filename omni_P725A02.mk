#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common Omni stuff.
$(call inherit-product, vendor/omni/config/common.mk)

# Inherit from P725A02 device
$(call inherit-product, device/zte/P725A02/device.mk)

PRODUCT_DEVICE := P725A02
PRODUCT_NAME := omni_P725A02
PRODUCT_BRAND := ZTE
PRODUCT_MODEL := ZTE A2121
PRODUCT_MANUFACTURER := zte

PRODUCT_GMS_CLIENTID_BASE := android-zte

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="CN_P725A02-user 11 RKQ1.220125.001 20221021.173842 release-keys"

BUILD_FINGERPRINT := ZTE/CN_P725A02/P725A02:11/RKQ1.220125.001/20221021.173842:user/release-keys
