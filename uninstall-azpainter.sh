#!/bin/bash
#
# uninstall-azpainter.sh
# install-azpainter.sh でインストールした AzPainter をアンインストールします。
#
# 使い方:
#   sudo ./uninstall-azpainter.sh

set -euo pipefail

MANIFEST="/var/lib/antix-azpainter/manifest"

# --- root権限チェック ---
if [ "$(id -u)" -ne 0 ]; then
    echo "エラー: このスクリプトは root権限で実行してください。"
    echo "例: sudo ./uninstall-azpainter.sh"
    exit 1
fi

echo "=== AzPainter アンインストールスクリプト ==="

# --- マニフェストの読み込み ---
if [ -f "${MANIFEST}" ]; then
    FILES="$(cat "${MANIFEST}")"
    echo "マニフェスト ${MANIFEST} からファイルを削除します。"
elif command -v azpainter >/dev/null 2>&1 || [ -e /usr/local/bin/azpainter ]; then
    echo "マニフェストが無いため、既知のインストール先を削除します。"
    FILES="$(cat <<'EOF'
/usr/local/bin/azpainter
/usr/local/bin/mlk-style
/usr/local/include/mlk
/usr/local/lib/libmlk.a
/usr/local/lib/libmlk.so
/usr/local/lib/libmlk.so.1
/usr/local/lib/libmlk.so.1.0.2
/usr/local/lib/pkgconfig/libmlk.pc
/usr/local/share/applications/azpainter.desktop
/usr/local/share/applications/mlk-style.desktop
/usr/local/share/azpainter3
/usr/local/share/mlk
/usr/local/share/mlk-style
/usr/local/share/doc/azpainter
/usr/local/share/doc/mlk
/usr/local/share/icons/hicolor/48x48/apps/application-x-azpainter-apd.png
/usr/local/share/icons/hicolor/48x48/apps/azpainter.png
/usr/local/share/icons/hicolor/scalable/apps/application-x-azpainter-apd.svg
/usr/local/share/icons/hicolor/scalable/apps/azpainter.svg
/usr/local/share/licenses/mlk
/usr/local/share/mime/application/x-azpainter-apd.xml
/usr/local/share/mime/packages/azpainter.xml
EOF
)"
else
    echo "AzPainter はインストールされていません。"
    exit 0
fi

# --- ファイル・シンボリックリンクの削除 ---
COUNT=0
while IFS= read -r f; do
    [ -z "${f}" ] && continue
    if [ -f "${f}" ] || [ -L "${f}" ]; then
        rm -f -- "${f}" && COUNT=$((COUNT + 1))
    fi
done <<< "${FILES}"

# --- ディレクトリの削除（中身が空になった場合のみ） ---
while IFS= read -r f; do
    [ -z "${f}" ] && continue
    d="$(dirname "${f}")"
    while [ "${d}" != "/" ] && [ "${d}" != "/usr" ]; do
        rmdir "${d}" 2>/dev/null || break
        d="$(dirname "${d}")"
    done
done <<< "${FILES}"

# --- マニフェストの削除 ---
rm -rf /var/lib/antix-azpainter

ldconfig 2>/dev/null || true

echo
echo "=== アンインストール完了 ==="
echo "削除したファイル: ${COUNT} 個"
echo "設定ファイル（~/.config/azpainter3/ など）は残っています。"
echo "完全に削除する場合は手動で削除してください。"
