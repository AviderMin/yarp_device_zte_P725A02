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
