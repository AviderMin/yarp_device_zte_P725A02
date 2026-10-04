#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from the common Open Source product configuration
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# This device has a 64-bit-only ABI list (stock prop.default
# ro.product.cpu.abilist=arm64-v8a,armeabi-v7a,armeabi and
# ro.product.first_api_level=29) - use the 64-bit product template.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)

# Inherit from P725A02 device
$(call inherit-product, device/zte/P725A02/device.mk)

# Inherit common TWRP stuff.  vendor/twrp is the only vendor tree in the
# TWRP-Test manifest - vendor/omni does not exist - so the generated
# vendor/omni/config/common.mk reference could never have worked.
$(call inherit-product, vendor/twrp/config/common.mk)

# Device identifier.  Must come after all inclusions.
PRODUCT_DEVICE := P725A02
PRODUCT_NAME := twrp_P725A02
PRODUCT_BRAND := ZTE
PRODUCT_MODEL := ZTE A2121
PRODUCT_MANUFACTURER := ZTE

# stock/vendor/build.prop ro.vendor.build.fingerprint
#   ZTE/CN_P725A02/P725A02:11/RKQ1.220125.001/20221021.173842:user/release-keys
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="CN_P725A02-user 11 RKQ1.220125.001 20221021.173842 release-keys"

BUILD_FINGERPRINT := ZTE/CN_P725A02/P725A02:11/RKQ1.220125.001/20221021.173842:user/release-keys
