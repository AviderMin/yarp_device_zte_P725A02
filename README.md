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
| FBE / metadata 解密 | **接近可用，尚未在真机确认**：t7 修可执行位与 VINTF manifest，t8 补齐 13 个 dlopen 依赖，t9 定位并修掉一处 **platform** 缺陷（libdm 在 legacy 格式下不发 `wrappedkey_v0`，见 `platform-patches/`）。整条链已起齐、密钥已被 keymaster 成功解开，只差 dm-default-key 那一跳的实机确认 |
| 实机验证（显示 / 触摸 / 挂载 / 引导） | **部分进行**：显示、触摸、logical 分区、`/metadata` 均正常；`/data` 仍无法挂载，但 t7 已在真机上把根因定到 "keymaster HAL 从未启动"（不是分区损坏），修复待刷入复验 |
| TWRP 设置持久化 | **已知缺陷，本轮只定性未修**：`/mnt/vendor/persist` 是三级挂载点，被 `Get_Root_Path()` 截成 `/mnt` 而永远挂不上，`.twrp_settings` 因此写在 ramdisk 上、重启即丢（见「真机复验（t7）」末节） |

## 重要风险提示（请先读）

1. **FBE / metadata 解密已编译进来，t7 又修掉了两个实测阻断，但都还没在修好后的镜像上复验。** 本设备 userdata 使用
   FBE + ICE + wrappedkey。设备树现在随 recovery ramdisk 一起提供 qseecomd、
   keymaster@4.0、gatekeeper@1.0 及其依赖库（`recovery/root/vendor_ramdisk/`）和
   keymaster TA（`recovery/root/vendor/firmware_mnt/image/`），由
   `recovery/root/init.recovery.qcom.rc` 在 TWRP 调用 `Decrypt_Data()` 之前启动，
   不再依赖会被 TWRP 卸掉的 `/vendor`；`TW_INCLUDE_CRYPTO := true`、
   `TW_INCLUDE_CRYPTO_FBE := true`、`TW_INCLUDE_FBE_METADATA_DECRYPT := true`。
   静态回归检查：`node tools/verify_decrypt_prereqs.mjs`。
   **在重新构建并刷入、看到 `Successfully decrypted metadata encrypted data partition`
   之前，不要对外宣称已能解密 data。**
2. **镜像使用 AOSP 测试密钥签名。** `BOARD_AVB_RECOVERY_KEY_PATH` 指向
   `external/avb/test/data/testkey_rsa2048.pem`，这是公开私钥。在**锁定的**（locked）
   设备上，该镜像无法通过厂商签名校验，可能直接拒绝引导；在已解锁设备上可引导，
   但请知悉其签名不具备任何可信度。
3. **解锁引导器通常要求清空用户数据**，请先自行备份，且本项目**不做任何自动刷写**。
4. **`/data` 挂载失败，但原因不是分区损坏，更不要靠格式化来"修"。**
   实机 `log/dmesg.txt` 显示内核 F2FS 驱动在 `/dev/block/sda9` 上两个 superblock 的 magic
   都不等于 `0xf2f52010`；同一时刻其它分区全部正常挂载。
   **t7 更正**：这**不是**"该分区不是有效的 F2FS"，而是 metadata 加密分区在 dm-default-key
   尚未建立时的**预期**现象——`/dev/block/sda9` 上本来就不该出现明文 F2FS superblock，
   必须先由 keymaster 解出 `/metadata/vold/metadata_encryption` 里的 wrapped key 并建立
   dm-default-key 映射，明文才可见。所以"F2FS magic 不对"和"keymaster 没起来"是同一件事的
   两个面，后者才是根因（见「真机复验（t7）」）。改 fstab 选项确实改变不了裸块字节，
   但那是因为解密根本没走到那一步。
   无论如何都**不要格式化 userdata / 不要 `make_f2fs` / 不要 `fsck -y`**，
   否则会真的毁掉现在仍可恢复的数据。详细依据见“实机检查清单”第 6a 条。

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

### FBE / metadata 解密（已编译进来，未在真机复验）

原厂把密钥管理实现为 vendor 分区里的 HIDL 服务，由 vendor 的 init 脚本启动，例如
`stock/vendor/bin/qseecomd`、
`stock/vendor/bin/hw/android.hardware.keymaster@4.0-service-qti`、
`stock/vendor/bin/hw/android.hardware.gatekeeper@1.0-service-qti`
（对应 `stock/vendor/etc/init/` 下的同名 rc），并依赖
`libQSEEComAPI`、`libkeymasterdeviceutils`、`libqtikeymaster4`、`libStDrvInt`、
`librpmb`、`libssd`、`libdrm*`、`libsecureui*` 等库；密钥管理 TA 镜像不在 vendor 中，
而是独立的 keymaster 分区（`stock/rawprogram4.xml:12` 的 `keymaster_a`）。

已核实：原厂 recovery 镜像的 ramdisk（433 个 cpio 条目）**不含**上述任何库或服务，
本仓库也没有这些二进制；本设备树改为把它们作为 prebuilt 放进 recovery ramdisk：
`recovery/root/vendor_ramdisk/{bin,lib64}` 里是原机 vendor 分区提取的
qseecomd / keymaster@4.0 / gatekeeper@1.0 与它们的库依赖闭包（含 gatekeeper 的
`hw/android.hardware.gatekeeper@1.0-impl-qti.so`），TA 镜像（`keymaster.mdt` 与
`keymaster.b00..b07`）放在 `recovery/root/vendor/firmware_mnt/image/` ——
`libkeymasterdeviceutils.so` 把该路径写死为 `/vendor/firmware_mnt/image`。
`TW_INCLUDE_CRYPTO := true`、`TW_INCLUDE_CRYPTO_FBE := true`、
`TW_INCLUDE_FBE_METADATA_DECRYPT := true`，服务定义在
`recovery/root/init.recovery.qcom.rc` 中（`on fs` 启动 qseecomd，等
`vendor.sys.listeners.registered` 后再由属性触发器拉起两个 HAL）。

### 真机复验（t7）：两个让 keymaster 永远起不来的确定性阻断

t7 直接在运行中的 recovery 上取证（`adb shell`，设备 320607233569，活动槽位 `_b`），
结论是：t4 那轮"把 vendor 加密栈搬进 ramdisk"的方向是对的，但**它从来没有真正跑起来过**。
实测四个属性：

    init.svc.vendor.qseecomd        = restarting
    hwservicemanager.disabled       = true
    hwservicemanager.ready          = (不存在)
    init.svc.keymaster-4-0          = (不存在，一次启动尝试都没有)
    init.svc.gatekeeper-1-0         = (不存在，一次启动尝试都没有)

两个原因彼此独立，各自都足以让 `Decrypt_Data()` 拿不到密钥。它们都是构建产物层面的缺陷，
所以在设备树上改 fstab、改 twrp.flags、改任何运行期选项都碰不到。

#### 阻断 1：ramdisk 里的三个二进制没有可执行位

    $ adb shell ls -l /vendor_ramdisk/bin/ /vendor_ramdisk/bin/hw/
    -rw-r--r--  qseecomd
    -rw-r--r--  android.hardware.gatekeeper@1.0-service-qti
    -rw-r--r--  android.hardware.keymaster@4.0-service-qti
    $ adb shell getprop init.svc.vendor.qseecomd
    restarting
    $ adb shell dmesg | grep -c "cannot execv('/vendor_ramdisk/bin/qseecomd')"
    46

**这个位在构建期设不了，只能在启动时由 init 设** —— 这是本轮最反直觉的一条，值得写清楚。

直觉上的修法是在 recovery ramdisk 的 recipe 里 chmod：`BOARD_RECOVERY_IMAGE_PREPARE` 确实在
`build/make/core/Makefile:2830` 展开，位置正好是"`recovery/root` 已复制完、ramdisk 尚未打包"，
看起来完全对路。但它**是无效的，并且已被实测证伪**：加上之后暂存目录确实是 `0755`，
打出来的镜像里仍是 `0644`。

原因是 mkbootfs 根本不看源文件权限。每个归档条目都要过 `fix_stat()`
（`system/core/mkbootfs/mkbootfs.cpp`），它用 `fs_config()` 的返回值**无条件覆盖** `st_mode`；
而 `fs_config()` 对一个不在任何 fs_config 表里的普通文件直接返回死值
（`system/core/libcutils/fs_config.cpp:391-395`）：

    *mode = (*mode & S_IFMT) | (dir ? 0755 : 0644);

`vendor_ramdisk/**` 不在任何表里（表里的条目是 `system/bin/*`、`vendor/bin/*`、
`first_stage_ramdisk/system/bin/*` 这类），所以这三个文件在 `ramdisk-recovery.img` 里
**永远是 0644**，与它在磁盘上的权限无关。这同时说明"在 git 里标成 100755"也救不了：打包器不看它，
而且本检出在 Windows 文件系统上本来就表示不了可执行位。

因此可执行位只能由 init 在启动时补上——那也是唯一还能改它的层
（`recovery/root/init.recovery.qcom.rc` 的 `on early-init`）：

    chmod 0755 /vendor_ramdisk/bin/qseecomd
    chmod 0755 /vendor_ramdisk/bin/hw/android.hardware.keymaster@4.0-service-qti
    chmod 0755 /vendor_ramdisk/bin/hw/android.hardware.gatekeeper@1.0-service-qti

`chmod` 是 init 现役 builtin（`system/core/init/builtins.cpp:1017` 的 `do_chmod`，`:1288` 注册为
`{2, 2}`），参数顺序是 **`chmod <八进制模式> <路径>`——模式在前**，很容易写反
（`system/core/init/README.md:556`）。放在 `on early-init` 余量充足：这三个服务要么由 `on fs`
启动、要么由更晚的属性触发器启动，而 init 按队列顺序执行动作；recovery 的 ramdisk 是可写
rootfs，所以 `fchmodat()` 会成功。

#### 阻断 2：ramdisk 里根本没有 VINTF manifest

`system/hwservicemanager/service.cpp:150-160` 的自检：

    auto transport = android::hardware::getTransport(ServiceManager::descriptor, serviceName);
    if (transport == android::vintf::Transport::EMPTY) {
        ALOGI("HIDL is not supported on this device so hwservicemanager is not needed");
        property_set("hwservicemanager.disabled", "true");
        while (true) { ALOGW("Waiting on init to shut this process down."); sleep(10); }
    }

`getTransport()`（`system/hwservicemanager/Vintf.cpp:40-71`）先查 framework manifest、再查 device
manifest，两处都没有就返回 EMPTY。真机表现与代码完全吻合：`hwservicemanager.disabled=true`，
进程 pid 停在 `__arm64_sys_nanosleep`（就是那个 `sleep(10)` 死循环）。后果是
`init.recovery.qcom.rc` 里那个
`on property:...&& property:hwservicemanager.ready=true` **永不成立**，两个 HAL 连 fork 都没有过。

设备侧 `/system/etc/vintf/` 只有一个 AIDL 片段 `manifest/android.system.keystore2-service.xml`，
而**片段目录只有在主 manifest 解析成功时才会被读**：`system/libvintf/VintfObject.cpp:454-461` 把
`addDirectoryManifests()` 放在 `fetchOneHalManifest(kSystemManifest)` 返回 OK 的分支里。也就是说
那个片段一直是死文件，补片段解决不了问题，必须**补主 manifest**。

新增 `recovery/root/system/etc/vintf/manifest.xml`（落地为 ramdisk 里的
`/system/etc/vintf/manifest.xml`），声明四项：

| 包 | 版本 | 接口 / 实例 | 为什么需要 |
|---|---|---|---|
| `android.hidl.manager` | **1.2** | `IServiceManager/default` | hwservicemanager 启动自检，不写它就直接自禁用 |
| `android.hidl.token` | 1.0 | `ITokenManager/default` | 与平台 `hwservicemanager_no_max.xml` 对齐 |
| `android.hardware.keymaster` | 4.0 | `IKeymasterDevice/default` | 注册闸门要求 |
| `android.hardware.gatekeeper` | 1.0 | `IGatekeeper/default` | 注册闸门要求 |

两个容易写错、都已在文件注释里写明：

* **必须是 1.2，写 1.0 无效。** `ServiceManager::descriptor` 取自服务实际实现的生成接口
  （`system/hwservicemanager/ServiceManager.h` include 的是 `android/hidl/manager/1.2/IServiceManager.h`），
  查询名就是 `android.hidl.manager@1.2::IServiceManager`；而"声明版本能匹配查询版本"的条件是
  **声明版本 ≥ 查询版本**（`system/libvintf/include/vintf/Version.h:61-67`，注释里明写
  `Version(2,1).minorAtLeast(Version(2,2)) == false`）。写成 1.0 的话 hwservicemanager 会继续自禁用。
* **keymaster / gatekeeper 也必须写。** 注册 HIDL 服务时客户端先查自己的 descriptor 是否被声明为
  hwbinder，不是就立刻失败：`system/libhidl/transport/ServiceManagement.cpp:988-1001`
  （`"must be in VINTF manifest in order to register/get."`），而 `PRODUCT_ENFORCE_VINTF_MANIFEST`
  在 `build/make/core/config.mk:785` 被无条件置为 `.KATI_READONLY` 的 true，没有开关可关。
  （这三者的 `interfaceChain` 都只有自己 + `android.hidl.base@1.0::IBase`，
  所以 `ServiceManager::add()` 的"父接口也必须在 manifest 里"检查不会额外要求别的条目。）

四项都放在 **framework** 一份里，而不是按常规拆成 framework + device 两份：常规拆法要求 device
那份落在 `/vendor/etc/vintf/`，而 `/vendor` 正是 TWRP 会挂上又卸下的地方；hwservicemanager 只在
启动时读一次并缓存（`system/libvintf/VintfObject.cpp` 的 `Get()`），framework 又先于 device 被查
（`Vintf.cpp:59` 在 `:64` 之前），所以全部放 `/system`（recovery ramdisk 本体，不会被遮蔽）最稳。
条目内容逐字取自平台自己的
`system/hwservicemanager/hwservicemanager_no_max.xml` 与
`stock/vendor/etc/vintf/manifest.xml:76-94`。

#### 用平台自己的解析器验证

离线最有力的验证不是"看一眼"，而是让平台自己的 libvintf 解析它——宿主机上就有这个工具：

    $ out/host/linux-x86/bin/assemble_vintf -i recovery/root/system/etc/vintf/manifest.xml -o /tmp/out.xml
    $ echo $?
    0

它输出的四个 `<fqname>` 正是这次要的东西：

    android.hidl.manager@1.2::IServiceManager/default
    android.hidl.token@1.0::ITokenManager/default
    android.hardware.keymaster@4.0::IKeymasterDevice/default
    android.hardware.gatekeeper@1.0::IGatekeeper/default

全部 `<transport>hwbinder</transport>`。

