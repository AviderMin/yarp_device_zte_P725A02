# platform-patches — 设备树之外必须打的补丁

这个仓库只包含 device tree。但 P725A02 的 metadata 解密有**一个缺陷在 platform 侧**，
不改那里就无法解密。补丁放在这里，是为了让它能被复核、能被重放，而不是消失在某个
WSL 工作树里。

应用方式（`~/workdir/TWRP-Test`）：

```bash
cd ~/workdir/TWRP-Test/system/core
git apply /path/to/0001-libdm-emit-wrappedkey_v0-for-the-legacy-options-format.patch
```

## 为什么需要它

真机日志（见主 README「真机复验（t9）」）在 `fscrypt_mount_metadata_encrypted` 最后一步失败：

```
MetadataCrypt.cpp:289 fscrypt_mount_metadata_encrypted: /data encrypt: 0 format: 0 with f2fs block device: /dev/block/sda9
KeyStorage.cpp:607 Retrieving key from keymaster
KeyStorage.cpp:337 reading blob_file: /metadata/vold/metadata_encryption/key/keymaster_key_blob
KeyStorage.cpp:366 KeyMint upgraded .../keymaster_key_blob for this operation only
dm.cpp:332 DM_TABLE_LOAD failed: Invalid argument
MetadataCrypt.cpp:195 Could not create default-key device userdata
MetadataCrypt.cpp:373 create_crypto_blk_dev failed in mountFstab
```

内核把原因说得更直接：

```
device-mapper: table: 253:6: default-key: Invalid keysize
device-mapper: ioctl: error adding target to table
```

**密钥长度不对**——送给内核的是 `exportWrappedStorageKey()` 产出的硬件包装密钥，
却没有同时告诉内核「这是包装过的」。

`libdm` 里那一句写在分支里：

```cpp
if (use_legacy_options_format_) {
    if (set_dun_) extra_argv.emplace_back("set_dun");
} else {
    ...
    if (is_hw_wrapped_) extra_argv.emplace_back("wrappedkey_v0");   // 只有非 legacy 才发
}
```

而本机**恰好落在 legacy 分支**，两条都成立：

* `EncryptionOptions::version` 由 fstab 的 `fileencryption=` 决定，本机是 `ice`（无 `:v2` 后缀），
  走 v1。`DmTargetDefaultKey::Valid()` 也间接印证：
  `if (!use_legacy_options_format_ && !set_dun_) return false;`——非 legacy 且 `set_dun` 为假会被
  libdm 自己拒绝，而我们是**内核**报的错，说明 legacy 为真。
* `use_hw_wrapped_key` 同时为真：`is_metadata_wrapped_key_supported()`
  （`system/vold/FsCrypt.cpp:381`）读的就是 `/metadata` 条目上的 `wrappedkey` 标志，
  而厂商 fstab 的 `/metadata` 行带的正是它。

两者同时成立时 `wrappedkey_v0` 被丢掉 → 内核把包装密钥当裸密钥解析 → `Invalid keysize`。

内核侧是支持的：本机内核（4.19.157-perf，msm-4.19）的字符串里有 `default-key`、
`wrappedkey_v0`、`set_dun`、`allow_discards`、`iv_large_sectors`、`sector_size`，
`drivers/md/dm-default-key.c` 也在。缺的只是 libdm 没把标记发出去。

补丁把 `wrappedkey_v0` 从 `else` 里挪出来，两种格式都发。这也应当是原厂 Android 11 的行为：
否则原厂无法在同样的「v1 fstab + wrappedkey」组合上启动。

## 注意

* 这段代码属于 `system/core`，**不在设备树里**；重新 sync TWRP 源码后需要重新应用。
* 补丁末尾的 `LOG(INFO)` 是**临时排障用的**（只打印格式标志与密钥长度，不打印密钥本身），
  解密确认可用之后应当删掉。

---

## 补丁清单

本目录只需要打 **一个** 补丁：

    0002-libdm-and-vold-metadata-decryption.patch

