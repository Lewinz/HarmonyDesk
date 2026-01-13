/**
 * HarmonyDesk - Rust Native Module
 * 基于 RustDesk 核心的鸿蒙远程桌面控制端
 */

#[macro_use]
extern crate napi_derive_ohos;

use napi_ohos::{CallContext, Env, Error, JsObject, Result};
use napi_ohos::bindgen_prelude::{Null, Object, ToNapiValue, Unknown};
use std::sync::{Arc, Mutex};

mod rustdesk;
mod core;
mod protocol;
mod video;

use core::{CoreManager, ServerConfig};
use video::{DecodedFrame, PixelFormat};

// 全局核心管理器
static CORE_MANAGER: Mutex<Option<Arc<CoreManager>>> = Mutex::new(None);

// 初始化模块
#[js_function(0)]
fn init(_ctx: CallContext) -> Result<u32> {
    log::info!("Initializing HarmonyDesk native module");

    let mut manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log::error!("Lock error: {}", e);
            Error::from_reason("Lock error")
        })?;

    if manager.is_some() {
        log::warn!("Module already initialized");
        return Ok(1);
    }

    *manager = Some(Arc::new(CoreManager::new()));

    log::info!("HarmonyDesk native module initialized successfully");
    Ok(0)
}

// 设置服务器配置
#[js_function(4)]
fn set_server_config(ctx: CallContext) -> Result<u32> {
    let id_server: String = ctx.get(0)?;
    let relay_server: String = ctx.get(1)?;
    let force_relay: bool = ctx.get(2)?;
    let key: String = ctx.get(3)?;

    let manager = CORE_MANAGER.lock()
        .map_err(|_| Error::from_reason("Failed to acquire lock"))?;

    let manager = manager.as_ref()
        .ok_or_else(|| Error::from_reason("Module not initialized. Call init() first."))?;

    let config = ServerConfig {
        id_server: if id_server.is_empty() { None } else { Some(id_server) },
        relay_server: if relay_server.is_empty() { None } else { Some(relay_server) },
        force_relay,
        key: if key.is_empty() { None } else { Some(key) },
    };

    let rt = tokio::runtime::Runtime::new()
        .map_err(|_| Error::from_reason("Failed to create runtime"))?;

    let manager = manager.clone();
    rt.block_on(async move {
        manager.update_server_config(config).await;
    });

    Ok(0)
}

// 连接到远程桌面
#[js_function(2)]
fn connect(ctx: CallContext) -> Result<u32> {
    let desk_id: String = ctx.get(0)?;
    let password: String = ctx.get(1)?;

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

    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| {
            log::error!("Failed to create runtime: {}", e);
            Error::from_reason("Failed to create runtime")
        })?;

    let manager = manager.clone();
    let desk_id_clone = desk_id.clone();

    let result = rt.block_on(async move {
        manager.connect(&desk_id_clone, &password).await
    });

    match result {
        Ok(_) => {
            log::info!("Connection successful to: {}", desk_id);
            Ok(0)
        }
        Err(e) => {
            log::error!("Connection failed: {}", e);
            Ok(1)
        }
    }
}

// 断开所有连接
#[js_function(0)]
fn disconnect(_ctx: CallContext) -> Result<()> {
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

    Ok(())
}

// 清理资源
#[js_function(0)]
fn cleanup(_ctx: CallContext) -> Result<()> {
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
    Ok(())
}

// 获取连接状态（返回活跃连接数）
#[js_function(0)]
fn get_connection_status(_ctx: CallContext) -> Result<u32> {
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
        Ok(count)
    } else {
        Ok(0)
    }
}

// 发送键盘事件
#[js_function(2)]
fn send_key_event(ctx: CallContext) -> Result<()> {
    let key_code: u32 = ctx.get(0)?;
    let pressed: bool = ctx.get(1)?;

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

    Ok(())
}

// 发送鼠标移动
#[js_function(2)]
fn send_mouse_move(ctx: CallContext) -> Result<()> {
    let x: i32 = ctx.get(0)?;
    let y: i32 = ctx.get(1)?;

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

    Ok(())
}

// 发送鼠标点击
#[js_function(2)]
fn send_mouse_click(ctx: CallContext) -> Result<()> {
    let button: u32 = ctx.get(0)?;
    let pressed: bool = ctx.get(1)?;

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

    Ok(())
}

// 获取视频帧数据（返回 RGBA 格式的像素数据）
#[js_function(0)]
fn get_video_frame(ctx: CallContext) -> Result<Unknown> {
    let manager = CORE_MANAGER.lock()
        .map_err(|_| Error::from_reason("Failed to acquire lock"))?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|_| Error::from_reason("Failed to create runtime"))?;

        let connections = rt.block_on(async move {
            manager.get_connections().await
        });

        if connections.first().is_some() {
            // TODO: 从实际连接中获取最新视频帧
            // 当前返回模拟帧数据用于测试
            let frame = create_test_frame(1920, 1080);
            let data = frame.data;

            let mut array_buffer = ctx.env.create_arraybuffer(data.len())?;
            array_buffer.as_mut().copy_from_slice(&data);
            let array_buffer = array_buffer.into_raw();

            let mut obj = ctx.env.create_object()?;
            obj.set_named_property("width", frame.width)?;
            obj.set_named_property("height", frame.height)?;
            obj.set_named_property("data", array_buffer)?;
            obj.set_named_property("timestamp", frame.timestamp)?;

            return Ok(obj.into_unknown());
        }
    }

    Null.into_unknown(&*ctx.env)
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
#[module_exports]
fn init_module(mut exports: JsObject, _env: Env) -> Result<()> {
    exports.create_named_method("init", init)?;
    exports.create_named_method("setServerConfig", set_server_config)?;
    exports.create_named_method("connect", connect)?;
    exports.create_named_method("disconnect", disconnect)?;
    exports.create_named_method("cleanup", cleanup)?;
    exports.create_named_method("getConnectionStatus", get_connection_status)?;
    exports.create_named_method("sendKeyEvent", send_key_event)?;
    exports.create_named_method("sendMouseMove", send_mouse_move)?;
    exports.create_named_method("sendMouseClick", send_mouse_click)?;
    exports.create_named_method("getVideoFrame", get_video_frame)?;
    Ok(())
}
