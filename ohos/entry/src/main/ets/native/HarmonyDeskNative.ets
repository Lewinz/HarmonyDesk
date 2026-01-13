/**
 * HarmonyDesk Native Module Bridge
 *
 * This module provides a bridge to the Rust native library (libharmonydesk.so)
 * for HarmonyOS remote desktop functionality.
 */

import nativeModule from '@ohos.module.harmonydesk_native';

// Native module interface
export interface HarmonyDeskNative {
  // Initialize the native module
  init(): number;

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

// Module loading state
let nativeModuleInstance: HarmonyDeskNative | null = null;
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

      // Try to load the native module
      if (nativeModule && typeof nativeModule.init === 'function') {
        console.info('[HarmonyDeskNative] Native module found, initializing...');

        // Create a wrapper that implements HarmonyDeskNative interface
        nativeModuleInstance = {
          init: (): number => {
            return nativeModule.init() || 0;
          },
          setServerConfig: (idServer: string, relayServer: string, forceRelay: boolean, key: string): number => {
            return nativeModule.setServerConfig(idServer, relayServer, forceRelay, key) || 0;
          },
          connect: (deskId: string, password: string): number => {
            return nativeModule.connect(deskId, password) || 0;
          },
          disconnect: (): void => {
            nativeModule.disconnect();
          },
          cleanup: (): void => {
            nativeModule.cleanup();
          },
          getConnectionStatus: (): number => {
            return nativeModule.getConnectionStatus() || 0;
          },
          sendKeyEvent: (keyCode: number, pressed: boolean): void => {
            nativeModule.sendKeyEvent(keyCode, pressed);
          },
          sendMouseMove: (x: number, y: number): void => {
            nativeModule.sendMouseMove(x, y);
          },
          sendMouseClick: (button: number, pressed: boolean): void => {
            nativeModule.sendMouseClick(button, pressed);
          },
          getVideoFrame: (): VideoFrame | null => {
            const frame = nativeModule.getVideoFrame();
            if (frame) {
              return {
                width: frame.width,
                height: frame.height,
                data: frame.data,
                timestamp: frame.timestamp
              };
            }
            return null;
          }
        };

        // Initialize the native module
        const result = nativeModuleInstance.init();
        if (result === 0) {
          isInitialized = true;
          console.info('[HarmonyDeskNative] Native module initialized successfully');
          resolve(true);
        } else {
          console.error('[HarmonyDeskNative] Native module initialization failed: ' + result);
          reject(new Error('Native module initialization failed'));
        }
      } else {
        console.error('[HarmonyDeskNative] Native module not found');
        reject(new Error('Native module not found'));
      }
    } catch (error) {
      console.error('[HarmonyDeskNative] Failed to load native module: ' + error);
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
    console.error('[HarmonyDeskNative] Failed to get native module: ' + error);
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
    usingMock: false,
    initialized: isInitialized
  };
  return info;
}