**一个之前被我说重的点，在此更正**：本文件第一版的分节线用的是连字符，而 XML 规范禁止注释里出现
连续两个连字符，Python 的 expat 也确实拒绝整个文档（`not well-formed (invalid token)`）。
我据此一度判断"这会让整套 HIDL 起不来"。**这个判断是错的**：libvintf 用的是 tinyxml2
（`system/libvintf/parse_xml.cpp:32`），它容忍这个序列，`assemble_vintf` 对带连字符注释的
manifest 同样返回 0。所以那是一个**合法性缺陷，不是设备阻断**。分节线仍然改用 `=`，并且
`vintf/xml-comment-safety` 与 `vintf/xml-parses` 两项继续保留它——原因是文件本来就该是良构
XML，而 expat 系的工具（xmllint 等）会直接拒绝——但不再把它说成阻断项。

#### 本轮回归检查

    node tools/verify_decrypt_prereqs.mjs --verbose

新增断言：`vintf/*`（存在、四项内容与版本、type=framework、不放在失效的片段目录、注释安全、
可被 expat 解析）、`keystore2/*`（触发条件、no_fatal 及其在 early-init、平台 service 定义未被
改动）、`rc/exec-bits` 与 `rc/exec-bits-early`（三行 chmod 都在 `on early-init` 块内且早于
`on fs`）、`build/no-inert-exec-chmod`（防止那个实测无效的构建期 chmod 被加回来），
以及在**已构建镜像**上读回 `init.recovery.qcom.rc` 的 `packed/exec-bit-strategy`。

#### 仍未修（本轮只定性，未改）：/mnt/vendor/persist 永远挂不上

实机取证：`mount | grep persist` 为空，但这两个目录存在，而且是 **0777 的根文件系统目录**
（不是挂载点）：

    $ adb shell ls -ld /mnt/vendor/persist /mnt/vendor/persist/TWRP
    drwxrwxrwx  /mnt/vendor/persist
    drwxrwxrwx  /mnt/vendor/persist/TWRP

`recovery.log` 里对应的两行是：

    I:Is_Mounted: Unable to find partition for path '/mnt/vendor/persist/TWRP'
    I:UnMount: Unable to find partition for path '/mnt'

原因是 TWRP 的路径助手只认**两级**挂载点。`TWFunc::Get_Root_Path()`
（`bootable/recovery/twrp-functions.cpp:371-383`）把路径截到第一个斜杠之后：

    size_t position = Local_Path.find("/", 2);
    if (position != string::npos) Local_Path.resize(position);

于是 `/mnt/vendor/persist/TWRP` → `/mnt`，而 `Mount_By_Path` / `UnMount_By_Path`
（`partitionmanager.cpp:758-800`）拿 `/mnt` 去逐个比对 `partition->Mount_Point`，自然找不到。

这与 fstab 注释里已经记录过的 `/vendor/firmware_mnt`、`/vendor/dsp`、`/vendor/bt_firmware`
是**同一类缺陷**；当时的处理（R2 修复）是"移出 recovery.fstab、改用 twrp.flags 里的一级挂载点"。
`/mnt/vendor/persist` 这一行没有一起迁走，于是它现在是 `recovery.fstab` 里唯一一个超过两级的
挂载点，也是唯一一个挂不上的。后果是 TWRP 把 `.twrp_settings` 写进 ramdisk 上的临时目录，
**重启即丢**——语言、亮度、超时等设置不会保存。

修法应与 R2 一致：把这一行从 `recovery.fstab` 移到 `twrp.flags`，改成一级挂载点。
本轮没有动它：解密是主目标，而改挂载点需要配套的实机复核，不宜和这一轮的验证混在一起。

### 真机复验（t8）：dlopen 的那一半依赖

t7 修好后重新构建、刷入、复验，`cannot execv` 计数从 46 变成 **0**，权限位也确实成了 `0755`：

    $ adb shell ls -l /vendor_ramdisk/bin/
    -rwxr-xr-x  qseecomd

但 qseecomd **仍然起不来**，而且这次是另一种失败——它真的被 fork 起来了，然后 18 毫秒后自己退出：

    init: starting service 'vendor.qseecomd'...
    init: ... started service 'vendor.qseecomd' has pid 620
    init: Service 'vendor.qseecomd' (pid 620) exited with status 255

排除项（都做过了，都不是原因）：

* **不是缺库导致的链接失败。** 让 linker 自己去解析，全部命中：
      $ adb shell LD_LIBRARY_PATH=... /system/bin/linker64 --list /vendor_ramdisk/bin/qseecomd
      libcutils.so => /system/lib64/libcutils.so
      libQSEEComAPI.so => /vendor_ramdisk/lib64/libQSEEComAPI.so
      ... 20 条，无一 not found
* **不是 SELinux。** 同期 avc 全是 `permissive=1`。
* **看不到任何输出**，因为 recovery 里**根本没有 logd**（`/dev/socket/logdw` 不存在、也没有 logcat），
  而这个二进制只用 ALOG* 说话，消息直接掉进黑洞——所以才表现为"静默退出 255"。

线索来自二进制自己的字符串：

    Init dlopen(%s, RLTD_NOW) is failed.... %s
    ERROR: RPMB_INIT failed, shall not start listener services
    ERROR: SSD_INIT failed, shall not start listener services

**根因：这套栈有一半是用 `dlopen()` 装的，而那些名字只以字符串形式存在于二进制里，
既不在 `DT_NEEDED` 中，也不在任何链接器可见的清单里。** qseecomd 会 dlopen
`librpmb.so`、`libqisl.so`、`libops.so`、`libsecureui.so`、`libGPreqcancel.so`，
它们又各自拉进 `libsecureui_svcsock.so`、`libGPreqcancel_svc.so`、`libStDrvInt.so`、
`libdisplayconfig.qti.so`、`libdrm.so`、`vendor.display.config@1.0/2.0.so`、
`vendor.qti.hardware.tui_comm@1.0.so`。**这 13 个一个都不在 ramdisk 里**，于是第一次 dlopen
就失败，进程直接退出。

这同时解释了**为什么 t4/t7 的静态检查会说"依赖闭包完整"**：那些检查用 readelf 走 `DT_NEEDED`，
而 dlopen 目标对 readelf 天然不可见——不是检查写错了，是它量错了东西。

#### 先实测、后重建

在重建之前先在真机上验证了假设：只把这 13 个文件 push 进运行中 recovery 的
`/vendor_ramdisk/lib64/`（rootfs，可写），等 init 的下一次 5 秒重试，四个属性立刻翻转：

| 属性 | push 前 | push 后 |
|---|---|---|
| `init.svc.vendor.qseecomd` | restarting | **running** |
| `vendor.sys.listeners.registered` | (不存在) | **true** |
| `init.svc.keymaster-4-0` | (不存在) | **running** |
| `init.svc.keystore2` | (不存在) | **running** |

dmesg 里能看到 t7 设计的那个闸门原样生效：

    init: processing action (hwservicemanager.ready=true && init.svc.vendor.qseecomd=running
                            && vendor.sys.listeners.registered=true) from (/init.recovery.qcom.rc:199)
    init: starting service 'keymaster-4-0'...
    init: ... started service 'keymaster-4-0' has pid 783

并且 `keystore.crash_count = 0`——keystore2 在启动时会**急切地**解析 keymint/TEE
（`service.rs:65-79`），失败即退出；它稳定运行且零崩溃，说明 TEE 那条路真的通了。
（该次开机的 `/data` 仍然是 `Unable to decrypt metadata encryption`：TWRP 只有一次解密机会，
发生在开机时，而我是在那之后才 push 的库。）

#### 回归防线

新增 `tools/lib_closure.py`：同时沿 `DT_NEEDED` **和**字符串里出现的 `.so` 名字做广度优先，
按 ramdisk → stock vendor dump → 已构建 `/system/lib64` 的顺序解析，把"只在 stock 里有"
（MUST STAGE）和"哪儿都没有"（UNRESOLVED）分开报告。当前结论：

    staged .so: 26   stock .so: 771   system .so: 183
    MUST STAGE: none
    UNRESOLVED: none

`tools/verify_decrypt_prereqs.mjs` 新增 `prereq/dlopen-closure` 断言它的结论，
所以这个缺口不会再次静默通过。

### 真机复验（t9）：密钥解开了，但 dm-default-key 建不起来（platform 缺陷）

t8 修好之后，整条加密链**第一次完整起来**：

```
qseecomd=running   listeners=true    keymaster=running
gatekeeper=running keystore2=running keystore.crash_count=0
```

但 `/data` 依旧不挂。而且这次可以确定**不是竞态**：重启 recovery 服务、让它在 HAL 全部就绪
之后重新跑一次 `Decrypt_Data()`，结果一模一样。

#### 先把日志弄出来

vold 的 `LOG()` 输出一直看不到，因为 recovery 里**没有 logd**（`/dev/socket/logdw` 不存在、
也没有 logcat），而 liblog 在 Android 上只写 logd、**没有 stderr 回退**
（`system/logging/liblog/logger_write.cpp:170`：`__ANDROID__` 下默认 logger 是
`__android_log_logd_logger`）。

但 liblog 留了一个口子：`ro.log.file_logger.path`（`logger_write.cpp:287-296`）。
设上它，liblog 就把每条日志追加写进那个文件：

```
adb shell setprop ro.log.file_logger.path /tmp/liblog_recovery.txt
adb shell setprop ctl.restart recovery
```

#### 日志说的第一件事：加密栈本身已经是好的

```
MetadataCrypt.cpp:289 fscrypt_mount_metadata_encrypted: /data encrypt: 0 format: 0 with f2fs block device: /dev/block/sda9
MetadataCrypt.cpp:128 metadata_key_dir/key: /metadata/vold/metadata_encryption/key
KeyUtil.cpp:302       Key exists, using: /metadata/vold/metadata_encryption/key
KeyStorage.cpp:607    Retrieving key from keymaster
KeyStorage.cpp:337    reading blob_file: .../keymaster_key_blob
KeyStorage.cpp:366    KeyMint upgraded .../keymaster_key_blob for this operation only
```

`Retrieving key from keymaster` 之后没有再报错——**硬件包装的密钥被成功解开了**。t7/t8 修的那些
（可执行位、VINTF manifest、dlopen 依赖）到此全部兑现。

#### 第二件事：卡在 dm-default-key

```
dm.cpp:332             DM_TABLE_LOAD failed: Invalid argument
MetadataCrypt.cpp:195  Could not create default-key device userdata
MetadataCrypt.cpp:373  create_crypto_blk_dev failed in mountFstab
```

内核把原因写得更直白：

```
device-mapper: table: 253:6: default-key: Invalid keysize
device-mapper: ioctl: error adding target to table
```

**密钥长度不对**：送给内核的是 `exportWrappedStorageKey()` 产出的硬件包装密钥，
却没有同时告诉内核它是包装过的。

#### 根因：libdm 只在非 legacy 分支发 `wrappedkey_v0`

`system/core/fs_mgr/libdm/dm_target.cpp`：

```cpp
if (use_legacy_options_format_) {
    if (set_dun_) extra_argv.emplace_back("set_dun");
} else {
    extra_argv.emplace_back("allow_discards");
    extra_argv.emplace_back("sector_size:4096");
    extra_argv.emplace_back("iv_large_sectors");
    if (is_hw_wrapped_) extra_argv.emplace_back("wrappedkey_v0");   // 只有这里发
}
```

本机**两个条件同时成立**，于是标记被丢掉：

* 走 legacy 格式：fstab 里是 `fileencryption=ice`（没有 `:v2` 后缀）。
  `DmTargetDefaultKey::Valid()` 是旁证：`if (!use_legacy_options_format_ && !set_dun_) return false;`
  ——非 legacy 且 `set_dun` 为假会被 libdm 自己拒掉，而报错的是**内核**。
* 同时 `use_hw_wrapped_key` 为真：`is_metadata_wrapped_key_supported()`
  （`system/vold/FsCrypt.cpp:381`）读的就是 `/metadata` 条目上的 `wrappedkey` 标志。

内核侧完全支持：本机内核（4.19.157-perf / msm-4.19）里有 `default-key`、`wrappedkey_v0`、
`set_dun`、`allow_discards`、`iv_large_sectors`、`sector_size`，`drivers/md/dm-default-key.c` 也在。
缺的只是 libdm 没把标记发出去。

#### 修法：一处 platform 补丁

把 `wrappedkey_v0` 从 `else` 里挪出来，两种格式都发。这也应当是原厂 Android 11 的行为，
否则原厂无法在同样的「v1 fstab + wrappedkey」组合上启动。补丁与说明见 `platform-patches/`
（`system/core` 不在设备树里，重新 sync TWRP 源码后需要重新应用）。

补丁用 `git apply --reverse --check` 验证过与工作树逐字一致；它确实进了镜像：

```
$ gzip -dc ramdisk-recovery.img | cpio -idm system/lib64/libfs_mgr.so
$ strings -a system/lib64/libfs_mgr.so | grep 'default-key: legacy='
default-key: legacy=
```

（`recovery` 二进制本身不含这段代码——它链接的是共享库 `libfs_mgr.so`；一开始查错了文件，
以为补丁没生效。）

**尚未在真机确认。** 判据：`/data` 挂上、`recovery.log` 出现
`Successfully decrypted metadata encrypted data partition`、内核不再打印
`default-key: Invalid keysize`。

### keystore2 启动顺序（t4：唯一一次解密尝试的胜负手）

解密只有一次机会：`Decrypt_Data()`（`partitionmanager.cpp:599-651`）在
`Setup_Fstab_Partitions()` 里被调用一次，失败后没有任何自动重试，用户看到的就是那个永远
解不开的密码页。整条链路上真正有阻塞等待的只有一处：

```
Decrypt_Data()
  -> vold::fscrypt_mount_metadata_encrypted()
     -> KeyStorage::exportWrappedStorageKey()        system/vold/KeyStorage.cpp:156
        -> Keystore::Keystore()                      system/vold/Keystore.cpp:112-143
           poll IKeystoreService/default 300 x 100 ms   <- 真的等，但只等 keystore2
           -> getSecurityLevel(TRUSTED_ENVIRONMENT)
              keystore2 用启动时就已经建好的 SecurityLevel 回答：
                service.rs:65-79      构造 TRUSTED_ENVIRONMENT，失败即致命
                security_level.rs:92  -> globals.rs:344 get_keymint_device()
                globals.rs:230        -> retry_get_interface()
                utils.rs:665          retry_count = 1 unless cfg!(early_vm)
                                      => binder::get_interface() 一次性查询，
                                         未注册立刻 NAME_NOT_FOUND
```

也就是说：**vold 会等 keystore2，但不会等 keymaster HAL**。如果 keystore2 先起来，它在启动
阶段就因为拿不到 TEE SecurityLevel 而退出，之后每 5 秒被重启一次
（`system/core/init/service.h:236`），那些失败的查询不会被重试。现象与"设备没有密码"完全一致。

