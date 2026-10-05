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
| **真机当前运行的镜像** | 构建时间 **2026-10-05 10:38:19 CST**、指纹 `ZTE/twrp_P725A02/P725A02:99.87.36/BP2A.250605.031.A2/eng.avider:eng/test-keys`、`ro.twrp.version=3.7.1_16-0`，其 ramdisk 配置与提交 `4585a19` 的检出**逐字节相同**，**早于 t1–t4 的全部修复**（复验见「集成审查」一节）。因此下表任何镜像哈希都不再对应插着 USB 的这一台 |
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
| `/boot` `/recovery` `/apdp` `/persistent`(frp) `/ztecfg` `/modem` `/dsp` `/bluetooth` | `recovery/root/system/etc/twrp.flags` |
| ~~`/msadp`~~ | **不写入**：本机 GPT 里没有 msadp（`ls /dev/block/by-name/msadp` → ENOENT；`raw4/941-msadp-node.out`），原条目已删 |
| `/vendor/firmware_mnt` `/vendor/dsp` `/vendor/bt_firmware` | **不在** `recovery.fstab`：三段式挂载点会被 TWRP 折叠进 `/vendor` 并丢弃（R2），现以一级挂载点 `/firmware_mnt` `/dsp_firmware` `/bt_firmware` 写在 `twrp.flags` 并标为 `/modem` 子分区（B1 用 `fsflags=` 恢复原厂的 `ro`/`context=`） |
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
   内部 AVB0 vbmeta 为 1664 字节；它的 ramdisk 内 4 个设备文件哈希与**当时的**工作区源文件逐项一致
   （`recovery.fstab` `bb4d6872…`、`twrp.flags` `00190f77…`、`ueventd.rc` `86c2edee…`、
   `init.recovery.qcom.rc` `a3656f7a…`）。
   > ⚠️ 这 4 个哈希**已经过期**：t5 集成审查又改动了设备树里的注释与一处错误结论
   > （见下节「集成审查」），所以它们既不等于当前工作区文件，也不等于任何一台真机上的镜像，
   > 仅作历史备案。**当前**工作区 4 个文件的 sha256 列在「集成审查」一节。
3. 早前一次构建（t4 阶段，设备树为 t5 整合前的版本）产出的哈希为
   `84c6ef39bc43c3a7253baf2d55dcbb229e290926b6c91210379ae98a5f0dbdd3`，
   **已被 t5 整合取代，不是最终产物**，仅在此备案以免混淆。

## 集成审查（t5）：逐项状态与"为什么有些项只能在刷机后验证"

本节是 t1–t4 全部改动的一轮集成审查结论（只读 adb 复验 + 上游源码只读核对；
**未构建、未刷写、未重启、未改 twrp16 源码**）。目的是让后续维护者一眼分清
"已经修好"、"只在静态层面修好"、"根本没修"三类状态。

### 1. 运行的镜像早于本设备树（这是所有动态验证的共同前提）

用只读 adb 复验（设备仍在 recovery，uptime ≈ 49 min，与 t1 会话那次启动不是同一次）：

| 项目 | 实测值 |
|---|---|
| 版本 / 指纹 | `3.7.1_16-0` / `ZTE/twrp_P725A02/P725A02:99.87.36/BP2A.250605.031.A2/eng.avider:eng/test-keys` |
| `ro.build.date` | `Mon Oct  5 10:38:19 CST 2026` |
| `/etc/recovery.fstab` | 8340 B，sha256 `bee0320b…9b38`（= `/ramdisk-files.sha256sum` 的记录） |
| `/etc/twrp.flags` | 4674 B，sha256 `48b6c779…8b4a` |
| `/init.recovery.usb.rc` | 8325 B，sha256 `5f60aed8…f01e` |
| `/init.recovery.qcom.rc` | 6377 B，sha256 `a3656f7a…b983` |

这 4 个文件与提交 `4585a19` 的那份检出**逐字节相同**，而那份检出里
**没有** `/modem`、`/usb_otg`，**有** `/msadp` 与 `display="VBMeta System"`（带空格），
`recovery.fstab` 里也**还有** `/vendor/firmware_mnt|/vendor/dsp|/vendor/bt_firmware` 三个三段式挂载点。
运行中的 `/tmp/recovery.log` 同样仍在打印 `I:Processing '/msadp'` 与
`I:Found an additional entry for '/vendor/firmware_mnt'`。**结论：t1–t4 的 storage 类修复尚未生效。**

### 2. 当前工作区 4 个文件的 sha256（本轮审查后的值）

