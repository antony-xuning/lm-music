/**
 * 二次确认与轻提示：使用系统弹窗（应用级沉浸光感自动生效）。
 */
import { promptAction, uiMaterial, UIContext } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { Logger } from '../common/Logger';

const SCOPE: string = 'ConfirmDialog';

export class ConfirmDialog {
  static async confirm(ui: UIContext, title: string, message: string, confirmText: string,
    danger: boolean = true): Promise<boolean> {
    try {
      const buttons: promptAction.Button[] = [];
      const cancelButton: promptAction.Button = { text: '取消', color: '#A1A1A8' };
      const okButton: promptAction.Button = { text: confirmText, color: danger ? '#FA2D48' : '#4E8CFF' };
      buttons.push(cancelButton);
      buttons.push(okButton);
      const options: promptAction.ShowDialogOptions = {
        title: title,
        message: message,
        buttons: buttons,
        systemMaterial: new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THICK
        })
      };
      const promise = ui.getPromptAction().showDialog(options) as Promise<promptAction.ShowDialogSuccessResponse>;
      const response: promptAction.ShowDialogSuccessResponse = await promise;
      return response.index === 1;
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `showDialog failed: ${err.code}`);
      return false;
    }
  }

  static toast(ui: UIContext, message: string, duration: number = 2000): void {
    try {
      const options: promptAction.ShowToastOptions = {
        message: message,
        duration: duration,
        systemMaterial: new uiMaterial.ImmersiveMaterial({
          style: uiMaterial.ImmersiveStyle.ULTRA_THIN
        })
      };
      ui.getPromptAction().showToast(options);
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `showToast failed: ${err.code}`);
    }
  }

  static actionSheet(ui: UIContext, title: string, actions: string[]): Promise<number> {
    return new Promise<number>((resolve) => {
      try {
        const buttons: promptAction.Button[] = [];
        for (let i = 0; i < actions.length; i++) {
          const button: promptAction.Button = { text: actions[i], color: '#F5F5F7' };
          buttons.push(button);
        }
        const options: promptAction.ShowDialogOptions = {
          title: title,
          buttons: buttons
        };
        const promise = ui.getPromptAction().showDialog(options) as Promise<promptAction.ShowDialogSuccessResponse>;
        promise.then((response: promptAction.ShowDialogSuccessResponse) => {
          resolve(response.index);
        }).catch((error: BusinessError) => {
          Logger.warn(SCOPE, `actionSheet failed: ${error.code}`);
          resolve(-1);
        });
      } catch (error) {
        resolve(-1);
      }
    });
  }
}