关于重启升级的准确读法（**t7 更正**）：判定是 `if (++crash_count_ > 4)`
（`system/core/init/service.cpp:366`，`LOG(FATAL)` 在 `:383`），也就是**第 5 次**退出才重启，
不是第 4 次。而外面那层窗口判断是
`if (now < time_crashed_ + fatal_crash_window_ || !boot_completed)`（`:365`），
recovery ramdisk 从不设置 `sys.boot_completed`，所以 `|| !boot_completed` 恒真、窗口形同
不存在，`critical window=0` 在 recovery 里退化成"任何时刻累计 5 次失败就重启"。

因为 keystore2 的 keymint 查询是一次性的，**第一次启动必然输给这个竞态**（init 置
`init.svc.keymaster-4-0=running` 只表示 fork 成功，HAL 还要用 QSEECom 载入 trustlet 才会注册），
所以这条升级路径必须摘掉。本设备树用 init 官方文档给出的开关
（`system/core/init/README.md:242-243`，判定处 `service.cpp:372`）：

    on early-init
        setprop init.svc_debug.no_fatal.keystore2 true

放在 `on early-init` 是为了保证它在第一次 `start keystore2` 之前就已经为真。这只去掉重启，
不会把"keystore2 真的起不来"变成静默挂起：vold 自己的 30 秒轮询
（`system/vold/Keystore.cpp:112-122`）仍然是等待上限。

因此本设备树把 keystore2 的启动点从平台默认的 `on late-init` 挪到 HAL 之后：

* `recovery/root/system/etc/init/keystore2.rc` 覆盖同名平台文件（ramdisk 覆盖层），触发条件
  改为 `on property:init.svc.keymaster-4-0=running`；service 定义逐字节保留平台版本（含
  `critical window=0` 与 `u:r:recovery:s0`）。
* `recovery/root/init.recovery.qcom.rc` 不再启动 keystore2，两个 HAL 的启动条件也补上
  `init.svc.vendor.qseecomd=running`（init 自己 fork 成功才置位）——这样“qseecomd 挂掉但
  残留属性还在”的旧触发方式不会再生效。

**仍然存在的空档（明说，不当作已修好）**：`init.svc.<name>` 是进程状态，不等于 hwbinder
注册；init 也没有“阻塞等待另一个进程完成服务注册”的原语，而 TWRP 的解密路径不读任何就绪
属性。因此从设备树 rc 无法建立“HAL 已注册 -> 才调用 Decrypt_Data()”的严格 happens-before。
要彻底闭合，需要一处 platform 改动，二选一：

1. 让解密路径等项目已就绪的信号（最贴近现有代码）：在 `system/vold/Keystore.cpp` 的
   `getSecurityLevel()` 之后判空时重试/等待，或让 keystore2 在 `get_keymint_device()` 失败时
   自身阻塞重试（`retry_get_interface()` 的 `retry_count` 在非 early_vm 构建上恒为 1，改这里
   等于给 keymaster 补上 vold 早就有的那种等待）；再在 TWRP 侧于 `Decrypt_Data()` 前用
   `android::base::WaitForProperty("init.svc.keymaster-4-0", "running")` 之类的显式前置条件。
2. 或者把“HAL 已注册”变成一个 init 能观察、TWRP 会读的属性，并在解密的唯一入口处检查它。

两条都改在 WSL 源码树之外无法完成（本设备树仓库只含 device tree），当前状态记为：设备树侧可
确定的顺序已经做足，剩余窗口需要上述 platform 改动。回归检查：
`node tools/check_decrypt_ordering.mjs`（21 项，覆盖触发条件、keystore2 触发点、可达性，以及
“没有用 sleep 伪装同步”）。
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
6. **FBE / metadata 解密**：预期 `/data` 能解密并挂载；关键日志是
   `Successfully decrypted metadata encrypted data partition with new block device`
   与其后的 `File Based Encryption is present`。若出现
   `I:Unable to decrypt metadata encryption`，先看 `logcat`/恢复日志里
   `vendor.qseecomd`、`keymaster-4-0`、`gatekeeper-1-0` 是否起来，
   以及 `/vendor/firmware_mnt/image` 是否存在。
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

---

## 设备树逐文件说明

设备树里的文件只保留单行注释，所有依据、出处、实测证据与回归检查都集中在这里。
本节按文件组织；行为层面的推导与真机复验记录见上文各章节（t1..t9）。

### BoardConfig.mk

#### A/B

是**普通 A/B**，不是 virtual A/B。依据：`stock/config/config.json` 的 `{"pd_vab":"ab"}`；原厂 boot ramdisk 的 `/fstab.qcom` 在 system/product/vendor 上带 `slotselect`；9008 救砖包（`stock/rawprogram4.xml`）里 boot、recovery、dtbo、modem、dsp、bluetooth、vbmeta 都有 `_a`/`_b` 两份。整包**找不到** snapshot / COW / super_empty 分区，所以 `ENABLE_VIRTUAL_AB` 必须保持关闭。

#### recovery 是独立分区

本机有**专用 recovery 分区**，所以 recovery 不能被折进 boot.img。依据三条：

1. 设备事实（用户确认）。
2. `stock/rawprogram4.xml:16` 的 `recovery_a` 与 `:39` 的 `recovery_b` 都是 24576 × 4096 = 100663296 字节。
3. `~/workdir/twrpgen/recovery.img` 正是该分区 100663296 字节的完整 dump，且是一张真正的 AVB 签名镜像（文件尾有 AVBf footer，`original_image_size` 为 0x03A87000），其内核与原厂 `boot.img-kernel` 逐字节相同（sha256 `697dd05f...aca3cb`）。

`BOARD_MOVE_RECOVERY_RESOURCES_TO_VENDOR_BOOT` 留空：原厂分区表里**没有 vendor_boot 分区**，recovery 资源属于 recovery ramdisk。

#### 架构

`arm64` + `armv8-a`，主 ABI `arm64-v8a`，运行时 `cortex-a76`；32 位副架构 `arm` + `armv7-a-neon`，运行时 `cortex-a55`，`TARGET_SUPPORTS_64_BIT_APPS := true`。

#### APEX

原厂 vendor 分区是 Android 11（SDK 30，见 `stock/vendor/build.prop` 的 `ro.vendor.build.version.sdk=30`），因此打开 `OVERRIDE_TARGET_FLATTEN_APEX`。

#### Bootloader

`TARGET_BOOTLOADER_BOARD_NAME := lito`，`TARGET_NO_BOOTLOADER := true`。

#### 显示

面板 1080x2460 @ 6.9 英寸，VISIONOX RM692C9（10-bit、DSC、command mode），物理约 400 PPI。但原厂 ROM 用的是 `ro.sf.lcd_density=480`，而这个值正是 `TARGET_SCREEN_DENSITY` 产生的（`build/make/core/system/sysprop_config.mk:127-129` → `ro.sf.lcd_density`）。所以 480 才是这台机器自己的密度，**不要**按物理 PPI 去「纠正」它。

**这里刻意没有「默认刷新率」这个开关。** 生成器模板曾带 `TARGET_RECOVERY_DEFAULT_REFRESH_RATE := 90`，那是个**死变量**：在整个 TWRP 16 检出（bootable/、vendor/、build/make/、system/core/、hardware/qcom-caf/、device/）里全局搜索，它只出现在本设备树，任何 makefile 或源码都不读它，所以它从来不可能影响构建。DRM 后端的模式选择完全由内核数据驱动：

* `twrpminui/graphics_drm.cpp:1023-1044` —— `find_main_monitor()` 选 `/proc/cmdline` 上 `video=Virtual-1:` 指定的模式，否则选第一个带 `DRM_MODE_TYPE_PREFERRED` 的模式，**从不看刷新率**；
* `twrpminui/graphics_drm.cpp:1291-1294` —— 所选模式的 hdisplay/vdisplay 成为 framebuffer 尺寸；
* `twrpminui/graphics_drm.cpp:1470` —— 该模式通过 DRM property blob 应用。

面板实际跑 90 Hz 是**引导器**选了 90 Hz 那个面板变体，与本设备树无关：`/proc/cmdline` 里是 `msm_drm.dsi_display0=qcom,dsi_visionox_rm692c9_10bit_dsc_90hz_cmd_display:`，dmesg 打印 `Successfully bind display panel 'qcom,dsi_visionox_rm692c9_10bit_dsc_90hz_cmd_display'`，`/sys/class/drm/.../modes` 里同时有 `1080x2460x60x63334cmd` 与 `1080x2460x90x88154cmd`。**不要重新加回刷新率设置**，没有消费者。

#### 内核镜像头

下面每个值都抄自**原厂镜像**，不是猜的：

* `stock/boot/split_img/boot.img-*`（header_version、base、pagesize、kernel_offset、ramdisk_offset、second_offset、tags_offset、dtb_offset、cmdline、imgtype、ramdiskcomp、hashtype、origsize）；
* `~/workdir/twrpgen/recovery.img` 的 raw v2 头。

原厂 boot.img：header v2、base 0x00000000、pagesize 4096、kernel_offset 0x00008000、ramdisk_offset 0x01000000、second_offset 0x00000000、tags_offset 0x00000100、dtb_offset 0x01f00000，AOSP、sha1、gzip、origsize 100663296。原厂 recovery.img 布局相同，只是头部 dtb_size 字段里多一块 12733035 字节的 dtb，内容与 `prebuilt/dtbo.img` 相同。

`BOARD_DTB_OFFSET := 0x01f00000` 必须显式给出：生成器模板从不传它，会静默地以 dtb_offset 0 重打包每一张镜像。

`BOARD_INCLUDE_DTB_IN_BOOTIMG := true`：原厂 boot/recovery 都把设备 DTB 放在镜像里，所以要保持开启；用 prebuilt dtb 时文件名还必须是 `*.dtb`，因为 `INSTALLED_DTBIMAGE_TARGET` 是 cat `BOARD_PREBUILT_DTBIMAGE_DIR/*.dtb`。

`BOARD_INCLUDE_RECOVERY_DTBO := false`：原厂 recovery 头里确实带 dtb，但 TWRP 的 recovery ramdisk 比原厂那 32 KiB 大得多，内核 42 MiB + ramdisk + dtbo 24 MiB 塞不进 96 MiB 分区；引导器本来就从 dtbo 分区加载，所以保持关闭，只有真机证明需要时才打开。

#### 预编译内核

没有 in-tree 内核源码，prebuilt 是唯一可行路径。三个 prebuilt 与原厂产物逐字节相同：`prebuilt/kernel`（sha256 `697dd05f...aca3cb` ＝ 原厂 `boot.img-kernel`，42035216 字节）、`prebuilt/dtb.dtb`（sha256 `df33dddc...0f1e34` ＝ 原厂 `boot.img-dtb`，2027715 字节）、`prebuilt/dtbo.img`（DTBO 表 magic 0xd7b7ab1e，21 个 overlay，＝ 设备 dtbo）。

#### 分区尺寸

尺寸来自原厂 9008 包的 GPT（`stock/rawprogram4.xml`），描述的是**出厂布局**；改过机的设备可能不同，刷任何东西之前先用 `fastboot getvar partition-size:<name>` 复核。

| 分区 | rawprogram4.xml | 计算 |
|---|---|---|
| boot_a / boot_b | `:13` / `:36` | 24576 × 4096 = 100663296 |
| recovery_a / recovery_b | `:16` / `:39` | 24576 × 4096 = 100663296 |
| dtbo_a / dtbo_b | `:19` / `:42` | 6144 × 4096 = 25165824 |

#### 输出目录：为什么 product / odm 没有单独设置

`TARGET_COPY_OUT_PRODUCT` / `TARGET_COPY_OUT_ODM` **刻意不设**。AOSP 默认是 `system/product` 与 `vendor/odm`。若把它们改成独立的 `product`／`odm`，会触发 `build/make/core/board_config.mk:404-414` 的 `check_image_config` 守卫，于是必须同时提供 `BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE` / `BOARD_ODMIMAGE_FILE_SYSTEM_TYPE`（或 prebuilt 镜像），`lunch` 会直接失败：

```
If TARGET_COPY_OUT_PRODUCT is 'product', either BOARD_PREBUILT_PRODUCTIMAGE
or BOARD_PRODUCTIMAGE_FILE_SYSTEM_TYPE must be set.
```

本机不构建 product.img / odm.img，所以不需要那两个独立目录。`BoardConfig.mk:713-716/822-826` 确认了默认值。

`BOARD_USES_METADATA_PARTITION := true`：原厂 boot ramdisk 的 `fstab.qcom` 挂载 `/metadata`，且 userdata 是 FBE/ICE（`fileencryption=ice,wrappedkey,keydirectory=/metadata/vold/metadata_encryption`）。

#### super 分区尺寸（已经定案）

`stock/rawprogram0.xml:10`：`label="super" num_partition_sectors="3145728" SECTOR_SIZE_IN_BYTES="4096"`，即 3145728 × 4096 = 12884901888 字节 = 12 GiB。这与 `stock/config/config.json` 的 `{"supersize":"12884901888"}` 以及 `{"repack_fz":"qti_dynamic_partitions"}` 一致。生成器给的 9126805504（8.5 GiB）是错的，这里已纠正。

`BOARD_ZTE_DYNAMIC_PARTITIONS_SIZE := 12883853312` 按 AOSP 规则 = SUPER_PARTITION_SIZE − 1 MiB（元数据槽）。

`system_ext` 与 `odm` 虽然列在分区清单里，但本仓库没有对应镜像、原厂 boot fstab 里也没有 `/system_ext` 条目。在 AOSP/TWRP 构建里它们无害（分区根本不会生成），若真实 super 元数据里的组包含它们则是必需的——用设备上的 `lpdump` 确认。

#### Recovery 与 fstab 位置

TWRP 先找 `/etc/twrp.fstab`、再找 `/etc/recovery.fstab`（`bootable/recovery/twrp.cpp:441-446`），也就是 recovery ramdisk 里的 `/system/etc/...`，由 `build/make/core/Makefile:2821` 复制过去。这里指向参考树（如 `device/xiaomi/munch`）通用的设备树路径，语义最明确；**刻意不用** `Makefile:2645` 的兜底路径（`$(TARGET_DEVICE_DIR)/recovery.fstab`）——生成器模板把 fstab 放错了地方，已经移到这里。

#### Recovery ramdisk 的可执行位（构建期修不了）

`recovery/root/vendor_ramdisk/bin/` 下那三个可执行文件，**构建期没有任何办法让它们带上可执行位**，所以这个文件不要去尝试。

看起来最对路的做法——在 `BOARD_RECOVERY_IMAGE_PREPARE` 里对 `$(TARGET_RECOVERY_ROOT_OUT)` 做 chmod——**是无效的，而且已被实测证伪**：加上之后暂存目录确实是 0755，打出来的镜像仍是 0644。因为 mkbootfs 会重写每个归档条目的权限（`system/core/mkbootfs/mkbootfs.cpp` 的 `fix_stat()`），来源是 `fs_config()`；而不在任何 fs_config 表里的普通文件，`fs_config()` 直接返回硬编码默认值（`system/core/libcutils/fs_config.cpp:391-395`）：

