/**
 * 播放队列面板：当前项高亮、点击切歌、移除。
 */
import { SheetShell } from '../components/SheetShell';
import { Artwork } from '../components/Artwork';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { PlayableItem } from '../model/MediaModels';
import { Formatters } from '../service/Formatters';
import { overlayStore } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct QueueSheet {
  private playAt(index: number): void {
    playerStore.currentIndex = index;
    playerStore.play();
    playerStore.seek(0);
  }

  @Builder
  queueRow(ri: RepeatItem<PlayableItem>) {
    Row({ space: 10 }) {
      Artwork({
        seed: ri.item.coverSeed,
        artworkSize: 40,
        radius: 10,
        title: ri.item.title,
        showRing: ri.index === playerStore.currentIndex
      })

      Column({ space: 2 }) {
        Text(ri.item.title)
          .fontSize(themeStore.font(13))
          .fontColor(ri.index === playerStore.currentIndex ? themeStore.palette.brand : themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(ri.item.subtitle)
          .fontSize(themeStore.font(10))
          .fontColor(themeStore.palette.sub)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text(Formatters.duration(ri.item.durationMs))
        .fontSize(themeStore.font(10))
        .fontColor(themeStore.palette.sub)

      Stack() {
        Image($r('app.media.ic_close'))
          .width(12)
          .height(12)
          .fillColor(themeStore.palette.sub)
      }
      .width(26)
      .height(26)
      .borderRadius(13)
      .stateStyles({
        pressed: { .scale({ x: 0.82, y: 0.82 }).opacity(0.6) },
        normal: { .scale({ x: 1, y: 1 }).opacity(1) }
      })
      .animation({ duration: 120, curve: Curve.EaseOut })
      .onClick(() => {
        playerStore.removeFromQueue(ri.index);
      })
    }
    .width('100%')
    .padding({ top: 7, bottom: 7 })
    .stateStyles({
      pressed: { .scale({ x: 0.98, y: 0.98 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 130, curve: Curve.EaseOut })
    .onClick(() => {
      this.playAt(ri.index);
    })
  }

  build() {
    SheetShell({
      sheetTitle: '播放队列',
      sheetSubtitle: `共 ${playerStore.queue.length} 首`,
      panelColor: themeStore.palette.card,
      textColor: themeStore.palette.text,
      subColor: themeStore.palette.sub,
      onClose: () => {
        overlayStore.closeSheet();
      }
    }) {
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('全部播放')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(13)
            .backgroundColor(themeStore.palette.brand)
            .stateStyles({
              pressed: { .scale({ x: 0.92, y: 0.92 }) },
              normal: { .scale({ x: 1, y: 1 }) }
            })
            .animation({ duration: 120, curve: Curve.EaseOut })
            .onClick(() => {
              if (playerStore.queue.length > 0) {
                playerStore.currentIndex = 0;
                playerStore.seek(0);
                playerStore.play();
              }
            })

          Text('清空队列')
            .fontSize(11)
            .fontColor(themeStore.palette.sub)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .borderRadius(13)
            .backgroundColor(themeStore.palette.controlBg)
            .stateStyles({
              pressed: { .scale({ x: 0.92, y: 0.92 }) },
              normal: { .scale({ x: 1, y: 1 }) }
            })
            .animation({ duration: 120, curve: Curve.EaseOut })
            .onClick(() => {
              ConfirmDialog.confirm(this.getUIContext(), '清空队列', '队列清空后当前播放将停止。', '清空')
                .then((ok: boolean) => {
                  if (ok) {
                    playerStore.clear();
                    overlayStore.closeSheet();
                  }
                });
            })

          Blank()
        }
        .width('100%')

        if (playerStore.queue.length === 0) {
          Text('队列是空的，去发现页挑一首歌吧')
            .fontSize(12)
            .fontColor(themeStore.palette.sub)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 40, bottom: 40 })
        } else {
          List() {
            // Repeat 虚拟滚动：队列长度不设上限，仅创建可视区+预加载区的节点。
            // 队列可能出现重复曲目，键值需带 index 保证唯一（列表不做重排，代价可接受）。
            Repeat<PlayableItem>(playerStore.queue)
              .key((item: PlayableItem, index: number) => `${item.id}_${index}`)
              .each((ri: RepeatItem<PlayableItem>) => {
                ListItem() {
                  this.queueRow(ri)
                }
              })
              .virtualScroll()
          }
          .width('100%')
          .constraintSize({ maxHeight: 420 })
          .divider({ strokeWidth: 0.5, color: themeStore.palette.softDivider })
          .scrollBar(BarState.Off)
          .cachedCount(6)
        }
      }
      .width('100%')
    }
  }
}