它做两件事：让 libdm 在 legacy 分支也发出 wrappedkey_v0；把 iv_offset 从硬编码 0 改回可设置（后者才是最终让 /data 解开的那一处）。

早先单独存在过一个 0001-...wrappedkey_v0...patch，它已被这份补丁**完整包含**——我当时用 git diff -- fs_mgr/libdm/ 生成新补丁，把旧的改动一起带进来了，两个都打会冲突。已删除。

---
## 0002 — 把 iv_offset 还回来（这是最终让 /data 解开的那一处）

**症状**：dm 设备建得起来、内核接受密钥、dm 层确实在变换数据，但明文全是噪声：

```
F2FS-fs (dm-6): Magic Mismatch, valid(0xf2f52010) - read(0x23aff3d6)
```

**怎么找到的**：设备系统能正常进桌面（`/data` 正常挂载 → 密钥和数据是好的），而且设备上**自带 `dmctl`**
（`/system/bin/dmctl`，需要 `su -c`）。用它把原厂自己那张表读出来：

```
原厂: aes-xts-plain64 - 25874496 8:9 0 3 allow_discards sector_size:4096 iv_large_sectors
我们: aes-xts-plain64 - 0        8:9 0 4 allow_discards sector_size:4096 iv_large_sectors set_dun
```

密文名一致（顺带纠正：`aes_256_xts` 的 kernel name 就是 `aes-xts-plain64`，早期把它当成 `AES-256-XTS` 是我的假设而非阅读）。
**真正的差异是第三个字段，它就是 IV offset。**

**根因**：`dm-default-key` 对某个扇区的 IV 取自 `(sector + iv_offset)`。数据是用 offset 25874496 写的，
而我们用 0 去读——**每个块的 IV 都是错的**，于是明文必然全是噪声，但表本身完全合法，所以内核一声不吭。

Android 11 的 libdm 从这个位置发的是 `DmTargetDefaultKey` 构造函数传进来的 offset；
**Android 16 把这个参数删掉了**：第 6 个参数变成了 `start_sector`，而 `GetParameterString()` 里写死 `"0"`。
全树搜索 `iv_offset` 只有那一处硬编码——**所以无论 fstab 怎么调都不可能修好**。

### 改动

```
system/core/fs_mgr/libdm/include/libdm/dm_target.h   + SetIvOffset() 与成员 iv_offset_
system/core/fs_mgr/libdm/dm_target.cpp               发 iv_offset_ 而不是写死的 0
system/vold/MetadataCrypt.cpp                        从 ro.crypto.metadata.iv_offset 取值（默认 0）
```

设备树侧（不在本目录，但配套）：`device.mk` 里 `ro.crypto.metadata.iv_offset=25874496`，
`recovery.fstab` 的 /data 行用 v2 格式（`fileencryption=ice:aes-256-cts:v2` + `metadata_encryption=aes-256-xts:wrappedkey_v0`）。

### 应用方式

这个补丁**跨两棵树**，要分两次打：

```bash
cd ~/workdir/TWRP-Test/system/core
git apply --include='fs_mgr/libdm/*' /path/to/0002-libdm-and-vold-metadata-decryption.patch
cd ~/workdir/TWRP-Test/system/vold
git apply --include='MetadataCrypt.cpp' /path/to/0002-libdm-and-vold-metadata-decryption.patch
```

### 结果（真机确认）

```
$ /tmp/dmctl table userdata
0-469200792: default-key, aes-xts-plain64 - 25874496 8:9 0 4 allow_discards ... wrappedkey_v0

$ dd if=/dev/block/mapper/userdata bs=1 skip=1024 count=8 | od -A d -t x4
0000000    f2f52010    000d0001        <- F2FS magic

$ mount | grep '/data '
/dev/block/dm-6 on /data type f2fs (rw,...)
内核: F2FS-fs (dm-6): Mounted with checkpoint version = 13d080cd
```

`25874496` 是**这台设备**的值（从它自己的 dm 表读来的）；换机器要重新读。
另外 `MetadataCrypt.cpp` 那段是**临时调试接口**，长期方案应当是让 libdm 把这个参数作为正常接口暴露出来。
