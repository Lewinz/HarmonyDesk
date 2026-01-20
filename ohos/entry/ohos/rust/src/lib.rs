/**
 * HarmonyDesk - Rust Native Module
 * 基于 RustDesk 核心的鸿蒙远程桌面控制端
 */

#[macro_use]
extern crate napi_derive_ohos;

use napi_ohos::{CallContext, Env, Error, JsObject, Result};
use napi_ohos::bindgen_prelude::{Null, Object, ToNapiValue, Unknown};
use std::sync::{Arc, Mutex};
use std::panic;

mod rustdesk;
mod core;
mod protocol;
mod video;
mod log_collector;

use core::{CoreManager, ServerConfig};
use video::{DecodedFrame, PixelFormat};
use log_collector::get_log_collector;

// 全局核心管理器
static CORE_MANAGER: Mutex<Option<Arc<CoreManager>>> = Mutex::new(None);

// 设置 Panic Hook
fn init_panic_hook() {
    let previous_hook = panic::take_hook();
    panic::set_hook(Box::move |panic_info| {
        let message = if let Some(s) = panic_info.payload().downcast_ref::<&str>() {
            format!("Panic: {}", s)
        } else if let Some(s) = panic_info.payload().downcast_ref::<String>() {
            format!("Panic: {}", s)
        } else if let Some(location) = panic_info.location() {
            format!("Panic at {}:{} - {}",
                location.file(),
                location.line(),
                panic_info.to_string())
        } else {
            format!("Panic: {}", panic_info.to_string())
        };

        // 保存到日志收集器
        let collector = get_log_collector();
        let mut guard = collector.lock().unwrap_or_else(|e| e.into_inner());
        guard.set_panic(message.clone());

        // 打印到 stderr
        eprintln!("[Rust PANIC] {}", message);

        // 调用之前的 hook
        previous_hook(panic_info);
    });
}

// 初始化模块
#[js_function(0)]
fn init(_ctx: CallContext) -> Result<u32> {
    // 初始化 panic hook
    init_panic_hook();

    log_info!("Initializing HarmonyDesk native module");

    let mut manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log_error!("Lock error: {}", e);
            Error::from_reason("Lock error")
        })?;

    if manager.is_some() {
        log_warn!("Module already initialized");
        return Ok(1);
    }

    *manager = Some(Arc::new(CoreManager::new()));

    log_info!("HarmonyDesk native module initialized successfully");
    Ok(0)
}

// 初始化调试模块
#[js_function(0)]
fn init_debug(_ctx: CallContext) -> Result<u32> {
    init_panic_hook();
    log_info!("Debug mode initialized");
    Ok(0)
}

// 获取所有日志
#[js_function(0)]
fn get_logs(ctx: CallContext) -> Result<Unknown> {
    let collector = get_log_collector();
    let guard = collector.lock().unwrap_or_else(|e| e.into_inner());
    let logs_string = guard.get_logs_string();

    ctx.env.create_string_from_std(logs_string).map(|s| s.into_unknown())
}

// 获取最后一条错误信息
#[js_function(0)]
fn get_last_error(ctx: CallContext) -> Result<Unknown> {
    let collector = get_log_collector();
    let guard = collector.lock().unwrap_or_else(|e| e.into_inner());

    if let Some(error) = guard.get_error() {
        ctx.env.create_string_from_std(error).map(|s| s.into_unknown())
    } else if let Some(panic) = guard.get_panic() {
        ctx.env.create_string_from_std(panic).map(|s| s.into_unknown())
    } else {
        Null.into_unknown(&*ctx.env)
    }
}

// 清空日志
#[js_function(0)]
fn clear_logs(_ctx: CallContext) -> Result<()> {
    let collector = get_log_collector();
    let mut guard = collector.lock().unwrap_or_else(|e| e.into_inner());
    guard.clear();
    Ok(())
}

