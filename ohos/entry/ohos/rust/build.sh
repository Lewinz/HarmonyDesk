#!/bin/bash

# HarmonyDesk Rust Native Module Build Script
# 用于构建 HarmonyOS 的 Rust Native 模块

set -e  # 遇到错误立即退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}=== HarmonyDesk Rust Native Module Build ===${NC}\n"

# 配置
TARGET="aarch64-unknown-linux-ohos"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../" && pwd)"
RUST_DIR="$PROJECT_ROOT/ohos/entry/ohos/rust"
TARGET_JSON="$RUST_DIR/targets/${TARGET}.json"
OUTPUT_DIR="$RUST_DIR/target/$TARGET/release"
LIB_OUTPUT="$RUST_DIR/../libs"

echo -e "${YELLOW}项目根目录: $PROJECT_ROOT${NC}"
echo -e "${YELLOW}Rust 目录: $RUST_DIR${NC}\n"

# 检查 Rust 工具链
echo -e "${GREEN}[1/5] 检查 Rust 工具链...${NC}"
if ! command -v rustc &> /dev/null; then
    echo -e "${RED}错误: 未找到 Rust 编译器${NC}"
    echo "请访问 https://rustup.rs/ 安装 Rust"
    exit 1
fi
echo -e "  Rust 版本: $(rustc --version)"

# 检查目标平台
echo -e "\n${GREEN}[2/5] 检查目标平台...${NC}"
if ! rustup target list | grep -q "$TARGET (installed)"; then
    echo -e "${YELLOW}目标平台 $TARGET 未安装，正在安装...${NC}"
    rustup target add "$TARGET"
fi
echo -e "  目标平台: $TARGET ✓"

# 检查 OHOS SDK
echo -e "\n${GREEN}[3/5] 检查 OHOS SDK...${NC}"
if [ -z "$OHOS_NATIVE_HOME" ]; then
    echo -e "${YELLOW}警告: OHOS_NATIVE_HOME 环境变量未设置${NC}"
    echo "  请设置 OHOS_NATIVE_HOME 指向 OHOS SDK 的 native 目录"
    echo "  例如: export OHOS_NATIVE_HOME=/path/to/ohos-sdk/native"
    echo ""
    echo -e "${YELLOW}尝试自动查找 OHOS SDK...${NC}"
    # 常见的 OHOS SDK 路径
    POSSIBLE_PATHS=(
        "$HOME/HarmonyOS/Sdk/ohos-sdk/native"
        "$HOME/Library/Huawei/Sdk/ohos-sdk/native"
        "$HOME/Library/OpenHarmony/Sdk/"*/native
        "/Applications/DevEco-Studio.app/Contents/sdk/ohos-sdk/native"
    )
    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -d "$path" ]; then
            export OHOS_NATIVE_HOME="$path"
            echo -e "  ${GREEN}找到 OHOS SDK: $OHOS_NATIVE_HOME${NC}"
            break
        fi
    done
    if [ -z "$OHOS_NATIVE_HOME" ]; then
        echo -e "${RED}错误: 无法找到 OHOS SDK${NC}"
        exit 1
    fi
fi
echo -e "  OHOS SDK: $OHOS_NATIVE_HOME"

# 兼容 build.rs 的环境变量
if [ -z "$HARMONYOS_NDK_PATH" ]; then
    export HARMONYOS_NDK_PATH="$OHOS_NATIVE_HOME"
fi

# 设置编译环境变量
export AR="$OHOS_NATIVE_HOME/llvm/bin/llvm-ar"
export CC="$OHOS_NATIVE_HOME/llvm/bin/clang"
export CXX="$OHOS_NATIVE_HOME/llvm/bin/clang++"
export RANLIB="$OHOS_NATIVE_HOME/llvm/bin/llvm-ranlib"
export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_OHOS_LINKER="$OHOS_NATIVE_HOME/llvm/bin/ld.lld"
export RUSTFLAGS="-C link-arg=--sysroot=$OHOS_NATIVE_HOME/sysroot"

# 创建输出目录
echo -e "\n${GREEN}[4/5] 准备输出目录...${NC}"
mkdir -p "$LIB_OUTPUT"
echo -e "  输出目录: $LIB_OUTPUT"

# 构建
echo -e "\n${GREEN}[5/5] 构建 Rust 模块...${NC}"
cd "$RUST_DIR"

if [ ! -f "$TARGET_JSON" ]; then
    echo -e "${RED}错误: 未找到 target json: $TARGET_JSON${NC}"
    echo "请先创建 targets/${TARGET}.json"
    exit 1
fi

echo -e "${YELLOW}运行: cargo +nightly build -Z build-std=std,panic_abort --target $TARGET_JSON --release${NC}"
cargo +nightly build -Z build-std=std,panic_abort --target "$TARGET_JSON" --release

# 检查构建结果
if [ -f "$OUTPUT_DIR/libharmonydesk.so" ]; then
    echo -e "\n${GREEN}✓ 构建成功!${NC}"

    # 复制 .so 文件到 libs 目录
    cp "$OUTPUT_DIR/libharmonydesk.so" "$LIB_OUTPUT/"
    echo -e "${GREEN}✓ 库文件已复制到: $LIB_OUTPUT/libharmonydesk.so${NC}"

    # 显示文件信息
    echo -e "\n${YELLOW}库文件信息:${NC}"
    ls -lh "$LIB_OUTPUT/libharmonydesk.so"

    echo -e "\n${GREEN}=== 构建完成 ===${NC}"
    echo -e "下一步: 在 DevEco Studio 中构建并运行应用"
else
    echo -e "\n${RED}✗ 构建失败: 未找到输出文件${NC}"
    echo -e "  期望的文件: $OUTPUT_DIR/libharmonydesk.so"
    exit 1
fi
