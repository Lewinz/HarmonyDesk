/**
 * 应用入口能力
 */
import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import nativeModule from 'libharmonydesk.so';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'HarmonyDesk', 'Ability onCreate');

    // 初始化 Rust 原生模块
    try {
      nativeModule.init();
      hilog.info(0x0000, 'HarmonyDesk', 'Rust native module initialized');
    } catch (error) {
      hilog.error(0x0000, 'HarmonyDesk', `Failed to initialize native module: ${error.message}`);
    }
  }

  onDestroy(): void {
    hilog.info(0x0000, 'HarmonyDesk', 'Ability onDestroy');

    // 清理 Rust 原生模块资源
    try {
      nativeModule.cleanup();
    } catch (error) {
      hilog.error(0x0000, 'HarmonyDesk', `Failed to cleanup native module: ${error.message}`);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'HarmonyDesk', 'Ability onWindowStageCreate');

    windowStage.loadContent('pages/Index', (err, data) => {
      if (err.code) {
        hilog.error(0x0000, 'HarmonyDesk', `Failed to load content. Code: ${err.code}, message: ${err.message}`);
        return;
      }
      hilog.info(0x0000, 'HarmonyDesk', 'Succeeded in loading content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'HarmonyDesk', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'HarmonyDesk', 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'HarmonyDesk', 'Ability onBackground');
  }
}
