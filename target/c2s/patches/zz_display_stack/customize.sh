# SPDX-License-Identifier: GPL-3.0-or-later
SKIPUNZIP=1

if [[ "$TARGET_CODENAME" != "c2s" || "$SOURCE_PLATFORM_SDK_VERSION" -lt 36 ]]; then
    return 0
fi

# Keep r8s' stock allocator and the current Mali ABI. Correct only the tested
# P010 import mapping used by video TextureViews and GPU/client composition.
python3 "$SRC_DIR/target/r8s/fix_p010_mapping_c2s.py" \
    "$WORK_DIR/vendor/lib64/egl/libGLES_mali.so" \
    "$WORK_DIR/vendor/lib64/hw/gralloc.exynos990.so" || return 1

unset R8S_DISPLAY_BLOBS R8S_DISPLAY_DSO
