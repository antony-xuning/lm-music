/**
 * 设置 · 账号音源：服务器配置、连接测试、会话状态、同步与退出登录。
 * 密码只在本次输入中进入内存，不写入任何持久化内容。
 */
import { AppSelect } from '../components/AppSelect';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { ServerStatusCard } from '../components/ServerStatusCard';
import { SettingGroup, SettingRow } from '../components/SettingRow';
import { OnlineSource, ServerConfig, SourceHelper } from '../model/SettingsModels';
import { SelectOptionItem } from '../model/UiModels';
import { Formatters } from '../service/Formatters';
import { libraryStore } from '../viewmodel/LibraryStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { serverStore } from '../viewmodel/ServerStore';
import { settingsStore } from '../viewmodel/SettingsStore';
import { syncStore } from '../viewmodel/SyncStore';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct SettingsAccountSection {
  @Local message: string = '';
  @Local messageOk: boolean = false;

  private sourceOptions(): SelectOptionItem[] {
    const list: OnlineSource[] = SourceHelper.all();
    const result: SelectOptionItem[] = [];
    for (let i = 0; i < list.length; i++) {
      result.push(new SelectOptionItem(list[i], SourceHelper.shortLabel(list[i])));
    }
    return result;
  }

  private sourceIndex(): number {
    const list: OnlineSource[] = SourceHelper.all();
    for (let i = 0; i < list.length; i++) {
      if (list[i] === settingsStore.prefs.onlineSource) {
        return i;
      }
    }
    return 0;
  }

  private startCreate(): void {
    overlayStore.openServerEdit('');
  }

  private startEdit(server: ServerConfig): void {
    overlayStore.openServerEdit(server.id);
  }

  private async sync(): Promise<void> {
    const ok: boolean = await syncStore.syncNow(true);
    this.messageOk = ok;
    this.message = ok ? `同步完成 · ${libraryStore.serverSongs.length} 首` : (syncStore.error.length > 0 ? syncStore.error : '同步失败');
  }

  private async logout(): Promise<void> {
    const ok: boolean = await ConfirmDialog.confirm(this.getUIContext(), '退出登录',
      '将清除本机保存的登录令牌，服务器曲库缓存会保留但不可访问。', '退出登录');
    if (!ok) {
      return;
    }
    await serverStore.logout();
    syncStore.reset();
    libraryStore.clearServerData();
    this.message = '已退出登录';
    this.messageOk = true;
  }

  private clearCache(): void {
    ConfirmDialog.confirm(this.getUIContext(), '清空缓存',
      '将移除本机保存的服务器曲库快照（不影响服务器数据）。', '清空').then((ok: boolean) => {
      if (ok) {
        libraryStore.clearServerData();
        syncStore.reset();
        this.message = '缓存已清空';
        this.messageOk = true;
      }
    });
  }

  private removeServer(server: ServerConfig): void {
    ConfirmDialog.confirm(this.getUIContext(), '删除服务器',
      `确定删除「${server.name}」？登录令牌与本地缓存会一并清除。`, '删除').then((ok: boolean) => {
      if (ok) {
        libraryStore.clearServerData();
        settingsStore.removeServer(server.id);
        if (settingsStore.activeServer === null) {
          serverStore.logout();
        }
        this.message = '服务器已删除';
        this.messageOk = true;
      }
    });
  }

  private async activate(server: ServerConfig): Promise<void> {
    libraryStore.clearServerData();
    settingsStore.activateServer(server.id);
    const ok: boolean = await serverStore.refreshSession();
    libraryStore.loadSnapshot();
    const base: string = '已切换到 ' + server.name;
    this.message = ok ? base : base + '，请重新登录';
    this.messageOk = ok;
  }

  @Builder
  serverRow(server: ServerConfig) {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text(server.name)
              .fontSize(12.5)
              .fontColor(themeStore.palette.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (server.isActive) {
              Text('使用中')
                .fontSize(8.5)
                .fontColor('#FFFFFF')
                .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                .borderRadius(4)
                .backgroundColor(themeStore.palette.brand)
            }
          }
          Text(server.url)
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(server.token.length > 0
            ? `已登录 ${server.displayName.length > 0 ? server.displayName : server.username}`
            : '未登录')
            .fontSize(9)
            .fontColor(server.token.length > 0 ? '#2ED3A6' : themeStore.palette.sub)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (!server.isActive) {
          Text('切换')
            .fontSize(9.5)
            .fontColor('#FFFFFF')
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .borderRadius(9)
            .backgroundColor(themeStore.palette.brand)
            .onClick(() => {
              this.activate(server);
            })
        }

        Image($r('app.media.ic_edit'))
          .width(13)
          .height(13)
          .fillColor(themeStore.palette.sub)
          .onClick(() => {
            this.startEdit(server);
          })

        Image($r('app.media.ic_trash'))
          .width(13)
          .height(13)
          .fillColor('#FA2D48')
          .onClick(() => {
            this.removeServer(server);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
  }

  build() {
    Column({ space: 16 }) {
      SettingGroup({
        groupTitle: '在线音源',
        groupDesc: '发现页与全网搜索使用的默认平台',
        cardColor: themeStore.palette.card,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      }) {
        SettingRow({
          rowTitle: '默认音源',
          rowDesc: SourceHelper.label(settingsStore.prefs.onlineSource),
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card,
          isLast: true
        }) {
          AppSelect({
            options: this.sourceOptions(),
            selectedIndex: this.sourceIndex(),
            textColor: themeStore.palette.text,
            accent: themeStore.palette.brand,
            selectWidth: 96,
            onSelect: (index: number) => {
              const list: OnlineSource[] = SourceHelper.all();
              settingsStore.setOnlineSource(list[index]);
            }
          })
        }
      }

      if (settingsStore.servers.length === 0) {
        Column({ space: 8 }) {
          Text('尚未连接服务器')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(themeStore.palette.text)
          Text('添加你的柠檬音乐服务器后即可同步曲库、在线播放与搜索。')
            .fontSize(10.5)
            .fontColor(themeStore.palette.sub)
        }
        .width('100%')
        .padding(16)
        .borderRadius(16)
        .backgroundColor(themeStore.palette.card)
        .alignItems(HorizontalAlign.Start)
      } else {
        ServerStatusCard()

        Row({ space: 8 }) {
          Text(syncStore.busy ? '正在同步…' : '立即同步')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .borderRadius(13)
            .backgroundColor(themeStore.palette.brand)
            .onClick(() => {
              this.sync();
            })
          Text('清空缓存')
            .fontSize(11)
            .fontColor(themeStore.palette.text)
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .borderRadius(13)
            .backgroundColor(themeStore.palette.controlBg)
            .onClick(() => {
              this.clearCache();
            })
          Text('退出登录')
            .fontSize(11)
            .fontColor(themeStore.palette.text)
            .padding({ left: 12, right: 12, top: 7, bottom: 7 })
            .borderRadius(13)
            .backgroundColor(themeStore.palette.controlBg)
            .onClick(() => {
              this.logout();
            })
          Blank()
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        if (libraryStore.syncedAt > 0) {
          Text(`最后同步：${Formatters.date(libraryStore.syncedAt)}（离线时仍可浏览缓存）`)
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
            .width('100%')
        }
      }

      SettingGroup({
        groupTitle: '我的音乐服务器',
        groupDesc: '凭据只保存在本机，密码不落盘',
        cardColor: themeStore.palette.card,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      }) {
        if (settingsStore.servers.length === 0) {
          Text('还没有配置服务器')
            .fontSize(11)
            .fontColor(themeStore.palette.sub)
            .width('100%')
            .padding(16)
        } else {
          Column() {
            ForEach(settingsStore.servers, (server: ServerConfig) => {
              this.serverRow(server)
            }, (server: ServerConfig) => server.id)
          }
          .width('100%')
        }
      }

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(10.5)
          .fontColor(this.messageOk ? '#2ED3A6' : '#FFB44C')
          .width('100%')
          .padding({ left: 4 })
      }

      Row({ space: 6 }) {
        Image($r('app.media.ic_plus'))
          .width(13)
          .height(13)
          .fillColor('#FFFFFF')
        Text('添加服务器')
          .fontSize(11.5)
          .fontColor('#FFFFFF')
      }
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .borderRadius(14)
      .backgroundColor(themeStore.palette.brand)
      .stateStyles({
        pressed: {
          .scale({ x: 0.94, y: 0.94 })
        },
        normal: {
          .scale({ x: 1, y: 1 })
        }
      })
      .animation({ duration: 130, curve: Curve.EaseOut })
      .onClick(() => {
        this.startCreate();
      })

      if (this.message.length > 0 && !this.messageOk && this.message.indexOf('过期') >= 0) {
        Text('请重新点击服务器编辑，输入密码后再次连接。')
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
