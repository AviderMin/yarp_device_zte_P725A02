#
# Copyright (C) 2026 The Android Open Source Project
# Copyright (C) 2026 SebaUbuntu's TWRP device tree generator
#
# SPDX-License-Identifier: Apache-2.0
#
# 注意：虚线 lunch 组合只用于补全，构建须用三参数形式，见 README。

PRODUCT_MAKEFILES := \
    $(LOCAL_DIR)/twrp_P725A02.mk

COMMON_LUNCH_CHOICES := \
    twrp_P725A02-eng
