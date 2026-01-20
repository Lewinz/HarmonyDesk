/**
 * HarmonyDesk Native Module Bridge
 *
 * This module provides a bridge to the Rust native library (libharmonydesk.so)
 * for HarmonyOS remote desktop functionality.
 */

// Import the native module
import nativeModule from 'libharmonydesk.so';

// Native module interface
export interface HarmonyDeskNative {
  // Initialize the native module
  init(): number;

  // Initialize debug mode (set up panic hook)
  initDebug(): number;

  // Configure server settings
  setServerConfig(idServer: string, relayServer: string, forceRelay: boolean, key: string): number;

  // Connect to a remote desktop
  connect(deskId: string, password: string): number;

  // Disconnect all connections
  disconnect(): void;

  // Clean up resources
  cleanup(): void;

  // Get current connection status
  getConnectionStatus(): number;

  // Send keyboard event
  sendKeyEvent(keyCode: number, pressed: boolean): void;

  // Send mouse move event
  sendMouseMove(x: number, y: number): void;

  // Send mouse click event
  sendMouseClick(button: number, pressed: boolean): void;

  // Get latest video frame
  getVideoFrame(): VideoFrame | null;

  // ===== Debug functions =====

  // Get all Rust logs
  getLogs(): string;

  // Get last error or panic message
  getLastError(): string | null;

  // Clear all logs
  clearLogs(): void;
}

export interface VideoFrame {
  width: number;
  height: number;
  data: ArrayBuffer;
  timestamp: number;
}

// Module info interface
export interface ModuleInfo {
  usingMock: boolean;
  initialized: boolean;
}

// Wrapper class that implements HarmonyDeskNative interface
class NativeModuleWrapper implements HarmonyDeskNative {
  init(): number {
    try {
      console.info('[HarmonyDeskNative] Calling nativeModule.init()...');
      const result: number = nativeModule.init();
      console.info('[HarmonyDeskNative] nativeModule.init() returned:', result);
      return result;
    } catch (e) {
      console.error('[HarmonyDeskNative] init error:', e);
      console.error('[HarmonyDeskNative] Error type:', typeof e);
      console.error('[HarmonyDeskNative] Error string:', String(e));
      if (e instanceof Error) {
        console.error('[HarmonyDeskNative] Error message:', e.message);
        console.error('[HarmonyDeskNative] Error stack:', e.stack);
      }
      return -1;
    }
  }

  setServerConfig(idServer: string, relayServer: string, forceRelay: boolean, key: string): number {
    try {
      const result: number = nativeModule.setServerConfig(idServer, relayServer, forceRelay, key);
      return result;
    } catch (e) {
      console.error('[HarmonyDeskNative] setServerConfig error: ' + JSON.stringify(e));
      return -1;
    }
  }

  connect(deskId: string, password: string): number {
    try {
      const result: number = nativeModule.connect(deskId, password);
      return result;
    } catch (e) {
      console.error('[HarmonyDeskNative] connect error: ' + JSON.stringify(e));
      return -1;
    }
  }

  disconnect(): void {
    try {
      nativeModule.disconnect();
    } catch (e) {
      console.error('[HarmonyDeskNative] disconnect error: ' + JSON.stringify(e));
    }
  }

  cleanup(): void {
    try {
      nativeModule.cleanup();
    } catch (e) {
      console.error('[HarmonyDeskNative] cleanup error: ' + JSON.stringify(e));
    }
  }

  getConnectionStatus(): number {
    try {
      const result: number = nativeModule.getConnectionStatus();
      return result;
    } catch (e) {
      console.error('[HarmonyDeskNative] getConnectionStatus error: ' + JSON.stringify(e));
      return 0;
    }
  }

  sendKeyEvent(keyCode: number, pressed: boolean): void {
    try {
      nativeModule.sendKeyEvent(keyCode, pressed);
    } catch (e) {
      console.error('[HarmonyDeskNative] sendKeyEvent error: ' + JSON.stringify(e));
    }
  }

  sendMouseMove(x: number, y: number): void {
    try {
      nativeModule.sendMouseMove(x, y);
    } catch (e) {
      console.error('[HarmonyDeskNative] sendMouseMove error: ' + JSON.stringify(e));
    }
  }

  sendMouseClick(button: number, pressed: boolean): void {
    try {
      nativeModule.sendMouseClick(button, pressed);
    } catch (e) {
      console.error('[HarmonyDeskNative] sendMouseClick error: ' + JSON.stringify(e));
    }
  }

  getVideoFrame(): VideoFrame | null {
    try {
      const frame: ESObject | null = nativeModule.getVideoFrame();
      if (frame !== null && typeof frame === 'object') {
        return {
          width: (frame as ESObject)['width'] as number,
          height: (frame as ESObject)['height'] as number,
          data: (frame as ESObject)['data'] as ArrayBuffer,
          timestamp: (frame as ESObject)['timestamp'] as number
        };
      }
      return null;
    } catch (e) {
      console.error('[HarmonyDeskNative] getVideoFrame error: ' + JSON.stringify(e));
      return null;
    }
  }

