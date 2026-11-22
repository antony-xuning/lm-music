/**
 * 服务器状态卡：在线状态、延迟、当前用户、最后同步时间、曲库数量。
 * 卡内直接读取 Store，避免 @Builder 按值传参导致的「数据更新但界面不刷新」。
 */
import { Formatters } from '../service/Formatters';
import { libraryStore } from '../viewmodel/LibraryStore';
import { serverStore } from '../viewmodel/ServerStore';
import { syncStore } from '../viewmodel/SyncStore';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct ServerStatusCard {
  /** 发现页使用「在线」文案，其他页面使用同步状态文案。 */
  @Param preferOnlineLabel: boolean = false;

  private serverName(): string {
    const name: string = serverStore.activeServer !== null ? serverStore.activeServer.name : '';
    return name.length > 0 ? name : '未连接服务器';
  }

  private stateText(): string {
    if (this.preferOnlineLabel && serverStore.online) {
      return '在线';
    }
    return syncStore.label;
  }

  private stateColor(): string {
    if (serverStore.online) {
      return '#2ED3A6';
    }
    if (serverStore.errorText.length > 0) {
      return '#FFB44C';
    }
    return themeStore.palette.sub;
  }

  private userLabel(): string {
    if (serverStore.displayName.length > 0) {
      return serverStore.displayName;
    }
    const server = serverStore.activeServer;
    if (server !== null) {
      if (server.displayName.length > 0) {
        return server.displayName;
      }
      if (server.username.length > 0) {
        return server.username;
      }
    }
    return '—';
  }

  private syncLabel(): string {
    return syncStore.lastSuccessAt > 0 ? Formatters.relativeDate(syncStore.lastSuccessAt) : '尚未同步';
  }

  build() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Column()
          .width(8)
          .height(8)
          .borderRadius(4)
          .backgroundColor(this.stateColor())

        Column({ space: 2 }) {
          Text(this.serverName())
            .fontSize(13.5)
            .fontWeight(FontWeight.Medium)
            .fontColor(themeStore.palette.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.stateText())
            .fontSize(10)
            .fontColor(this.stateColor())
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (serverStore.online) {
          Text(`${serverStore.latencyMs} ms`)
            .fontSize(10)
            .fontColor(themeStore.palette.sub)
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .borderRadius(9)
            .backgroundColor('#22FFFFFF')
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (serverStore.errorText.length > 0) {
        Text(serverStore.errorText)
          .fontSize(10.5)
          .fontColor('#FFB44C')
          .width('100%')
          .maxLines(2)
      }

      Row({ space: 10 }) {
        Column({ space: 2 }) {
          Text('当前用户')
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
          Text(this.userLabel())
            .fontSize(12)
            .fontColor(themeStore.palette.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 2 }) {
          Text('曲库')
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
          Text(`${libraryStore.serverSongs.length} 首`)
            .fontSize(12)
            .fontColor(themeStore.palette.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column({ space: 2 }) {
          Text('最后同步')
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
          Text(this.syncLabel())
            .fontSize(12)
            .fontColor(themeStore.palette.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(18)
    .backgroundColor(themeStore.palette.card)
  }
}