// 设置服务器配置
#[js_function(4)]
fn set_server_config(ctx: CallContext) -> Result<u32> {
    let id_server: String = ctx.get(0)?;
    let relay_server: String = ctx.get(1)?;
    let force_relay: bool = ctx.get(2)?;
    let key: String = ctx.get(3)?;

    let manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log_error!("Lock error: {}", e);
            Error::from_reason("Failed to acquire lock")
        })?;

    let manager = manager.as_ref()
        .ok_or_else(|| {
            log_error!("Module not initialized");
            Error::from_reason("Module not initialized. Call init() first.")
        })?;

    let config = ServerConfig {
        id_server: if id_server.is_empty() { None } else { Some(id_server) },
        relay_server: if relay_server.is_empty() { None } else { Some(relay_server) },
        force_relay,
        key: if key.is_empty() { None } else { Some(key) },
    };

    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| {
            log_error!("Failed to create runtime: {}", e);
            Error::from_reason("Failed to create runtime")
        })?;

    let manager = manager.clone();
    rt.block_on(async move {
        manager.update_server_config(config).await;
    });

    log_info!("Server config set: id_server={}, relay_server={}, force_relay={}",
        if id_server.is_empty() { "none" } else { &id_server },
        if relay_server.is_empty() { "none" } else { &relay_server },
        force_relay);

    Ok(0)
}

// 连接到远程桌面
#[js_function(2)]
fn connect(ctx: CallContext) -> Result<u32> {
    let desk_id: String = ctx.get(0)?;
    let password: String = ctx.get(1)?;

    log_info!("Connecting to remote desk: {}", desk_id);

    let manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log_error!("Failed to acquire lock: {}", e);
            Error::from_reason("Failed to acquire lock")
        })?;

    let manager = manager.as_ref()
        .ok_or_else(|| {
            log_error!("Module not initialized");
            Error::from_reason("Module not initialized. Call init() first.")
        })?;

    let rt = tokio::runtime::Runtime::new()
        .map_err(|e| {
            log_error!("Failed to create runtime: {}", e);
            Error::from_reason("Failed to create runtime")
        })?;

    let manager = manager.clone();
    let desk_id_clone = desk_id.clone();
    let password_clone = password.clone();

    let result = rt.block_on(async move {
        manager.connect(&desk_id_clone, &password_clone).await
    });

    match result {
        Ok(session) => {
            log_info!("Connection successful to: {}, session: {:?}", desk_id, session);
            Ok(0)
        }
        Err(e) => {
            log_error!("Connection failed to {}: {}", desk_id, e);
            // 保存错误信息以便从 ArkTS 读取
            let collector = get_log_collector();
            let mut guard = collector.lock().unwrap_or_else(|e| e.into_inner());
            guard.set_error(format!("Connection failed: {}", e));
            Ok(1)
        }
    }
}

// 断开所有连接
#[js_function(0)]
fn disconnect(_ctx: CallContext) -> Result<()> {
    log_info!("Disconnecting all remote desks");

    let manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log_error!("Lock error: {}", e);
            Error::from_reason("Failed to acquire lock")
        })?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|e| {
                log_error!("Failed to create runtime: {}", e);
                Error::from_reason("Failed to create runtime")
            })?;

        let manager = manager.clone();
        let _ = rt.block_on(async move {
            manager.disconnect_all().await
        });

        log_info!("All connections disconnected");
    }

    Ok(())
}

// 清理资源
#[js_function(0)]
fn cleanup(_ctx: CallContext) -> Result<()> {
    log_info!("Cleaning up HarmonyDesk native module");

    let mut manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log_error!("Lock error: {}", e);
            Error::from_reason("Failed to acquire lock")
        })?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|e| {
                log_error!("Failed to create runtime: {}", e);
                Error::from_reason("Failed to create runtime")
            })?;

        let manager = manager.clone();
        let _ = rt.block_on(async move {
            manager.disconnect_all().await
        });
    }

    *manager = None;

    log_info!("Cleanup completed");
    Ok(())
}

