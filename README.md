# 中兴 P725A02（ZTE A2121，lito / SM7250）TWRP 设备树

本设备树用于 TWRP 3.7.1_16（Android 16 基线）。初始版本由 SebaUbuntu 在线生成器
产出，随后依据 `stock/` 中的原厂固件与 `~/workdir/TWRP-Test` 中的真实 TWRP 源码
逐项修缮，并经过一次完整的真实编译与镜像核对。

## 当前状态

| 项目 | 状态 |
|---|---|
| fstab / 分区布局 | 已按原厂 recovery 镜像与 9008 包证据重写；super 的实际内容已用实机日志核对（只有 system / product / vendor，见「super 的实际内容」） |
| 产品继承 / lunch | 已适配 TWRP 16，可编译 |
| boot 与 recovery 镜像头布局 | 与原厂字节布局逐项一致 |
| super / A/B 分区尺寸 | 已由原厂 9008 救砖包确定 |
| 预编译 kernel / DTB / DTBO | 与原厂产物逐字节相同，已校验 |
| 静态证据核对 | 通过 |
| 编译验证 | **通过**（`mka recoveryimage` 成功产出 recovery.img） |
| 镜像结构核对 | **通过**（镜像头、内核、DTB、ramdisk 内容逐项核对） |
| FBE / metadata 解密 | **不支持**，明确不宣称 |
| 实机验证（显示 / 触摸 / 挂载 / 引导） | **部分进行**：已拿到一次实机运行的 `log/`；显示、触摸、logical 分区、`/metadata` 均正常，`/data` 无法挂载（原因见实机检查清单 6a） |

## 重要风险提示（请先读）

1. **不支持 FBE 解密。** 本设备 userdata 使用 FBE + ICE + wrappedkey。当前构建
   未包含高通 qseecom / keymaster 相关库与服务，进入 TWRP 后**无法解密 data**，
   也无法读取加密后的用户数据。`TW_INCLUDE_CRYPTO := false`。详见下文“FBE 限制”。
2. **镜像使用 AOSP 测试密钥签名。** `BOARD_AVB_RECOVERY_KEY_PATH` 指向
   `external/avb/test/data/testkey_rsa2048.pem`，这是公开私钥。在**锁定的**（locked）
   设备上，该镜像无法通过厂商签名校验，可能直接拒绝引导；在已解锁设备上可引导，
   但请知悉其签名不具备任何可信度。
3. **解锁引导器通常要求清空用户数据**，请先自行备份，且本项目**不做任何自动刷写**。
4. **`/data` 挂载失败属于分区本身的问题，不是本设备树的配置问题，也不要靠格式化来“修”。**
   实机 `log/dmesg.txt` 显示内核 F2FS 驱动在 `/dev/block/sda9` 上两个 superblock 的 magic
   都不等于 `0xf2f52010`；同一时刻其它分区全部正常挂载。也就是说该分区当前不是有效的 F2FS。
   任何 `recovery.fstab` 选项都改变不了这一点。**不要格式化 userdata / 不要 `make_f2fs` /
   不要 `fsck -y`**，否则可能毁掉本来可恢复的数据。详细依据见“实机检查清单”第 6a 条。

5. **显示与触摸依赖设备的 dtbo 分区。** 面板与触摸的 overlay 不在本 recovery 镜像内，
   而是由引导器从 `dtbo_a`/`dtbo_b` 分区叠加；因此首次实机验证必须确认显示与触摸，
   若该分区被改动过，可能出现黑屏或无触摸。

## 源码版本

| 项目 | 取值 |
|---|---|
| manifest 仓库 | `https://github.com/TWRP-Test/platform_manifest_twrp_aosp`（分支 `lvgl`） |
| manifest 版本 | `ffeeac4395eac483df102495ea6f908c95fd3891` |
| AOSP 基线 | `android-16.0.0_r1` |
| TWRP 版本串 | `3.7.1_16`（`bootable/recovery/variables.h:20` 的 `TW_MAIN_VERSION_STR`） |
| 本设备树验证基线 | 提交 `dce3d21d3f183ae08ac821c94fbfff679731ed5c`（下表 `recovery.img` 哈希即对应此版本；构建时间 2026-10-04T23:54+08:00）。任何后续改动都必须重新构建并再次独立复验 |
| 可用 release 配置 | `bp2a`（另有 ap2a / ap3a / ap4a / bp1a），位于 `build/release/release_configs/` |

编译验证与复验均在真实检出 `~/workdir/TWRP-Test` 上完成，**未对上游 TWRP 源码做任何修改**。

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
| 数据加密 | FBE + ICE + wrappedkey，密钥目录 `/metadata/vold/metadata_encryption` | 原厂 `fstab.qcom` 与 `~/workdir/twrpgen/recovery.img` 内的 `system/etc/recovery.fstab` |

