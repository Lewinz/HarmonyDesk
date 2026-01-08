use ohos_napi::{sys, NapiValue};

fn main() {
    println!("cargo:rerun-if-changed=src/lib.rs");

    // 配置 NDK 路径（需要根据实际环境调整）
    let ohos_ndk_path = std::env::var("HARMONYOS_NDK_PATH")
        .expect("请设置 HARMONYOS_NDK_PATH 环境变量");

    println!("cargo:rustc-link-search={}/native/lib/aarch64-linux-ohos", ohos_ndk_path);

    // 链接必要的系统库
    println!("cargo:rustc-link-lib=dylib=c++");
    println!("cargo:rustc-link-lib=dylib=ohos_ndk");
}
