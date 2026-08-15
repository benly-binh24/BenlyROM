#!/usr/bin/env bash
# ==============================================================================
# Unica Patch Engine Script - BenlyROM Lockscreen Video Fix (Advanced)
# Path: /unica/patches/Lockscreen/customize.sh
# ==============================================================================

set -e

echo "[+] Starting Advanced Lockscreen Video Fix Patch..."

# 1. Xác định đường dẫn gốc tuyệt đối của dự án Unica
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Ưu tiên lấy WORK_SCOPE từ Unica Engine
WORK_SCOPE="${WORK_DIR:-${TARGET_DIR:-$PROJECT_ROOT/out}}"

echo "[+] Project Root : $PROJECT_ROOT"
echo "[+] Search Scope : $WORK_SCOPE"

# Kiểm tra xem thư mục out/work scope có tồn tại không
if [ ! -d "$WORK_SCOPE" ]; then
    echo "[-] Warning: Work scope directory not found: $WORK_SCOPE"
    echo "[-] Skipping property injection."
    exit 0
fi

# ------------------------------------------------------------------------------
# 2. Inject Properties vào toàn bộ các file prop có sẵn trong ROM
# ------------------------------------------------------------------------------
INJECTED_COUNT=0

while IFS= read -r -d '' PROP_FILE; do
    if [ -f "$PROP_FILE" ]; then
        if ! grep -q "BenlyROM LOCKSCREEN VIDEO FIX" "$PROP_FILE"; then
            echo "[+] Injecting wallpaper properties into: $PROP_FILE"
            cat << 'EOF' >> "$PROP_FILE"

# BenlyROM LOCKSCREEN VIDEO FIX
# Ép buộc tắt tính năng tự động fit màn hình lệch tỷ lệ của Samsung
ro.samsung.wallpaper.video_fit_screen=false
persist.sys.wallpaper.force_crop=false
persist.wallpaper.exact_matched_caching=true
# Cố định kích thước khung render của SurfaceFlinger ở độ phân giải gốc
debug.sf.fusion_pd_enabled=0
EOF
            INJECTED_COUNT=$((INJECTED_COUNT + 1))
        fi
    fi
done < <(find "$WORK_SCOPE" -type f \( -name "build.prop" -o -name "system.prop" -o -name "product.prop" -o -name "vendor.prop" \) -print0 2>/dev/null)

echo "[+] Successfully injected properties into $INJECTED_COUNT file(s)."
echo "[+] BenlyROM Lockscreen Video Fix Completed Successfully!"