### 原厂 XML 依据（分区尺寸的唯一来源）

本仓库的 `rawprogram*.xml` 是原厂 9008 救砖包分区表，所有分区尺寸都由它计算得出：

| 分区 | XML 位置 | 扇区数 x 扇区大小 | 字节 |
|---|---|---|---|
| super | `stock/rawprogram0.xml:10` | 3145728 x 4096 | 12884901888（12 GiB） |
| boot_a / boot_b | `stock/rawprogram4.xml:13` / `:36` | 24576 x 4096 | 100663296（96 MiB） |
| recovery_a / recovery_b | `stock/rawprogram4.xml:16` / `:39` | 24576 x 4096 | 100663296（96 MiB） |
| dtbo_a / dtbo_b | `stock/rawprogram4.xml:19` / `:42` | 6144 x 4096 | 25165824（24 MiB） |
| apdp | `stock/rawprogram4.xml:51` | 64 x 4096 | 262144 |
| logdump | `stock/rawprogram4.xml:58` | 16384 x 4096 | 67108864 |

XML 描述的是**救砖包中的原厂 GPT**；若实机 GPT 被改动过，请以真机读取结果为准（见实机清单）。

## 布局决策

### recovery 位于独立分区

`BOARD_USES_RECOVERY_AS_BOOT := false`，构建目标为 `recoveryimage`，
产物是 `out/target/product/P725A02/recovery.img`。

依据三条：原厂 9008 包声明了 `recovery_a`/`recovery_b`；`~/workdir/twrpgen/recovery.img`
这份原厂 recovery 转储恰好是 100663296 字节且带真实 AVB 页脚（`AVBf`，
`original_image_size` 为 0x03A87000）；该转储的内核与原厂 `boot.img` 的内核逐字节相同。
编译结果也印证了这一点：只产出 `recovery.img` 与 `dtb.img`，
**没有** `boot.img` / `vendor_boot.img` / `dtbo.img`。

### 分区输出目录保持 AOSP 默认值

`TARGET_COPY_OUT_PRODUCT` 与 `TARGET_COPY_OUT_ODM` 被**刻意不设置**，
因此保持默认值 `system/product` 与 `vendor/odm`
（`build/make/core/board_config.mk:713-716`、`:822-826`）。

一旦把它们设成独立的 `product` / `odm`，就会触发
`build/make/core/board_config.mk:404-414` 中的 `check_image_config` 校验，
进而要求提供 `BOARD_PREBUILT_PRODUCTIMAGE` / `BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE`
（ODM 同理），使 `lunch` 阶段直接失败并报出
`If TARGET_COPY_OUT_PRODUCT is 'product', either BOARD_PREBUILT_PRODUCTIMAGE or BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE must be set.`
本设备不构建 `product.img` / `odm.img`，因此该校验必须保持不触发。
（`TARGET_COPY_OUT_VENDOR := vendor` 可以保留，因为 `BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE`
已经设置。）回归检查：`grep -c '^TARGET_COPY_OUT_(PRODUCT|ODM)' BoardConfig.mk` 必须为 0。

### super 分区尺寸

`BOARD_SUPER_PARTITION_SIZE := 12884901888`（12 GiB），
`BOARD_ZTE_DYNAMIC_PARTITIONS_SIZE := 12883853312`（12 GiB 减 1 MiB）。
生成器原先填写的 8.5 GiB 是错误的，已纠正。组名 `zte_dynamic_partitions` 与
`BOARD_ZTE_DYNAMIC_PARTITIONS_PARTITION_LIST` 一一对应，避免了组名为 `super` 时
与 `BOARD_SUPER_DYNAMIC_PARTITIONS_SIZE` 撞车的问题。

### super 的实际内容（只有 system / product / vendor）

实机日志与 `stock/` 物证给出同一个结论：本机 super 当前槽位元数据里只有 `system_b`、
`product_b`、`vendor_b` 三个逻辑分区，**没有** `system_ext_b`，也没有 `odm_b`。

| 证据 | 内容 |
|---|---|
| `log/recovery.txt:36/49/54` | system、product、vendor 各拿到一个 dm 节点（dm-4 / dm-3 / dm-5）并建好 by-name 符号链接 |
| `log/recovery.txt:42-43`、`:59-60` | system_ext、odm 查不到对应 dm 节点，打印 `unable to update logical partition`；TWRP 随后把这两条从分区列表里丢弃（预期行为，不是崩溃） |
| `stock/boot/ramdisk/fstab.qcom`、`stock/vendor/etc/fstab.default` | 原厂自己的 fstab 只把 system / product / vendor 标为 `logical,first_stage_mount`，既没有 system_ext 也没有 odm |
| `stock/config/` | 只有 system / product / vendor 的 fs_config、file_contexts 与 `*_size.txt`，没有 odm / system_ext 的任何一项 |
| `stock/vendor/odm/etc/build.prop`、`stock/system/system/system_ext/etc/build.prop`、`stock/system/system_ext` | odm 内容在 vendor 镜像的 `/vendor/odm`；system_ext 内容在 system 镜像的 `/system/system_ext`，根目录 `/system_ext` 是指向它的符号链接——正是 AOSP 默认输出目录 `vendor/odm`、`system/system_ext` 下的合并布局 |
| `stock/product/etc/build.prop:25` | 原厂 `ro.product.ab_ota_partitions=system,product,vbmeta_system`，同样不含 system_ext / odm |

