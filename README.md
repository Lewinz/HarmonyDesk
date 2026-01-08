# HarmonyDesk

> 基于 RustDesk 协议的鸿蒙远程桌面控制端

HarmonyDesk 是一个专为鸿蒙系统设计的远程桌面控制端应用，可以作为控制端连接到其他运行 RustDesk 的设备。

## 项目特点

- **纯控制端设计**: 仅作为控制端，不包含被控功能，体积更小、安全性更高
- **高性能**: 核心网络和视频处理使用 Rust 实现，性能优异
- **鸿蒙原生**: 使用 ArkTS + Rust Native 架构，完美适配鸿蒙系统
- **完全兼容**: 使用 RustDesk 协议，可连接任何运行 RustDesk 的设备

## 技术架构

```
┌─────────────────────────────────────┐
│       ArkTS UI Layer (上层)         │
│  - 连接管理界面                      │
│  - 视频流显示                        │
│  - 输入事件处理                      │
└──────────────┬──────────────────────┘
               │ FFI (N-API)
┌──────────────▼──────────────────────┐
│      Rust Native Module (核心层)    │
│  - RustDesk 协议实现                │
│  - 网络连接管理                      │
│  - 视频流解码                        │
│  - 输入转发                          │
└─────────────────────────────────────┘
```

## 技术栈

| 层级 | 技术 | 用途 |
|------|------|------|
| UI 层 | ArkTS | 鸿蒙原生 UI 开发 |
| 核心层 | Rust | 高性能网络和视频处理 |
| FFI | ohos-napi | ArkTS 与 Rust 交互 |
| 运行时 | Tokio | Rust 异步运行时 |
| 协议 | RustDesk Core | 远程桌面协议 |

## 项目结构

```
HarmonyDesk/
├── harmonyos/                  # 鸿蒙应用主体
│   ├── entry/
│   │   ├── src/main/
│   │   │   ├── ets/           # ArkTS 源码
│   │   │   │   ├── entryability/
│   │   │   │   │   └── EntryAbility.ets
│   │   │   │   └── pages/
│   │   │   │       └── Index.ets    # 主页面
│   │   │   ├── resources/     # 资源文件
│   │   │   └── module.json5   # 模块配置
│   │   ├── ohos/              # Rust Native 模块
│   │   │   └── rust/
│   │   │       ├── Cargo.toml
│   │   │       ├── build.rs
│   │   │       └── src/
│   │   │           ├── lib.rs         # FFI 绑定
│   │   │           ├── core.rs        # 核心管理
│   │   │           └── rustdesk/      # RustDesk 集成
│   │   └── libs/              # 编译后的 .so 文件
│   └── AppScope/
├── build.sh                    # 构建脚本
├── DEVELOPMENT.md              # 开发文档
└── README.md
```

## 快速开始

### 环境要求

- **DevEco Studio**: 4.0 或更高版本
- **HarmonyOS SDK**: API 10 或更高
- **HarmonyOS NDK**: 最新版本
- **Rust**: 1.70 或更高版本
- **ohos-rs**: 鸿蒙 Rust 绑定工具

### 安装步骤

#### 1. 安装 DevEco Studio

下载并安装 [DevEco Studio](https://developer.huawei.com/consumer/cn/deveco-studio/)

#### 2. 配置鸿蒙 NDK

```bash
# 设置 NDK 路径环境变量
export HARMONYOS_NDK_PATH=/path/to/your/ohos-ndk

# 添加到 ~/.bashrc 或 ~/.zshrc 以持久化
echo 'export HARMONYOS_NDK_PATH=/path/to/your/ohos-ndk' >> ~/.bashrc
```

#### 3. 安装 Rust 工具链

```bash
# 安装 Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# 添加鸿蒙交叉编译目标
rustup target add aarch64-linux-ohos
```

#### 4. 编译 Rust Native 模块

```bash
# 使用提供的构建脚本
chmod +x build.sh
./build.sh
```

#### 5. 在 DevEco Studio 中打开项目

1. 启动 DevEco Studio
2. 选择 `File > Open`
3. 选择 `harmonyos` 目录
4. 等待 Gradle 同步完成

#### 6. 配置签名

1. 打开 `File > Project Structure`
2. 配置 `Signing Configs`
3. 选择自动或手动签名

#### 7. 运行应用

1. 连接鸿蒙设备或启动模拟器
2. 点击 `Run` 按钮
3. 首次运行需要授予必要的权限

## 开发指南

### 添加新的 FFI 函数

1. 在 `harmonyos/entry/ohos/rust/src/lib.rs` 中添加 Rust 函数:

```rust
#[ohos_napi::js_function(1)]
fn myFunction(mut env: Env, info: CallbackInfo) -> Result<JsValue> {
    let param: String = info.get(0)?.into_inner(&env)?;
    // 你的逻辑...
    env.create_string("result").map(|v| v.into_raw())
}
```

2. 在 `exports` 函数中导出:

```rust
fn exports(exports: &mut Exports) -> Result<()> {
    exports.export("myFunction", myFunction)?;
    // ...
}
```

3. 在 ArkTS 中调用:

```typescript
import nativeModule from 'libharmonydesk.so';
const result = nativeModule.myFunction("param");
```

### 调试

#### 查看 Rust 日志

```bash
# 使用 hilog 查看日志
hilog | grep HarmonyDesk
```

#### 查看 ArkTS 日志

在 DevEco Studio 的 `HiLog` 窗口中查看。

## 常见问题

### Q: 编译时提示找不到 `aarch64-linux-ohos` 目标？

A: 运行 `rustup target add aarch64-linux-ohos` 添加目标。

### Q: 运行时提示找不到 .so 文件？

A: 确保已运行 `build.sh` 编译 Rust 模块，并且 .so 文件已复制到 `libs` 目录。

### Q: DevEco Studio 无法识别项目？

A: 确保 `harmonyos` 目录是有效的鸿蒙项目根目录，包含 `build-profile.json5` 等配置文件。

### Q: 如何连接到远程桌面？

A:
1. 在被控设备上安装并运行 RustDesk
2. 记下被控设备的 ID 和密码
3. 在 HarmonyDesk 中输入 ID 和密码
4. 点击连接

## 路线图

- [x] 基础项目架构
- [x] Rust Native 模块集成
- [ ] RustDesk 核心协议实现
- [ ] 视频流解码和显示
- [ ] 键鼠输入转发
- [ ] 多显示器支持
- [ ] 文件传输
- [ ] 地址簿/收藏夹
- [ ] 录屏功能
- [ ] 性能优化
- [ ] 发布到鸿蒙应用市场

## 贡献指南

欢迎贡献代码、报告问题或提出建议！

1. Fork 本仓库
2. 创建特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交更改 (`git commit -m 'Add some AmazingFeature'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 开启 Pull Request

## 许可证

本项目采用 AGPL-3.0 许可证，与 RustDesk 保持一致。

## 致谢

- [RustDesk](https://github.com/rustdesk/rustdesk) - 核心协议实现
- [ohos-rs](https://ohos.rs/) - 鸿蒙 Rust 绑定
- [HarmonyOS](https://www.harmonyos.com/) - 鸿蒙操作系统

## 联系方式

- 问题反馈: [GitHub Issues](https://github.com/lewinz/HarmonyDesk/issues)

---

**注意**: 本项目仅作为控制端使用，不包含被控功能。如需完整的双向控制，请使用官方 [RustDesk](https://github.com/rustdesk/rustdesk)。
