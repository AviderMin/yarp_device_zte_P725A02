#!/usr/bin/env python3
"""Mirror vold's encryption-options parsing against the device tree's /data line.

Reimplements, from system/extras/libfscrypt/fscrypt.cpp and
system/vold/MetadataCrypt.cpp, the two decisions that pick the dm-default-key
table layout, then prints the table libdm would build.  This is a static check:
it proves what the fstab SAYS, not what the device DOES.

  ParseOptionsForApiLevel()   -> options_format_version (the branch selector)
  parse_options()             -> CryptoOptions (cipher / legacy / set_dun / wrapped)
  DmTargetDefaultKey::GetParameterString()
"""
import re, sys

Q = 29  # __ANDROID_API_Q__

CONTENTS_MODES = {"aes-256-xts", "software", "adiantum", "ice"}   # fscrypt.cpp:54-59
FILENAMES_MODES = {"aes-256-cts", "aes-256-heh", "adiantum"}      # fscrypt.cpp:61-64
SUPPORTED_CIPHERS = {"aes-256-xts": "AES-256-XTS", "adiantum": "Adiantum"}


def parse_encryption_options(first_api_level, s):
    """fscrypt.cpp ParseOptionsForApiLevel -> version, or None on failure."""
    parts = s.split(":")
    if len(parts) > 3:
        return None, "Invalid encryption options"
    if parts and parts[0] and parts[0] not in CONTENTS_MODES:
        return None, "Invalid file contents encryption mode: %s" % parts[0]
    if len(parts) > 1 and parts[1] and parts[1] not in FILENAMES_MODES:
        return None, "Invalid file names encryption mode: %s" % parts[1]
    version = 2 if first_api_level > Q else 1
    flags = []
    if len(parts) > 2 and parts[2]:
        for f in parts[2].split("+"):
            if f == "v1":
                version = 1
            elif f == "v2":
                version = 2
            elif f in ("inlinecrypt_optimized", "emmc_optimized", "wrappedkey_v0", "dusize_4k"):
                flags.append(f)
            else:
                return None, "Unknown flag: %s" % f
    return version, None


def parse_metadata_options(s):
    """MetadataCrypt.cpp parse_options -> dict, or None on failure."""
    parts = [p for p in s.split(":") if p != ""] if s else []   # base::Split, no_empty
    if len(parts) < 1 or len(parts) > 2:
        return None, "Invalid metadata encryption option: %r" % s
    if parts[0] not in SUPPORTED_CIPHERS:
        return None, "No metadata cipher named %s found" % parts[0]
    opts = {"cipher": parts[0], "use_legacy_options_format": False,
            "set_dun": True, "use_hw_wrapped_key": False}
    if len(parts) == 2:
        if parts[1] == "wrappedkey_v0":
            opts["use_hw_wrapped_key"] = True
        else:
            return None, "Invalid metadata encryption flag: %s" % parts[1]
    return opts, None


def dm_table(cipher, legacy, set_dun, wrapped, key="<KEY>"):
    argv = [cipher, key]
    if not legacy:
        argv.append("0")
    argv += ["/dev/block/sda9", "0"]
    extra = []
    if legacy:
        if set_dun:
            extra.append("set_dun")
    else:
        extra = ["allow_discards", "sector_size:4096", "iv_large_sectors"]
    if wrapped:
        extra.append("wrappedkey_v0")
    if extra:
        argv.append(str(len(extra)))
        argv += extra
    return " ".join(argv)


def data_line(path):
    for line in open(path, encoding="utf-8"):
        if not line.startswith("#") and " " in line and " /data " in line:
            return line.split()
    raise SystemExit("no /data line in " + path)


def evaluate(path, first_api_level, wrapped_key_on_metadata=True, label=""):
    f = data_line(path)
    fs_mgr_flags = ", ".join(f[4:]) if len(f) > 4 else ""
    enc = metadata = keydir = None
    checkpoint_blk = False
    for tok in re.split(r"[,\s]+", fs_mgr_flags):
        if tok.startswith("fileencryption="):
            enc = tok.split("=", 1)[1]
        elif tok.startswith("metadata_encryption="):
            metadata = tok.split("=", 1)[1]
        elif tok.startswith("keydirectory="):
            keydir = tok.split("=", 1)[1]
        elif tok == "checkpoint=block":
            checkpoint_blk = True
    print("== %s (first_api_level=%d) ==" % (label or path, first_api_level))
    print("   fileencryption      : %s" % enc)
    print("   metadata_encryption : %s" % (metadata if metadata else "(absent)"))

    version, err = parse_encryption_options(first_api_level, enc or "")
    if version is None:
        print("   -> ParseOptions FAILED (%s); version stays 0" % err)
        print("   -> 'Unknown options_format_version: 0' -> no dm device at all")
        return 1
    print("   -> options_format_version = %d" % version)

    if version == 1:
        if metadata:
            print("   -> v1 branch: 'metadata_encryption options cannot be set in legacy mode' -> FAIL")
            return 1
        opts = {"cipher": "aes-256-xts", "use_legacy_options_format": True,
                "set_dun": False, "use_hw_wrapped_key": wrapped_key_on_metadata}
        opts["set_dun"] = False   # ro.crypto.set_dun unset on this device
        if not opts["set_dun"] and checkpoint_blk:
            print("   -> v1 branch: checkpoint=block without set_dun -> FAIL")
            return 1
    else:
        opts, err = parse_metadata_options(metadata or "")
        if opts is None:
            print("   -> v2 branch: parse_options FAILED (%s) -> no dm device at all" % err)
            return 1

    print("   legacy=%s set_dun=%s hw_wrapped=%s cipher=%s" %
          (opts["use_legacy_options_format"], opts["set_dun"],
           opts["use_hw_wrapped_key"], SUPPORTED_CIPHERS[opts["cipher"]]))
    table = dm_table(SUPPORTED_CIPHERS[opts["cipher"]], opts["use_legacy_options_format"],
                     opts["set_dun"], opts["use_hw_wrapped_key"])
    print("   dm table: %s" % table)
    print("   wrappedkey_v0 present: %s" % ("wrappedkey_v0" in table))
    return 0


if __name__ == "__main__":
    fstab = sys.argv[1]
    rc = 0
    rc |= evaluate(fstab, 30, label="this device, first_api_level=30 (prop.default)")
    print()
    rc |= evaluate(fstab, 29, label="same fstab, first_api_level=29")
    sys.exit(0)
