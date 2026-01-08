/**
 * HarmonyDesk - Rust Native Module
 * 基于 RustDesk 核心的鸿蒙远程桌面控制端
 */

use ohos_napi::*;
use std::sync::Arc;
use std::os::raw::c_void;

mod rustdesk;
mod core;
mod protocol;
mod video;

use core::CoreManager;
use video::{H264Decoder, DecodedFrame, FrameBuffer, DecoderConfig, PixelFormat};

// 全局核心管理器
static CORE_MANAGER: Mutex<Option<Arc<CoreManager>>> = Mutex::new(None);

// 初始化模块
#[ohos_napi::js_function(0)]
fn init(mut env: Env, info: CallbackInfo) -> Result<JsValue> {
    log::info!("Initializing HarmonyDesk native module");

    let mut manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log::error!("Lock error: {}", e);
            Error::from_reason("Lock error")
        })?;

    if manager.is_some() {
        log::warn!("Module already initialized");
        return env.create_uint32(1).map(|v| v.into_raw());
    }

    *manager = Some(Arc::new(CoreManager::new()));

    log::info!("HarmonyDesk native module initialized successfully");
    env.create_uint32(0).map(|v| v.into_raw())
}

// 连接到远程桌面
#[ohos_napi::js_function(2)]
fn connect(mut env: Env, info: CallbackInfo) -> Result<JsValue> {
    let desk_id: String = info.get(0)?.into_inner(&env)?;
    let password: String = info.get(1)?.into_inner(&env)?;

    log::info!("Connecting to remote desk: {}", desk_id);

    let manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log::error!("Failed to acquire lock: {}", e);
            Error::from_reason("Failed to acquire lock")
        })?;

    let manager = manager.as_ref()
        .ok_or_else(|| {
            log::error!("Module not initialized");
            Error::from_reason("Module not initialized. Call init() first.")
        })?;

    // 创建 Tokio runtime 进行异步操作
    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| {
            log::error!("Failed to create runtime: {}", e);
            Error::from_reason("Failed to create runtime")
        })?;

    let manager = manager.clone();
    let desk_id_clone = desk_id.clone();

    // 在异步上下文中执行连接
    let result = rt.block_on(async move {
        manager.connect(&desk_id_clone, &password).await
    });

    match result {
        Ok(_) => {
            log::info!("Connection successful to: {}", desk_id);
            env.create_uint32(0).map(|v| v.into_raw())
        }
        Err(e) => {
            log::error!("Connection failed: {}", e);
            env.create_uint32(1).map(|v| v.into_raw())
        }
    }
}

// 断开所有连接
#[ohos_napi::js_function(0)]
fn disconnect(mut env: Env, info: CallbackInfo) -> Result<JsValue> {
    log::info!("Disconnecting all remote desks");

    let manager = CORE_MANAGER.lock()
        .map_err(|_| Error::from_reason("Failed to acquire lock"))?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|_| Error::from_reason("Failed to create runtime"))?;

        let manager = manager.clone();
        let _ = rt.block_on(async move {
            manager.disconnect_all().await
        });

        log::info!("All connections disconnected");
    }

    env.create_undefined().map(|v| v.into_raw())
}

// 清理资源
#[ohos_napi::js_function(0)]
fn cleanup(mut env: Env, info: CallbackInfo) -> Result<JsValue> {
    log::info!("Cleaning up HarmonyDesk native module");

    let mut manager = CORE_MANAGER.lock()
        .map_err(|_| Error::from_reason("Failed to acquire lock"))?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|_| Error::from_reason("Failed to create runtime"))?;

        let manager = manager.clone();
        let _ = rt.block_on(async move {
            manager.disconnect_all().await
        });
    }

    *manager = None;

    log::info!("Cleanup completed");
    env.create_undefined().map(|v| v.into_raw())
}

// 获取连接状态（返回活跃连接数）
#[ohos_napi::js_function(0)]
fn getConnectionStatus(mut env: Env, info: CallbackInfo) -> Result<JsValue> {
    let manager = CORE_MANAGER.lock()
        .map_err(|_| Error::from_reason("Failed to acquire lock"))?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|_| Error::from_reason("Failed to create runtime"))?;

        let manager = manager.clone();
        let connections = rt.block_on(async move {
            manager.get_connections().await
        });

        let count = connections.len() as u32;
        log::info!("Active connections: {}", count);
        env.create_uint32(count).map(|v| v.into_raw())
    } else {
        env.create_uint32(0).map(|v| v.into_raw())
    }
}

// 发送键盘事件
#[ohos_napi::js_function(2)]
fn sendKeyEvent(mut env: Env, info: CallbackInfo) -> Result<JsValue> {
    let key_code: u32 = info.get(0)?.into_inner(&env)?;
    let pressed: bool = info.get(1)?.into_inner(&env)?;

    log::trace!("Sending key event: key={}, pressed={}", key_code, pressed);

    let manager = CORE_MANAGER.lock()
        .map_err(|_| Error::from_reason("Failed to acquire lock"))?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|_| Error::from_reason("Failed to create runtime"))?;

        let connections = rt.block_on(async move {
            manager.get_connections().await
        });

        if let Some(first_conn) = connections.first() {
            let desk_id = &first_conn.id;
            let _ = rt.block_on(async move {
                manager.send_key(desk_id, key_code, pressed).await
            });
        }
    }

    env.create_undefined().map(|v| v.into_raw())
}