| 文件 | sha256 |
|---|---|
| `recovery/root/system/etc/recovery.fstab` | `d2c82b7999301b4efa345865d4af289c89a3b2bf287c36e5ea8107c73ee38011` |
| `recovery/root/system/etc/twrp.flags` | `f189cf35b9dcd60fa2c2d8917440eb8c539ff8853339e8e706e048e0141a7164` |
| `recovery/root/init.recovery.usb.rc` | `4118f4e1bf212835793cac47d3e7f7f56fa741d2d7c9f11ff942a4504e596571` |
| `recovery/root/init.recovery.qcom.rc` | `c5b8c90b0be3d27f5f77bbd09b2c4cc65cffc98f432bc6b50cccfeb7e7e6fa25` |

### 3. 逐项状态

| 项 | 内容 | 状态 | 为什么 |
|---|---|---|---|
| t4-1 | `BoardConfig.mk` 删除死变量 `TARGET_RECOVERY_DEFAULT_REFRESH_RATE` | **已核验** | 对 TWRP 16 检出全量 grep，唯一命中就是本设备树，上游 0 处 ⇒ 该变量没有任何消费者 |
| t4-2 | 显示 1080×2460 / `XBGR8888` / density 480 / 触摸 `goodix_ts` / 按键 / 振动 / 背光 | **已实机核验** | recovery.log 的 `width: 1080, height: 2460`、`b1 f1`… 等行与只读 sysfs 读数一致（细节见 BoardConfig.mk 注释） |
| t2-B1 | `/firmware_mnt`、`/dsp_firmware`、`/bt_firmware` 用 `fsflags=` 恢复原厂 `ro`/uid/gid/dmask/fmask/`context=` | **静态核验**<br>（字段逐字取自原厂 recovery 镜像 fstab） | `fsflags=` 确实是上游 `tw_flags` 里的标志、`mountoptions=` 不存在；`mount_flags[]` 里 `ro` 会置 `Mount_Read_Only`，其余 token 原样进 `Mount_Options` ⇒ 会走到 `mount(2)`。当前镜像里这三行还不存在，无法动态确认 |
| t2-C2 | `display="..."` 里的空格会截断 flags 字段（7 条受影响），显示名改成单 token | **静态核验** | 已按上游 `parse_twrp_flags` 的分词逻辑独立重实现并复算：修复前那 7 条的 `backup=1;flashimg=1;subpartitionof=…` 确实被丢弃，修复后全部保留 |
| t3-D1 | `mtp,adb` 的 configfs 绑定改成 AOSP `mtp_adb` 写法 + `idProduct 0x4EE2` | **待刷机验证** | 与 AOSP 16 `system/core/rootdir/init.usb.configfs.rc:35-40` 逐字同构，也与原厂 `stock/system/system/etc/init/hw/init.usb.configfs.rc` 被注释掉的同一块一致；但当前镜像的 configfs 仍是 `f1 -> ffs.adb` + `configuration "adb"` + `idProduct 0xd001`，改好的分支从未在真机上执行过 |
| t3-D1 回退 | 关掉 MTP 走 `none` 分支后仍应只剩 ADB | **设计上安全，未动态验证** | 回退路径只依赖 `sys.usb.ffs.ready`（由 adbd 设置），与 MTP 是否就绪完全无关；唯一新增写入是 `mtp.gs0 -> b.1/f1`，内核若拒绝绑定则那一次 UDC 写入失败，重启 recovery 必回到仅 ADB |
| t2-D2 | 厂商 fstab（`/etc/additional.fstab`）会覆盖 `/data`、`/metadata` 的定义 | **证据充分，但本轮刻意不改** | 上游 `partitionmanager.cpp` 的 `parse_userdata` 分支只吃这两条；运行日志 `fstab.additional=1`、`Reading /etc/additional.fstab`、`/data` 的最终 `Mount_Options` 与厂商 fstab 逐项吻合。真正"修"它要在 `BoardConfig.mk` 打开 `TW_SKIP_ADDITIONAL_FSTAB` ⇒ 属平台范围，见下节 |
| t2-B2 | `/sdcard1`、`/usb_otg` 的 `auto` 设备字段 | **未修复，已定性** | 见下节 |
| t1-D1 | 删除 `/msadp` 幽灵条目 | **已核验（分区表层面）** | 设备 by-name 里没有 msadp；运行镜像里它仍是 0 B 幽灵项，删掉后不会再出现 |
| t1-R2 | 三个三段式挂载点迁移到 twrp.flags 一级挂载点 | **静态核验** | 三个新挂载点过 `Get_Root_Path()` 后保持不变，不再被折叠进 `/vendor`；当前镜像里仍是被丢弃的老写法 |

### 4. 三个"不能靠改设备树解决"的问题（本轮没有假装修好）