```c
*mode = (*mode & S_IFMT) | (dir ? 0755 : 0644);
```

`vendor_ramdisk/**` 匹配不到任何表项（表里覆盖的是 `system/bin/*`、`vendor/bin/*`、`first_stage_ramdisk/system/bin/*` 之类），所以这三个文件在镜像里**永远是 0644**，与磁盘上的权限无关。在 git 里标成 100755 也没用——打包器不看它，而且本检出在 Windows 文件系统上本来就表示不了这个位。

因此可执行位由 init 在启动时补上，那是唯一还能改它的层（`recovery/root/init.recovery.qcom.rc` 的 `on early-init`）：

```
chmod 0755 /vendor_ramdisk/bin/qseecomd
chmod 0755 /vendor_ramdisk/bin/hw/android.hardware.keymaster@4.0-service-qti
chmod 0755 /vendor_ramdisk/bin/hw/android.hardware.gatekeeper@1.0-service-qti
```

`chmod` 是 init 现役 builtin（`system/core/init/builtins.cpp:1017`／注册在 `:1288`），参数顺序是 `chmod <八进制模式> <路径>`（`system/core/init/README.md:556`）——**模式在前**。回归检查：`tools/verify_decrypt_prereqs.mjs` 的 `rc/exec-bits`。

#### 安全补丁级别

原厂 `stock/vendor/build.prop` 的 `ro.vendor.build.security_patch=2022-01-01` 与 `stock boot.img-os_patch_level=2022-01` 都是 2022-01-01；生成器模板给的 2021-08-01 是错的。

#### 验证启动（AVB）

原厂 recovery 是 AVB 签名的，所以 recovery.img 保留 AVB。`--flags 3` = vbmeta 里 HASHTREE_DISABLED | VERIFICATION_DISABLED。签名用的是 AOSP **公开测试密钥**——它不具备任何可信度，锁定设备上无法通过厂商校验。

#### Platform 版本变量

`PLATFORM_SECURITY_PATCH` / `PLATFORM_VERSION` 在 Android 16 里是只读发布标志（`.KATI_READONLY`），从设备树设置会触发 `build/make/core/version_util.mk` 里的 `$(error)` 守卫。只有 `PLATFORM_VERSION` 还可以覆盖。留档的原厂值：`PLATFORM_VERSION=11`，patch 2022-01-01。

#### TWRP 配置：触屏、背光、振动

`TW_INPUT_BLACKLIST` 保持不设，而且这**已在真机确认**（不只是「未证明」）：生成器模板拉黑了 `hbtp_vm`，本机没有这个设备；五个已注册输入设备里恰好只有一个属于 touchscreen 类，没有任何东西需要过滤。

真机实测（只读 adb，原始 dump 在 `log/session-20261005-2150/`，来源 `/proc/bus/input/devices`）：

| 设备 | event | 事实 |
|---|---|---|
| `goodix_ts` | event4 | **就是触屏**。`ABS=0x0261800000000003` + `BTN_TOUCH` + `BTN_TOOL_FINGER`，即 protocol-B 多点触控，TWRP 的 `events.cpp:434-437` `has_touch_protocol` 判定通过（`BTN_TOUCH` 与 `ABS_MT_POSITION_X/Y` 都置位）。驱动 probe 干净：`goodix_ts_probe OUT r:0`、`input: goodix_ts as .../input4`、IRQ 372 |
| `gpio-keys` | event3 | `KEY=0xc000000000000`，即 bit 114/115 = `KEY_VOLUMEUP`/`KEY_VOLUMEDOWN` |
| `qpnp_pon` | event0 | `KEY=0x14000000000000`，即 bit 116/118 = `KEY_POWER`/`KEY_POWER2`（pm8150 pwrkey+resin） |
| `ah1898` | event1 | `EV=3`、KEY 位图空 → 霍尔传感器，只发 `EV_KEY` 0/1，无法注入按键或触摸 |
| `goodix_fp` | event2 | 指纹，非 touchscreen 类 |

TWRP 在 `ev_init()` 扫描 `/dev/input`（`events.cpp:462-470`）之后用 `ev_get()`（`events.cpp:1345`）读取它们，设备节点存在且属主符合预期：`/dev/input/event*` 是 `crw-rw---- root input`；`/sys/class/leds/vibrator/{duration,activate}` 是 `-rw-rw-r-- root root`。

背光路径是**自动发现**的——`recovery.log` 打印 `Found brightness file at '/sys/class/backlight/panel0-backlight/brightness'`，即 `data.cpp:795` 的 `find_first_named_file("brightness", "/sys/class/backlight")`——所以 `TW_BRIGHTNESS_PATH` 是多余的，刻意不设。TWRP 自己的初始默认值是 `tw_brightness = 255/5 = 51`（`data.cpp:828`），而且只是默认值：实际取值来自持久化的 twrp 设置文件，这也是为什么本机 `recovery.log` 里显示 100（属于设备侧状态，不是本设备树的事）。`max_brightness=255` 让任何 0..255 的 TWRP 取值都合法，`TW_SCREEN_BLANK_ON_BOOT`（`gui.cpp:940`）在启动时写 0——`recovery.log` 里正是那条 100 → 0 的序列。

**振动也刻意没有开关**：本机振动马达**可以**通过 TWRP 写的那套接口驱动（`events.cpp:65-68`、`352-358`、`380`）——PMIC 驱动把它注册成 LED class 设备 `/sys/class/leds/vibrator/{duration,activate}`（device → `qcom,vibrator@5300`），所以不需要 `vibrate_with_ff()` 那条路，`TW_NO_HAPTICS := true` 在事实层面是错的。不用 TWRP 也能复现振动：

```
echo 200 > /sys/class/leds/vibrator/duration
echo 1   > /sys/class/leds/vibrator/activate
```

（写下去手机会震；本设备树从不自动这么做。）

#### Crypto（FBE）

`/data` 是 metadata 加密的：裸的 userdata 块设备**故意**没有明文 F2FS superblock。TWRP 必须先解开 `/metadata/vold/metadata_encryption` 下的 metadata 密钥、建立 dm-default-key 映射；直接挂 `/dev/block/sda9` 一定报 magic mismatch。保留厂商 additional.fstab 那条路径，因为它提供原厂的 `inlinecrypt` 选项。Qualcomm FBE 支持与 metadata 解密都必须编译进来。

`TW_INCLUDE_CRYPTO_FBE := true` 的传递链：`vendor/twrp/config/BoardConfigSoong.mk:271-272` 在 `TW_INCLUDE_CRYPTO` 为真时设置它，进而喂给 soong 变量 `include_crypto_fbe`（`BoardConfigSoong.mk:286`）→ `-DTW_INCLUDE_FBE`（`vendor/twrp/build/soong/Android.bp:295-297`）。已在构建产物里验证：`strings .../recovery | grep -c "misc/vold/user_keys"` → 1（该字符串只在 `#ifdef TW_INCLUDE_FBE` 下编译），而 `#else` 分支里的 `"FBE found but FBE support not present in TWRP"` 为 0。回归检查：`tools/verify_decrypt_prereqs.mjs` 的 `fbe-macro`。

`TW_FORCE_KEYMASTER_VER := true` 把 keymaster HAL 代次钉死，而不是从 `/vendor` 推导：`Process_Keymaster_Version()`（`partitionmanager.cpp:265-302`）否则会去读 `<partition>/etc/vintf/manifest.xml`，而 TWRP 在调用 `Decrypt_Data()` 之前已经把 `/vendor` 卸掉了（`partitionmanager.cpp:453-456` / `561`）。原厂 vendor manifest 声明的是 keymaster 4.0 与 4.1（`stock/vendor/etc/vintf/manifest.xml:87-90`），本设备树提供的正是 4.0 HAL，所以 4.x 是这里的正确值。宏和属性都需要：`TW_FORCE_KEYMASTER_VER` 短路 manifest 探测（`vendor/twrp/build/soong/Android.bp:403-406`），`keymaster_ver` 提供取值（`variables.h:161` 的 `TW_KEYMASTER_VERSION_PROP`）。

#### 加密相关的平台版本改写

`PLATFORM_SECURITY_PATCH := 2099-12-31` 与 `PLATFORM_VERSION := 99.87.36` 是**构建期属性**，用来满足 FBE metadata 解密过程中的 keymaster patch-level 比较；它们**不是**设备真实的补丁级别。已观察到在本树的 TWRP 16 构建里生效（`log/recovery.log` 显示 `ro.build.version.security_patch = 2099-12-31`、`ro.build.version.release = 99.87.36`）。`VENDOR_SECURITY_PATCH` 经 `build/make/core/sysprop_config.mk` 变成 `ro.vendor.build.security_patch`。若上游 manifest／分支变化，要重新确认这些赋值仍然生效（上游 AOSP 在 `version_util.mk` 里用 ifdef + `$(error)` 守着 `PLATFORM_SECURITY_PATCH`）。

### device.mk / twrp_P725A02.mk / AndroidProducts.mk / Android.mk / Android.bp

#### device.mk

| 变量 | 取值与理由 |
|---|---|
| `PRODUCT_SHIPPING_API_LEVEL` | `30`。原厂 `stock/system/build.prop` 的 `ro.build.version.sdk=30`、`ro.board.api_level=30`，即这台的 vendor 侧是 Android 11。 |
| `PRODUCT_USE_DYNAMIC_PARTITIONS` | `true`。原厂 `prop.default` 带 `ro.boot.dynamic_partitions=true`，原厂 fstab 把 system/product/vendor 标为 logical，super 本身是 3145728 × 4096 = 12 GiB（`stock/rawprogram0.xml:10`）。 |
| `AB_OTA_UPDATER` | `true`。普通（非 virtual）A/B：`stock/config/config.json` 的 `{"pd_vab":"ab"}`，9008 包里有 `_a`/`_b` 两份与一张非 sparse 的 `super.img`，但**没有** snapshot / COW / super_empty 分区，所以 `ENABLE_VIRTUAL_AB` 必须保持关闭。 |
| `PRODUCT_PACKAGES`（boot control） | `android.hardware.boot@1.1-impl` + `android.hardware.boot@1.1-service`。原厂 vendor 实现的是 **boot@1.1 而不是 1.0**（`stock/vendor/etc/init/android.hardware.boot@1.1-service.rc`，`stock/vendor/etc/vintf` 指向 `android.hardware.boot@1.1`），生成器给的 boot@1.0 那对是错的。 |
| A/B postinstall | `otapreopt_script`、`cppreopts.sh`、`update_engine`、`update_verifier`、`update_engine_sideload`，以及 `AB_OTA_POSTINSTALL_CONFIG` 的 `RUN_POSTINSTALL_system` / `POSTINSTALL_PATH_system` / `FILESYSTEM_TYPE_system=ext4` / `POSTINSTALL_OPTIONAL_system`。 |
| fastbootd | `fastbootd` + `android.hardware.fastboot@1.0-impl-mock`。 |
| `TARGET_RECOVERY_DEVICE_MODULES` / `RECOVERY_LIBRARY_SOURCE_FILES` | `libion` 及其 `.so`：msm-4.19/lito 上 recovery 显示路径要用它。 |
| `PRODUCT_PROPERTY_OVERRIDES` | `ro.adb.secure=0`、`keymaster_ver=4.x`。`ro.boot.dynamic_partitions` 由引导器设置，无需覆盖。 |
| Crypto 开关 | `TW_INCLUDE_CRYPTO` / `TW_INCLUDE_CRYPTO_FBE` / `TW_INCLUDE_FBE_METADATA_DECRYPT` 均为 `true`。裸 userdata 是 metadata 加密的，只有 `/metadata/vold/metadata_encryption` 里的密钥被解开、dm-default-key 设备建立之后，明文 F2FS superblock 才会出现。 |

**关于 `bootctrl.lito`（刻意不加）**：QTI/CAF 的 boot control 实现**不在本 manifest 里**——检出中既没有 `hardware/qcom-caf/bootctrl`，也没有任何 in-tree 模块提供它，所以请求它只会让构建失败。TWRP 本身不需要 boot control HAL：它从 `ro.boot.slot_suffix` 读槽位、直接操作 misc 分区。因此 `PRODUCT_PACKAGES += bootctrl.lito` 与 `PRODUCT_STATIC_BOOT_CONTROL_HAL` 都已从生成器模板里删掉。只有 manifest 里出现可用的 bootctrl 实现之后才考虑加回。

#### twrp_P725A02.mk

继承顺序（`PRODUCT_*` 标识必须放在所有 inherit 之后）：

1. `$(SRC_TARGET_DIR)/product/base.mk`；
2. `$(SRC_TARGET_DIR)/product/core_64_bit_only.mk` —— 本机是 **64 位-only ABI 列表**（原厂 `prop.default` 的 `ro.product.cpu.abilist=arm64-v8a,armeabi-v7a,armeabi` 与 `ro.product.first_api_level=29`），所以用 64 位产品模板；
3. `device/zte/P725A02/device.mk`；
4. `vendor/twrp/config/common.mk` —— **`vendor/twrp` 是本 manifest 里唯一的 vendor 树，`vendor/omni` 不存在**，所以生成器模板里的 `vendor/omni/config/common.mk` 引用从来不可能工作。

设备标识：`PRODUCT_DEVICE := P725A02`、`PRODUCT_NAME := twrp_P725A02`、`PRODUCT_BRAND := ZTE`、`PRODUCT_MODEL := ZTE A2121`、`PRODUCT_MANUFACTURER := ZTE`。

`PRIVATE_BUILD_DESC` 与 `BUILD_FINGERPRINT` 都取自原厂 `stock/vendor/build.prop` 的 `ro.vendor.build.fingerprint`：`ZTE/CN_P725A02/P725A02:11/RKQ1.220125.001/20221021.173842:user/release-keys`。

#### AndroidProducts.mk

`PRODUCT_MAKEFILES := $(LOCAL_DIR)/twrp_P725A02.mk`；`COMMON_LUNCH_CHOICES := twrp_P725A02-eng`。

注意 `COMMON_LUNCH_CHOICES` 里的虚线写法**只用于 Tab 补全与 `list_products` 元数据**，它并不能让 `lunch twrp_P725A02-eng` 变得可用——构建必须用三参数形式 `lunch twrp_P725A02 bp2a eng`，理由见本文档「构建步骤」。

#### Android.mk / Android.bp

`Android.mk` 只在 `TARGET_DEVICE` 是 P725A02 时 include 子目录 makefile；`Android.bp` 只声明 `soong_namespace {}`。两者都没有逻辑，只有版权头。

### recovery/root/init.recovery.qcom.rc

#### 这个文件的来历

它是从生成器模板里**唯一保留下来**的一块：内容与原厂 recovery ramdisk 自带的 `init.recovery.qcom.rc` 逐字节相同（同样的背光写入、同样的 USB controller 属性、同样的 bootdevice 符号链接）。`recovery/root` 里其余部分都被改造成 TWRP 16 真正会读的路径：