机理（`bootable/recovery/`）：`Setup_Super_Devices()` → `fs_mgr::CreateLogicalPartitions()`
只按当前槽位元数据里的 enabled 分区建 dm 节点，`Prepare_Super_Volume()` 再用
`<名字><槽位>`（如 `system_ext_b`）去查；查不到就在 `partitionmanager.cpp:387` 处把该条目
丢掉。所以把 super 里不存在的分区写进 `recovery.fstab`，只会得到日志噪声与失真的
`Super (5) partitions` 计数，**不可能**把分区变出来。
这两条已从 `recovery/root/system/etc/recovery.fstab` 移除，内容改由 `/system`、`/vendor` 覆盖。
挂载后仍可访问：`/system_root/system/system_ext`（system 分区内）与 `/vendor/odm`（vendor 分区内）。

真机上只读复核 super 布局：

```sh
lpdump                     # super 元数据里的分区名，应只有 system_? / product_? / vendor_?
ls -l /dev/block/mapper/   # 当前槽位实际建出的 dm 名字
```

顺带一提：这两条上原本的 `optional` 标记对 TWRP 没有意义（日志里是 `Unhandled flag:
'optional'`），本次一并去掉；同一次开机的 dmesg 里 init 侧也有 2 条 `[libfstab] Warning:
unknown flag: optional`，数量与这两条一致。

`BoardConfig.mk` 里 `BOARD_ZTE_DYNAMIC_PARTITIONS_PARTITION_LIST`（第 169 行）与
`AB_OTA_PARTITIONS`（第 20-30 行）也仍按生成器模板列着 `system_ext`、`odm`。两者都没有
造成上面那两条日志，处理方式如下：组列表只被 soong 的 `super_image.go` 在构建 super.img 时
读取（`build/make/core/` 下没有引用），对 `recovery.img` 完全没有影响；`AB_OTA_PARTITIONS`
只会写进 `ro.*.build.ab_ota_partitions` 属性（实机日志里可见），而 TWRP 运行时不读该属性
（`bootable/recovery/` 里 grep 不到 `ab_ota_partitions`）。因此本轮不改动它们；若以后要用
本树构建 super/OTA，必须先按上面的结论把 `system_ext`、`odm` 去掉。

**注意**：本轮只改了 ramdisk 内的 fstab，`recovery.img` 必须重新构建并再次独立复验；
「验证记录」表里的 sha256 是改动前的基线（见该表说明 1）。

### 预编译产物

| 文件 | sha256 | 身份 |
|---|---|---|
| `prebuilt/kernel` | `697dd05f4b7af136542e9224e5fa87cafb93a3bb50a22966cf24dc32d5aca3cb` | 原厂 `boot.img-kernel`（42035216 字节） |
| `prebuilt/dtb.dtb` | `df33dddc39c6d0b732149229f25f003e9548618f05b608be092bb5b5c10f1e34` | 原厂 `boot.img-dtb`（2027715 字节） |
| `prebuilt/dtbo.img` | `8683beb6efaab11f15a9f7108a31955c55b3d28f6301f0001bee542df40b3a0b` | DTBO 表，文件头字节为 `d7 b7 ab 1e`（即 DTBO 表结构标识），含 21 个 overlay（4561933 字节） |

`dtb.img` 被改名为 `dtb.dtb`，原因是 `INSTALLED_DTBIMAGE_TARGET` 会把
`$(BOARD_PREBUILT_DTBIMAGE_DIR)/*.dtb` 拼接成 `dtb.img`
（`build/make/core/Makefile:1030-1035`），旧扩展名会被忽略。

### 分区表在 fstab 与 twrp.flags 之间的分工

原厂 recovery 镜像自带的 `system/etc/recovery.fstab` 同时列出了可挂载文件系统与
整块分区。TWRP 的惯例是：可挂载的文件系统写进 `recovery.fstab`，
只能整块备份/刷写的分区写进 `twrp.flags`。因此本项目按此分工拆分，
并把原厂 fstab 中的**每一个**挂载点都保留在了二者之一（唯一例外是 `/odm`：它只在原厂模板里出现，实机 super 里没有这个分区，详见下表与「super 的实际内容」）：

