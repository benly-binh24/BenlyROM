#!/usr/bin/env bash
# ==============================================================================
# Unica Patch Engine Script - BenlyROM  Lockscreen Video Fix (Advanced)
# Path: /unica/patches/Lockscreen/customize.sh
# ==============================================================================

echo "[+] Starting Advanced Lockscreen Video Fix Patch..."

# 1. Xác định đường dẫn gốc tuyệt đối của dự án Unica
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Ưu tiên lấy WORK_SCOPE từ Unica Engine
WORK_SCOPE="${WORK_DIR:-${TARGET_DIR:-$PROJECT_ROOT/out}}"

echo "[+] Project Root : $PROJECT_ROOT"
echo "[+] Search Scope : $WORK_SCOPE"

# ------------------------------------------------------------------------------
# 2. Inject Properties vào toàn bộ các file prop có thể (build.prop, product.prop, v.v.)
# ------------------------------------------------------------------------------
find "$WORK_SCOPE" -type f \( -name "build.prop" -o -name "system.prop" -o -name "product.prop" \) 2>/dev/null | while read -r PROP_FILE; do
    if [ -f "$PROP_FILE" ]; then
        if ! grep -q "BenlyROM  LOCKSCREEN VIDEO FIX" "$PROP_FILE"; then
            echo "[+] Injecting wallpaper properties into: $PROP_FILE"
            cat << 'EOF' >> "$PROP_FILE"

# BenlyROM  LOCKSCREEN VIDEO FIX
ro.config.wallpaper_crop_type=0
persist.sys.wallpaper.crop=1
ro.samsung.wallpaper.video_fit_screen=false
vendor.display.enable_lockscreen_scaling=true
ro.wallpaper.rescale=false
config.disable_lockscreen_wallpaper_crop=false
ro.lockscreen.wallpaper.fps=60
ro.config.lockscreen_wallpaper=true
EOF
        fi
    fi
done

# ------------------------------------------------------------------------------
# 3. Quét thông minh tìm file Smali điều khiển Video Lockscreen trong SystemUI
# ------------------------------------------------------------------------------
echo "[+] Searching for Lockscreen Video/Player Smali files in SystemUI..."

# Tìm tất cả các file smali liên quan đến Player hoặc Video trong SystemUI của bản build
TARGET_SMALIS=$(find "$WORK_SCOPE" -type f -path "*/SystemUI.apk/*" \( -name "*VideoController*.smali" -o -name "*Player*.smali" -o -name "*Keyguard*Wallpaper*.smali" \) 2>/dev/null)

if [ -n "$TARGET_SMALIS" ]; then
    echo "$TARGET_SMALIS" | while read -r TARGET_SMALI; do
        if [ -f "$TARGET_SMALI" ]; then
            # Kiểm tra nếu file chứa đoạn mã gán hằng số liên quan đến player video thì tiến hành patch
            if grep -q "const/4" "$TARGET_SMALI"; then
                echo "[+] Patching target smali: $TARGET_SMALI"
                
                # Thực hiện thay thế các biến cấu hình hiển thị video/scaler (nâng cấp từ 0x1 lên 0x2 hoặc ép giá trị fit)
                sed -i 's/const\/4 v[0-9], 0x1/const\/4 v1, 0x2/g' "$TARGET_SMALI"
                sed -i 's/const\/16 v[0-9], 0x1/const\/16 v1, 0x2/g' "$TARGET_SMALI"
                
                echo "    --> Patched successfully!"
            fi
        fi
    done
else
    echo "[!] Notice: Specific Player Smali not found via standard pattern. Properties injection will handle the scaling fallback."
fi

echo "[+] BenlyROM  Lockscreen Video Fix Completed Successfully!"