**D2 —— `/data`、`/metadata` 的运行期定义来自厂商 fstab。**
上游证据：`bootable/recovery/partitionmanager.cpp` 的 `#ifndef TW_SKIP_ADDITIONAL_FSTAB` 分支在
recovery 模式下把厂商 fstab 复制成 `/etc/additional.fstab`，接下来的那一轮
`parse_userdata` 只会 `std::erase` + 重建 `/data` 与 `/metadata`，其余行 `continue`；
开关映射在 `vendor/twrp/config/BoardConfigSoong.mk:321` → `soong_config_set_bool(..., skip_additional_fstab, …)`。
**本轮不建议打开它**，三条理由：(a) 打开后本树的 `/data` 行没有 `inlinecrypt`，会真实改变挂载选项，
而 `/data` 当前因 sda9 没有可识别的 F2FS/明文 superblock 根本挂不上，打开它并不能让 `/data` 可用；
(b) 那会改 `BoardConfig.mk`（平台范围），且必须重新构建才能验证；(c) 属"要不要做"的决策，
不是集成审查该替队长做的决定。**结论：证据充分、但决定权不在本任务，且不改。**

**B2 —— `auto` 不是通配符。**
上游证据：`partition.cpp` 里 `auto` 只在 `Classify_By_Mount_Point()` 当**挂载点**用时被改写；
块设备通配符只有两条路 —— `/devices/…` 行（本文件写不出来：行首字段会被当挂载点）或设备字段含 `*`
（`Apply_Block_Device_Attributes()` → `Wildcard_Block_Device` → `Find_Wildcard_Block_Devices()`）。
`auto` 两条都不满足，所以它一直是字面串。实机证据：`/sdcard1` 与 `/usb_otg` 在日志里都是
`Size: 0 B`、`Flags` 里没有 `IsPresent`、`Primary_Block_Device: auto`，并有
`Unable to mount '/sdcard1'` / `'/usb_otg'`。卡其实在位（`/dev/block/mmcblk0p1` 可读，FAT32）。
**结论：B2 仍未解决。** 本轮只更正了设备树里那条**错误结论**（原先写"auto 通配符由 TWRP 自己去扫块设备"），
没有改行为 —— 换一条同样无法在刷机前验证的写法，只会把"已知未解"变成"未知未解"。
刷机后的复核要看 `/tmp/recovery.log` 里 `/sdcard1` 的 `Primary_Block_Device` 与 `mount | grep sdcard1`。

**MTP 端到端 —— 只有内核侧条件被证明，用户可见效果未知。**
已被只读探针证明的：`/config/usb_gadget` 存在（configfs 可写）、`functions/mtp.gs0` 可创建、
`/dev/mtp_usb` 存在且为 `crw-rw---- root mtp`、内核 f_mtp 在运行镜像里**真的被调用过**
（`dmesg` 有 `mtp_open` / `mtp_release`），TWRP 的 sepolicy 把 `recovery`、`init`、`adbd` 设为
`permissive`（`system/sepolicy/private/twrp.te`），所以 `/dev/mtp_usb` 上的 `avc denied` 不会变成
读写失败。**没有**被证明的：主机（Windows）是否真的识别出"便携设备"、能不能传文件 ——
这必须在刷入新 `recovery.img` 后看主机端。因此本节不声称"MTP 已修复"。

### 5. 本轮（t5）对设备树做的改动

只动注释与一处**错误结论**，**任何一行的行为字段都没变**（分区条目、flags、rc 命令逐字不变，
已由 `tools/check_fstab_static.mjs` 与 `log/session-20261005-2150/scripts/t2-storage-conformance.mjs`
在改动后重跑确认，两者仍全量 PASS）：

* `recovery/root/system/etc/twrp.flags`：更正"auto 通配符"的错误机理（上文 B2），并在文件头加一段
  "运行镜像早于本文件"的复验注记。
* `recovery/root/system/etc/recovery.fstab`：在文件头加同一段复验注记（R2/B3/D2 同样只能在刷机后复核）。
* `README.md`：更正"ADB / MTP 可用"的过时表述、补上真机镜像基线与 R2 迁移后的分区归属表、加上本节。

`stock/**`、`log/**`、`tools/**` 与 twrp16 源码**在本轮中均未被修改**
（`stock` 最新 mtime 为 2026-10-05 00:30:29，`tools` 为 11:58:40；`log` 下只有各任务自己的
只读采集与报告文件，非本轮改动）。工作区里另有 4 个未跟踪的临时文件（`.t3-bootusb-report.md`、
`.t6run2.ps1`、`.t6run3.ps1`、`.t6run4.ps1`），属构建/验证会话的残留，保持未跟踪。

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

本节把实机 recovery 运行的日志逐条定性，避免后续重复调查。**只有 `/data`（sda9）是真故障**（见上文 6a），
其余各项都不是本设备树能修、也不需要修的问题；其中触屏实测工作正常。