// 获取连接状态（返回活跃连接数）
#[js_function(0)]
fn get_connection_status(_ctx: CallContext) -> Result<u32> {
    let manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log_error!("Lock error: {}", e);
            Error::from_reason("Failed to acquire lock")
        })?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|e| {
                log_error!("Failed to create runtime: {}", e);
                Error::from_reason("Failed to create runtime")
            })?;

        let manager = manager.clone();
        let connections = rt.block_on(async move {
            manager.get_connections().await
        });

        let count = connections.len() as u32;
        log_info!("Active connections: {}", count);
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

    log_debug!("Sending key event: key={}, pressed={}", key_code, pressed);

    let manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log_error!("Lock error: {}", e);
            Error::from_reason("Failed to acquire lock")
        })?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|e| {
                log_error!("Failed to create runtime: {}", e);
                Error::from_reason("Failed to create runtime")
            })?;

        let connections = rt.block_on(async move {
            manager.get_connections().await
        });

        if let Some(first_conn) = connections.first() {
            let desk_id = &first_conn.id;
            let result = rt.block_on(async move {
                manager.send_key(desk_id, key_code, pressed).await
            });

            if let Err(e) = result {
                log_error!("Failed to send key event: {}", e);
            }
        }
    }

    Ok(())
}

// 发送鼠标移动
#[js_function(2)]
fn send_mouse_move(ctx: CallContext) -> Result<()> {
    let x: i32 = ctx.get(0)?;
    let y: i32 = ctx.get(1)?;

    log_debug!("Sending mouse move: x={}, y={}", x, y);

    let manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log_error!("Lock error: {}", e);
            Error::from_reason("Failed to acquire lock")
        })?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|e| {
                log_error!("Failed to create runtime: {}", e);
                Error::from_reason("Failed to create runtime")
            })?;

        let connections = rt.block_on(async move {
            manager.get_connections().await
        });

        if let Some(first_conn) = connections.first() {
            let desk_id = &first_conn.id;
            let result = rt.block_on(async move {
                manager.send_mouse_move(desk_id, x, y).await
            });

            if let Err(e) = result {
                log_error!("Failed to send mouse move: {}", e);
            }
        }
    }

    Ok(())
}

// 发送鼠标点击
#[js_function(2)]
fn send_mouse_click(ctx: CallContext) -> Result<()> {
    let button: u32 = ctx.get(0)?;
    let pressed: bool = ctx.get(1)?;

    log_debug!("Sending mouse click: button={}, pressed={}", button, pressed);

    let manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log_error!("Lock error: {}", e);
            Error::from_reason("Failed to acquire lock")
        })?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|e| {
                log_error!("Failed to create runtime: {}", e);
                Error::from_reason("Failed to create runtime")
            })?;

        let connections = rt.block_on(async move {
            manager.get_connections().await
        });

        if let Some(first_conn) = connections.first() {
            let desk_id = &first_conn.id;
            let result = rt.block_on(async move {
                manager.send_mouse_click(desk_id, button, pressed).await
            });

            if let Err(e) = result {
                log_error!("Failed to send mouse click: {}", e);
            }
        }
    }

    Ok(())
}

// 获取视频帧数据（返回 RGBA 格式的像素数据）
#[js_function(0)]
fn get_video_frame(ctx: CallContext) -> Result<Unknown> {
    let manager = CORE_MANAGER.lock()
        .map_err(|e| {
            log_error!("Lock error: {}", e);
            Error::from_reason("Failed to acquire lock")
        })?;

    if let Some(manager) = manager.as_ref() {
        let rt = tokio::runtime::Runtime::new()
            .map_err(|e| {
                log_error!("Failed to create runtime: {}", e);
                Error::from_reason("Failed to create runtime")
            })?;

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
    exports.create_named_method("initDebug", init_debug)?;
    exports.create_named_method("setServerConfig", set_server_config)?;
    exports.create_named_method("connect", connect)?;
    exports.create_named_method("disconnect", disconnect)?;
    exports.create_named_method("cleanup", cleanup)?;
    exports.create_named_method("getConnectionStatus", get_connection_status)?;
    exports.create_named_method("sendKeyEvent", send_key_event)?;
    exports.create_named_method("sendMouseMove", send_mouse_move)?;
    exports.create_named_method("sendMouseClick", send_mouse_click)?;
    exports.create_named_method("getVideoFrame", get_video_frame)?;
    // 调试函数
    exports.create_named_method("getLogs", get_logs)?;
    exports.create_named_method("getLastError", get_last_error)?;
    exports.create_named_method("clearLogs", clear_logs)?;
    Ok(())
}