| 原厂 recovery.fstab 挂载点 | 本项目位置 |
|---|---|
| `/system` `/product` `/vendor` `/metadata` `/data` `/mnt/vendor/persist` `/misc` `/vendor/firmware_mnt` `/vendor/dsp` `/vendor/bt_firmware` | `recovery/root/system/etc/recovery.fstab` |
| `/boot` `/recovery` `/apdp` `/persistent`(frp) `/msadp` `/ztecfg` | `recovery/root/system/etc/twrp.flags` |
| `/sdcard` `/storage/sdcard1` `/storage/usbotg` | `twrp.flags` 中的 `/sdcard1`、`/usb_otg`（TWRP 采用自身可移动存储处理，不用 voldmanaged 通配符） |
| —（本项目新增） | `recovery.fstab` 的 `/logdump` |
| `/odm`（原厂 fstab 列出，但本机 super 里没有该分区） | **不写入** `recovery.fstab`：odm 的内容在 vendor 镜像的 `/vendor/odm`，由 `/vendor` 条目覆盖；原厂 fstab 里根本没有 `/system_ext`，system_ext 的内容在 system 镜像的 `/system/system_ext`（依据见「super 的实际内容」） |

`twrp.flags` 内部对证据做了分级：`[已证实]` 表示名称出现在本仓库 XML 或原厂
recovery fstab 中；`[待确认]` 表示仅见于原厂 recovery fstab（未出现在本仓库 XML），
真机上节点不存在时 TWRP 会直接忽略，但**未确认前不要用它刷写**。

同一个道理也适用于 `/odm` 与 `/system_ext`：`/odm` 只出现在原厂 fstab 里（super 元数据里没有它），`/system_ext` 连原厂 fstab 里都没有。把它们写进 `recovery.fstab` 只会让 TWRP 每次开机打印 `unable to update logical partition`，所以两者都不写，内容分别由 `/vendor`、`/system` 覆盖。

## 验证记录

下表明确区分四类验证：静态核对、编译验证、镜像结构核对、实机验证。
“结果”列中标注了依据来源；“未做”即为未做，不做推测。

| 类型 | 项目 | 结果 |
|---|---|---|
| 静态 | 预编译 kernel 与原厂 `boot.img-kernel` 逐字节相同 | 通过（sha256 `697dd05f…aca3cb`，两侧一致） |
| 静态 | `prebuilt/dtb.dtb` 与原厂 `boot.img-dtb` 逐字节相同 | 通过（sha256 `df33dddc…0f1e34`，两侧一致） |
| 静态 | `prebuilt/dtbo.img` 为 DTBO 表 | 通过（文件头字节 `d7 b7 ab 1e`，21 个 overlay） |
| 静态 | 分区尺寸与 `rawprogram*.xml` 一致 | 通过（见上表，全部由扇区数 x 4096 复算） |
| 静态 | `TARGET_COPY_OUT_PRODUCT` / `_ODM` 未设置 | 通过（回归检查计数为 0） |
| 编译 | `lunch` 与 `mka recoveryimage` | 通过（`lunch twrp_P725A02 bp2a eng` 返回 0；`mka recoveryimage` 返回 0，约 2.5 分钟） |
| 编译 | 是否为独立 recoveryimage 而非 recovery-as-boot | 通过（只产出 `recovery.img` 与 `dtb.img`，无 `boot.img`／`vendor_boot.img`／`dtbo.img`） |
| 镜像 | `recovery.img` 尺寸 | 100663296 字节（恰好 96 MiB，余量为 0） |
| 镜像 | `recovery.img` sha256 | `539ca3630b04ea2187685d4b1e5df8c6f52d1bca6732667e619a112bfbeba15b`（独立复验构建，2026-10-04T23:54+08:00） |
| 镜像 | 镜像头字段 | 通过（`ANDROID!` / v2；pagesize 4096；kernel_addr 0x00008000；ramdisk_addr 0x01000000；tags_addr 0x00000100；dtb_addr 0x01f00000；second_size 0） |
| 镜像 | 内核与原厂逐字节相同 | 通过（镜像内 kernel sha256 `697dd05f…aca3cb`；产物 `out/.../kernel` 亦为同一哈希） |
| 镜像 | DTB 段 | 通过（产物 `dtb.img` sha256 `df33dddc…0f1e34`，与原厂 `boot.img-dtb` 相同，2027715 字节） |
| 镜像 | recovery ramdisk 内容 | 通过（gzip，压缩 27461540 字节 / 解压 66198272 字节，含 `system/bin/recovery`） |
| 镜像 | ramdisk 内 4 个设备文件与工作区源文件是否一致 | 通过（`recovery.fstab`、`twrp.flags`、`ueventd.rc`、`init.recovery.qcom.rc` 哈希逐项相同） |
| 镜像 | `/etc` 解析 | 通过（TWRP 自带 `init.rc` 执行 `symlink /system/etc /etc`；`twrp.cpp:441-446` 先找 `/etc/twrp.fstab`，否则用 `/etc/recovery.fstab`） |
| 实机 | 真实分区尺寸 | **未做** |
| 实机 | 显示与触摸 | **未做** |
| 实机 | 挂载 logical 分区与 metadata | **未做** |
| 实机 | FBE 解密 | **未做且当前不支持** |
| 实机 | 引导（`fastboot boot`） | **未做** |

