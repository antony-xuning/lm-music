/**
 * 华为音乐风底部悬浮页签栏（仅页签，不含播放器）。
 *
 * 玻璃底色/模糊/描边由 Index.glassDock 统一绘制，单元格自身不绘制实色底。
 * 选中态不绘制白色底色：品牌色图标 + 加粗文字 + 轻微放大直接落在玻璃上；
 * 未选中项保持轻阴影文字与按压反馈，底层内容透过同一套玻璃配方可见。
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
    return this.selected ? 1.08 : 1;
  }

  private iconOffset(): number {
    return this.selected ? -1 : 0;
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column({ space: 2 }) {
        // 选中态：不加白色底色，仅用品牌色与轻微放大突出选中项。
        Stack() {
          Image(this.itemIcon)
            .width(this.selected ? 21 : 23)
            .height(this.selected ? 21 : 23)
            .fillColor(this.idleColor())
        }
        .width(38)
        .height(38)
        .scale({ x: this.iconScale(), y: this.iconScale() })
        .translate({ y: this.iconOffset() })
        .animation({ duration: 200, curve: Curve.EaseOut })

        Stack() {
          Text(this.itemTitle)
            .fontSize(themeStore.font(10.5))
            .fontWeight(this.selected ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.idleColor())
            .textShadow({
              radius: this.selected ? 0 : 4,
              color: this.labelShadow(),
              offsetX: 0,
              offsetY: 1
            })
            .opacity(this.selected ? 1 : 0.75)
            .maxLines(1)
            .animation({ duration: 200, curve: Curve.EaseOut })
        }
      }
      .width('100%')
      .height('100%')
      .padding({ bottom: 8 })
      .justifyContent(FlexAlign.End)
    }
    .width('100%')
    .height('100%')
    .stateStyles({
      pressed: { .scale({ x: 0.9, y: 0.9 }).opacity(0.8) },
      normal: { .scale({ x: 1, y: 1 }).opacity(1) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
  }
}
