# 中兴 P725A02（ZTE A2121，lito / SM7250）TWRP 设备树

本设备树对应 TWRP 3.7.1_16（Android 16，TWRP-Test 的 `lvgl` manifest）。
初始版本由 SebaUbuntu 在线生成器产出，随后依据 `stock/` 中的原厂固件与
真实的 TWRP 源码逐项修缮。

## 当前状态

| 项目 | 状态 |
|---|---|
| fstab / 分区布局 | 已按原厂证据重写 |
| 产品继承 / lunch | 已适配 TWRP 16，可编译 |
| boot 与 recovery 镜像头布局 | 与原厂字节布局一致 |
| super / A/B 分区尺寸 | 已由原厂 9008 救砖包确定 |
| 预编译 kernel / DTB / DTBO | 与原厂产物逐字节相同，已校验 |
| 编译验证 | `lunch` + `mka recoveryimage` 通过（t4） |
| FBE / metadata 解密 | **尚不支持**，明确不宣称 |
| 实机验证 | **未进行**，需要真机 |

## 设备事实及其证据出处

| 事实 | 取值 | 证据 |
|---|---|---|
| 平台 / SoC | lito（SM7250） | `stock/vendor/build.prop` 的 `ro.board.platform=lito`；内核串 `Linux version 4.19.157-perf+` |
| Android / vendor API | 11 / SDK 30 | `stock/vendor/build.prop` 的 `ro.vendor.build.version.sdk=30` |
| 指纹 | `ZTE/CN_P725A02/P725A02:11/RKQ1.220125.001/20221021.173842:user/release-keys` | `stock/vendor/build.prop`、原厂 `prop.default` |
| 安全补丁级别 | 2022-01-01 | `stock/vendor/build.prop` 的 `ro.vendor.build.security_patch`、`boot.img-os_patch_level=2022-01` |
| 启动存储 | UFS `1d84000.ufshc` | 原厂 `fstab.qcom`、原厂 DTB |
| A/B | 是，普通（非虚拟）A/B | `stock/config/config.json` 的 `{"pd_vab":"ab"}`；`stock/rawprogram4.xml` 中存在 `_a`/`_b` 分区；包内无 snapshot / COW 分区 |
| 动态分区 | 是，super 为 12 GiB | `stock/rawprogram0.xml:10`：3145728 x 4096 = 12884901888；`stock/config/config.json` 的 `supersize` |
| boot_a / boot_b | 各 100663296 字节 | `stock/rawprogram4.xml:13`、`:36`（24576 x 4096） |
| recovery_a / recovery_b | 各 100663296 字节 | `stock/rawprogram4.xml:16`、`:39`（24576 x 4096） |
| dtbo_a / dtbo_b | 各 25165824 字节 | `stock/rawprogram4.xml:19`、`:42`（6144 x 4096） |
| 镜像头 | v2、AOSP、pagesize 4096、base 0、kernel_offset 0x8000、ramdisk_offset 0x01000000、dtb_offset 0x01f00000、tags 0x00000100、gzip ramdisk | `stock/boot/split_img/*` |
| 密钥管理 Keymaster | HIDL `android.hardware.keymaster@4.0`（qti 实现） | `stock/vendor/etc/init/android.hardware.keymaster@4.0-service-qti.rc` |
| 启动控制 HAL | HIDL `android.hardware.boot@1.1` | `stock/vendor/etc/init/android.hardware.boot@1.1-service.rc` |
| 数据加密 | FBE + ICE + wrappedkey，密钥目录 `/metadata/vold/metadata_encryption` | 原厂 `fstab.qcom` 的 userdata 条目 |

## 布局决策

### recovery 位于独立分区

`BOARD_USES_RECOVERY_AS_BOOT := false`，构建目标为 `recoveryimage`，
产物是 `out/target/product/P725A02/recovery.img`。

依据有两条：原厂 9008 包明确声明了 `recovery_a`/`recovery_b`
（`stock/rawprogram4.xml:16`、`:39`）；并且 `~/workdir/twrpgen/recovery.img`
这份原厂 recovery 转储恰好是 100663296 字节，带有真实的 AVB 页脚
（`AVBf`，`original_image_size` 为 0x03A87000）。该镜像的内核与原厂
`boot.img` 的内核逐字节相同。

### 分区输出目录保持 AOSP 默认值

`TARGET_COPY_OUT_PRODUCT` 与 `TARGET_COPY_OUT_ODM` 被**刻意不设置**，
因此保持默认值 `system/product` 与 `vendor/odm`
（`build/make/core/board_config.mk:713-716`、`:822-826`）。

