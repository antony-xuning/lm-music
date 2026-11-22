/**
 * 首页模式分段切换：本地曲库 / 柠檬音乐服务器。
 * 未配置服务器时服务器段禁用，并给出「去设置」入口。
 */
import { HomeMode } from '../model/LocalScanModels';

@ComponentV2
export struct HomeModeSwitch {
  @Param mode: HomeMode = HomeMode.LOCAL;
  @Param serverAvailable: boolean = false;
  @Param accent: string = '#FA2D48';
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @Param chipBg: string = '#242429';
  @Event onSelect: (mode: HomeMode) => void = () => {
  };
  @Event onNeedServer: () => void = () => {
  };

  build() {
    Column({ space: 6 }) {
      Row() {
        Row() {
          Text('本地曲库')
            .fontSize(12.5)
            .fontWeight(this.mode === HomeMode.LOCAL ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.mode === HomeMode.LOCAL ? '#FFFFFF' : this.subColor)
        }
        .layoutWeight(1)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .borderRadius(15)
        .backgroundColor(this.mode === HomeMode.LOCAL ? this.accent : '#00000000')
        .onClick(() => {
          this.onSelect(HomeMode.LOCAL);
        })

        Row() {
          Text('柠檬音乐服务器')
            .fontSize(12.5)
            .fontWeight(this.mode === HomeMode.SERVER ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.mode === HomeMode.SERVER ? '#FFFFFF' : this.subColor)
        }
        .layoutWeight(1)
        .height(32)
        .justifyContent(FlexAlign.Center)
        .borderRadius(15)
        .backgroundColor(this.mode === HomeMode.SERVER ? this.accent : '#00000000')
        .opacity(this.serverAvailable ? 1 : 0.45)
        .onClick(() => {
          if (this.serverAvailable) {
            this.onSelect(HomeMode.SERVER);
          } else {
            this.onNeedServer();
          }
        })
      }
      .width('100%')
      .padding(3)
      .borderRadius(18)
      .backgroundColor(this.chipBg)

      if (!this.serverAvailable) {
        Row({ space: 4 }) {
          Text('尚未添加服务器，服务器内容需先登录')
            .fontSize(10)
            .fontColor(this.subColor)
            .layoutWeight(1)
          Text('去设置')
            .fontSize(10.5)
            .fontColor(this.accent)
            .onClick(() => {
              this.onNeedServer();
            })
        }
        .width('100%')
        .padding({ left: 6, right: 6 })
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
