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
TARGET="aarch64-linux-ohos"
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"
RUST_DIR="$PROJECT_ROOT/harmonyos/entry/ohos/rust"
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

# 设置编译环境变量
export AR="$OHOS_NATIVE_HOME/llvm/bin/llvm-ar"
export CC="$OHOS_NATIVE_HOME/llvm/bin/clang"
export CXX="$OHOS_NATIVE_HOME/llvm/bin/clang++"

# 创建输出目录
echo -e "\n${GREEN}[4/5] 准备输出目录...${NC}"
mkdir -p "$LIB_OUTPUT"
echo -e "  输出目录: $LIB_OUTPUT"

# 构建
echo -e "\n${GREEN}[5/5] 构建 Rust 模块...${NC}"
cd "$RUST_DIR"

echo -e "${YELLOW}运行: cargo build --target $TARGET --release${NC}"
cargo build --target "$TARGET" --release

# 检查构建结果
if [ -f "$OUTPUT_DIR/liblib.so" ]; then
    echo -e "\n${GREEN}✓ 构建成功!${NC}"

    # 复制 .so 文件到 libs 目录
    cp "$OUTPUT_DIR/liblib.so" "$LIB_OUTPUT/"
    echo -e "${GREEN}✓ 库文件已复制到: $LIB_OUTPUT/liblib.so${NC}"

    # 显示文件信息
    echo -e "\n${YELLOW}库文件信息:${NC}"
    ls -lh "$LIB_OUTPUT/liblib.so"

    echo -e "\n${GREEN}=== 构建完成 ===${NC}"
    echo -e "下一步: 在 DevEco Studio 中构建并运行应用"
else
    echo -e "\n${RED}✗ 构建失败: 未找到输出文件${NC}"
    echo -e "  期望的文件: $OUTPUT_DIR/liblib.so"
    exit 1
fi
