/**
 * 二次确认与轻提示：系统弹窗 + 自定义操作菜单。
 * 操作菜单收窄为 88% 屏宽，并沿用悬浮玻璃条同款折射配方实现沉浸光感。
 */
import { promptAction, uiMaterial, UIContext, ComponentContent } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';
import { ImmersiveGlass } from '../common/ImmersiveGlass';
import { Logger } from '../common/Logger';
import { themeStore } from '../viewmodel/ThemeStore';

const SCOPE: string = 'ConfirmDialog';

/** 自定义底部操作菜单的构建参数。 */
class ActionMenuParams {
  actions: string[];
  textColor: string;
  dividerColor: string;
  fontSize: number;
  onSelect: (index: number) => void;

  constructor(actions: string[], textColor: string, dividerColor: string, fontSize: number,
    onSelect: (index: number) => void) {
    this.actions = actions;
    this.textColor = textColor;
    this.dividerColor = dividerColor;
    this.fontSize = fontSize;
    this.onSelect = onSelect;
  }

  getPanelHeight(): number {
    return this.actions.length * 52 + 20;
  }
}

@Builder
function ActionMenuPanel(params: ActionMenuParams) {
  Stack({ alignContent: Alignment.TopStart }) {
    // 层 1：垂直折射渐变。
    Column()
      .width('100%')
      .height('100%')
      .linearGradient({ angle: 180, colors: ImmersiveGlass.barTint() })

    // 层 2：顶部扫光。
    Row()
      .width('58%')
      .height(1.5)
      .borderRadius(1)
      .linearGradient({ angle: 90, colors: ImmersiveGlass.barSheen() })
      .margin({ left: 20, top: 1 })

    // 层 3：动作列表。
    Column() {
      ForEach(params.actions, (action: string, index: number) => {
        Column() {
          if (index > 0) {
            Divider()
              .color(params.dividerColor)
              .strokeWidth(1)
              .margin({ left: 28, right: 28 })
          }
          Text(action)
            .fontSize(params.fontSize)
            .fontWeight(FontWeight.Medium)
            .fontColor(params.textColor)
            .height(52)
            .width('100%')
            .textAlign(TextAlign.Center)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .onClick(() => {
              params.onSelect(index);
            })
        }
        .width('100%')
      }, (action: string) => action)
    }
    .width('100%')
    .padding({ left: 10, right: 10 })
  }
  .width('88%')
  .height(params.getPanelHeight())
  .borderRadius(28)
  .backgroundColor(ImmersiveGlass.barBase())
  .backgroundEffect({ radius: 32, saturation: 1.35, brightness: 1.05 })
  .border({ width: 1, color: ImmersiveGlass.barEdge() })
  .shadow({ radius: 24, color: ImmersiveGlass.barShadow(), offsetX: 0, offsetY: 10 })
  .clip(true)
}

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
      if (actions.length === 0) {
        resolve(-1);
        return;
      }
      let settled: boolean = false;
      const settle = (index: number): void => {
        if (settled) {
          return;
        }
        settled = true;
        resolve(index);
      };
      let content: ComponentContent<ActionMenuParams> | null = null;
      const params: ActionMenuParams = new ActionMenuParams(actions, themeStore.palette.text,
        themeStore.palette.softDivider, themeStore.font(16.5),
        (index: number): void => {
          settle(index);
          if (content !== null) {
            ui.getPromptAction().closeCustomDialog(content).catch((): void => {
            });
          }
        });
      const options: promptAction.BaseDialogOptions = {
        alignment: DialogAlignment.Bottom,
        offset: { dx: 0, dy: -20 },
        autoCancel: true,
        isModal: true,
        onDidDisappear: (): void => {
          settle(-1);
        }
      };
      try {
        content = new ComponentContent<ActionMenuParams>(ui, wrapBuilder(ActionMenuPanel), params);
        ui.getPromptAction().openCustomDialog(content, options).catch((error: BusinessError): void => {
          Logger.warn(SCOPE, `openCustomDialog failed: ${error.code}`);
          settle(-1);
        });
      } catch (error) {
        const err = error as BusinessError;
        Logger.warn(SCOPE, `actionSheet failed: ${err.code}`);
        settle(-1);
      }
    });
  }
}
