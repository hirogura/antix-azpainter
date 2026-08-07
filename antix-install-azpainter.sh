#!/bin/bash
#
# install_azpainter.sh
# antiX26 (runit init) 向け AzPainter インストールスクリプト
#
# AzPainterはDebian公式リポジトリにもdeb配布にも存在しないため、
# 作者(Azel氏)のGitLabリポジトリからソースを取得してビルドします。
# 2025/06以降のバージョンは、自作GUIライブラリ「mlk」を先にビルド・
# インストールする必要があります。
#
# 使い方:
#   chmod +x install_azpainter.sh
#   sudo ./install_azpainter.sh
#

set -e  # エラーが出たら即座に終了

BUILD_DIR="/usr/local/src/azpainter-build"
MLK_REPO="https://gitlab.com/azelpg/mlk.git"
AZPAINTER_REPO="https://gitlab.com/azelpg/azpainter.git"

# --- root権限チェック ---
if [ "$(id -u)" -ne 0 ]; then
    echo "エラー: このスクリプトは root権限で実行してください。"
    echo "例: sudo ./install_azpainter.sh"
    exit 1
fi

echo "=== antiX26 AzPainter インストールスクリプト ==="
echo

# --- 既にインストール済みか確認 ---
if command -v azpainter >/dev/null 2>&1; then
    echo "AzPainter は既にインストールされています。"
    exit 0
fi

# --- ビルドに必要なパッケージのインストール ---
echo "[1/5] ビルド依存パッケージをインストールしています..."
apt-get update
apt-get install -y \
    git gcc ninja-build pkg-config \
    libfreetype6-dev libfontconfig1-dev zlib1g-dev \
    libpng-dev libjpeg-dev libtiff-dev libwebp-dev libheif-dev \
    libx11-dev libxext-dev libxcursor-dev libxi-dev libxfixes-dev \
    libwayland-dev libxkbcommon-dev libegl1-mesa-dev

# --- 作業ディレクトリの準備 ---
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# --- mlkライブラリのビルド・インストール ---
echo "[2/5] mlkライブラリ（AzPainterが依存する自作GUIライブラリ）を取得しています..."
if [ -d "mlk" ]; then
    rm -rf mlk
fi
git clone "${MLK_REPO}"
cd mlk
echo "[3/5] mlkライブラリをビルド・インストールしています..."
./configure
cd build
ninja
ninja install
ldconfig
cd "${BUILD_DIR}"

# --- AzPainter本体のビルド・インストール ---
echo "[4/5] AzPainter本体を取得しています..."
if [ -d "azpainter" ]; then
    rm -rf azpainter
fi
git clone "${AZPAINTER_REPO}"
cd azpainter
echo "[5/5] AzPainterをビルド・インストールしています..."
./configure
cd build
ninja
ninja install

echo
echo "=== インストール完了 ==="
if command -v azpainter >/dev/null 2>&1; then
    echo "デスクトップメニューまたは 'azpainter' コマンドで起動できます。"
    echo "ビルド用ソース一式は ${BUILD_DIR} に残っています（不要なら削除してください）。"
else
    echo "警告: インストールが正常に完了していない可能性があります。"
    echo "上記のビルドログでエラーが無かったか確認してください。"
    exit 1
fi