关于上面这组数值的三点说明：

1. 表中 `recovery.img` 的尺寸与 sha256 对应的是**上表所列验证基线（提交 `dce3d21d…`）**，
   即 t5 整合后的设备树版本；任何后续改动（包括仅修改 ramdisk 内的配置文件）都会改变该哈希，
   必须重新构建并发起独立复验。
2. 该镜像另经独立复验：AVBf 页脚存在（`orig_image_size` = 76099584，0x04893000），
   内部 AVB0 vbmeta 为 1664 字节；ramdisk 内 4 个设备文件的哈希与工作区源文件逐项一致
   （`recovery.fstab` `bb4d6872…`、`twrp.flags` `00190f77…`、`ueventd.rc` `86c2edee…`、
   `init.recovery.qcom.rc` `a3656f7a…`）。
3. 早前一次构建（t4 阶段，设备树为 t5 整合前的版本）产出的哈希为
   `84c6ef39bc43c3a7253baf2d55dcbb229e290926b6c91210379ae98a5f0dbdd3`，
   **已被 t5 整合取代，不是最终产物**，仅在此备案以免混淆。

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
  `Missing config trunk_staging`。本分支实际提供 `bp2a`，位于 `build/release/release_configs/`。

`AndroidProducts.mk` 中的 `COMMON_LUNCH_CHOICES := twrp_P725A02-eng` 仍然保留，
仅用于 Tab 补全与 `list_products` 元数据，它并不能让虚线组合变得可构建。

预期产物：

```
out/target/product/P725A02/recovery.img          # 必须 <= 100663296 字节
out/target/product/P725A02/ramdisk-recovery.img  # TWRP 的 recovery ramdisk
out/target/product/P725A02/dtb.img
```

（本设备为独立 recovery 分区，因此**不会**产出 `boot.img`、`vendor_boot.img`、`dtbo.img`。）

核对产物镜像头（可选，需要 magiskboot）：

```bash
magiskboot unpack -h recovery.img   # 期望 header v2、pagesize 4096、
                                    # kernel_offset 0x00008000、
                                    # ramdisk_offset 0x01000000、
                                    # dtb_offset 0x01f00000
```

## FBE 限制与 AVB 签名限制

### FBE（当前不支持）

原厂把密钥管理实现为 vendor 分区里的 HIDL 服务，由 vendor 的 init 脚本启动，例如
`stock/vendor/bin/qseecomd`、
`stock/vendor/bin/hw/android.hardware.keymaster@4.0-service-qti`、
`stock/vendor/bin/hw/android.hardware.gatekeeper@1.0-service-qti`
（对应 `stock/vendor/etc/init/` 下的同名 rc），并依赖
`libQSEEComAPI`、`libkeymasterdeviceutils`、`libqtikeymaster4`、`libStDrvInt`、
`librpmb`、`libssd`、`libdrm*`、`libsecureui*` 等库；密钥管理 TA 镜像不在 vendor 中，
而是独立的 keymaster 分区（`stock/rawprogram4.xml:12` 的 `keymaster_a`）。

已核实：原厂 recovery 镜像的 ramdisk（433 个 cpio 条目）**不含**上述任何库或服务，
本仓库也没有这些二进制。因此本设备树**不启用**加密支持：
`TW_INCLUDE_CRYPTO := false`、`TW_INCLUDE_CRYPTO_FBE := false`，
`recovery/root/init.recovery.qcom.rc` 中相关服务以注释形式给出模板。
在提取到上述文件并通过实机验证之前，**不要**声称可以解密 data。

### AVB 签名（使用公开测试密钥）

`BOARD_AVB_ENABLE := true`，`BOARD_AVB_RECOVERY_KEY_PATH` 指向
`external/avb/test/data/testkey_rsa2048.pem`，算法 `SHA256_RSA2048`。
该私钥是公开的，因此产出的 recovery 镜像**不具备可信签名**：
锁定（locked）设备上的厂商校验不会通过，可能拒绝引导；
已解锁设备可以引导，但需要自行确认是否接受该签名的 vbmeta 策略。
`BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3` 表示 vbmeta 中关闭 hashtree 与 verification；
即关闭 hashtree 与 verification；这属于 TWRP 的常见做法，
但仍需在真机上结合设备自身的 vbmeta 策略确认。