| 路径 | 用途 |
|---|---|
| `system/etc/recovery.fstab` | `TARGET_RECOVERY_FSTAB`，由 `core/Makefile` 复制 |
| `system/etc/twrp.flags` | 被当作 `/etc/twrp.flags` 读取 |
| `system/etc/ueventd.rc` | recovery 模式下 ueventd 解析的第一个路径 |
| `init.recovery.usb.rc` | USB gadget + ADB/MTP 触发；覆盖同名上游文件 |

#### 路径前提

TWRP 自己的 `bootable/recovery/etc/init.rc` 已经做了这些事，所以这里不重复：

* `import /init.recovery.${ro.hardware}.rc` —— 也就是本文件（`ro.hardware=qcom`）；
* `symlink /system/etc /etc` —— 因此 `/etc/twrp.fstab`、`/etc/recovery.fstab`、`/etc/twrp.flags` 都能解析；
* `import /init.recovery.usb.rc` —— USB gadget 初始化。

本设备树**确实覆盖了最后一个文件**：`recovery/root/init.recovery.usb.rc` 落到 ramdisk 根目录，替换上游 `bootable/recovery/etc/init.recovery.usb.rc`（真机验证：`/init.recovery.usb.rc` 的 md5 `8bf681c1486ed9c88efd772b66879a14` 与仓库文件一致）。上游 init.rc 没有提供的 configfs `mtp,adb` 分支就在那个文件里。只有 `/system/etc -> /etc` 这个符号链接没有在这里重复。

#### on early-init：为什么加密服务必须跑在 ramdisk 里

TWRP 挂载 `/vendor` 只是为了读 keymaster manifest 和 vendor build.prop，然后在解密之前又把它卸掉：

* `partitionmanager.cpp:426`（`Process_Fstab` 第一遍）挂载 `/vendor`；
* `partitionmanager.cpp:453-456` / `487-515`（`Setup_Fstab_Partitions`）把它卸掉；
* `partitionmanager.cpp:560-561` 随后置 `TW_IS_ENCRYPTED=1` 并调用 `Decrypt_Data()`。

而 init 启动服务是异步的、主循环每轮只执行一条动作命令（`system/core/init/init.cpp`、`builtins.cpp` 的 `do_start`），所以从「由 `/vendor` 触发的动作」里排队一条 `start <vendor hal>` 会和那次卸载赛跑，而且通常输：init fork HAL 的时候 `/vendor/bin` 已经没了。没有 keymaster，`Decrypt_Data()` 就解不开硬件包装的 metadata 密钥，dm-default-key 建不起来，`/data` 永远挂不上，`TW_IS_ENCRYPTED` 停在 1，于是 `gui_loadResources()`（`gui/gui.cpp:990-999`）无限加载解密页——而这台设备**根本没有密码**。

这些二进制本体放在 `recovery/root/vendor_ramdisk/`（qseecomd、keymaster 4.0 HAL、gatekeeper 1.0 HAL 及其共享库闭包）。这里不依赖 `/vendor`、不依赖 vendor mapper 节点、也不依赖任何 `twrp.super.*` 属性。

#### on early-init：可执行位

三个加密二进制**构建期拿不到可执行位**。原因与实测证据见本文档「BoardConfig.mk / Recovery ramdisk 的可执行位」，此处不重复。结论：由 init 在 early-init 里补 `chmod 0755`。

early-init 的余量很大：这些服务要么由 `on fs` 启动、要么由更晚的属性触发器启动，而 init 按队列顺序执行动作；recovery 的 ramdisk 是可写 rootfs，所以 `do_chmod` 里的 `fchmodat()` 会成功。没有这一步，每次 fork 都会失败：`init: cannot execv('/vendor_ramdisk/bin/qseecomd') ... Permission denied`，服务永远停在 `restarting`。

#### on early-init：trustlet 目录

`libkeymasterdeviceutils.so` 用**硬编码**路径 `/vendor/firmware_mnt/image` 打开 keymaster TA（那串字面量就在原厂库里），所以这个路径必须在 keymaster-4-0 运行之前存在，而且**不能被任何挂载遮蔽**。

#### on early-init：为什么是 bind mount 而不是拷贝

`/vendor/bin` 与 `/vendor/lib64` 是 bind mount：链接器会沿服务导出的 `LD_LIBRARY_PATH` 去解析 HAL 的 `DT_NEEDED`，而将来一旦把真实的 vendor 分区挂到 `/vendor`，拷贝过去的目录树会被遮住——bind mount 不会（因为它本身就是 `/vendor` 当时显示的东西）。

同时把 firmware loader 的路径也指过去：内核 firmware loader 还会走 `recovery/root/system/etc/ueventd.rc` 里的 `firmware_directories` 列表。

#### on init

* 写 `/sys/class/backlight/panel0-backlight/brightness` 为 `200` —— 原厂 recovery ramdisk 就是这么做的。
* `setprop sys.usb.configfs 1`。

#### on property:ro.boot.usbcontroller=*

把 `ro.boot.usbcontroller` 转成 `sys.usb.controller`。原厂 recovery 里那条 `write /sys/class/udc/.../mode peripheral` 是**注释掉的**，原因：controller 字符串本身就以 `.dwc3` 结尾，而 `sys.usb.controller` 是原样消费的（`ro.boot.usbcontroller=a600000.dwc3`，见原厂 `boot.img-cmdline`），所以 `/sys/class/udc/${ro.boot.usbcontroller}` 不需要额外的 `.dwc3` 后缀就能解析。这里保持禁用。

#### on fs：bootdevice 符号链接与 /metadata 提前挂载

`/dev/block/bootdevice` 是这里创建的符号链接；`by-name` 那些链接由 ueventd 在处理 UFS 的 block uevent 时创建，所以 `on fs`（TWRP 自己的 init.rc 从 late-init 触发的时机，早于 recovery 服务被 fork）对它们来说足够早，也远早于 TWRP 走到 `Partition_Post_Processing()`。

**把 `/metadata` 提前挂上**：包装密钥在 `/metadata/vold/metadata_encryption` 下，而 `Decrypt_Data()`（`partitionmanager.cpp:604-607`）只会尝试 `Mount_By_Path(data->Key_Directory)`——这条查找会过 `Find_Partition_By_Path()`，而它把 `/metadata/vold/...` 截断成 `/metadata`。提前挂好就消除了这个顺序依赖。`UnMount_Main_Partitions()`（`partitionmanager.cpp:2305-2323`）只动 `/vendor`、Android root、`/product`、`/boot` 和 `/data`，所以这个挂载能活到密钥被解开之后。

#### on fs：qseecomd 的启动条件

qseecomd 先注册 QSEE 监听器，然后发布 `vendor.sys.listeners.registered`——那是原厂二进制**唯一**设置的 `vendor.sys.*` 属性（`strings -a stock/vendor/bin/qseecomd` 可验）。它的 RPMB/SSD 监听器需要 `/dev/qseecom` 和 `ssd` 的 by-name 链接，否则会打印 `ERROR: RPMB_INIT failed, shall not start listener services` 并且什么都不注册。两个节点都由 ramdisk 的 `ueventd.rc` 打标签（`/dev/qseecom` 0660 system drmrpc，`/dev/ion` 0664 system system——ION 是必需的，因为 QSEECom 通过它分配共享缓冲）。

#### HAL 的闸门：为什么必须是这两个条件

没有这道闸门，两个 HAL 会在 QSEE 就绪之前调用 `QSEECom_start_app` 并反复崩溃。

* `vendor.sys.listeners.registered` 由 qseecomd 自己发布，是语义上的「QSEE 监听器已就绪」信号；
* `init.svc.vendor.qseecomd = running` 由 init 在服务**真正被 fork 的那一刻**设置（`system/core/init/service.cpp:173-192` 的 `NotifyStateChange`，从 `:783`/`:884`/`:409` 的进程启动路径调用）。因此「某个进程没起来但属性残留」这种情况**永远无法**满足这个动作，HAL 的拉起不可能被陈旧属性误触发。

再加上 `hwservicemanager.ready=true`（它由 VINTF manifest 决定，见本文档「vintf/manifest.xml」）。

#### 三个 service 定义

| service | 可执行文件 | 关键字段 |
|---|---|---|
| `vendor.qseecomd` | `/vendor_ramdisk/bin/qseecomd` | `class core`、`user root`、`group root drmrpc`、`disabled`、`u:r:recovery:s0` |
| `keymaster-4-0` | `/vendor_ramdisk/bin/hw/android.hardware.keymaster@4.0-service-qti` | `class early_hal`、`user system`、`group system drmrpc`、`interface android.hardware.keymaster@4.0::IKeymasterDevice default`、`disabled` |
| `gatekeeper-1-0` | `/vendor_ramdisk/bin/hw/android.hardware.gatekeeper@1.0-service-qti` | `class early_hal`、`user system`、`group system drmrpc`、`interface android.hardware.gatekeeper@1.0::IGatekeeper default`、`disabled` |

三者都导出同一串 `LD_LIBRARY_PATH`：`/vendor_ramdisk/lib64:/vendor_ramdisk/lib64/hw:/vendor/lib64:/vendor/lib64/hw:/system/lib64`。三者都是 `disabled`——只由上面的闸门显式 `start`，不随 class 自动拉起。

keymaster 4.0 HAL 是 keystore2 获取 `TRUSTED_ENVIRONMENT` 安全级别时对话的对象，也就是 metadata 解密期间**唯一**能导出包装存储密钥的组件。gatekeeper 1.0 则是原厂 vendor vintf manifest 声明的、TWRP 的 `Decrypt_Device()`（「用默认密码解密」那条路）与凭据检查会走的组件；它绑定同一个 QSEECom 守护进程，所以闸门与 keymaster 完全一致。

#### keystore2 不在这里启动

决定「唯一一次解密能否成功」的顺序只有一个：**keymaster HAL 注册 → keystore2 能回答 `getSecurityLevel(TRUSTED_ENVIRONMENT)` → vold 才能导出包装存储密钥**。从 `on late-init`（`bootable/recovery/etc/init/keystore2.rc` 的原厂触发点）启动 keystore2 会把这个顺序交给竞态：

```
TWPartitionManager::Decrypt_Data()             partitionmanager.cpp:599-651
  -> android::vold::fscrypt_mount_metadata_encrypted()
     -> KeyStorage::exportWrappedStorageKey()   system/vold/KeyStorage.cpp:156
        -> Keystore::Keystore()                 system/vold/Keystore.cpp:112-143
           AServiceManager_checkService("android.system.keystore2.IKeystoreService/default")
           轮询 300 x 100 ms = 真正阻塞 30 秒的屏障，但**只等 keystore2**，从不等 keymaster HAL
           -> getSecurityLevel(TRUSTED_ENVIRONMENT)
              取自 keystore2 启动时就填好的缓存：
                service.rs:65-79        构造 SecurityLevel::TRUSTED_ENVIRONMENT，失败即致命
                security_level.rs:92-97 -> globals.rs:344 get_keymint_device()
                globals.rs:230-246      -> retry_get_interface()
                utils.rs:665-684        retry_count = 1 unless cfg!(early_vm)，
                                        即 binder::get_interface() 是**一次性**查询，
                                        未注册立刻 NAME_NOT_FOUND
```

于是在 HAL 注册之前启动的 keystore2 会在启动阶段退出，并在 HAL 还没起来时每 5 秒被重启一次（`system/core/init/service.h:236`）；失败的查询不会重试，而 `critical` 标志会让 init 在若干次退出后重启到 fatal target。可观察到的现象不是崩溃对话框，而是**一台根本没有密码的设备**上永远显示 `I:Unable to decrypt metadata encryption`。

因此启动点搬到了 `recovery/root/system/etc/init/keystore2.rc`——它覆盖 ramdisk 里的同名平台文件，改为 `on property:init.svc.keymaster-4-0=running` 启动。**两个文件必须保持同步：本文件绝不能再启动 keystore2。**

#### 仍然存在的空档（明说，不当作已解决）

`init.svc.<name>` 反映的是**进程状态**，不等于 hwbinder 注册；init 也没有「阻塞等待另一个进程完成服务注册」的原语。TWRP 的解密路径同样不读任何就绪属性，所以「keymaster 已注册」到「调用 `Decrypt_Data()`」之间的严格 happens-before，在设备树 rc 里表达不出来。设备树能确定的是 keystore2 观察到的顺序；剩下那个窗口需要 platform 侧的等待，记录在本文档「keystore2 启动顺序」一节。

### recovery/root/init.recovery.usb.rc

本文件在 ramdisk 内覆盖 TWRP 上游的 `etc/init.recovery.usb.rc`。

#### 现场问题（t1 只读诊断 D1，见 `log/session-20261005-2150/FINDINGS.md`）

**ADB 正常，MTP 不可用。** 原因链：

1. 本机是 **configfs gadget**：`sys.usb.configfs=1`、UDC=`a600000.dwc3`，内核里没有 legacy 的 `/sys/class/android_usb/android0` 节点（真机 `cat` 该路径 ENOENT）。
2. TWRP 上游 `bootable/recovery/etc/init.rc` 的 configfs 分支只有 `adb` / `sideload` / `fastboot` / `none`（`:195-253`），**没有 `mtp,adb` 分支**，也不创建 `functions/mtp.gs0`（`:165-178` 只建 `ffs.adb` 与 `ffs.fastboot`）。但 TWRP UI 启动后会自动启用 MTP：`twrp.cpp:373-393`（STARTUP 步骤）→ `partitionmanager.cpp:2689-2695` 的 `Enable_MTP()`（先把 `sys.usb.config` 置 `none`、再置 `mtp,adb`）。没有这个分支，`mtp,adb` 期间 UDC 就不会被重新拉起——「显示修好后 ADB 失效」正是这么来的。
3. TWRP 的 MTP 后端在两条路径间运行期二选一：`/dev/usb-ffs/mtp/ep0` 可写 → `MtpFfsHandle`（functionfs，端点常量见 `mtp/ffs/MtpDescriptors.h:24-27`，选择逻辑见 `TwrpMtpServer.cpp:62-70` 与 `MtpServer.cpp:124-130`）；否则 → `MtpDevHandle`（内核 f_mtp 的 `/dev/mtp_usb`，`MtpDevHandle.cpp:34`）。本 ramdisk 里没有任何 rc 挂载 `/dev/usb-ffs/mtp`（上游 `init.rc:187-193` 只挂 adb 与 fastboot），因此运行期走内核 f_mtp 这条：真机 dmesg 有 recovery 打开 `/dev/mtp_usb` 的 `mtp_open`/`mtp_release`；`/system/lib64/libtwrpmtp-ffs.so` 同时含 `/dev/usb-ffs/mtp/ep0` 与 `/dev/mtp_usb` 两个字面量；且 `/dev/mtp_usb` 节点存在（`crw-rw---- root mtp`，由 `ueventd.rc` 的规则建出）。

