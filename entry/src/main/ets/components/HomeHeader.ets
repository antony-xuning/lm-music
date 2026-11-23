/**
 * 首页顶部（模式感知）：
 * - 本地模式：大标题「本地音乐」+ 副标题「已收录 N 首已下载歌曲 · M 张专辑」
 *   + 右侧 [下载圆钮][本地曲库下拉]。
 * - 服务器模式：大标题「发现」+ 副标题「在线云端曲库 · 柠檬音乐」
 *   + 右侧 [音源红色胶囊下拉][下载圆钮][服务器下拉]。
 * 上滑折叠后标题缩小，右侧仅保留搜索与下载圆钮，副标题隐藏。
 */
import { AppConstants } from '../common/Constants';
import { ServerEndpoints } from '../common/ServerEndpoints';
import { ConfirmDialog } from './ConfirmDialog';
import { HomeMode } from '../model/LocalScanModels';
import { DownloadOpResult } from '../service/ServerDownloadService';
import { downloadStore } from '../viewmodel/DownloadStore';
import { localScanStore } from '../viewmodel/LocalScanStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { serverStore } from '../viewmodel/ServerStore';
import { syncStore } from '../viewmodel/SyncStore';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct HomeHeader {
  @Param mode: HomeMode = HomeMode.LOCAL;
  @Param source: string = 'kw';
  @Param serverAvailable: boolean = false;
  @Param searchCollapsed: boolean = false;
  @Event onModeChange: (mode: HomeMode) => void = () => {
  };
  @Event onSourceChange: (code: string) => void = () => {
  };
  @Event onSearch: () => void = () => {
  };
  @Event onNeedServer: () => void = () => {
  };

  private isServer(): boolean {
    return this.mode === HomeMode.SERVER;
  }

  /** 标题：服务器模式=发现，本地模式=本地音乐。 */
  private titleText(): string {
    return this.isServer() ? '发现' : '本地音乐';
  }

  /** 副标题：服务器模式说明在线来源，本地模式给出真实收录统计。 */
  private subtitleText(): string {
    if (this.isServer()) {
      return `在线云端曲库 · ${AppConstants.APP_NAME}`;
    }
    return `已收录 ${localScanStore.trackCount} 首已下载歌曲 · ${localScanStore.albumCount} 张专辑`;
  }

  /** 当前音源短标签（网易云 -> 网易），贴合设计图紧凑胶囊。 */
  private sourceLabel(): string {
    const label: string = ServerEndpoints.platformLabel(this.source);
    if (label === '网易云') {
      return '网易';
    }
    return label;
  }

  /** 服务器胶囊文案：连接时显示服务器名，否则提示。 */
  private serverLabel(): string {
    if (!this.serverAvailable) {
      return '未连接';
    }
    const name: string = serverStore.activeServer !== null ? serverStore.activeServer.name : '';
    return name.length > 0 ? name : '服务器';
  }

  private sourceCodes(): string[] {
    return ServerEndpoints.allPlatforms();
  }

  /** 下拉「立即同步」：触发真实服务器同步并给出结果提示。 */
  private async doSync(): Promise<void> {
    if (!this.serverAvailable) {
      this.onNeedServer();
      return;
    }
    if (syncStore.busy) {
      return;
    }
    const ok: boolean = await syncStore.syncNow(true);
    ConfirmDialog.toast(this.getUIContext(), ok ? '同步完成' :
      (syncStore.error.length > 0 ? syncStore.error : '同步失败'));
  }

  /** 下拉「清空已完成」：与下载页同一确认流程。 */
  private clearCompleted(): void {
    ConfirmDialog.confirm(this.getUIContext(), '清空已完成',
      '将从服务器移除所有已完成任务记录（不删除音频文件）。', '清空').then((ok: boolean) => {
      if (!ok) {
        return;
      }
      downloadStore.clearCompleted().then((result: DownloadOpResult) => {
        ConfirmDialog.toast(this.getUIContext(), result.message);
      });
    });
  }

  /** 音源下拉：与服务器下拉同款卡片行，勾选列 + 红色高亮。 */
  @Builder
  sourceMenuBuilder() {
    Menu() {
      ForEach(this.sourceCodes(), (code: string) => {
        MenuItem() {
          Row({ space: 12 }) {
            Column() {
              if (code === this.source) {
                Image($r('app.media.ic_check'))
                  .width(18)
                  .height(18)
                  .fillColor('#FA2D48')
              }
            }
            .width(20)

            Text(ServerEndpoints.platformLabel(code))
              .fontSize(16)
              .fontColor(code === this.source ? '#FA2D48' : themeStore.palette.text)
          }
          .padding({ top: 11, bottom: 11 })
        }
        .onClick(() => {
          if (code !== this.source) {
            this.onSourceChange(code);
          }
        })
      }, (code: string) => code)
    }
  }

  /** 下载下拉：打开下载页 / 清空已完成（真实功能）。 */
  @Builder
  downloadMenuBuilder() {
    Menu() {
      MenuItem() {
        Row({ space: 12 }) {
          Column() {
            Image($r('app.media.ic_download'))
              .width(18)
              .height(18)
              .fillColor(themeStore.palette.text)
          }
          .width(20)

          Text('下载管理')
            .fontSize(16)
            .fontColor(themeStore.palette.text)
        }
        .padding({ top: 11, bottom: 11 })
      }
      .onClick(() => {
        overlayStore.setTab(2);
      })

      MenuItem() {
        Row({ space: 12 }) {
          Column() {
            Image($r('app.media.ic_refresh'))
              .width(18)
              .height(18)
              .fillColor('#FA2D48')
          }
          .width(20)

          Text('清空已完成')
            .fontSize(16)
            .fontColor('#FA2D48')
        }
        .padding({ top: 11, bottom: 11 })
      }
      .onClick(() => {
        this.clearCompleted();
      })
    }
  }

  /** 下拉卡片：本地 / 在线（当前勾选，红色）/ 立即同步（红色）。 */
  @Builder
  modeMenuBuilder() {
    Menu() {
      MenuItem() {
        Row({ space: 12 }) {
          Column() {
            if (!this.isServer()) {
              Image($r('app.media.ic_check'))
                .width(18)
                .height(18)
                .fillColor('#FA2D48')
            }
          }
          .width(20)

          Text('本地 · 离线曲库')
            .fontSize(16)
            .fontColor(!this.isServer() ? '#FA2D48' : themeStore.palette.text)
        }
        .padding({ top: 11, bottom: 11 })
      }
      .onClick(() => {
        if (this.isServer()) {
          this.onModeChange(HomeMode.LOCAL);
        }
      })

      MenuItem() {
        Row({ space: 12 }) {
          Column() {
            if (this.isServer()) {
              Image($r('app.media.ic_check'))
                .width(18)
                .height(18)
                .fillColor('#FA2D48')
            }
          }
          .width(20)

          Text(this.serverAvailable ? `在线 · ${this.serverLabel()}` : '在线 · 未连接')
            .fontSize(16)
            .fontColor(this.isServer() ? '#FA2D48' : themeStore.palette.text)
        }
        .padding({ top: 11, bottom: 11 })
      }
      .onClick(() => {
        if (!this.serverAvailable) {
          this.onNeedServer();
          return;
        }
        if (!this.isServer()) {
          this.onModeChange(HomeMode.SERVER);
        }
      })

      MenuItem() {
        Row({ space: 12 }) {
          Column() {
            Image($r('app.media.ic_refresh'))
              .width(18)
              .height(18)
              .fillColor('#FA2D48')
          }
          .width(20)

          Text(syncStore.busy ? '同步中…' : '立即同步')
            .fontSize(16)
            .fontColor('#FA2D48')
        }
        .padding({ top: 11, bottom: 11 })
      }
      .onClick(() => {
        this.doSync();
      })
    }
  }

  @Builder
  roundButton(icon: Resource, action: () => void) {
    Stack() {
      Image(icon)
        .width(18)
        .height(18)
        .fillColor(themeStore.palette.text)
    }
    .width(38)
    .height(38)
    .borderRadius(19)
    .backgroundColor(themeStore.isDark ? '#22FFFFFF' : '#14000000')
    .onClick(() => {
      action();
    })
  }

  /** 下载胶囊：与音源/服务器胶囊同款玻璃质感，带卡片下拉。 */
  @Builder
  downloadPill() {
    Row({ space: 6 }) {
      Image($r('app.media.ic_download'))
        .width(15)
        .height(15)
        .fillColor(themeStore.palette.text)
      Image($r('app.media.ic_chevron_down'))
        .width(12)
        .height(12)
        .fillColor(themeStore.palette.sub)
    }
    .height(38)
    .padding({ left: 12, right: 10 })
    .borderRadius(19)
    .backgroundColor(themeStore.isDark ? '#22FFFFFF' : '#14000000')
    .bindMenu(this.downloadMenuBuilder())
  }

  /** 音源胶囊：红色强调（设计图网易红），带波形图标与下拉箭头。 */
  @Builder
  sourcePill() {
    Row({ space: 6 }) {
      Image($r('app.media.ic_headset'))
        .width(15)
        .height(15)
        .fillColor('#FA2D48')
      Text(this.sourceLabel())
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FA2D48')
      Image($r('app.media.ic_chevron_down'))
        .width(12)
        .height(12)
        .fillColor('#FA2D48')
    }
    .height(38)
    .padding({ left: 12, right: 10 })
    .borderRadius(19)
    .backgroundColor('#1EFA2D48')
    .border({ width: 1, color: '#55FA2D48' })
    .bindMenu(this.sourceMenuBuilder())
  }

  /** 本地曲库 / 服务器胶囊：深色玻璃质感，带下拉箭头。 */
  @Builder
  modePill() {
    Row({ space: 6 }) {
      Image($r('app.media.ic_server'))
        .width(15)
        .height(15)
        .fillColor(this.isServer() ? '#FA2D48' : themeStore.palette.text)
      Text(this.isServer() ? this.serverLabel() : '本地曲库')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(themeStore.palette.text)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Image($r('app.media.ic_chevron_down'))
        .width(12)
        .height(12)
        .fillColor(themeStore.palette.sub)
    }
    .height(38)
    .constraintSize({ maxWidth: 150 })
    .padding({ left: 12, right: 10 })
    .borderRadius(19)
    .backgroundColor(themeStore.isDark ? '#22FFFFFF' : '#14000000')
    .bindMenu(this.modeMenuBuilder())
  }

  build() {
    Column() {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(this.titleText())
            .fontSize(this.searchCollapsed ? 17 : 20)
            .fontWeight(FontWeight.Bold)
            .fontColor(themeStore.palette.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (!this.searchCollapsed) {
            Text(this.subtitleText())
              .fontSize(11)
              .fontColor(themeStore.palette.sub)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.searchCollapsed) {
          this.roundButton($r('app.media.ic_search'), () => {
            this.onSearch();
          })
        } else if (this.isServer()) {
          this.sourcePill()
        }

        if (this.searchCollapsed) {
          this.roundButton($r('app.media.ic_download'), () => {
            overlayStore.setTab(2);
          })
        } else {
          this.downloadPill()
        }

        if (!this.searchCollapsed) {
          this.modePill()
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (!this.serverAvailable && !this.searchCollapsed && !this.isServer()) {
        Row({ space: 4 }) {
          Text('尚未添加服务器，服务器模式需先在设置中登录')
            .fontSize(10)
            .fontColor(themeStore.palette.sub)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text('去设置')
            .fontSize(10.5)
            .fontColor(themeStore.palette.brand)
            .onClick(() => {
              this.onNeedServer();
            })
        }
        .width('100%')
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .animation({ duration: 200, curve: Curve.EaseOut })
  }
}
