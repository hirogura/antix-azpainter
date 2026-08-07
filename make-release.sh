#!/bin/bash
#
# make-release.sh
# 現在インストールされている AzPainter（および依存 mlk ライブラリ）の
# ビルド済みファイルを、GitHub Releases にアップロードするための
# tarball にパッケージングするスクリプト。
#
# 使い方:
#   sudo ./make-release.sh
#   → dist/azpainter-linux-<arch>.tar.gz が生成されるので、
#     GitHub の Releases ページから「latest release」としてアップロードする。
#
# 注意: 実行前にあらかじめ antix-install-azpainter.sh で
#       AzPainter がインストールされていること。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ARCH="$(uname -m)"
VERSION="3.0.12"          # AzPainter バージョン（必要に応じて更新）
ASSET="azpainter-linux-${ARCH}.tar.gz"
OUT_DIR="${SCRIPT_DIR}/dist"
OUT="${OUT_DIR}/${ASSET}"

SRC="/usr/local"          # インストール先プレフィックス
PREFIX_NAME="usr/local"   # tarball 内の配置先

STAGE="$(mktemp -d)"
trap 'rm -rf "${STAGE}"' EXIT
PKG="${STAGE}/pkg"
PREFIX="${PKG}/${PREFIX_NAME}"

# --- root権限チェック（/usr/local の読み取りには不要だが安全のため） ---
if [ "$(id -u)" -ne 0 ]; then
    echo "エラー: このスクリプトは root権限で実行してください。"
    echo "例: sudo ./make-release.sh"
    exit 1
fi

# --- パッケージ対象ファイル（/usr/local 配下の相対パス） ---
FILES=(
    "bin/azpainter"
    "bin/mlk-style"
    "include/mlk"
    "lib/libmlk.a"
    "lib/libmlk.so"
    "lib/libmlk.so.1"
    "lib/libmlk.so.1.0.2"
    "lib/pkgconfig/libmlk.pc"
    "share/applications/azpainter.desktop"
    "share/applications/mlk-style.desktop"
    "share/azpainter3"
    "share/mlk"
    "share/mlk-style"
    "share/doc/azpainter"
    "share/doc/mlk"
    "share/icons/hicolor/48x48/apps/application-x-azpainter-apd.png"
    "share/icons/hicolor/48x48/apps/azpainter.png"
    "share/icons/hicolor/scalable/apps/application-x-azpainter-apd.svg"
    "share/icons/hicolor/scalable/apps/azpainter.svg"
    "share/licenses/mlk"
    "share/mime/application/x-azpainter-apd.xml"
    "share/mime/packages/azpainter.xml"
)

echo "=== AzPainter ビルド済みパッケージ作成スクリプト ==="
echo "アーキテクチャ: ${ARCH}"
echo

# --- 対象ファイルの存在確認 ---
for f in "${FILES[@]}"; do
    if [ ! -e "${SRC}/${f}" ]; then
        echo "エラー: ${SRC}/${f} がありません。"
        echo "先に antix-install-azpainter.sh でインストールしてください。"
        exit 1
    fi
done

# --- ステージングディレクトリへコピー ---
for f in "${FILES[@]}"; do
    mkdir -p "$(dirname "${PREFIX}/${f}")"
    cp -a "${SRC}/${f}" "${PREFIX}/${f}"
done

# --- インストールファイルのマニフェストを生成（絶対パス） ---
find "${PREFIX}" \( -type f -o -type l \) | \
    sed "s|^${PREFIX}|/${PREFIX_NAME}|" | sort > "${PKG}/manifest"

# --- tarball 作成 ---
mkdir -p "${OUT_DIR}"
tar -C "${PKG}" -czf "${OUT}" "${PREFIX_NAME}" manifest
chmod 644 "${OUT}"

echo
echo "=== パッケージ作成完了 ==="
echo "生成ファイル: ${OUT}"
echo "SHA256: $(sha256sum "${OUT}" | awk '{print $1}')"
echo "ファイル数: $(wc -l < "${PKG}/manifest")"
echo
echo "次に、GitHub の Releases ページ（https://github.com/hirogura/antix-azpainter/releases/new）から"
echo "この tarball を 'latest release' としてアップロードしてください。"
echo "タグは azpainter-${VERSION} が推奨です。"
