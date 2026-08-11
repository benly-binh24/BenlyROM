#!/usr/bin/env bash
# ==============================================================================
# Unica Patch Engine Script - ArtisanROM Lockscreen Video Fix
# Path: /unica/patches/Lockscreen/customize.sh
# ==============================================================================

echo "[+] Starting Lockscreen Video Fix Patch..."

# 1. Xác định đường dẫn gốc tuyệt đối của dự án Unica
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Đi ngược lên từ /unica/patches/Lockscreen về gốc dự án
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Ưu tiên lấy WORK_DIR/TARGET_DIR của Unica Engine, nếu không có sẽ trỏ thẳng vào thư mục out/work_dir
WORK_SCOPE="${WORK_DIR:-${TARGET_DIR:-$PROJECT_ROOT/out}}"

echo "[+] Project Root : $PROJECT_ROOT"
echo "[+] Search Scope : $WORK_SCOPE"
# ------------------------------------------------------------------------------
#  Tìm và chèn Properties vào build.prop thuộc WORK_SCOPE
# ------------------------------------------------------------------------------
PROP_FILE=$(find "$WORK_SCOPE" -type f \( -name "build.prop" -o -name "system.prop" \) 2>/dev/null | head -n 1)

if [ -n "$PROP_FILE" ] && [ -f "$PROP_FILE" ]; then
    echo "[+] Injecting wallpaper properties into: $PROP_FILE"
    
    if ! grep -q "ARTISANROM LOCKSCREEN VIDEO FIX" "$PROP_FILE"; then
        cat << 'EOF' >> "$PROP_FILE"

# BenlyROM LOCKSCREEN VIDEO FIX
ro.config.wallpaper_crop_type=0
persist.sys.wallpaper.crop=1
ro.samsung.wallpaper.video_fit_screen=false
vendor.display.enable_lockscreen_scaling=true
ro.wallpaper.rescale=false
config.disable_lockscreen_wallpaper_crop=false
EOF
        echo "  --> Properties injected successfully."
    else
        echo "  --> Properties already exist in build.prop. Skipping injection."
    fi
else
    echo "[!] Warning: Target prop file not found in $WORK_SCOPE"
fi

# ------------------------------------------------------------------------------
# Replace const/4 v1, 0x1 to 0x2 in VideoController$PlayerSession.smali
# ------------------------------------------------------------------------------
TARGET_SMALI=$(find "$WORK_SCOPE" -type f -path "*/SystemUI.apk/*/VideoController\$PlayerSession.smali" 2>/dev/null | head -n 1)

if [ -f "$TARGET_SMALI" ]; then
    echo "[+] Replacing 'const/4 v1, 0x1' in: $TARGET_SMALI"
    
    # Thực hiện thay thế nguyên chuỗi
    sed -i 's/const\/4 v1, 0x1/const\/4 v1, 0x2/g' "$TARGET_SMALI"
    
    echo "[+] Done patching Smali!"
fi

echo "[+] BenlyROM Lockscreen Video Fix Completed!"
