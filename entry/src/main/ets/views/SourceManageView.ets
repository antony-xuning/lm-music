/**
 * 音源脚本管理：脚本卡片、启停、平台开关、健康统计与 URL 导入。
 */
import { ConfirmDialog } from '../components/ConfirmDialog';
import { EmptyState } from '../components/EmptyState';
import { SourcePlatform, SourceScript } from '../model/ServerModels';
import { SourceOpResult } from '../service/SourceService';
import { layoutStore } from '../viewmodel/LayoutStore';
import { serverStore } from '../viewmodel/ServerStore';
import { sourceStore } from '../viewmodel/SourceStore';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct SourceManageView {
  @Local importUrl: string = '';
  @Local showImport: boolean = false;

  aboutToAppear(): void {
    sourceStore.load();
  }

  private healthText(script: SourceScript): string {
    if (!script.active) {
      return '已停用';
    }
    if (script.health === 'ok' || script.health === 'healthy' || script.health === 'good') {
      return '健康';
    }
    if (script.health === 'fair') {
      return '一般';
    }
    if (script.health === 'poor' || script.health === 'bad') {
      return '较差';
    }
    return '未知';
  }

  private healthTone(script: SourceScript): string {
    if (script.health === 'ok' || script.health === 'healthy' || script.health === 'good') {
      return 'success';
    }
    if (script.health === 'poor' || script.health === 'bad') {
      return 'warn';
    }
    return 'glass';
  }

  private async toggle(script: SourceScript): Promise<void> {
    const ok: boolean = await ConfirmDialog.confirm(this.getUIContext(), script.active ? '停用脚本' : '启用脚本',
      script.active ? `停用「${script.name}」会影响在线搜索与播放。` : `启用「${script.name}」？`,
      script.active ? '停用' : '启用', !script.active);
    if (!ok) {
      return;
    }
    const result: SourceOpResult = await sourceStore.toggleActive(script);
    ConfirmDialog.toast(this.getUIContext(), result.message);
  }

  private async togglePlatform(script: SourceScript, platform: SourcePlatform): Promise<void> {
    const result: SourceOpResult = await sourceStore.togglePlatform(script, platform.id, !platform.enabled);
    ConfirmDialog.toast(this.getUIContext(), result.message);
  }

  private async submitImport(): Promise<void> {
    const url: string = this.importUrl.trim();
    if (url.length === 0) {
      ConfirmDialog.toast(this.getUIContext(), '请输入脚本 URL');
      return;
    }
    const result: SourceOpResult = await sourceStore.importUrl(url);
    ConfirmDialog.toast(this.getUIContext(), result.message);
    if (result.ok) {
      this.importUrl = '';
      this.showImport = false;
    }
  }

  @Builder
  importCard() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Image($r('app.media.ic_plus'))
          .width(13)
          .height(13)
          .fillColor('#FFFFFF')
        Text(sourceStore.busy ? '处理中…' : '导入音源脚本')
          .fontSize(11.5)
          .fontColor('#FFFFFF')
      }
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(14)
      .backgroundColor(themeStore.palette.brand)
      .onClick(() => {
        this.showImport = !this.showImport;
      })

      if (this.showImport) {
        Row({ space: 8 }) {
          TextInput({ text: this.importUrl, placeholder: 'https://example.com/source.js' })
            .fontSize(12)
            .fontColor(themeStore.palette.text)
            .placeholderColor(themeStore.palette.sub)
            .layoutWeight(1)
            .height(38)
            .backgroundColor('#22FFFFFF')
            .borderRadius(12)
            .onChange((value: string) => {
              this.importUrl = value;
            })
          Text('导入')
            .fontSize(12)
            .fontColor('#FFFFFF')
            .padding({ left: 14, right: 14, top: 9, bottom: 9 })
            .borderRadius(12)
            .backgroundColor(themeStore.palette.brand)
            .onClick(() => {
              this.submitImport();
            })
        }
        .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  platformChip(script: SourceScript, platform: SourcePlatform) {
    Text(`${platform.label.length > 0 ? platform.label : platform.id}${platform.enabled ? '' : '（关）'}`)
      .fontSize(9.5)
      .fontColor(platform.enabled ? themeStore.palette.text : themeStore.palette.sub)
      .padding({ left: 8, right: 8, top: 3, bottom: 3 })
      .borderRadius(9)
      .backgroundColor(platform.enabled ? '#33FFFFFF' : '#11FFFFFF')
      .onClick(() => {
        this.togglePlatform(script, platform);
      })
  }

  @Builder
  scriptCard(script: SourceScript) {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Row({ space: 6 }) {
            Text(script.name)
              .fontSize(13.5)
              .fontWeight(FontWeight.Medium)
              .fontColor(themeStore.palette.text)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            Text(this.healthText(script))
              .fontSize(9)
              .fontColor(this.healthTone(script) === 'warn' ? '#FFB44C' : '#2ED3A6')
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .borderRadius(4)
              .backgroundColor('#22FFFFFF')
          }
          Text(`v${script.version.length > 0 ? script.version : '—'} · ${script.author.length > 0 ? script.author : '未知作者'}`)
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(script.active ? '停用' : '启用')
          .fontSize(10.5)
          .fontColor(script.active ? themeStore.palette.text : '#FFFFFF')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .borderRadius(10)
          .backgroundColor(script.active ? '#22FFFFFF' : themeStore.palette.brand)
          .onClick(() => {
            this.toggle(script);
          })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (script.platforms.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(script.platforms, (platform: SourcePlatform) => {
            Column() {
              this.platformChip(script, platform)
            }
            .margin({ right: 6, bottom: 4 })
          }, (platform: SourcePlatform) => platform.id)
        }
        .width('100%')
      }

      Column({ space: 2 }) {
        ForEach(script.platforms, (platform: SourcePlatform) => {
          if (platform.lastError.length > 0 || platform.avgMs > 0) {
            Text(`${platform.id}：成功率 ${Math.round(platform.okRatio * 100)}% · 平均 ${Math.round(platform.avgMs)}ms${platform.lastError.length > 0 ? ' · ' + platform.lastError : ''}`)
              .fontSize(9)
              .fontColor(themeStore.palette.sub)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
        }, (platform: SourcePlatform) => `health_${platform.id}`)
      }
      .width('100%')
    }
    .width('100%')
    .padding(12)
    .borderRadius(16)
    .backgroundColor(themeStore.palette.card)
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        if (!serverStore.canRead) {
          EmptyState({
            title: '尚未连接柠檬音乐服务器',
            description: '连接服务器后可管理音源脚本',
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand
          })
        } else {
          this.importCard()

          if (sourceStore.loading && sourceStore.scripts.length === 0) {
            EmptyState({ loading: true, title: '正在读取音源脚本' })
          } else if (sourceStore.errorText.length > 0 && sourceStore.scripts.length === 0) {
            EmptyState({
              title: '读取音源失败',
              description: sourceStore.errorText,
              actionText: '重试',
              textColor: themeStore.palette.text,
              subColor: themeStore.palette.sub,
              accent: themeStore.palette.brand,
              onAction: () => {
                sourceStore.load();
              }
            })
          } else if (sourceStore.scripts.length === 0) {
            EmptyState({
              title: '服务器上没有音源脚本',
              description: '可通过上面的入口按 URL 导入',
              textColor: themeStore.palette.text,
              subColor: themeStore.palette.sub,
              accent: themeStore.palette.brand
            })
          } else {
            ForEach(sourceStore.scripts, (script: SourceScript) => {
              this.scriptCard(script)
            }, (script: SourceScript) => script.id)
          }
        }
      }
      .width('100%')
      .padding({ left: layoutStore.gutter, right: layoutStore.gutter, top: 8, bottom: 40 })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .height('100%')
    .scrollBar(BarState.Off)
  }
}
