/**
 * 徽章：音质 / 来源 / 状态 / 计数。
 * glass 色调跟随应用主题；叠加在恒暗表面（播放器封面等）时传 onDark = true。
 */
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct BadgeView {
  @Param text: string = '';
  @Param tone: string = 'glass';
  @Param textSize: number = 10;
  /** 所处表面是否恒为深色（如全屏播放器封面）。 */
  @Param onDark: boolean = false;

  private glassBg(): string {
    if (this.onDark) {
      return '#33FFFFFF';
    }
    return themeStore.isDark ? '#33FFFFFF' : '#1A000000';
  }

  private glassFg(): string {
    if (this.onDark) {
      return '#E8E8EE';
    }
    return themeStore.palette.glassFg;
  }

  private bgColor(): string {
    if (this.tone === 'brand') {
      return '#FA2D48';
    }
    if (this.tone === 'success') {
      return '#1F7A55';
    }
    if (this.tone === 'warn') {
      return '#8A5A16';
    }
    return this.glassBg();
  }

  private fgColor(): string {
    if (this.tone === 'brand' || this.tone === 'success' || this.tone === 'warn') {
      return '#FFFFFF';
    }
    return this.glassFg();
  }

  build() {
    Text(this.text)
      .fontSize(this.textSize)
      .fontColor(this.fgColor())
      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
      .borderRadius(6)
      .backgroundColor(this.bgColor())
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }
}