一旦把它们设成独立的 `product` / `odm`，就会触发
`build/make/core/board_config.mk:404-414` 中的 `check_image_config` 校验，
进而要求提供 `BOARD_PREBUILT_PRODUCTIMAGE` / `BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE`
（ODM 同理），使 `lunch` 阶段直接失败并报出
`If TARGET_COPY_OUT_PRODUCT is 'product', either BOARD_PREBUILT_PRODUCTIMAGE or BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE must be set.`
本设备不构建 `product.img` / `odm.img`，不需要这两个独立目录，因此该校验必须保持不触发。
（`TARGET_COPY_OUT_VENDOR := vendor` 可以保留，因为 `BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE`
已经设置。）

### 预编译产物

| 文件 | sha256 | 身份 |
|---|---|---|
| `prebuilt/kernel` | `697dd05f4b7af136542e9224e5fa87cafb93a3bb50a22966cf24dc32d5aca3cb` | 原厂 `boot.img-kernel`（42035216 字节） |
| `prebuilt/dtb.dtb` | `df33dddc39c6d0b732149229f25f003e9548618f05b608be092bb5b5c10f1e34` | 原厂 `boot.img-dtb`（2027715 字节） |
| `prebuilt/dtbo.img` | `8683beb6efaab11f15a9f7108a31955c55b3d28f6301f0001bee542df40b3a0b` | DTBO 表，magic `0xd7b7ab1e`，含 21 个 overlay（4561933 字节） |

`dtb.img` 被改名为 `dtb.dtb`，原因是 `INSTALLED_DTBIMAGE_TARGET` 会把
`$(BOARD_PREBUILT_DTBIMAGE_DIR)/*.dtb` 拼接成 `dtb.img`
（`build/make/core/Makefile:1030-1035`），旧扩展名会被忽略。

### super 分区尺寸

`BOARD_SUPER_PARTITION_SIZE := 12884901888`（12 GiB），
`BOARD_ZTE_DYNAMIC_PARTITIONS_SIZE := 12883853312`（12 GiB 减 1 MiB）。
生成器原先填写的 8.5 GiB 是错误的，已纠正。

## 已知缺口与待办

1. **未启用加密（FBE）。** `TW_INCLUDE_CRYPTO := false`。解密路径所需的
   高通 qseecom/keymaster 相关库不在本仓库内，也未在真机上验证过解密。
   `recovery/root/init.recovery.qcom.rc` 中已用注释列出了必须先提取的确切文件清单。
2. **触摸驱动未知。** 已移除 `TW_INPUT_BLACKLIST`，因为生成器填入的 `hbtp_vm`
   在原厂内核与原厂 DTB 中都不存在。请在真机进入 TWRP 后用
   `cat /proc/bus/input/devices` 确认真实驱动，仅在确实出现幽灵输入设备时才重新加入黑名单。
3. **未随包提供内核模块。** 原厂内核是单体的 `Image`，原厂证据中没有任何
   recovery 需要外部模块的迹象（只有在启用 `TW_LOAD_VENDOR_MODULES` 时才需要加载
   `recovery/root/lib/modules`，而本设备并未启用）。
4. **未请求 `bootctrl.lito`。** 本 manifest 中没有 `hardware/qcom-caf/bootctrl`，
   而 TWRP 本身也不需要启动控制 HAL。只有在该实现可用后才应重新加入。
5. **分区尺寸描述的是原厂 GPT。** 已被改动过的机器可能不同，刷写前请在真机上重新读取。

## 构建步骤

设备树必须位于检出目录的 `device/zte/P725A02`：

```bash
cp -r /mnt/d/Projects/Github/yarp_device_zte_P725A02 ~/workdir/TWRP-Test/device/zte/P725A02
cd ~/workdir/TWRP-Test
source build/envsetup.sh
lunch twrp_P725A02 bp2a eng
mka recoveryimage
```

必须使用**三参数**形式。Android 16 的 `lunch` 也接受单个
`<product>-<release>-<variant>` 参数，但只接受这一种完整形状：

* `lunch twrp_P725A02-eng` 会走旧式（legacy）组合解析，`variant` 解析为空，
  报错 `Invalid lunch combo: twrp_P725A02-eng` 并失败。
