#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#
# 详细依据见根目录 README.md「设备树逐文件说明 / twrp_P725A02.mk」。

# 通用开源产品配置
$(call inherit-product, $(SRC_TARGET_DIR)/product/base.mk)

# 本机是 64 位-only ABI 列表，用 64 位产品模板
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit_only.mk)

# 继承 P725A02 设备配置
$(call inherit-product, device/zte/P725A02/device.mk)

# 继承 TWRP 公共配置（vendor/omni 不存在，只有 vendor/twrp）
$(call inherit-product, vendor/twrp/config/common.mk)

# 设备标识，必须放在所有 inherit 之后
PRODUCT_DEVICE := P725A02
PRODUCT_NAME := twrp_P725A02
PRODUCT_BRAND := ZTE
PRODUCT_MODEL := ZTE A2121
PRODUCT_MANUFACTURER := ZTE

# 取自原厂 stock/vendor/build.prop 的 ro.vendor.build.fingerprint
PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="CN_P725A02-user 11 RKQ1.220125.001 20221021.173842 release-keys"

BUILD_FINGERPRINT := ZTE/CN_P725A02/P725A02:11/RKQ1.220125.001/20221021.173842:user/release-keys