  // ===== Debug functions =====

  getLogs(): string {
    try {
      const logs: string = nativeModule.getLogs();
      return logs;
    } catch (e) {
      console.error('[HarmonyDeskNative] getLogs error: ' + JSON.stringify(e));
      return '[HarmonyDeskNative] Failed to get logs: ' + JSON.stringify(e);
    }
  }

  getLastError(): string | null {
    try {
      const error: ESObject | null = nativeModule.getLastError();
      if (error === null || error === undefined) {
        return null;
      }
      const errorStr = String(error);
      if (errorStr === 'null' || errorStr === 'undefined') {
        return null;
      }
      return errorStr;
    } catch (e) {
      console.error('[HarmonyDeskNative] getLastError error: ' + JSON.stringify(e));
      return JSON.stringify(e);
    }
  }

  clearLogs(): void {
    try {
      nativeModule.clearLogs();
    } catch (e) {
      console.error('[HarmonyDeskNative] clearLogs error: ' + JSON.stringify(e));
    }
  }
}

// Module loading state
let nativeModuleInstance: NativeModuleWrapper | null = null;
let isInitialized = false;
let initPromise: Promise<boolean> | null = null;

/**
 * Initialize the native HarmonyDesk module
 */
export async function initHarmonyDesk(): Promise<boolean> {
  if (isInitialized && nativeModuleInstance != null) {
    return true;
  }

  if (initPromise != null) {
    return initPromise;
  }

  initPromise = new Promise<boolean>((resolve, reject) => {
    try {
      console.info('[HarmonyDeskNative] Loading native module...');
      console.info('[HarmonyDeskNative] nativeModule type:', typeof nativeModule);
      console.info('[HarmonyDeskNative] nativeModule:', nativeModule);

      // Create wrapper instance
      nativeModuleInstance = new NativeModuleWrapper();
      console.info('[HarmonyDeskNative] Wrapper instance created');

      // Initialize the native module
      const result: number = nativeModuleInstance.init();
      console.info('[HarmonyDeskNative] init() returned:', result);
      
      if (result === 0) {
        isInitialized = true;
        console.info('[HarmonyDeskNative] Native module initialized successfully');
        resolve(true);
      } else if (result === 1) {
        // Already initialized
        isInitialized = true;
        console.info('[HarmonyDeskNative] Native module already initialized');
        resolve(true);
      } else {
        console.error('[HarmonyDeskNative] Native module initialization failed with code: ' + result);
        reject(new Error('Native module initialization failed with code: ' + result));
      }
    } catch (error) {
      console.error('[HarmonyDeskNative] Failed to initialize:', error);
      console.error('[HarmonyDeskNative] Error type:', typeof error);
      if (error instanceof Error) {
        console.error('[HarmonyDeskNative] Error message:', error.message);
        console.error('[HarmonyDeskNative] Error stack:', error.stack);
      }
      reject(error);
    }
  });

  return initPromise;
}

/**
 * Get the native module instance (initializes if needed)
 */
export async function getNativeModule(): Promise<HarmonyDeskNative | null> {
  try {
    await initHarmonyDesk();
    return nativeModuleInstance;
  } catch (error) {
    console.error('[HarmonyDeskNative] Failed to get native module: ' + JSON.stringify(error));
    return null;
  }
}

/**
 * Check if the actual native module is loaded (not mock)
 */
export function isNativeModuleLoaded(): boolean {
  return isInitialized && nativeModuleInstance !== null;
}

/**
 * Get module info for debugging
 */
export function getModuleInfo(): ModuleInfo {
  const info: ModuleInfo = {
    usingMock: false, // Using real native module
    initialized: isInitialized
  };
  return info;
}

/**
 * Debug information interface
 */
export interface DebugInfo {
  initialized: boolean;
  logs: string;
  lastError: string;
  connectionStatus: number;
}

/**
 * Get debug information from the native module
 * Useful for troubleshooting Rust layer errors
 */
export async function getDebugInfo(): Promise<DebugInfo> {
  const module = await getNativeModule();

  if (module === null) {
    return {
      initialized: false,
      logs: 'Native module not initialized',
      lastError: 'Native module not initialized',
      connectionStatus: 0
    };
  }

  const logs = module.getLogs();
  const lastError = module.getLastError();

  return {
    initialized: isInitialized,
    logs: logs,
    lastError: lastError ?? 'No error',
    connectionStatus: module.getConnectionStatus()
  };
}

/**
 * Print debug info to console (useful for hdc shell hidumper)
 */
export async function printDebugInfo(): Promise<void> {
  const info = await getDebugInfo();
  console.info('========== HarmonyDesk Debug Info ==========');
  console.info('Initialized:', info.initialized);
  console.info('Connection Status:', info.connectionStatus);
  console.info('Last Error:', info.lastError);
  console.info('--- Logs ---');
  console.info(info.logs);
  console.info('=============================================');
}
