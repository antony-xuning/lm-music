/**
 * 封面：优先显示已缓存的远程封面（file:// 或 http），失败回退程序化渐变，始终不会破图。
 */
import { GradientHelper, GradientPair } from '../common/Palette';

@ComponentV2
export struct Artwork {
  @Param seed: number = 0;
  @Param artworkSize: number = 48;
  @Param radius: number = 12;
  @Param title: string = '';
  @Param showRing: boolean = false;
  @Param showInitial: boolean = true;
  @Param remoteUrl: string = '';
  @Local failed: boolean = false;

  @Monitor('remoteUrl')
  onRemoteChange(): void {
    this.failed = false;
  }

  private initial(): string {
    if (this.title.length === 0) {
      return '♪';
    }
    return this.title.substring(0, 1);
  }

  private useRemote(): boolean {
    return this.remoteUrl.length > 0 && !this.failed;
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 135,
          colors: [[GradientHelper.pair(this.seed).start, 0.0], [GradientHelper.pair(this.seed).end, 1.0]]
        })

      if (this.useRemote()) {
        Image(this.remoteUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
          .onError(() => {
            this.failed = true;
          })
      } else {
        if (this.showRing) {
          Column()
            .width('62%')
            .height('62%')
            .borderRadius('50%')
            .border({ width: 1, color: '#40FFFFFF' })
          Column()
            .width('18%')
            .height('18%')
            .borderRadius('50%')
            .backgroundColor('#40FFFFFF')
        }

        if (this.showInitial) {
          Text(this.initial())
            .fontSize(Math.max(this.artworkSize * 0.34, 11))
            .fontWeight(FontWeight.Medium)
            .fontColor('#F2FFFFFF')
        }
      }
    }
    .width(this.artworkSize)
    .height(this.artworkSize)
    .borderRadius(this.radius)
    .clip(true)
    .backgroundColor('#2A2A30')
  }
}

export function artworkColors(seed: number): GradientPair {
  return GradientHelper.pair(seed);
}