#### 本次修复（t3）

* **(a) `mtp,adb` 的 configfs 绑定**由「当成 adb」改为 AOSP 的 `mtp_adb` 写法：`configuration "mtp_adb"`，`f1` = `functions/mtp.gs0`（内核 f_mtp，configfs 侧不需要用户态就绪），`f2` = `functions/ffs.adb`（仍等 `sys.usb.ffs.ready=1`，即 adbd 写完描述符之后）。该写法与上游 AOSP 16 的 `system/core/rootdir/init.usb.configfs.rc:35-40` 逐字同构，也与本机原厂 `stock/system/system/etc/init/hw/init.usb.configfs.rc:32-40` 被厂商注释掉的同一块一致；内核侧 `CONFIG_USB_F_MTP=y`、`CONFIG_USB_CONFIGFS_F_MTP=y`，且 configfs 里 `functions/mtp.gs0` 本来就能创建成功。→ 修 MTP。
* **(b) 同一块写 `idProduct 0x4EE2`**：MTP+ADB 是复合设备，Google USB 驱动 INF 里复合设备的 ADB 子接口正是 `USB\VID_18D1&PID_4EE2&MI_01`；TWRP 自己 `Enable_MTP` 用的 `usb.product.mtpadb` 默认值也是 4EE2（`partitionmanager.cpp:2692`）。MTP 子接口（MI_00）由主机的类驱动（Windows 便携设备 / Linux libmtp）按接口 class 识别，与 PID 无关。
* **(c) `none` 分支**补「先解绑 UDC、再删链接」的正确顺序。
* **(d) legacy android0 分支**补 `&& property:sys.usb.configfs=0` 守卫，对齐上游 `init.rc:180-223`；`configfs=1` 时这些写入必然失败、只是日志噪声。

#### 故意不做的事

**不挂载 `/dev/usb-ffs/mtp`、不创建 `functions/ffs.mtp`。** 只要该 functionfs 实例存在，TWRP 就会优先走 `MtpFfsHandle`，而那条路线要求 configfs 侧先有 `functions/ffs.mtp`、并且必须等 `sys.usb.ffs.mtp.ready=1`（`MtpDescriptors.cpp:280` 写完描述符后置位）才允许把函数放进配置再写 UDC ⇒ 要么「先绑 adb、随后解绑重绑」（重绑失败会把 ADB 一起带走），要么让 ADB 一直等到 MTP 就绪（TWRP 因 `/data` 不可挂载而不启动 MTP 时该属性永远为 0，见 `twrp.cpp:373-378` 的条件与 `Disable_MTP` 的清零，ADB 就起不来了）。这里选单次绑定、内核 MTP 函数 + adb functionfs：**ADB 只依赖 adbd，与修复前的门控完全相同。**

说明：init 的 builtin 失败只记日志、不中断该 action（`system/core/init/action.cpp:159-174`），且 `symlink` 会覆盖已存在的链接（builtins 的 EEXIST 分支），所以与上游 `init.rc` 之间的重复创建是安全的。

#### 验证与回退（重刷之后在主机侧只读复核）

```
adb devices -l                     # ADB 必须仍然可用
adb shell getprop sys.usb.state    # 期望 mtp,adb
adb shell cat /config/usb_gadget/g1/configs/b.1/strings/0x409/configuration
                                   # 期望 mtp_adb
adb shell ls -l /config/usb_gadget/g1/configs/b.1
                                   # 期望 f1 -> functions/mtp.gs0、f2 -> functions/ffs.adb
adb shell getprop sys.usb.ffs.mtp.ready   # 本路线下应为空或 0（未走 functionfs）
```

主机文件管理器应出现 MTP 设备（Windows 为「便携设备」）。

**回退**：若主机端 ADB 子接口因更换 PID 绑不上驱动，把 `mtp_adb` 块里的 `idProduct` 改回 `0xD001`（ADB 即回到修复前的标识，MTP 仍按接口 class 枚举）；若要完全退回「仅 ADB」，则把 configuration 改回 `adb`、两条 symlink 换成 `ffs.adb -> f1`、并去掉 `functions/mtp.gs0` 的创建。

### recovery/root/system/etc/recovery.fstab

#### 来源

下面每一条设备路径与标志都取自**原厂**：原厂 boot ramdisk 里的 `fstab.qcom`（`stock/boot/ramdisk`）以及原厂 recovery 镜像自带的 `/system/etc/recovery.fstab`。没有一条是编造的。

设备节点事实：

* bootdevice：`/dev/block/platform/soc/1d84000.ufshc`（UFS）；
* 原厂 fstab 使用 `/dev/block/bootdevice/by-name/<name>` 符号链接；
* A/B：按槽位选择的设备是 `<name>_a` / `<name>_b`，所以需要 `slotselect`。

#### t5 集成审查留档（历史）

静态复核通过，但**当时本文件尚未在任何真机镜像上生效**。运行中的 recovery 镜像早于本文件的全部修复（只读 adb 复验，2026-10-05）：

* `/ramdisk-files.sha256sum` 里 `./system/etc/recovery.fstab` = `bee0320b7bd4f954b0cd1f5eced6cd3ac18ce068a23e1f7f4fcd2ce4f0399b38`，与设备上 `/etc/recovery.fstab`（8340 B）逐字节一致，而本文件当时已不同；
* 运行镜像里 `/etc/recovery.fstab` 仍定义 `/vendor/firmware_mnt`、`/vendor/dsp`、`/vendor/bt_firmware` 三个挂载点，即 R2 迁移尚未生效。

结论：R2/B1/B3 与 D2 的更正都必须重新构建并刷入 recovery.img 之后才能复核。这一段只记录当时的静态状态，**不要**把它当作当前结论。

#### super 里的逻辑分区：为什么只有 system / product / vendor

本机 super 里只有 system / product / vendor 三个逻辑分区。`system_ext` 与 `odm` **不是**独立分区：前者内容在 system 镜像内的 `/system/system_ext`（根目录的 `/system_ext` 是指向它的符号链接），后者内容在 vendor 镜像内的 `/vendor/odm`。所以 super 元数据里不存在 `system_ext_<slot>` / `odm_<slot>`，这两条条目不能写。

TWRP 侧机理（`bootable/recovery/partitionmanager.cpp`）：`Setup_Super_Devices()` 调用 `fs_mgr::CreateLogicalPartitions()`，只按 super 当前槽位（`ro.boot.slot_suffix=_b`）元数据里的 enabled 分区创建 `/dev/block/dm-*`；随后 `Prepare_Super_Volume()` 用 `<名字><槽位>`（如 `system_ext_b`）去查该 dm 节点，查不到就打印 `unable to update logical partition`，并在 `partitionmanager.cpp:387` 处把该条目直接丢弃（不崩溃，但会让日志与 `Super (N) partitions` 计数失真）。

证据（都可在本仓库或 `log/` 内独立复核）：

1. 同一次映射里 system/product/vendor 拿到 dm-4/dm-3/dm-5，唯独 `system_ext_b`、`odm_b` 不存在——同一份 super 元数据不会只缺这两个名字。
2. 设备上真正在跑的 fstab（`/vendor/etc/fstab.default`）与仓库留档的 `stock/boot/ramdisk/fstab.qcom` 都只把 system/product/vendor 标为 `logical,first_stage_mount`。
3. `stock/config/` 只有 system/product/vendor 的 fs_config、file_contexts 与 `*_size.txt`。
4. odm / system_ext 的内容在父镜像里：`stock/vendor/odm/etc/build.prop`（`ro.odm.*`）、`stock/system/system/system_ext/etc/build.prop`（`ro.system_ext.*`）、以及 `stock/system/system_ext` 这个符号链接本身。
5. 原厂 `stock/product/etc/build.prop:25` 的 `ro.product.ab_ota_partitions=system,product,vbmeta_system` 里也没有这两个名字。

**B3 措辞更正（非行为改动）：不能说「原厂从没写过 odm」。** 原厂 recovery 镜像自带的 `recovery.fstab` 第 36 行就有 `odm /odm ext4 ... logical,first_stage_mount`（证据：`stock/recovery/ramdisk/system/etc/recovery.fstab:36`，同文件 `:33-35` 是 system/product/vendor）。运行期只看得到 3 个逻辑分区，说明 odm 在 super **元数据**里没有启用，但厂商 fstab 里保留了它的定义。正确表述是：**运行期实测 super 只映射出 system/product/vendor 三个逻辑分区；原厂 recovery 镜像的 fstab 里另有 odm 定义，属未启用条目。** system_ext 则连原厂 fstab 里都没有，两件事不要混为一谈。

挂载后内容照样可达：`/system_root/system/system_ext` 与 `/vendor/odm`，无需单列分区。回归检查：本文件不得再出现以 system_ext / odm 为 src 的逻辑分区行。

#### /metadata

FBE 密钥存储，包装密钥经 keymaster 处理。**D2：本行在运行时并不生效**（见下面 /data 的 D2 结论）。留在这里是为了让静态定义与原厂 recovery 镜像的 `recovery.fstab` 保持可比对（gatekeeper / keydirectory 的语义没变）。

#### /data：D2 实测结论（本行挂载选项在运行时被覆盖）

本行的**挂载选项与 fs_mgr 标志在运行时不会生效**。TWRP 在 recovery 模式下先解析 `/etc/recovery.fstab`，再把厂商 fstab 复制成 `/etc/additional.fstab` 并**只**用它重新定义 `/data` 与 `/metadata`（`partitionmanager.cpp:365-380` 的 `parse_userdata` 分支会先 `std::erase` 掉同名条目再重建，其余行 continue 跳过）。实测证据：

* `raw/201-recovery-log.out:89-101`：`GetFstabPath` → `/vendor/etc/fstab.default` → `I:Reading /etc/additional.fstab` → 重新 `I:Processing '/metadata' / '/data'`；
* `raw3/931-additional-fstab.out`：`/etc/additional.fstab` 与 `stock/vendor/etc/fstab.default` 逐行相同；`raw/015-getprop.out`：`fstab.additional=1`；
* `/data` 的最终 `Mount_Options` = `discard,reserve_root=32768,resgid=1065,fsync_mode=nobarrier,inlinecrypt` —— 与 additional.fstab 的 /data 行逐项吻合。本文件这一行**没有** inlinecrypt，而且带 `sysfs_path`（TWRP 把它放进 `ignored_mount_items`，永远不进 Mount_Options），即最终定义来自厂商 fstab。

所以对 `/data`、`/metadata` 的任何 fstab 改动在真机上都是「只改文档」。要让本文件成为唯一来源，必须重新构建并在 `BoardConfig.mk` 打开上游开关（属 platform 范围，本次未改）：

```make
TW_SKIP_ADDITIONAL_FSTAB := true
```

开关位置：`vendor/twrp/config/BoardConfigSoong.mk:321` → `soong_config_set_bool(..., skip_additional_fstab, ...)`；`partitionmanager.cpp:432` 有 `#ifndef` 分支，开启后 `fstab.additional=0` 且日志打印 `Skipping Additional Fstab Processing`。副作用：开启后 `/data` 的 `Mount_Options` 不再带 `inlinecrypt`（本行没有它）。

本次刻意**不**把本行改成厂商 fstab 的副本：那会让静态定义与「当前真实运行路径」混在一起，改动与否都不影响运行期行为，只会掩盖 D2 本身。

#### 裸块证据的边界（避免过度断言）

内核 F2FS 驱动在同一块设备上先后探测两个 superblock，两个 magic 都不对：

```
F2FS-fs (sda9): Magic Mismatch, valid(0xf2f52010) - read(0x5243fa92)   # 1st superblock
F2FS-fs (sda9): Magic Mismatch, valid(0xf2f52010) - read(0xc7c8d9ea)   # 2nd superblock
F2FS-fs (sda9): Can't find valid F2FS filesystem in 1th/2th superblock
```

同一时刻 `/metadata`(sda6)、persist(sda2)、system/product/vendor 全部正常挂载，说明块设备层可用；只有 sda9 找不到 F2FS 签名，TWRP 因此报 `Can't probe device /dev/block/sda9` 与 `Failed to mount '/data' (Invalid argument)`。

能确证的是：`/dev/block/sda9` 上不存在内核可识别的 ext4/F2FS **明文** superblock（前 8 KB 高熵，offset 1024 = `0x5243fa92` ≠ `0xf2f52010`，offset 1080 = `0xdc58` ≠ `0x53ef`）。这一条**不能**推出「分区已损坏」，也**不能**排除 metadata encryption 之类的整体加密方案。

**t7/t9 之后的更正**：这其实是 metadata 加密分区在 dm-default-key 尚未建立时的**预期**现象——sda9 上本来就不该出现明文 F2FS superblock。完整因果链见本文档「真机复验（t7）」「（t9）」。

处理原则（保护现有数据）：**不要格式化 /data，不要 mke2fs/make_f2fs，不要 fsck -y。** 只读取证命令：

```
dd if=/dev/block/sda9 bs=4096 count=2 2>/dev/null | od -A d -t x4 | head
```

#### 已删除：/vendor/firmware_mnt、/vendor/dsp、/vendor/bt_firmware（R2 修复）

这三行原先定义在这里，但 TWRP 在解析阶段就把它们丢掉了：`Process_Fstab_Line()`（`partition.cpp:385-389`）用 `Find_Partition_By_Path(Mount_Point)` 判断「附加条目」，而该函数先过 `TWFunc::Get_Root_Path()`，**只保留路径第一段**，于是 `/vendor/firmware_mnt` → `/vendor` 命中已存在的 /vendor（super 逻辑分区），走到 `partition.cpp:411-413` 把这一行的 fs 标志 `Save_FS_Flags()` 进 /vendor 后 `return false`，条目被 delete。

影响：modem/dsp/bluetooth 三个分区并不是不可访问——`twrp.flags` 的 `/modem`、`/dsp`、`/bluetooth` 用的是同一批设备节点；被丢掉的只是这三个挂载点，外加把 vfat/ext4 的 fs 标志混进 /vendor 的 fs 标志集。

处理：移到 `twrp.flags`，改成一级挂载点并标为 `/modem` 的子分区。原厂在这三个挂载点上声明的 `ro` / `context=` 等属性不能丢，已用 `twrp.flags` 的 `fsflags=` 恢复（原厂值见 `stock/recovery/ramdisk/system/etc/recovery.fstab:40-42`）。

回归检查：本文件不得再出现 `/vendor/firmware_mnt`、`/vendor/dsp`、`/vendor/bt_firmware`。

**同一类缺陷仍未处理的一个**：`/mnt/vendor/persist` 也是三级挂载点，同样会被 `Get_Root_Path()` 截成 `/mnt` 而永远挂不上，`.twrp_settings` 因此写在 ramdisk 上、重启即丢。见本文档「真机复验（t7）」末节。

#### 其余条目

