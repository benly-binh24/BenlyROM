#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""Align the tested ARM64 Mali P010 import with the Exynos 990 stock gralloc
(Galaxy S20 FE r8s -> Galaxy Note 20 Ultra c2s/c1s port).

Gralloc uses internal format 0x204 for semiplanar P010. This Mali build maps
it to packed Y210 (DRM fourcc Y210), causing doubled/pink video during GPU
composition. Select its existing P010 table entry instead. No codec, HDR,
overlay, blur, GPU clock or other pixel-format paths are disabled.
"""
import hashlib
import os
from pathlib import Path
import stat
import struct
import sys

ORIGINAL_SHA256 = "9ce9377713c7e25290685ab025db5a898eb29db0d9677ce1ca476d32161d682f"
PATCHED_SHA256 = "8a9ff1d037f62bd68d51d5c311b0a13975ee978be793e35a86c01a65f0d2cd2a"
# Reviewed gralloc.exynos990.so builds (internal format 0x204 = semiplanar P010).
# The Mali library is byte-identical on r8s and c2s; add the c2s gralloc hash
# here once it has been reviewed.
GRALLOC_SHA256S = {
    "1dd0cd1c9d20b224f63f780bfc647f828203e3fb2b5654172aa6d86aed9b70e7",  # r8s
}
INSTRUCTION_OFFSET = 0x81D604


def sha256(data):
    return hashlib.sha256(data).hexdigest()


def patch(gpu, gralloc):
    gpu, gralloc = Path(gpu), Path(gralloc)
    # Guard both ends of the interface; an unknown replacement GPU/gralloc
    # must receive an explicit review, rather than the same numeric offset.
    gralloc_digest = sha256(gralloc.read_bytes())
    if gralloc_digest not in GRALLOC_SHA256S:
        raise ValueError("gralloc %s is not a reviewed P010 stack; send this hash for review" % gralloc_digest)
    original = gpu.read_bytes()
    digest = sha256(original)
    if digest == PATCHED_SHA256:
        print("Exynos990 Mali P010 mapping already corrected")
        return False
    if digest != ORIGINAL_SHA256:
        raise ValueError("Unknown Exynos990 Mali library; refusing an unverified binary patch")
    if original[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", original, 18)[0] != 183:
        raise ValueError("P010 compatibility fix requires the verified AArch64 ELF")
    data = bytearray(original)
    # android_config_interface::get_buffer_fourcc_format, internal 0x204:
    # mov w10,#16 (Y210 table entry) -> mov w10,#17 (P010 table entry).
    if struct.unpack_from("<I", data, INSTRUCTION_OFFSET)[0] != 0x5280020A:
        raise ValueError("Mali P010 instruction does not match the reviewed function")
    struct.pack_into("<I", data, INSTRUCTION_OFFSET, 0x5280022A)
    if sha256(data) != PATCHED_SHA256:
        raise ValueError("Corrected Mali library failed its complete-file integrity check")
    temporary = gpu.with_name(gpu.name + ".p010-tmp")
    try:
        temporary.write_bytes(data)
        temporary.chmod(stat.S_IMODE(gpu.stat().st_mode))
        os.replace(temporary, gpu)
    finally:
        if temporary.exists():
            temporary.unlink()
    print("Corrected Exynos990 Mali internal P010 import; all other instructions retained")
    return True


if __name__ == "__main__":
    try:
        if len(sys.argv) != 3:
            raise ValueError("Usage: fix_p010_mapping.py libGLES_mali.so gralloc.exynos990.so")
        patch(sys.argv[1], sys.argv[2])
    except (OSError, ValueError) as error:
        sys.exit(str(error))