> 日志已更新一次：当前 `log/` 下是 `dmesg.txt` 与 `recovery.log`（旧文件名 `recovery.txt`、
> `fastbootd/dmesg.txt` 已被替换）。已对**新老两套日志**各复核一遍：下列各项（含 sda9 superblock
> magic、QG `%)`、`DM_DEV_STATUS`、Goodix 配置/固件缺失与 sensor id mismatch、触屏事件）
> 全部**逐字复现**，仅时间戳与本次点按次数不同；因此定性结论不变。新日志对应一次更新的构建
> （其属性为 `ro.odm.build.date=Mon Oct  5 10:38:19 CST 2026`，早前一份是 01:18:55），
> 但 `/data` 行为与其它现象完全相同。

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
| USB-PD `send hard reset` ×3 → `disabling PD` | 电源协商降级为 SDP，充电与 USB 功能均正常 | 否（内核 PD 驱动，非设备树） |

### 4. USB-PD 连续三次 hard reset 后自行关闭 PD —— 噪声，不影响用户需求

```
usbpd usbpd0: Type-C Source (default) connected
usbpd usbpd0: SNK_Startup -> SNK_Wait_for_Capabilities  (delay 500ms)
usbpd usbpd0: SNK_Wait_for_Capabilities -> SNK_Hard_Reset
usbpd usbpd0: send hard reset
usbpd usbpd0: SNK_Hard_Reset -> SNK_Transition_to_default (delay 685ms)
... 重复 3 次（t=1.57s / 2.76s / 3.95s）...
usbpd usbpd0: Sink hard reset count exceeded, disabling PD
pm7250b_charger: smblib_set_prop_pd_active: pd_active:0
pm7250b_charger: smblib_update_usb_type: APSD=SDP PD=0, real_charger_type=4
```

**它是否影响用户需求：不影响。** 依据：

* **不是崩溃、与挂载无关**：PD 协商完全发生在前 5.13 s 的启动早期，与 TWRP 挂载各分区、
  读写 storage 的时段不重叠；全程 `Kernel panic` / oops 为 0（唯一 WARNING 是上面第 2 条的 QG）。
* **自愈且降级到这个充电器本来就支持的模式**：三次重试后内核主动放弃 PD（`Sink hard reset count
  exceeded, disabling PD`），回落到 `APSD=SDP PD=0` 的 SDP 模式，充电**照常进行**：禁用后仍有
  6 次电流设置、最后一条为 `usb suspend:0`，全程 USB 挂起事件 0 次（即没有被挂起）。
* **USB 门控没有被 PD 影响**：`configfs-gadget gadget: super-speed config #1`（dmesg 2.447 s）、
  `USB_STATE=CONFIGURED`（2.447 s）都发生在 PD 被禁用之后，说明 USB 枚举走的是电源协商之外的路径。
  > ⚠️ 更正（t5 集成审查）：此处原先写“ADB / MTP 可用”**与实测不符**。当时设备实测
  > **ADB 可用、MTP 不可用**（configfs 只有 `f1 -> ffs.adb`、`configuration "adb"`、`idProduct 0xd001`；
  > `/dev/usb-ffs/mtp` 不存在）。dmesg 里的 `mtp_open` 只说明 TWRP 打开了内核 f_mtp 节点
  > `/dev/mtp_usb`，不能推出主机侧 MTP 可用。MTP 的修复（`init.recovery.usb.rc` 的 `mtp_adb` 分支）
  > 尚未在任何镜像上生效，见「集成审查」一节。
* **唯一实际后果**：无法用 PD 高压快充，只按 5V/900mA 充。这只会让**充电变慢**，
  不会中断操作、不会丢数据，也不影响刷写/备份；需要长时供电时应插更强的充电器或留意电量。
* **成因与归属**：这是 Type-C 对端（充电器/线材）在该时序下未按 PD 规范回应 capabilities 的
  常见现象，内核按规范重试后自行降级；`usbpd`/`pm7250b_charger` 都是内核内建驱动，
  本项目不编译内核、设备树也无任何 PD 相关配置，因此**无本项目可修点**。

## 刷写说明（仅供参考，本项目从不自动刷机）

仅在前述只读探测与 `fastboot boot` 均通过后，才考虑写入；写入前请自行备份。

```bash
fastboot getvar partition-size:recovery   # 先确认真实尺寸
fastboot flash recovery_a out/target/product/P725A02/recovery.img   # 与当前槽位对应
```

需要说明的是：TWRP 16 只会在 recovery-as-boot 形态的镜像上向内核命令行追加
`twrpfastboot=1`；本设备是独立 recovery 分区，直接引导该镜像仍是最安全的首个验证步骤。