* `/persist`（`/dev/block/bootdevice/by-name/persist`）：持久化固件/属性。
* `/misc`：控制块（emmc）。
* `/logdump`：日志存储。
* 可移动存储：UFS LUN 已经占用了 sda..sd*；外置介质（UFS 卡槽与 USB-OTG）由 `twrp.flags` 处理，不写 fstab 条目。

### recovery/root/system/etc/twrp.flags

#### 这个文件是什么

TWRP 把它当 `/etc/twrp.flags` 读取（`bootable/recovery/partitionmanager.cpp` 的 `TWPartitionManager::Process_Fstab()` 里 `Reading /etc/twrp.flags` 那一段），按挂载点与 `recovery.fstab` 中的条目对应；`recovery.fstab` 里没有的挂载点会在之后以 `Processing remaining twrp.flags` 补进来。

每行格式：`<挂载点> <文件系统> <设备> [设备2=备用块设备] flags=...`

解析细则（同一段代码，务必按此写）：

* 字段按空白切分后，第 1 个字段 = 挂载点（行首不是 `/` 时布局会变，本文件一律以 `/` 开头）；
* 第 2 个字段 = 文件系统；第 3 个字段 = 主块设备；
* 第 4 个字段 = 备用块设备，**只有以 `/` 开头才会被收下**，其它内容整段忽略；
* 含 `flags=` 的那一个字段 = TWRP 标志串（以 `;` 分隔），找到它就不再往后扫。

所以这里**没有** Android fstab 那种独立的 mount 选项列；挂载选项只能通过第 5 列 `flags=` 里的 `fsflags=` 传。

**这一段扫描不认双引号。** 它先把整行所有 ≤ 32 的字节清成 `\0`，再按字段切。也就是说 `display="..."` / `backupname="..."` 里**不能有空格**——空格会提前结束 flags 字段，该字段后面的一切（`backup=1;flashimg=1;subpartitionof=...;fsflags=...`）会被静默丢弃。（对比：`TWPartition::Process_Fstab_Line()` 处理 `recovery.fstab` 时是引号感知的，只有本文件不是。）

实测教训：本文件原先有 7 条 `display` 带空格（VBMeta System / Persistent (frp) / Modem ST1 / Modem ST2 / Modem Firmware (firmware_mnt) / DSP Firmware / BT Firmware），复原解析器后可以看到它们的 flags 字段分别只剩 1~2 个 token，即 `backup`/`flashimg`/`subpartitionof` 从未生效（TWRP 备份列表里这些分区实际不可勾选）。现已全部改成单 token。

回归检查：本文件任何一个有效行都不得出现双引号内的空格；有效行字段数不得超过 5。

#### 分区名与尺寸的来源

来自原厂 9008 救砖包分区表（`stock/rawprogram4.xml`）：boot_a/b 与 recovery_a/b 都是 24576 × 4096 = 100663296；dtbo_a/b 为 6144 × 4096 = 25165824；apdp 为 64 × 4096 = 262144；logdump 为 16384 × 4096 = 67108864（已写在 `recovery.fstab`）。

#### two 个容易写错的标志

* `flashimg=1` 让 TWRP 以裸镜像方式备份与刷写该分区（`partition.cpp` 里置 `Can_Flash_Img`）。**不要写 `image=<挂载点>`**：`twrp.flags` 的解析器只认 `bootable/recovery/partition.cpp` 中 `tw_flags` 表里的标志，该表里没有 `image=`，写了只会得到 `E:Unhandled flag: 'image=...'`。裸镜像能力完全由 `flashimg=` 提供。回归检查：本文件不得出现 `image=`。
* **刻意不写 `primary`**：`primary` 会固定使用无槽位的设备节点，而本机是 A/B，真实节点是 `<name>_a` / `<name>_b`。

#### 证据分级

* **[已证实]** 名称出现在 `stock/rawprogram4.xml`，且/或出现在原厂 recovery 镜像自带的 `system/etc/recovery.fstab` 条目中。
* **[待确认]** 只在原厂 `recovery.fstab` 中出现（未在本仓库的 XML 分区表中出现）；必须在真机上先确认 `/dev/block/by-name/<名称>` 存在，否则不要用。

每个条目都会先与 `log/session-20261005-110836/derived/partition-coverage.txt` 或 `log/session-20261005-2150/raw` 里的 by-name 列表（实机 99 个 `/dev/block/by-name` 条目 + 88 个 `bootdevice/by-name` 条目）核对；节点确实不存在的条目一律删除，不留在文件里当幽灵项。现状：本文件所有条目的 by-name 节点都已在实机上确认存在（0 个幽灵项）。

#### t5 集成审查留档（历史）

静态复核通过，但**当时本文件尚未在任何真机镜像上生效**：运行中的 recovery 镜像早于本文件的全部修复（只读 adb 复验，2026-10-05）。当时的 `/ramdisk-files.sha256sum` 里 `./system/etc/twrp.flags` = `48b6c7798337c419028188187e6e5b2f778f5942f0e01428a612bffeeaac8b4a`，与设备上 `/etc/twrp.flags`（4674 B）逐字节一致，而修复后本文件已不同。结论：B1（fsflags）、C2（display 单 token）、被删的 `/msadp` 等改动都必须重新构建并刷入 recovery.img 之后才能复核。这一段只记录当时状态，不要当作当前结论。

#### 已证实分区（第一组）

`/boot`、`/recovery`、`/dtbo`、`/vbmeta`、`/vbmeta_system` 都带 `slotselect;display=...;backup=1;flashimg=1`；`/apdp` 无槽位。

#### 调制解调器固件族

`/modem` 带 `slotselect;display="Modem";backup=1;flashimg=1`；`/dsp` 与 `/bluetooth` 带 `slotselect;backup=1;subpartitionof=/modem`，即作为 `/modem` 的子分区，备份/恢复时一起处理。

#### [待确认 → 已实机核对] 一组

以下名称来自原厂 recovery 镜像自带的 fstab（`/persistent`→frp、`/ztecfg`，以及高通惯用的 modemst1/modemst2/fsg/fsc）。实机核对结果（`log/session-20261005-110836`）：frp(sda5)、ztecfg(sdf6)、fsg(sdf4)、fsc(sdf5)、modemst1(sdf2)、modemst2(sdf3) —— 六个节点的 by-name 链接都存在，可以保留。

**D1（已修）：原 `/msadp` 行已删除** —— 本机 GPT 里没有 msadp，它只是一个幽灵条目。证据：

* `ls /dev/block/by-name/msadp` → No such file or directory；
* `derived/partition-coverage.txt`：全表交叉核对后，「被引用但设备上不存在」的节点只有 msadp；
* `/proc/partitions`：sda1..9 / sdb1..2 / sdc1..2 / sdd1..3 / sde1..63 / sdf1..6 编号连续无空洞，GPT 里没有被隐藏的未命名分区；
* `recovery.log:701-712`：`/msadp | | Size: 0 B`，Flags 里没有 `IsPresent`。

它只会让分区列表持续出现一个 0 B 幽灵项（名称来源是原厂 recovery 镜像的 `system/etc/recovery.fstab` 与 `vendor_file_contexts`，那只说明原厂通用配置里有它，不说明本机有）。回归检查：本文件不得再出现 `/dev/block/by-name/msadp`。

#### 固件分区（R2 修复 + B1 修复）

原先这三条写在 `recovery.fstab` 里，挂载点分别是 `/vendor/firmware_mnt`、`/vendor/dsp`、`/vendor/bt_firmware`。它们**在运行时被 TWRP 丢弃**，从来没有进入分区表：`recovery.log:59-64` 只有 `Found an additional entry for '/vendor/firmware_mnt'` 等三行，而完整的 Partition Logs（`:486-870`）里根本找不到这三个挂载点。

机理：`TWPartition::Process_Fstab_Line()` 在 `partition.cpp:385-389` 用 `PartitionManager.Find_Partition_By_Path(Mount_Point)` 判断「附加条目」，而 `Find_Partition_By_Path`（`partitionmanager.cpp:836-847`）会先过 `TWFunc::Get_Root_Path()`（`twrp-functions.cpp:371-384`）——该函数**只保留路径的第一段**，`/vendor/firmware_mnt` 被截成 `/vendor`，于是命中已经存在的 `/vendor`（super 逻辑分区），走到 `partition.cpp:411-413`：把这一行的 fs 标志 `Save_FS_Flags()` 塞进 `/vendor` 后 `return false`，条目被 delete。**任何三段式挂载点（`/a/b/c` 形式）在这个 TWRP 上都会被同样处理。**

因此把三条改成**一级挂载点**（`/firmware_mnt` 过 `Get_Root_Path` 后仍是 `/firmware_mnt`），并像 `/dsp`、`/bluetooth` 那样标成 `/modem` 的子分区：modem 固件族在备份/恢复里一起处理，不会出现只备份一半调制解调器固件的状态；`flashimg=1` 保留单独刷写镜像的能力。设备节点取自 `/dev/block/bootdevice/by-name/`（`slotselect` 负责选 `_b`）。

**B1 修复（恢复原厂的只读 + SELinux 上下文）**：仅把这三行搬过来时，它们会以读写、无 context 的方式挂载 modem/dsp/bluetooth 裸分区，原厂在这三个挂载点上声明的 `ro` / `context=` 全部丢失。修复方式是给每条加 `fsflags=<mount 选项>`：

* `fsflags=` 是 `bootable/recovery/partition.cpp` 的 `tw_flags` 表里的标志（`{ "fsflags=", TWFLAG_FSFLAGS }`），命中后走 `TWPartition::Process_FS_Flags()`：不带 `=` 的挂载标志（`ro` / `nosuid` / `nodev` / `noatime` …）进 `mount_flags` 表，`ro` 置 `Mount_Read_Only`（`Mount()` 里合成 `MS_RDONLY`）；其余 token 原样拼进 `Mount_Options`，由 `mount(2)` 直接收到。
* mount 选项逐字取自同机、已知可用的原厂 recovery 镜像自带 `recovery.fstab`（`stock/recovery/ramdisk/system/etc/recovery.fstab:40-42`）。**recovery 模式下取 uid=0**：原厂 recovery 镜像的 `/vendor/firmware_mnt` 行就是 `uid=0,gid=1000`（设备上真正在跑的 `/vendor/etc/fstab.default:44` 写的是 `uid=1000,gid=1000`，两者对同一份数据给出不同 uid，而 recovery 里 TWRP 以 root 运行、文件管理器也以 root 读取，取 recovery 镜像的值既与原厂 recovery 行为一致、又比 uid=1000 更严）。`gid`/`dmask`/`fmask`/`context` 三份来源一致（gid=1000、227/337、`firmware_file` / `bt_firmware_file`）。
* 刻意**不**加 `nosuid`/`nodev`：原厂这三行本来就没有它们（原厂对 vfat 用 `uid`/`gid`/`dmask`/`fmask` + `context` 控权），本次只做「恢复原厂属性」。
* 加错会怎样：未知 flag 只会得到 `Unhandled flag: '...'`，选项原样透传，不会损坏分区数据；但若 SELinux 策略里没有 `firmware_file` / `bt_firmware_file` 类型，mount 会直接失败，那一行就退化成「不可挂载」（备份/刷写走 dd，不依赖挂载，能力不受影响）。

回归检查：

1. 这三行必须带 `fsflags=` 且含 `ro`；`/firmware_mnt` 与 `/bt_firmware` 必须带 `context=`；`/dsp_firmware` 必须带 `barrier=1`。
2. 本文件不得出现 `mountoptions=`（`tw_flags` 表里没有这个标志）。
3. 这三条不得把 fstab 选项写在第 4 列：解析器把第 4 列当「备用块设备」（只有以 `/` 开头才收）。
4. `recovery.fstab` 不得再出现 `/vendor/firmware_mnt`、`/vendor/dsp`、`/vendor/bt_firmware`。

#### 可移动存储（B2，**未修好**）

`/usb_otg`：TWRP 侧用 `auto` 通配符，不写设备路径。`/sdcard1`（B2，实测复现，但本轮无法在设备上验证修法）：

实测（只读 adb，会话 2026-10-05）：

* microSD 卡**已在位**：`/dev/block/mmcblk0` + `mmcblk0p1`（31166976 KiB ≈ 29.7 GiB），p1 的引导扇区含 `FAT32` + 标签 `android` → 卡本身正常，vfat 可挂。
* 但 TWRP 运行日志里 `/sdcard1` 依旧是 `I:Processing '/sdcard1'` / `I:Created '/sdcard1' folder.` / `I:Unable to mount '/sdcard1'`，即 `auto` 路径在当前镜像上**没有**解析到 `mmcblk0p1`。
* 卡所在控制器：`/sys/class/mmc_host` 只有 `mmc0`，对应 `/sys/devices/platform/soc/8804000.sdhci/mmc_host`。原厂 recovery 镜像 fstab 的第二条 `1da4000.ufshc_card/host*` 在这台机器上**不存在**，原厂自己第一条写的也是 `8804000.sdhci`。

为什么这里仍然是 `auto` 而不是照抄原厂一条 `/devices/...` 行：**`twrp.flags` 里不能写 `/devices/...`**。解析器把行首第一个字段直接当作挂载点，再按第 3 个字段找块设备；而 `Process_Fstab_Line()` 只在第一个字段以 `/` 开头时才走 fstab v2 分支——`/devices/platform/...` 会被当成**挂载点**，而不是块设备通配符。

**上一轮的推测「auto 通配符由 TWRP 自己去扫块设备」是错的**（t5 集成审查实测更正）：上游 `bootable/recovery` 里 `auto` 只作为**挂载点**有意义（`partition.cpp` 的 `Classify_By_Mount_Point():519`：`if (Mount_Point == "auto") { Mount_Point = "/auto" + n; ... }`），而本文件第 3 列是**块设备**，取值不会经过那条分支。「通配符」只有两条实际通路：

* `a)` `/devices/...` 开头的行 → `Apply_Block_Device_Attributes()` 把它存进 `Sysfs_Entry` 并置 `Wildcard_Block_Device=true`，最终由 uevent 补上块设备；但 `twrp.flags` 里行首字段会被当成挂载点，所以这条路在本文件里写不出来；
* `b)` 设备字段里含 `*` → 同一函数置 `Wildcard_Block_Device=true`，`Find_Actual_Block_Device()` → `Find_Wildcard_Block_Devices()` 对 `/dev/block` 目录按 `<前缀>*` 展开。

`auto` 两条都不满足，于是它一直是字面串。实机证据（当前镜像，只读 adb）：`/sdcard1` → Size 0 B、Flags 里没有 `IsPresent`、`Primary_Block_Device: auto`；`/usb_otg` 同上；日志 `Unable to mount '/sdcard1'` / `'/usb_otg'`。即 **B2 未被修好**：卡在位而 TWRP 拿不到设备节点，本轮不声称已修复。

修法必须等新镜像刷入后按实机日志验证，例如给本文件写一条设备字段带 `*` 的条目；但这条方案本轮**未验证**，且内核 `/sys/block/mmcblk0/removable=0`，TWRP 是否过滤 removable 也还没定性，因此本轮不改行为。