### recovery 内 DTB 与原厂 DTBO 的差异

本项目 `BOARD_INCLUDE_RECOVERY_DTBO := false`，因此 recovery 镜像**不携带** DTBO；
镜像内的 DTB 段就是原厂的 `boot.img-dtb`（基础 DTB，2027715 字节，21 个 overlay
而不在其内）。显示、触摸等外设的 overlay 由**引导器**从设备的 `dtbo_a`/`dtbo_b`
分区加载，与 recovery 镜像内容无关。因此：本设备树不打包 DTBO 并不会丢失 overlay，
但如果实机的 dtbo 分区缺失或被改坏，就可能出现黑屏或无触摸——这正是实机清单中
“显示与触摸”必须单独验证的原因。

## 独立证据复核

上文所有数值都可以只凭本仓库重新推导，无需编译。

```powershell
# 预编译产物与原厂文件逐字节相同
Get-FileHash prebuilt/kernel  -Algorithm SHA256   # == stock/boot/split_img/boot.img-kernel
Get-FileHash prebuilt/dtb.dtb -Algorithm SHA256   # == stock/boot/split_img/boot.img-dtb

# 分区尺寸直接来自 9008 包（label / 扇区数 / 扇区大小）
Select-String -Path stock/rawprogram0.xml -Pattern 'label="super"'
Select-String -Path stock/rawprogram4.xml -Pattern 'label="(boot|recovery|dtbo)_[ab]"'

# 两个会导致阻塞的输出目录变量必须不出现（未注释形式），应为 0
(Select-String -Path BoardConfig.mk -Pattern '^TARGET_COPY_OUT_(PRODUCT|ODM)').Count
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

以下项目必须逐条在真机上确认；在此之前，任何涉及“能用”的结论都视为未验证。
本项目**不会**自动刷机。

1. **只读探测（不做任何写入）**：
   `fastboot getvar partition-size:recovery`、`:boot`、`:dtbo`、`:super`，
   与本文档记录的原厂值比对。
2. **最小风险引导**：`fastboot boot recovery.img`（只引导、不写入任何分区），
   确认能进入 TWRP 界面。
3. **显示与触摸**：界面方向、分辨率、背光是否正常；触摸是否可用；
   必要时用 `cat /proc/bus/input/devices` 记录输入设备名，判断是否需要设置
   `TW_INPUT_BLACKLIST`。
4. **分区挂载**：能否挂载三个 logical 分区 `/system`、`/vendor`、`/product`，以及
   `/metadata`；`/boot`、`/recovery`、`/dtbo`、`/vbmeta` 是否能被识别。
   **不要**再期待 `/odm`、`/system_ext` 出现在 TWRP 的分区列表里：本机 super 里没有
   这两个分区（见「super 的实际内容」），odm 的内容在 `/vendor/odm`，system_ext 的内容在
   `/system_root/system/system_ext`。
5. **存储与备份**：能否正确识别内部存储与外部存储，备份/恢复是否可用。
6. **FBE**：当前不支持，进入后应预期无法挂载 `/data`；如需支持，先提取
   qseecom/keymaster 相关文件并单独验证。
6a. **`/data` 挂载失败的真实根因（已由实机日志确定，2026-10 补充）**：
   截取的实机日志在 `log/dmesg.txt` 与 `log/recovery.txt`。结论是**原始分区上没有有效的
   F2FS 文件系统**，而不是“解密不了”：

   ```
   F2FS-fs (sda9): Magic Mismatch, valid(0xf2f52010) - read(0x5243fa92)   ← 1st superblock
   F2FS-fs (sda9): Magic Mismatch, valid(0xf2f52010) - read(0xc7c8d9ea)   ← 2nd superblock
   F2FS-fs (sda9): Can't find valid F2FS filesystem in 1th superblock
   F2FS-fs (sda9): Can't find valid F2FS filesystem in 2th superblock
   ```

   依据与推论：

   * 内核 F2FS 驱动对 `/dev/block/sda9` 先后探测两个 superblock，两处 magic 都不是
     `0xf2f52010`；一次开机内共记录 56 行 `F2FS-fs (sda9)` 日志（14 轮 × 4 行）。
   * 同一时刻 `/metadata`(sda6)、`/mnt/vendor/persist`(sda2)、`/logdump`(sde56) 以及
     system/product/vendor 全部**成功挂载**（本次开机共 22 次成功挂载，全部是 ext4/dm-*/loop*），
     说明块设备层、UFS 控制器、SELinux 都不是瓶颈；只有 sda9 找不到 F2FS 签名。
   * 因此 TWRP 的报错链条是
     `I:Can't probe device /dev/block/sda9` → `I:Unable to mount '/data'` →
     `Failed to mount '/data' (Invalid argument)`，
     并且 `/data` 分区尺寸被探测为 0 B、`Mount_Options` 里带 `inlinecrypt`。
   * FBE/ICE 只加密文件内容与文件名，不会把 superblock 的 magic 变成另一个值。所以
     “缺 keymaster/qseecom 所以解不开”不能解释 magic mismatch；这一层失败**早于**解密。
     这也意味着：在 `recovery.fstab` 里增删 `inlinecrypt`、`checkpoint=fs`、
     `reservedsize=128M`、`sysfs_path=…` 都不会改变结果——原始设备字节没变，没有 fstab
     选项能让内核重新认识一个不存在的 F2FS superblock。
   * 已核对：本仓库 `recovery.fstab` 的 `/data` 行与原厂 recovery 镜像内
     `system/etc/recovery.fstab` 的 `/data` 行**逐字节一致**（把连续空白压成一个空格后
     完全相同），所以此处不存在“设备树写错选项”的问题。原厂 `fstab.qcom` / `fstab.default`
     比 recovery 版多一个 `inlinecrypt`，那是正常启动（keymaster 已就绪）才需要的。

   **数据安全（最重要）**：现在**不要**格式化 `/data`，不要 `make_f2fs`/`mke2fs`，
   不要 `fsck -y`。在确定 sda9 上原本是什么（以及是否已被改写）之前，任何写入都可能让
   本来可恢复的数据彻底消失。

   不做任何写入的取证命令（TWRP 的 adb shell 内）：

   ```sh
   dd if=/dev/block/sda9 bs=4096 count=2 2>/dev/null | od -A d -t x4 | head
   # 期望 0x400 处出现 F2FS magic 0xf2f52010；若仍不是，说明该分区已不是 F2FS，
   # 需要在 PC 侧用原厂 9008 包先评估分区表/分区内容，再决定恢复方案。
   ```

   本仓库能做的到此为止：日志证据已归档、配置已确认与原厂一致、且明确禁止格式化。
   真正的修复必须在设备侧做（恢复原始分区内容），不属于设备树能解决的范围。
