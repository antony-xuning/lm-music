/**
 * 区块标题：标题 + 副标题 + 右侧动作。
 */
@ComponentV2
export struct SectionHeader {
  @Param title: string = '';
  @Param subtitle: string = '';
  @Param actionText: string = '';
  @Param titleSize: number = 18;
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @Param actionColor: string = '#FA2D48';
  @Event onAction: () => void = () => {
  };

  build() {
    Row() {
      Column({ space: 2 }) {
        Text(this.title)
          .fontSize(this.titleSize)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
        if (this.subtitle.length > 0) {
          Text(this.subtitle)
            .fontSize(12)
            .fontColor(this.subColor)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.actionText.length > 0) {
        Row({ space: 2 }) {
          Text(this.actionText)
            .fontSize(12)
            .fontColor(this.actionColor)
          Image($r('app.media.ic_next'))
            .width(12)
            .height(12)
            .fillColor(this.actionColor)
        }
        .padding({ left: 8, top: 4, bottom: 4 })
        .borderRadius(10)
        .onClick(() => {
          this.onAction();
        })
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }
}
