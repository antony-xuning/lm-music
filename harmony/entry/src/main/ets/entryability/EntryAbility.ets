import { AbilityConstant, Configuration, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { Logger } from '../common/Logger';
import { avSessionService } from '../service/AvSessionService';
import { backgroundPlaybackService } from '../service/BackgroundPlaybackService';
import { themeStore } from '../viewmodel/ThemeStore';

const SCOPE: string = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppContextHolder.init(this.context);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `setColorMode failed: ${err.code}`);
    }
    themeStore.setSystemDark(this.isSystemDark());
    Logger.info(SCOPE, 'onCreate');
  }

  private isSystemDark(): boolean {
    try {
      const config: Configuration = this.context.config;
      return config.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
    } catch (error) {
      return true;
    }
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    themeStore.setSystemDark(newConfig.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
  }

  onDestroy(): void {
    Logger.info(SCOPE, 'onDestroy');
    // 退出应用：结束实况窗并取消长时任务，避免残留系统通知。
    avSessionService.destroy();
    backgroundPlaybackService.stop();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        Logger.error(SCOPE, `loadContent failed: ${err.code}`);
        return;
      }
      Logger.info(SCOPE, 'content loaded');
    });

    try {
      const mainWindow: window.Window = windowStage.getMainWindowSync();
      mainWindow.setWindowBackgroundColor('#101014');
      mainWindow.setWindowLayoutFullScreen(true)
        .then(() => {
          Logger.info(SCOPE, 'full screen layout enabled');
        })
        .catch((error: BusinessError) => {
          Logger.warn(SCOPE, `setWindowLayoutFullScreen failed: ${error.code}`);
        });
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `main window unavailable: ${err.code}`);
    }
  }

  onWindowStageDestroy(): void {
    Logger.info(SCOPE, 'onWindowStageDestroy');
  }

  onForeground(): void {
    Logger.info(SCOPE, 'onForeground');
  }

  onBackground(): void {
    Logger.info(SCOPE, 'onBackground');
  }
}