7. **AVB**：确认已解锁设备是否接受测试密钥签名的镜像；如需修改 vbmeta 策略，
   请自行评估风险。
8. **尺寸回归**：若在真机阶段改动设备树，请重新构建并确认 `recovery.img` 仍
   ≤ 100663296 字节，并重新发起独立复验。

## 实机日志中可忽略项与已定性项（内核 / 触屏 / 格式）

本节把一次实机 recovery 运行（`log/dmesg.txt`、`log/fastbootd/dmesg.txt`、`log/recovery.txt`）里
除 `/data` 之外的报错逐条定性，避免后续重复调查。结论：**只有 `/data`（sda9）是真故障**（见上文 6a），
其余三条都不是本设备树能修、也不需要修的问题；其中触屏实测工作正常。

### 1. Goodix 触屏 “cfg bin / 固件缺失 + sensor id mismatch” —— 噪声，且触摸可用

日志表现（`log/dmesg.txt` 与 `log/fastbootd/dmesg.txt` 两次开机完全一致，可复现、非偶发）：

```
[GTP-ERR][goodix_read_cfg_bin:448] failed get cfg bin[goodix_cfg_group.bin] error:-11, try_times:1
[GTP-ERR][goodix_read_cfg_bin:448] failed get cfg bin[goodix_cfg_group.bin] error:-11, try_times:2
[GTP-ERR][goodix_read_cfg_bin:457] get cfg_bin FAILED
[GTP-ERR][goodix_get_reg_and_cfg:326] pkg:1..9, sensor id contrast FAILED, reg:0x402f
[GTP-ERR][goodix_get_reg_and_cfg:329] sensor_id from i2c:0, sensor_id of cfg bin:1..9
[GTP-ERR][goodix_request_firmware:1078] Firmware image [goodix_firmware.bin] not available,errno:-11
[GTP-ERR][goodix_later_init_thread:564] fw update failed, -11[ignore]
[GTP-INF][goodix_ts_stage2_init:2540] failed send normal config[ignore]
```

定性证据：

* **触摸是好的**：同一份 dmesg 里有 5 组真实触摸事件，坐标覆盖到屏幕右下角
  （`ufp_touch_point: touch_down/up id: 0, coord[851, 2360]` 等），输入设备已注册
  （`input: goodix_ts as /devices/virtual/input/input4`）。要产生这些事件必须已经点到
  右下角，说明驱动、I2C、中断、面板链路都正常。
* **固件目录不是本设备树造成的**：原厂 recovery 镜像的 `ueventd.rc` 写着同一行
  `firmware_directories /etc/firmware/ /odm/firmware/ /vendor/firmware/ /firmware/image/`，
  本仓库逐字沿用（`recovery/root/system/etc/ueventd.rc`）；而且原厂 recovery ramdisk 里
  同样**没有** firmware 目录、也没有这两个 .bin。即原厂 recovery 本身也拿不到这两个文件，
  这不是 TWRP 相对原厂的回归。
