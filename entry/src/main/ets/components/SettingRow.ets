/**
 * 设置行：标题 + 说明 + 右侧控件插槽。
 */
@ComponentV2
export struct SettingRow {
  @Param rowTitle: string = '';
  @Param rowDesc: string = '';
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @Param rowColor: string = '#1C1C20';
  @Param isLast: boolean = false;
  @BuilderParam control: () => void = this.emptyControl;

  @Builder
  emptyControl() {
    Blank()
  }

  build() {
    Column() {
      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text(this.rowTitle)
            .fontSize(13)
            .fontColor(this.textColor)
          if (this.rowDesc.length > 0) {
            Text(this.rowDesc)
              .fontSize(10)
              .fontColor(this.subColor)
              .maxLines(2)
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        this.control()
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 11, bottom: 11 })
      .alignItems(VerticalAlign.Center)

      if (!this.isLast) {
        Divider()
          .strokeWidth(0.5)
          .color('#1AFFFFFF')
          .margin({ left: 14, right: 14 })
      }
    }
    .width('100%')
    .backgroundColor(this.rowColor)
  }
}

/** 分组容器：标题 + 卡片内容。 */
@ComponentV2
export struct SettingGroup {
  @Param groupTitle: string = '';
  @Param groupDesc: string = '';
  @Param cardColor: string = '#1C1C20';
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
    Column()
  }

  build() {
    Column({ space: 8 }) {
      Column({ space: 2 }) {
        Text(this.groupTitle)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.textColor)
        if (this.groupDesc.length > 0) {
          Text(this.groupDesc)
            .fontSize(10)
            .fontColor(this.subColor)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 4 })

      Column() {
        this.content()
      }
      .width('100%')
      .borderRadius(16)
      .backgroundColor(this.cardColor)
      .clip(true)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