// 发送鼠标移动
#[ohos_napi::js_function(2)]
fn sendMouseMove(mut env: Env, info: CallbackInfo) -> Result<JsValue> {
    let x: i32 = info.get(0)?.into_inner(&env)?;
    let y: i32 = info.get(1)?.into_inner(&env)?;

    log::trace!("Sending mouse move: x={}, y={}", x, y);

    let manager = CORE_MANAGER.lock()
        .map_err(|_| Error::from_reason("Failed to acquire lock"))?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|_| Error::from_reason("Failed to create runtime"))?;

        let connections = rt.block_on(async move {
            manager.get_connections().await
        });

        if let Some(first_conn) = connections.first() {
            let desk_id = &first_conn.id;
            let _ = rt.block_on(async move {
                manager.send_mouse_move(desk_id, x, y).await
            });
        }
    }

    env.create_undefined().map(|v| v.into_raw())
}

// 发送鼠标点击
#[ohos_napi::js_function(2)]
fn sendMouseClick(mut env: Env, info: CallbackInfo) -> Result<JsValue> {
    let button: u32 = info.get(0)?.into_inner(&env)?;
    let pressed: bool = info.get(1)?.into_inner(&env)?;

    log::trace!("Sending mouse click: button={}, pressed={}", button, pressed);

    let manager = CORE_MANAGER.lock()
        .map_err(|_| Error::from_reason("Failed to acquire lock"))?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|_| Error::from_reason("Failed to create runtime"))?;

        let connections = rt.block_on(async move {
            manager.get_connections().await
        });

        if let Some(first_conn) = connections.first() {
            let desk_id = &first_conn.id;
            let _ = rt.block_on(async move {
                manager.send_mouse_click(desk_id, button, pressed).await
            });
        }
    }

    env.create_undefined().map(|v| v.into_raw())
}

// 获取视频帧数据（返回 RGBA 格式的像素数据）
#[ohos_napi::js_function(0)]
fn getVideoFrame(mut env: Env, info: CallbackInfo) -> Result<JsValue> {
    let manager = CORE_MANAGER.lock()
        .map_err(|_| Error::from_reason("Failed to acquire lock"))?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|_| Error::from_reason("Failed to create runtime"))?;

        let connections = rt.block_on(async move {
            manager.get_connections().await
        });

        if let Some(first_conn) = connections.first() {
            // TODO: 从实际连接中获取最新视频帧
            // 当前返回模拟帧数据用于测试

            let frame = create_test_frame(1920, 1080);
            let data = frame.data;

            // 创建 ArrayBuffer 并复制数据
            let mut array_buffer = env.create_arraybuffer(data.len())
                .map_err(|_| Error::from_reason("Failed to create ArrayBuffer"))?;

            unsafe {
                let raw_ptr = env.get_arraybuffer_data(&mut array_buffer)
                    .map_err(|_| Error::from_reason("Failed to get ArrayBuffer pointer"))?;

                std::ptr::copy_nonoverlapping(data.as_ptr() as *const c_void, raw_ptr, data.len());
            }

            // 创建返回对象
            let mut obj = env.create_object()?;

            // 设置 width 属性
            let width_value = env.create_uint32(frame.width)?;
            obj.set_named_property("width", width_value)?;

            // 设置 height 属性
            let height_value = env.create_uint32(frame.height)?;
            obj.set_named_property("height", height_value)?;

            // 设置 data 属性
            let data_value = env.create_arraybuffer(array_buffer)?;
            obj.set_named_property("data", data_value)?;

            // 设置 timestamp 属性
            let timestamp_value = env.create_uint64(frame.timestamp)?;
            obj.set_named_property("timestamp", timestamp_value)?;

            return obj.into_raw(&mut env);
        }
    }

    // 没有活动连接，返回 null
    env.get_null().map(|v| v.into_raw())
}

// 创建测试帧（用于开发调试）
fn create_test_frame(width: u32, height: u32) -> DecodedFrame {
    let mut frame = DecodedFrame::new(width, height, PixelFormat::RGBA);

    // 生成渐变测试图案
    for y in 0..height {
        for x in 0..width {
            let idx = ((y * width + x) * 4) as usize;

            // 创建渐变
            let r = (x * 255 / width) as u8;
            let g = (y * 255 / height) as u8;
            let b = 128;

            // 添加棋盘格效果
            let block_size = 64;
            let is_dark = ((x / block_size) + (y / block_size)) % 2 == 0;

            let multiplier = if is_dark { 0.7 } else { 1.0 };

            frame.data[idx] = (r as f32 * multiplier) as u8;
            frame.data[idx + 1] = (g as f32 * multiplier) as u8;
            frame.data[idx + 2] = (b as f32 * multiplier) as u8;
            frame.data[idx + 3] = 255; // Alpha
        }
    }

    // 在中心添加时间戳区域
    let timestamp = std::time::SystemTime::now()
        .duration_since(std::time::UNIX_EPOCH)
        .unwrap()
        .as_secs();

    frame.timestamp = timestamp;

    frame
}

// 导出模块
#[ohos_napi::module_exports]
fn exports(exports: &mut Exports) -> Result<()> {
    exports.export("init", init)?;
    exports.export("connect", connect)?;
    exports.export("disconnect", disconnect)?;
    exports.export("cleanup", cleanup)?;
    exports.export("getConnectionStatus", getConnectionStatus)?;
    exports.export("sendKeyEvent", sendKeyEvent)?;
    exports.export("sendMouseMove", sendMouseMove)?;
    exports.export("sendMouseClick", sendMouseClick)?;
    exports.export("getVideoFrame", getVideoFrame)?;
    Ok(())
}