* **内核固件加载时机决定拿不到**：`goodix_*` 是内核内建驱动，probe 在启动早期完成；此时
  `/vendor/firmware` 尚未由 TWRP 挂载，`request_firmware` 只能得到 `-11`（EAGAIN，
  即“当前取不到”）。驱动把关键失败标成 `[ignore]` 并继续，stage2 初始化成功。
* **sensor id mismatch 是上一条的后果**：`goodix_cfg_group.bin` 取不到，驱动只能用默认
  （i2c 读到 sensor id 0），于是与 cfg bin 里 pkg 1..9 逐条比对全部失败。
* **修复边界**：仓库内全量检索 `goodix*` 为 0 命中，两个 .bin 不在本仓库；加路径或改时序
  都改不了“文件不存在”这一事实。要消掉这些 `GTP-ERR` 只能由厂商把 cfg/固件放进 recovery
  ramdisk，收益远小于风险，因此本项目不处理。

### 2. QG 的 `Please remove unsupported %) in format string` —— 噪声，非本项目可修

```
QG-K: qg_topoff_current_cb: Qg: QG_DEFAULT_VOTER topoff(100
------------[ cut here ]------------
Please remove unsupported %) in format string
WARNING: CPU: 7 PID: 128 at lib/vsprintf.c:2171 format_decode+0x44c/0x460
Call trace: format_decode → vsnprintf → vscnprintf → vprintk_store → vprintk_emit
            → vprintk_default → vprintk_func → printk → qg_topoff_current_cb+0x4c/0x60
```

* 这是**原厂内核自身**的 printk 格式串缺陷：某条电池 QG 打印里写了 `%)`，而 `%` 后必须是
  合法转换字符（字面百分号要写 `%%`）。栈回溯结束在 `qg_topoff_current_cb`，没有本项目代码。
* 后果只是内核在该处发一次 WARNING 并截断这行日志（`topoff(100` 后面就没了），不改变功能。
  本项目**不编译内核**（`prebuilt/kernel` 与原厂 `boot.img-kernel` sha256 逐字节相同），
  设备树侧没有任何手段能改这条格式串。
* 结论：可忽略，且**不要**为此加 dmesg 抑制——收益低，还会把真实内核报错一起吞掉。

### 3. `DM_DEV_STATUS failed for system_ext_b / product_b` —— 恢复环境预期输出

```
init: First stage mount skipped (recovery mode)
init: DM_DEV_STATUS failed for system_ext_b: No such device or address
init: Could not update logical partition
init: DM_DEV_STATUS failed for product_b: No such device or address
```

* 这两行来自**原厂 init 的 first stage**，而紧邻的上一行已说明
  `First stage mount skipped (recovery mode)`：recovery 模式下 init 不做 first stage mount，
  槽位后缀 `_b` 对应的 dm 设备本就不会创建，`DM_DEV_STATUS` 必然失败——预期输出，非设备树错误。
* 它没有阻止 TWRP 工作：TWRP 之后按需建立 `dm-4`(system)、`dm-3`(product)、`dm-5`(vendor)
  并成功挂载（`EXT4-fs (dm-4/dm-3/dm-5): mounted filesystem`）。
* `system_ext` / `odm` 为何在 super 里不存在、TWRP 侧为何打印 `unable to update logical partition`，
  见「super 的实际内容」一节；该问题的配置侧结论已由另一成员在 `recovery.fstab` 落实，本任务不重复改动。

### 汇总

| 日志现象 | 定性 | 本项目可否修 |
|---|---|---|
| `F2FS-fs (sda9)` 两个 superblock magic mismatch | **真故障**（原始分区非 F2FS） | 不可（须设备侧处理，见 6a） |
| Goodix cfg/固件缺失 + sensor id mismatch | 恢复环境固有噪声，触摸实测正常 | 否（bin 不在仓库，原厂 recovery 同样没有） |
| `unsupported %) in format string` + WARNING | 原厂内核 printk 缺陷，无功能影响 | 否（不编译内核） |
| `DM_DEV_STATUS failed for system_ext_b/product_b` | recovery 模式预期输出 | 否（无需修） |

## 刷写说明（仅供参考，本项目从不自动刷机）

仅在前述只读探测与 `fastboot boot` 均通过后，才考虑写入；写入前请自行备份。

```bash
fastboot getvar partition-size:recovery   # 先确认真实尺寸
fastboot flash recovery_a out/target/product/P725A02/recovery.img   # 与当前槽位对应
```

需要说明的是：TWRP 16 只会在 recovery-as-boot 形态的镜像上向内核命令行追加
`twrpfastboot=1`；本设备是独立 recovery 分区，直接引导该镜像仍是最安全的首个验证步骤。