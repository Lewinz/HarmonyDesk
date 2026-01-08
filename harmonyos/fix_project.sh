#!/bin/bash

echo "=== HarmonyDesk 项目修复脚本 ==="
echo ""

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 1. 删除 .idea 目录
echo "[1/5] 清理 DevEco Studio 缓存..."
if [ -d "$PROJECT_ROOT/.idea" ]; then
    rm -rf "$PROJECT_ROOT/.idea"
    echo "  ✓ 已删除 .idea 目录"
else
    echo "  - .idea 目录不存在"
fi

# 2. 创建 local.properties
echo ""
echo "[2/5] 配置 local.properties..."
if [ -z "$HARMONYOS_SDK" ]; then
    # 尝试自动检测 SDK 路径
    POSSIBLE_SDK=(
        "$HOME/HarmonyOS/Sdk"
        "$HOME/Library/Huawei/Sdk"
    )
    for sdk_path in "${POSSIBLE_SDK[@]}"; do
        if [ -d "$sdk_path" ]; then
            HARMONYOS_SDK="$sdk_path"
            break
        fi
    done
fi

if [ -n "$HARMONYOS_SDK" ] && [ -d "$HARMONYOS_SDK" ]; then
    echo "sdk.dir=$HARMONYOS_SDK" > "$PROJECT_ROOT/local.properties"
    echo "  ✓ 已配置 SDK: $HARMONYOS_SDK"
else
    echo "  ! 未找到 HarmonyOS SDK"
    echo "  请手动编辑 local.properties 并设置 sdk.dir"
    echo "sdk.dir=$HOME/HarmonyOS/Sdk" > "$PROJECT_ROOT/local.properties"
fi

# 3. 确保 oh_modules 目录存在
echo ""
echo "[3/5] 创建必要的目录..."
mkdir -p "$PROJECT_ROOT/oh_modules"
mkdir -p "$PROJECT_ROOT/.hvigor"
echo "  ✓ 已创建 oh_modules 和 .hvigor 目录"

# 4. 设置文件权限
echo ""
echo "[4/5] 设置文件权限..."chmod -R u+w "$PROJECT_ROOT"
chmod +x "$PROJECT_ROOT/entry/ohos/rust/build.sh" 2>/dev/null || true
echo "  ✓ 已设置文件权限"

# 5. 验证项目结构
echo ""
echo "[5/5] 验证项目结构..."

REQUIRED_FILES=(
    "build-profile.json5"
    "oh-package.json5"
    "oh-package-lock.json5"
    "AppScope/app.json5"
    "entry/build-profile.json5"
    "entry/src/main/module.json5"
)

all_ok=true
for file in "${REQUIRED_FILES[@]}"; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        echo "  ✓ $file"
    else
        echo "  ✗ $file (缺失)"
        all_ok=false
    fi
done

echo ""
if [ "$all_ok" = true ]; then
    echo "✓ 项目结构完整!"
else
    echo "! 项目结构不完整，可能需要手动检查"
fi

echo ""
echo "=== 完成 ==="
echo ""
echo "下一步:"
echo "1. 打开 DevEco Studio"
echo "2. File -> Open -> 选择此目录: $PROJECT_ROOT"
echo "3. 等待项目索引完成"
echo "4. 如果提示 Sync，点击 Sync Project 按钮"
echo ""
echo "如果仍然有问题，请查看 DEVSTUDIO_SETUP.md"