回归检查：本文件不得再出现 `1da4000.ufshc_card`，也不得把 `/devices/...` 写成第 1 列；两条 `auto` 条目在修好之前必须保留「未解决」标注。

### recovery/root/system/etc/ueventd.rc

#### 这个文件在 recovery 里由谁解析

`system/core/init/ueventd.cpp:299-334` 在 `ro.product.first_api_level < 33` 时按以下顺序解析：

```
/system/etc/ueventd.rc  ->  /vendor/ueventd.rc  ->  /odm/ueventd.rc  ->  /ueventd.${ro.hardware}.rc
```

本设备 `PRODUCT_SHIPPING_API_LEVEL := 30`（`device.mk`），所以会解析旧路径；真机日志也证实了这一点（`log/dmesg.txt` 1.236 s：先 `Parsing file /system/etc/ueventd.rc...`，再 `Parsing file /vendor/ueventd.rc...`）。

注意：本构建的 recovery ramdisk 里**没有** `/vendor/ueventd.rc`、也**没有** `/odm/ueventd.rc`（解包 `ramdisk-recovery.img` 的 776 个 cpio 条目核对过），并且原厂 vendor 分区那份 `stock/vendor/ueventd.rc`（481 行）里 0 处 `subsystem` 段。因此「其它文件会补上 subsystem 声明」是不成立的：**下面四个 subsystem 段必须由本文件提供。**

#### 为什么 subsystem 段是必需的（不是可选优化）

节点落在哪里由 `system/core/init/devices.cpp:758-795` 与 `devices.h:96-110` 决定：

| 情形 | 结果 |
|---|---|
| `block` | `/dev/block/<basename(devpath)>`（显式分支） |
| 已声明的 subsystem | `<dirname>/<basename(devpath)>`（drm → `/dev/dri/card0`） |
| `usb` | 显式分支 |
| 其它／未声明 subsystem | `/dev/<basename(devpath)>`（drm → `/dev/card0`） |

缺少 `subsystem drm` 时，DRM 节点会被建成 `/dev/card0`；而 TWRP 的显示后端只打开 `/dev/dri/cardN`（`twrpminui/graphics_drm.cpp:1224-1230`，且只尝试一次），于是真机出现（`log/recovery.txt:15-35`）：

```
cannot find/open a drm device: No such file or directory
cannot open fb0 (retrying) x20 -> (giving up)
```

同一原因，input 节点会落到 `/dev/event*`，而 TWRP 只扫 `/dev/input`（`twrpminui/events.cpp:222/232`），触摸与按键同样会失效。graphics / sound 同理。

本机内核**没有任何 fbdev 驱动**（`prebuilt/kernel` 里 msm_fb / mdss_fb / msmdrmfb / fbcon / drm_fb_helper 全部 0 命中，dmesg 里也没有 fb0/fbcon 记录），所以 `/dev/graphics/fb0` 永远不会出现：DRM 是唯一可用的显示路径。

#### 规则来源（不做任何发明）

「原厂恢复镜像 ueventd.rc」一节**逐字**取自原厂 recovery 镜像 ramdisk 的 `system/etc/ueventd.rc`。本地落盘副本：`stock/recovery/ramdisk/system/etc/ueventd.rc`，2824 字节，sha256 `828f6b7d08d38d3b09c2203b1624f6ea68bd8eb4c15607cf38f24dfff727c5da`（与 `~/workdir/twrpgen/recovery.img` 解包出的同名文件逐字节相同）。该文件在原厂机器上工作正常，因此直接沿用其全部规则，不再自创等价物；本设备树只在其后追加「本树增量」一节，每条增量都写明理由。

#### 格式（`system/core/init/ueventd_parser.cpp:36-43`）

```
/dev 行：devname mode uid gid         （4 或 5 段）
/sys  行：nodename attr mode uid gid  （5 或 6 段）
```

`/sys` 行的 nodename 必须是设备自身的 sysfs 路径（`uevent.path`），`/sys/class/...` 这类别名路径不会命中（`devices.cpp:368-384`），故本文件不写这种无效规则；背光写入由 root 完成（日志显示 SELinux `permissive=1`，写入已成功）。

#### 本树增量（3 条）

* `/dev/ion`：msm-4.19 的 ION 节点；本构建 recovery ramdisk 内没有 `/vendor/ueventd.rc`，所以原厂 vendor 那份里的 `/dev/ion` 规则在本环境不会被解析。QSEECom 通过 ION 分配共享缓冲，没有它 qseecomd 起不来。
* `/dev/qseecom`：与原厂 vendor 规则一致；写上只是让权限与原厂保持一致。
* `/dev/block/sd*` 与 `/dev/block/platform/soc/1d84000.ufshc/by-name/*`：UFS（bootdevice `1d84000.ufshc`）及其 by-name 链接。

#### 其余规则

`firmware_directories`（供内核 firmware loader 查找 keymaster trustlet）与 `uevent_socket_rcvbuf_size 16M`；四个 `subsystem` 段；以及原厂那份 `/dev/*` 与 `/sys/*` 权限规则（null/zero/full/ptmx/tty/random/urandom/hw_random/ashmem/binder/hwbinder/vndbinder、stmvl53l1_ranging、zlog/pmsg0、dri、uhid/uinput/rtc0/tty0/graphics/input/v4l-touch/snd/bus-usb/mtp_usb/usb_accessory/tun、ppp，以及 trusty_version、input enable/poll_delay、usb_composite enable、cpu scaling_max_freq/scaling_min_freq）。

### recovery/root/system/etc/init/keystore2.rc

本文件是 `bootable/recovery/etc/init/keystore2.rc` 的设备树覆盖版本。**只有触发条件变了**，service 定义与平台版本逐字节相同（含 `critical window=0` 与 recovery 的 SELinux 标签）。

#### 为什么要覆盖

平台原文件从 `on late-init` 启动 keystore2，而这个时间点与「必须从 ramdisk 拉起的 vendor keymaster HAL」完全没有关系。keystore2 在启动时会**急切地**解析 `TRUSTED_ENVIRONMENT` SecurityLevel（`system/security/keystore2/src/service.rs:65-79`），而这个解析在本次构建上是**一次性** binder 查询：

```
globals.rs:344 get_keymint_device()
  -> globals.rs:230 connect_keymint()
     -> utils.rs:665 retry_get_interface(): retry_count = 1 unless cfg!(early_vm)，
        所以重试循环一次都不跑；HAL 尚未注册时 binder::get_interface()
        立刻以 NAME_NOT_FOUND 失败。
```

因此先启动的 keystore2 会在启动阶段退出，并被每 5 秒重启一次（`system/core/init/service.h:236`）——这正是让第二次尝试越过竞态的方式。与此同时，vold 自己的屏障**只为 keystore2 存在**：`system/vold/Keystore.cpp:112-122` 以 300 × 100 ms（30 秒）轮询 `android.system.keystore2.IKeystoreService/default`，然后才去问安全级别。也就是说：**keystore2 缺失会被重试，但一个失去了 keymaster 连接的 keystore2 不会被重试。**

#### 为什么必须拆掉 fatal 重启升级

第一次退出在结构上是**必然**的，所以它绝不能升级成重启：init 在 `crash_count_` 超过 4 之后会重启到 fatal target（`system/core/init/service.cpp:366` → `:383`），而限制这个计数的窗口在 recovery 里是失效的，因为判据是

```c
if (now < time_crashed_ + fatal_crash_window_ || !boot_completed)
```

（`system/core/init/service.cpp:365`），而 recovery ramdisk **从不设置 `sys.boot_completed`**。于是计数无上限，`critical` 退化成「任何时刻累计 5 次失败就重启」。

`init.svc_debug.no_fatal.<service-name>` 正是为这种情况提供的官方开关（`system/core/init/README.md:242-243`，判定处 `service.cpp:372`）：设上它，init 会一直重启 keystore2，而不是中止到 fatal target。它从 `on early-init` 设置，因此在第一次启动之前很久就已经为真——第一次启动最早也只能由 keymaster 被 fork（即 `on fs`）触发。vold 自己的 30 秒屏障仍然限制 TWRP 的等待时长，所以这不会把「keystore2 真的起不来」变成静默挂起，只是去掉了重启。

#### 本文件的触发点与残留空档

启动点改为 `on property:init.svc.keymaster-4-0=running`。顺序在这里仍然是设备树的责任：`init.svc.keymaster-4-0 = running` 由 init 在 fork 该服务时自行设置（`system/core/init/service.cpp:173-192`，从 `:783`/`:884` 调用），而 HAL 只在 QSEE 守护进程起来并注册监听器之后才会被启动（见 `init.recovery.qcom.rc`）。

**进程状态不等于 hwbinder 注册**：这个残留空档与「能闭合它的 platform 侧等待」记录在本文档「keystore2 启动顺序」一节。回归检查：`tools/verify_decrypt_prereqs.mjs` 的 `keystore2/*` 各条。

#### service 定义要点

`class early_hal`；`user root`；`group keystore readproc log`；`task_profiles ProcessCapacityHigh`；`rlimit memlock unlimited unlimited`（默认 65536 字节对 keystore 来说太小）；`critical window=0`；`seclabel u:r:recovery:s0`。

### recovery/root/system/etc/vintf/manifest.xml

这是补上 **VINTF framework manifest**，让 `hwservicemanager` 不再自禁用、并让 keymaster / gatekeeper 能注册。完整推导、证据与版本选择理由见本文档「真机复验（t7）」的「阻断 2」，这里只留结论与要点。

#### 为什么必须有这个文件

`system/hwservicemanager/service.cpp:150-160` 会自检 `android.hidl.manager@1.2::IServiceManager/default` 是否能在 VINTF manifest 里解析出 transport；解析不到就 `property_set("hwservicemanager.disabled", "true")` 并进入 `sleep(10)` 死循环。`getTransport()`（`system/hwservicemanager/Vintf.cpp:40-71`）先查 framework manifest、再查 device manifest。真机证据：`hwservicemanager.disabled=true`、`hwservicemanager.ready` 不存在、进程停在 `__arm64_sys_nanosleep`；后果是 `init.recovery.qcom.rc` 里以 `hwservicemanager.ready=true` 为条件的闸门**永不成立**，两个 HAL 一次都没被 fork。

补「片段文件」不管用：片段目录只有在主 manifest 解析成功时才会被读（`system/libintf/VintfObject.cpp:454-461` 把 `addDirectoryManifests()` 放在 `fetchOneHalManifest(kSystemManifest)` 返回 OK 的分支里）。设备上原有的 `manifest/android.system.keystore2-service.xml` 就是这样一个一直失效的片段。**必须补主 manifest。**

同理，注册 HIDL 服务时客户端会先查自己的 descriptor 是否被声明为 hwbinder，不是就立刻失败（`system/libhidl/transport/ServiceManagement.cpp:988-1001`，`must be in VINTF manifest in order to register/get.`），而 `PRODUCT_ENFORCE_VINTF_MANIFEST` 在 `build/make/core/config.mk:785` 被无条件置为 `.KATI_READONLY` 的 true，没有开关可关。所以 keymaster 与 gatekeeper 也必须列出来。

#### 四条声明与其版本

| 包 | 版本 | 接口 / 实例 | 为什么需要 |
|---|---|---|---|
| `android.hidl.manager` | **1.2** | `IServiceManager/default` | hwservicemanager 启动自检，不写就自禁用 |
| `android.hidl.token` | 1.0 | `ITokenManager/default` | 与平台 `hwservicemanager_no_max.xml` 对齐 |
| `android.hardware.keymaster` | 4.0 | `IKeymasterDevice/default` | 注册闸门要求 |
| `android.hardware.gatekeeper` | 1.0 | `IGatekeeper/default` | 注册闸门要求 |

**必须是 1.2，写 1.0 无效。** `ServiceManager::descriptor` 取自服务实际实现的生成接口（`system/hwservicemanager/ServiceManager.h` include 的是 `android/hidl/manager/1.2/IServiceManager.h`），查询名就是 `android.hidl.manager@1.2::IServiceManager`；而「声明版本能匹配查询版本」的条件是**声明版本 ≥ 查询版本**（`system/libvintf/include/vintf/Version.h:61-67`，注释里明写 `Version(2,1).minorAtLeast(Version(2,2)) == false`）。

四条都写在 **framework** 一份里，而不是按常规拆成 framework + device 两份：常规拆法要求 device 那份落在 `/vendor/etc/vintf/`，而 `/vendor` 正是 TWRP 会挂上又卸下的地方；hwservicemanager 只在启动时读一次并缓存（`VintfObject.cpp` 的 `Get()`），framework 又先于 device 被查（`Vintf.cpp:59` 在 `:64` 之前），所以全部放 `/system`（recovery ramdisk 本体，不会被遮蔽）最稳。

在 `type="framework"` 的 manifest 里声明 vendor HAL 是安全的：只有 `HalManifest::sepolicyVersion()`（CHECK DEVICE）与 `HalManifest::vendorNdks()`（CHECK FRAMEWORK）会按类型分支，而 `getTransport()` 只遍历实例（`system/libvintf/HalManifest.cpp:285-301`），两条都到不了。

#### 落地位置与不要放错

`recovery/root/system/etc/vintf/manifest.xml` → ramdisk 里的 `/system/etc/vintf/manifest.xml`（`build/make/core/Makefile:2817-2818` 把 `recovery/root` 复制进 `$(TARGET_RECOVERY_OUT)`）。

**不要**改放到 `/system/etc/vintf/manifest/` 目录里：那里是片段目录，只有主 manifest 解析成功才会被读（理由见上）。

#### XML 注释的一条硬规则

XML 注释里不能出现**连续两个连字符**（即 dash dash）。本文件第一版的分节线就是用连字符画的，Python 的 expat 直接拒绝整个文档（`not well-formed (invalid token)`）。

**但要如实说明严重程度**：libvintf 用的是 tinyxml2（`system/libvintf/parse_xml.cpp:32`），它**容忍**这个序列，`assemble_vintf` 对带连字符注释的 manifest 同样返回 0。所以那是一个**合法性缺陷，不是设备阻断**。分节线仍改用等号，并由 `tools/verify_decrypt_prereqs.mjs` 的 `vintf/xml-comment-safety` 与 `vintf/xml-parses` 两项守住——因为文件本来就该是良构 XML，而 expat 系工具（xmllint 等）会直接拒绝。

#### 离线验证（最有力的一条）

用平台自己的解析器验：

```
$ out/host/linux-x86/bin/assemble_vintf -i recovery/root/system/etc/vintf/manifest.xml
$ echo $?
0
```

它输出的四个 `<fqname>` 正是要的东西：`android.hidl.manager@1.2::IServiceManager/default`、`android.hidl.token@1.0::ITokenManager/default`、`android.hardware.keymaster@4.0::IKeymasterDevice/default`、`android.hardware.gatekeeper@1.0::IGatekeeper/default`，全部 `hwbinder`。