* `lunch twrp_P725A02`（或 `lunch twrp_P725A02 eng`）会把 `TARGET_RELEASE`
  取为默认值 `trunk_staging`，而本 manifest 不存在该 release 配置，
  会在 `build/make/core/release_config.mk:142` 处中止并报
  `Missing config trunk_staging`。本分支实际提供 `bp2a`（以及 ap2a/ap3a/ap4a/bp1a），
  位于 `build/release/release_configs/`。

`AndroidProducts.mk` 中的 `COMMON_LUNCH_CHOICES := twrp_P725A02-eng` 仍然保留，
仅用于 Tab 补全与 `list_products` 元数据，它并不能让虚线组合变得可构建。

预期产物：

```
out/target/product/P725A02/recovery.img          # 必须 <= 100663296 字节
out/target/product/P725A02/ramdisk-recovery.img  # TWRP 的 recovery ramdisk
out/target/product/P725A02/dtb.img
out/target/product/P725A02/dtbo.img
```

如需核对产物镜像头（可选，需要 magiskboot）：

```bash
magiskboot unpack -h recovery.img   # 期望 header v2、pagesize 4096、
                                    # kernel_offset 0x00008000、
                                    # ramdisk_offset 0x01000000、
                                    # dtb_offset 0x01f00000
```

## 独立证据复核

上文所有数值都可以只凭本仓库重新推导，无需编译。

```powershell
# 预编译产物与原厂文件逐字节相同
Get-FileHash prebuilt/kernel  -Algorithm SHA256   # == stock/boot/split_img/boot.img-kernel
Get-FileHash prebuilt/dtb.dtb -Algorithm SHA256   # == stock/boot/split_img/boot.img-dtb

# 分区尺寸直接来自 9008 包（label / 扇区数 / 扇区大小）
Select-String -Path stock/rawprogram0.xml -Pattern 'label="super"'
Select-String -Path stock/rawprogram4.xml -Pattern 'label="(boot|recovery|dtbo)_[ab]"'

# 两个会导致阻塞的输出目录变量必须不出现（未注释形式）
Select-String -Path BoardConfig.mk -Pattern '^TARGET_COPY_OUT_(PRODUCT|ODM)'   # 应无输出
```

```bash
# 同样的检查，在 WSL 中执行
cd ~/workdir/TWRP-Test/device/zte/P725A02
sha256sum prebuilt/kernel prebuilt/dtb.dtb \
  /mnt/d/Projects/Github/yarp_device_zte_P725A02/stock/boot/split_img/boot.img-kernel \
  /mnt/d/Projects/Github/yarp_device_zte_P725A02/stock/boot/split_img/boot.img-dtb
grep -nE '^(TARGET_COPY_OUT_(PRODUCT|ODM)|BOARD_(SUPER|RECOVERYIMAGE)_PARTITION_SIZE)' BoardConfig.mk
```

## 实机检查清单

以下项目在真机上逐条确认前，均视为未验证：

1. 真实分区尺寸：`fastboot getvar partition-size:recovery`（以及 `:boot`、`:dtbo`、`:super`），
   与本文档记录的原厂值对照；被改动过的机器可能不同。
2. 触摸驱动：在 TWRP 中执行 `cat /proc/bus/input/devices`，确认触摸设备名与
   `TW_INPUT_BLACKLIST` 是否需要设置。
3. 屏幕方向、分辨率与背光：确认 TWRP 界面方向正确，背光可调。
4. 能否挂载 `system` / `vendor` / `product` / `odm`（logical 分区）与 `metadata`。
5. FBE 解密：当前不支持，需先提取原厂 vendor 的 qseecom/keymaster 相关文件后再验证。
6. `recovery.img` 实际尺寸是否仍不超过 100663296 字节。
7. AVB 策略：`--flags 3` 是否满足本机启动要求（可能需要配合 vbmeta 处理）。
8. 至少一次 `fastboot boot recovery.img`（只引导、不写入）作为最小风险验证。

## 刷写说明（仅供参考，本项目从不自动刷机）

```bash
fastboot getvar partition-size:recovery   # 先确认真实尺寸
fastboot flash recovery out/target/product/P725A02/recovery.img
# 或者与机器当前 A/B 槽位对应：
fastboot flash recovery_a out/target/product/P725A02/recovery.img
```

进入 recovery 的最低风险方式是 `fastboot boot recovery.img`（不写入任何分区）。
需要说明的是：TWRP 16 只会在 recovery-as-boot 形态的镜像上向内核命令行追加
`twrpfastboot=1`；本设备是独立 recovery 分区，直接引导该镜像仍是最安全的首个验证步骤。