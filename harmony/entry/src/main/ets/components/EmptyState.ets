/**
 * 空态 / 错误态 / 加载态统一展示。
 */
@ComponentV2
export struct EmptyState {
  @Param title: string = '暂无内容';
  @Param description: string = '';
  @Param actionText: string = '';
  @Param iconSeed: number = 0;
  @Param accent: string = '#FA2D48';
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @Param loading: boolean = false;
  @Event onAction: () => void = () => {
  };

  build() {
    Column({ space: 10 }) {
      if (this.loading) {
        LoadingProgress()
          .width(34)
          .height(34)
          .color(this.accent)
      } else {
        Stack() {
          Column()
            .width(64)
            .height(64)
            .borderRadius(24)
            .backgroundColor('#1F2A2A30')
            .border({ width: 1, color: '#22FFFFFF' })
          Image($r('app.media.ic_playlist_add'))
            .width(26)
            .height(26)
            .fillColor(this.subColor)
        }
        .width(64)
        .height(64)
      }

      Text(this.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.textColor)
        .textAlign(TextAlign.Center)

      if (this.description.length > 0) {
        Text(this.description)
          .fontSize(12)
          .fontColor(this.subColor)
          .textAlign(TextAlign.Center)
          .padding({ left: 24, right: 24 })
      }

      if (this.actionText.length > 0 && !this.loading) {
        Text(this.actionText)
          .fontSize(13)
          .fontColor('#FFFFFF')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(16)
          .backgroundColor(this.accent)
          .margin({ top: 4 })
          .onClick(() => {
            this.onAction();
          })
      }
    }
    .width('100%')
    .padding({ top: 44, bottom: 44 })
    .justifyContent(FlexAlign.Center)
  }
}
