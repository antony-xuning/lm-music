/**
 * 半模态面板统一壳：拖拽把手 + 标题 + 关闭按钮 + 内容插槽。
 * 面板本身的沉浸式材质由 bindSheet（系统半模态）在应用级开关下自动提供。
 */
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct SheetShell {
  @Param sheetTitle: string = '';
  @Param sheetSubtitle: string = '';
  @Param panelColor: string = '#1C1C20';
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @BuilderParam content: () => void = this.emptyContent;
  @Event onClose: () => void = () => {
  };

  @Builder
  emptyContent() {
    Column()
  }

  build() {
    Column() {
      Column()
        .width(36)
        .height(4)
        .borderRadius(2)
        .backgroundColor(themeStore.palette.handle)
        .margin({ top: 8, bottom: 6 })

      Row() {
        Column({ space: 2 }) {
          Text(this.sheetTitle)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.textColor)
          if (this.sheetSubtitle.length > 0) {
            Text(this.sheetSubtitle)
              .fontSize(11)
              .fontColor(this.subColor)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Stack() {
          Image($r('app.media.ic_close'))
            .width(16)
            .height(16)
            .fillColor(this.subColor)
        }
        .width(30)
        .height(30)
        .borderRadius(15)
        .backgroundColor(themeStore.palette.controlBg)
        .onClick(() => {
          this.onClose();
        })
      }
      .width('100%')
      .padding({ top: 4, bottom: 10 })
      .alignItems(VerticalAlign.Center)

      this.content()
    }
    .width('100%')
    .padding({ left: 18, right: 18, bottom: 20 })
    .backgroundColor(this.panelColor)
    .constraintSize({ maxHeight: '86%' })
  }
}
