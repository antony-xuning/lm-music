/**
 * 华为音乐风底部悬浮页签栏（仅页签，不含播放器）。
 *
 * 玻璃材质完全由 Tabs.barFloatingStyle 提供：单元格不再绘制任何底色/遮罩，
 * 只叠加顶部 1px 高光、选中扫光、选中放大与标签渐现；底层内容直接透过玻璃可见。
 * 文字/图标按系统材质亮度取色，并加轻阴影保证深浅色下都可读（FR-125/148）。
 */
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct BottomDock {
  @Param itemIndex: number = 0;
  @Param itemTitle: string = '';
  @Param itemIcon: Resource = $r('app.media.ic_home');
  @Param selected: boolean = false;
  @Param iconColor: string = '#A1A1A8';
  @Param activeColor: string = '#FA2D48';

  private labelShadow(): string {
    return themeStore.surfaceDark ? '#99000000' : '#B3FFFFFF';
  }

  private idleColor(): string {
    if (this.selected) {
      return this.activeColor;
    }
    return themeStore.surfaceDark ? '#C9FFFFFF' : '#99000000';
  }

  private iconScale(): number {
    return this.selected ? 1.16 : 1;
  }

  private iconOffset(): number {
    return this.selected ? -2 : 0;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column({ space: 2 }) {
        Stack() {
          Image(this.itemIcon)
            .width(20)
            .height(20)
            .fillColor(this.idleColor())
        }
        .width(34)
        .height(22)
        .scale({ x: this.iconScale(), y: this.iconScale() })
        .translate({ y: this.iconOffset() })
        .animation({ duration: 200, curve: Curve.EaseOut })

        Text(this.itemTitle)
          .fontSize(9)
          .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
          .fontColor(this.idleColor())
          .textShadow({ radius: 4, color: this.labelShadow(), offsetX: 0, offsetY: 1 })
          .opacity(this.selected ? 1 : 0.75)
          .maxLines(1)
          .animation({ duration: 200, curve: Curve.EaseOut })
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 11 })
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}
