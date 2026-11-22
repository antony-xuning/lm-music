/**
 * 主页面自定义玻璃标题栏（Navigation 标题栏之外的降级方案）。
 */
@ComponentV2
export struct ImmersiveHeader {
  @Param headerTitle: string = '';
  @Param headerSubtitle: string = '';
  @Param showBack: boolean = false;
  @Param rightIcon: Resource | null = null;
  @Param trailingText: string = '';
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @Param accent: string = '#FA2D48';
  @Param blurStyle: BlurStyle = BlurStyle.Regular;
  @Event onBack: () => void = () => {
  };
  @Event onRight: () => void = () => {
  };

  build() {
    Row({ space: 10 }) {
      if (this.showBack) {
        Stack() {
          Image($r('app.media.ic_back'))
            .width(18)
            .height(18)
            .fillColor(this.textColor)
        }
        .width(34)
        .height(34)
        .borderRadius(17)
        .backgroundColor('#22FFFFFF')
        .onClick(() => {
          this.onBack();
        })
      }

      Column({ space: 1 }) {
        Text(this.headerTitle)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.textColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        if (this.headerSubtitle.length > 0) {
          Text(this.headerSubtitle)
            .fontSize(11)
            .fontColor(this.subColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.trailingText.length > 0) {
        Text(this.trailingText)
          .fontSize(11)
          .fontColor(this.accent)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(12)
          .backgroundColor('#22FFFFFF')
      }

      if (this.rightIcon !== null) {
        Stack() {
          Image(this.rightIcon)
            .width(18)
            .height(18)
            .fillColor(this.textColor)
        }
        .width(34)
        .height(34)
        .borderRadius(17)
        .backgroundColor('#22FFFFFF')
        .onClick(() => {
          this.onRight();
        })
      }
    }
    .width('100%')
    .height(58)
    .padding({ left: 16, right: 16 })
    .alignItems(VerticalAlign.Center)
    .backgroundBlurStyle(this.blurStyle)
    .backgroundColor('#22101014')
  }
}
