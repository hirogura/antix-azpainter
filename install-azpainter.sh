#!/bin/bash
#
# install-azpainter.sh
# antiX (x86_64 / aarch64) 向け AzPainter インストールスクリプト
# GitHub Releases にアップロードされたビルド済みパッケージをダウンロードして
# /usr/local 配下にインストールします（ソースからのビルドは不要）。
#
# 使い方:
#   chmod +x install-azpainter.sh
#   sudo ./install-azpainter.sh
#
# ダウンロード元:
#   https://github.com/hirogura/antix-azpainter/releases/latest/download/azpainter-linux-<arch>.tar.gz

set -euo pipefail

REPO="hirogura/antix-azpainter"
ARCH="$(uname -m)"
ASSET="azpainter-linux-${ARCH}.tar.gz"
URL="https://github.com/${REPO}/releases/latest/download/${ASSET}"
MANIFEST_DIR="/var/lib/antix-azpainter"
MANIFEST="${MANIFEST_DIR}/manifest"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

# --- root権限チェック ---
if [ "$(id -u)" -ne 0 ]; then
    echo "エラー: このスクリプトは root権限で実行してください。"
    echo "例: sudo ./install-azpainter.sh"
    exit 1
fi

echo "=== AzPainter インストールスクリプト（ビルド済みパッケージ） ==="
echo "対象: ${ARCH} / ダウンロード元: ${URL}"
echo

# --- ダウンロード ---
echo "[1/4] パッケージをダウンロードしています..."
if command -v wget >/dev/null 2>&1; then
    wget -q --show-progress -O "${TMP_DIR}/${ASSET}" "${URL}"
elif command -v curl >/dev/null 2>&1; then
    curl -fL --progress-bar -o "${TMP_DIR}/${ASSET}" "${URL}"
else
    echo "エラー: wget または curl がインストールされていません。"
    exit 1
fi

# --- 展開 ---
echo "[2/4] 展開しています..."
tar -xzf "${TMP_DIR}/${ASSET}" -C "${TMP_DIR}"

# --- インストール ---
echo "[3/4] /usr/local 配下にインストールしています..."
if [ -d "${TMP_DIR}/usr/local" ]; then
    cp -a "${TMP_DIR}"/usr/local/. /usr/local/
else
    echo "エラー: パッケージ内に usr/local が見つかりません。"
    exit 1
fi

# マニフェストを保存（アンインストール用）
mkdir -p "${MANIFEST_DIR}"
if [ -f "${TMP_DIR}/manifest" ]; then
    cp "${TMP_DIR}/manifest" "${MANIFEST}"
    chmod 644 "${MANIFEST}"
fi

# --- 依存ライブラリの確認・修復 ---
echo "[4/4] 依存ライブラリを確認しています..."

# Debian系（trixie以降）は libjpeg.so.8 を提供しない（libjpeg62-turbo は libjpeg.so.62 のみ）。
# AzPainter のバイナリは libjpeg.so.8 にリンクされているため、
# libjpeg62-turbo のライブラリから互換シンボリックリンクを作成して補完する。
ensure_libjpeg8() {
    if ldconfig -p 2>/dev/null | awk '{print $1}' | grep -qx 'libjpeg.so.8'; then
        return 0
    fi
    local lib62 dir
    lib62="$(ldconfig -p 2>/dev/null | awk '$1 == "libjpeg.so.62" {print $NF; exit}')"
    [ -n "${lib62}" ] || return 0
    dir="$(dirname "${lib62}")"
    [ -d "${dir}" ] || return 0
    echo "libjpeg.so.8 が見つからないため、libjpeg62-turbo から互換リンクを作成します。"
    ln -sf "${lib62}" "${dir}/libjpeg.so.8"
    ldconfig
}

check_missing() {
    ldd /usr/local/bin/azpainter /usr/local/bin/mlk-style 2>/dev/null \
        | grep 'not found' | awk '{print $1}' | sort -u
}

ensure_libjpeg8

MISSING="$(check_missing)"
if [ -n "${MISSING}" ]; then
    echo "不足しているライブラリ: ${MISSING}"
    PKGS=""
    for lib in ${MISSING}; do
        case "${lib}" in
            libpng16.so.16)      PKGS="${PKGS} libpng16-16" ;;
            libtiff.so.6)        PKGS="${PKGS} libtiff6" ;;
            libtiff.so.5)        PKGS="${PKGS} libtiff5" ;;
            libjpeg.so.8)        PKGS="${PKGS} libjpeg62-turbo" ;;
            libwebp.so.7)        PKGS="${PKGS} libwebp7" ;;
            libwebpdemux.so.2)   PKGS="${PKGS} libwebpdemux2" ;;
            libheif.so.1)        PKGS="${PKGS} libheif1" ;;
            libX11.so.6)         PKGS="${PKGS} libx11-6" ;;
            libXext.so.6)        PKGS="${PKGS} libxext6" ;;
            libXcursor.so.1)     PKGS="${PKGS} libxcursor1" ;;
            libXi.so.6)          PKGS="${PKGS} libxi6" ;;
            libXfixes.so.3)      PKGS="${PKGS} libxfixes3" ;;
            libXrender.so.1)     PKGS="${PKGS} libxrender1" ;;
            libXrandr.so.2)      PKGS="${PKGS} libxrandr2" ;;
            libfreetype.so.6)    PKGS="${PKGS} libfreetype6" ;;
            libfontconfig.so.1)  PKGS="${PKGS} libfontconfig1" ;;
            libwayland-client.so.0) PKGS="${PKGS} libwayland-client0" ;;
            libxkbcommon.so.0)   PKGS="${PKGS} libxkbcommon0" ;;
            libEGL.so.1)         PKGS="${PKGS} libegl1" ;;
            libGL.so.1)          PKGS="${PKGS} libgl1" ;;
            libz.so.1)           PKGS="${PKGS} zlib1g" ;;
            *) echo "警告: ${lib} に対応するパッケージ名が不明です。" ;;
        esac
    done
    if [ -n "${PKGS}" ]; then
        echo "apt で不足ライブラリをインストールします..."
        apt-get update
        # shellcheck disable=SC2086
        apt-get install -y ${PKGS}
    fi

    ensure_libjpeg8
    MISSING="$(check_missing)"
    if [ -n "${MISSING}" ]; then
        echo
        echo "エラー: 以下のライブラリが不足しています: ${MISSING}"
        echo "対応パッケージが不明またはインストールに失敗しています。"
        echo "パッケージの状態を確認してください:"
        echo "  apt-file search ${MISSING}"
        exit 1
    fi
fi

ldconfig

echo
echo "=== インストール完了 ==="
if command -v azpainter >/dev/null 2>&1; then
    echo "デスクトップメニューまたは 'azpainter' コマンドで起動できます。"
    echo "アンインストールする場合は uninstall-azpainter.sh を実行してください。"
else
    echo "警告: インストールが正常に完了していない可能性があります。"
    echo "上記のログでエラーが無かったか確認してください。"
    exit 1
fi
