/**
 * 服务器标签编辑：只读信息、编辑表单、在线匹配候选列表与二次确认写入。
 */
import { ConfirmDialog } from '../components/ConfirmDialog';
import { EmptyState } from '../components/EmptyState';
import { Artwork } from '../components/Artwork';
import { BadgeView } from '../components/Badge';
import { TagCandidate } from '../model/ServerModels';
import { ServerEndpoints } from '../common/ServerEndpoints';
import { TagOpResult } from '../service/TagService';
import { layoutStore } from '../viewmodel/LayoutStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { serverStore } from '../viewmodel/ServerStore';
import { settingsStore } from '../viewmodel/SettingsStore';
import { syncStore } from '../viewmodel/SyncStore';
import { tagStore } from '../viewmodel/TagStore';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct TagEditorView {
  @Param filePath: string = '';
  @Local source: string = 'kw';

  aboutToAppear(): void {
    // 从播放器「更多」半模态进入时，确保浮层已完全收起，避免遮挡本页点击。
    overlayStore.closeSheet();
    this.source = ServerEndpoints.platformCode(settingsStore.prefs.onlineSource);
    if (this.filePath.length > 0) {
      tagStore.load(this.filePath);
    }
  }

  @Monitor('filePath')
  onFilePathChange(): void {
    if (this.filePath.length > 0) {
      tagStore.load(this.filePath);
    }
  }

  private async confirmWrite(): Promise<void> {
    if (!tagStore.writable || tagStore.busy) {
      return;
    }
    const ok: boolean = await ConfirmDialog.confirm(this.getUIContext(), '写入标签',
      '该操作将直接修改服务器上的音频文件标签，且不可撤销。确认写入？', '写入', true);
    if (!ok) {
      return;
    }
    const second: boolean = await ConfirmDialog.confirm(this.getUIContext(), '再次确认',
      '请再次确认写入服务器文件标签。', '确认写入', true);
    if (!second) {
      return;
    }
    const result: TagOpResult = await tagStore.write();
    ConfirmDialog.toast(this.getUIContext(), result.ok ? '标签已写入服务器' : result.error);
    if (result.ok) {
      syncStore.syncNow(true);
    }
  }

  @Builder
  infoHeader() {
    Row({ space: 12 }) {
      Artwork({
        seed: Math.abs(tagStore.info.title.length) % 12,
        artworkSize: 64,
        radius: 16,
        title: tagStore.info.title,
        showRing: false
      })
      Column({ space: 4 }) {
        Text(tagStore.info.title.length > 0 ? tagStore.info.title : '未命名词曲')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(tagStore.info.filePath)
          .fontSize(9.5)
          .fontColor(themeStore.palette.sub)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Row({ space: 6 }) {
          BadgeView({ text: tagStore.info.format.length > 0 ? tagStore.info.format : 'AUDIO', tone: 'glass' })
          BadgeView({
            text: tagStore.info.hasPicture ? '有封面' : '无封面',
            tone: tagStore.info.hasPicture ? 'success' : 'glass'
          })
          BadgeView({
            text: tagStore.info.hasLyric ? '有歌词' : '无歌词',
            tone: tagStore.info.hasLyric ? 'success' : 'glass'
          })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(12)
    .borderRadius(16)
    .backgroundColor(themeStore.palette.card)
  }

  @Builder
  candidateRow(candidate: TagCandidate) {
    Row({ space: 10 }) {
      Artwork({
        seed: Math.abs(candidate.title.length) % 12,
        artworkSize: 40,
        radius: 10,
        title: candidate.title,
        showInitial: false,
        remoteUrl: candidate.coverUrl
      })
      Column({ space: 2 }) {
        Text(candidate.title.length > 0 ? candidate.title : '未知标题')
          .fontSize(12.5)
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${candidate.artist}${candidate.album.length > 0 ? ' · ' + candidate.album : ''}`)
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      BadgeView({ text: ServerEndpoints.platformLabel(candidate.source), tone: 'glass' })
      Text('应用')
        .fontSize(10.5)
        .fontColor('#FFFFFF')
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .borderRadius(10)
        .backgroundColor(themeStore.palette.brand)
        .onClick(() => {
          tagStore.applyCandidate(candidate);
        })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        if (!serverStore.canRead) {
          EmptyState({
            title: '尚未连接柠檬音乐服务器',
            description: '标签编辑仅对服务器本地文件开放',
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand
          })
        } else if (tagStore.loading) {
          EmptyState({ loading: true, title: '正在读取标签' })
        } else if (tagStore.errorText.length > 0) {
          EmptyState({
            title: '读取标签失败',
            description: tagStore.errorText,
            actionText: '重试',
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand,
            onAction: () => {
              tagStore.load(this.filePath);
            }
          })
        } else {
          this.infoHeader()

          Column({ space: 8 }) {
            Row({ space: 8 }) {
              Column({ space: 3 }) {
                Text('标题').fontSize(10).fontColor(themeStore.palette.sub)
                TextInput({ text: tagStore.info.title, placeholder: '标题' })
                  .fontSize(12)
                  .fontColor(themeStore.palette.text)
                  .placeholderColor(themeStore.palette.sub)
                  .height(36)
                  .backgroundColor('#22FFFFFF')
                  .borderRadius(12)
                  .onChange((value: string) => {
                    tagStore.setTitle(value);
                  })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Column({ space: 3 }) {
                Text('歌手').fontSize(10).fontColor(themeStore.palette.sub)
                TextInput({ text: tagStore.info.artist, placeholder: '歌手' })
                  .fontSize(12)
                  .fontColor(themeStore.palette.text)
                  .placeholderColor(themeStore.palette.sub)
                  .height(36)
                  .backgroundColor('#22FFFFFF')
                  .borderRadius(12)
                  .onChange((value: string) => {
                    tagStore.setArtist(value);
                  })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')

            Row({ space: 8 }) {
              Column({ space: 3 }) {
                Text('专辑').fontSize(10).fontColor(themeStore.palette.sub)
                TextInput({ text: tagStore.info.album, placeholder: '专辑' })
                  .fontSize(12)
                  .fontColor(themeStore.palette.text)
                  .placeholderColor(themeStore.palette.sub)
                  .height(36)
                  .backgroundColor('#22FFFFFF')
                  .borderRadius(12)
                  .onChange((value: string) => {
                    tagStore.setAlbum(value);
                  })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Column({ space: 3 }) {
                Text('流派').fontSize(10).fontColor(themeStore.palette.sub)
                TextInput({ text: tagStore.info.genre, placeholder: '流派' })
                  .fontSize(12)
                  .fontColor(themeStore.palette.text)
                  .placeholderColor(themeStore.palette.sub)
                  .height(36)
                  .backgroundColor('#22FFFFFF')
                  .borderRadius(12)
                  .onChange((value: string) => {
                    tagStore.setGenre(value);
                  })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')

            Row({ space: 8 }) {
              Column({ space: 3 }) {
                Text('年份').fontSize(10).fontColor(themeStore.palette.sub)
                TextInput({ text: `${tagStore.info.year}`, placeholder: '年份' })
                  .fontSize(12)
                  .fontColor(themeStore.palette.text)
                  .placeholderColor(themeStore.palette.sub)
                  .height(36)
                  .backgroundColor('#22FFFFFF')
                  .borderRadius(12)
                  .onChange((value: string) => {
                    tagStore.setYear(value);
                  })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Column({ space: 3 }) {
                Text('音轨号').fontSize(10).fontColor(themeStore.palette.sub)
                TextInput({ text: `${tagStore.info.track}`, placeholder: '音轨号' })
                  .fontSize(12)
                  .fontColor(themeStore.palette.text)
                  .placeholderColor(themeStore.palette.sub)
                  .height(36)
                  .backgroundColor('#22FFFFFF')
                  .borderRadius(12)
                  .onChange((value: string) => {
                    tagStore.setTrack(value);
                  })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
          }
          .width('100%')
          .padding(12)
          .borderRadius(16)
          .backgroundColor(themeStore.palette.card)

          Row({ space: 8 }) {
            Text(tagStore.matching ? '匹配中…' : '在线匹配')
              .fontSize(11)
              .fontColor(themeStore.palette.text)
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .borderRadius(14)
              .backgroundColor('#22FFFFFF')
              .onClick(() => {
                tagStore.match(this.source);
              })

            Text(tagStore.busy ? '处理中…' : '写入服务器')
              .fontSize(11)
              .fontColor('#FFFFFF')
              .padding({ left: 12, right: 12, top: 7, bottom: 7 })
              .borderRadius(14)
              .backgroundColor(tagStore.dirty ? themeStore.palette.brand : '#553A3A42')
              .onClick(() => {
                this.confirmWrite();
              })

            Blank()
          }
          .width('100%')

          if (tagStore.matchError.length > 0) {
            Text(tagStore.matchError)
              .fontSize(10.5)
              .fontColor('#FFB44C')
              .width('100%')
          }

          if (tagStore.candidates.length > 0) {
            Column() {
              ForEach(tagStore.candidates, (candidate: TagCandidate, index: number) => {
                this.candidateRow(candidate)
              }, (candidate: TagCandidate, index: number) => `cand_${index}_${candidate.title}`)
            }
            .width('100%')
            .padding({ left: 12, right: 12 })
            .borderRadius(16)
            .backgroundColor(themeStore.palette.card)
          }

          Text('标签写入会直接修改服务器文件，请确认后再执行；在线来源曲目不支持写入。')
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
            .width('100%')
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
