/**
 * 徽章：音质 / 来源 / 状态 / 计数。
 */
@ComponentV2
export struct BadgeView {
  @Param text: string = '';
  @Param tone: string = 'glass';
  @Param textSize: number = 10;

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
    return '#33FFFFFF';
  }

  private fgColor(): string {
    if (this.tone === 'brand' || this.tone === 'success' || this.tone === 'warn') {
      return '#FFFFFF';
    }
    return '#E8E8EE';
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
