/**
 * 渐变 / 玻璃卡片容器：彩色渐变背景、圆角、按压反馈与可选角标。
 */
import { GradientHelper } from '../common/Palette';

@ComponentV2
export struct GlassCard {
  @Param gradientSeed: number = 0;
  @Param useGradient: boolean = true;
  @Param badge: string = '';
  @Param radius: number = 20;
  @Param contentPadding: number = 14;
  @Param cardColor: string = '#1C1C20';
  @Param strokeTint: string = '#22FFFFFF';
  @Event onTap: () => void = () => {
  };
  @BuilderParam content: () => void = this.emptyContent;

  @Builder
  emptyContent() {
    Column()
  }

  build() {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column() {
        this.content()
      }
      .width('100%')
      .padding(this.contentPadding)
      .borderRadius(this.radius)
      .backgroundColor(this.useGradient ? Color.Transparent : this.cardColor)
      .borderRadius(this.radius)
      .clip(true)

      if (this.badge.length > 0) {
        Text(this.badge)
          .fontSize(9)
          .fontColor('#F0FFFFFF')
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .borderRadius(8)
          .backgroundColor('#33000000')
          .margin({ top: 10, right: 10 })
      }
    }
    .width('100%')
    .borderRadius(this.radius)
    .clip(true)
    .border({ width: 1, color: this.strokeTint })
    .linearGradient({
      angle: 140,
      colors: this.useGradient
        ? [[GradientHelper.pair(this.gradientSeed).start, 0.0], [GradientHelper.pair(this.gradientSeed).end, 1.0]]
        : [[this.cardColor, 0.0], [this.cardColor, 1.0]]
    })
    .onClick(() => {
      this.onTap();
    })
  }
}
