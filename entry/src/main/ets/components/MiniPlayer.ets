/**
 * 独立迷你播放器胶囊（华为音乐风双层底栏的上层）。
 *
 * 背景与底部 Dock 同色系（headerGlass 色值，alpha 略低更通透）+ 背景模糊，
 * 压住底层花哨光斑、呈现与 Dock 一致的玻璃观感；因 systemMaterial 通用属性在普通容器上
 * 真机可能渲染为全透明，故改用确定性的实色 + 模糊，保证可见。文字轻阴影保证可读。
 * 展示封面 / 标题 / 歌手 / 播放暂停 / 下一首 / 队列入口；有进度时显示顶部进度段。
 * 点击非按钮区域打开全屏播放器（走收缩/展开过渡）。
 */
import { DockMetrics } from '../common/Constants';
import { PlayableItem, PlayerStatus } from '../model/MediaModels';
import { colorService } from '../service/ColorService';
import { Formatters } from '../service/Formatters';
import { overlayStore, SheetKind } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { Artwork } from './Artwork';

@ComponentV2
export struct MiniPlayer {
  private currentItem(): PlayableItem {
    const item: PlayableItem | null = playerStore.current;
    if (item === null) {
      return new PlayableItem();
    }
    return item;
  }

  private progressPercent(): string {
    const ratio: number = playerStore.durationMs > 0 ? playerStore.positionMs / playerStore.durationMs : 0;
    const clamped: number = Math.max(0, Math.min(ratio, 1));
    return `${(clamped * 100).toFixed(2)}%`;
  }

  private progressOpacity(): number {
    if (playerStore.status === PlayerStatus.PLAYING) {
      return 1;
    }
    return 0.45;
  }

  /** 只有真正开始播放后才绘制进度段，静默/暂停在 0:00 时不出现任何横线。 */
  private hasProgress(): boolean {
    return playerStore.durationMs > 0 && playerStore.positionMs > 0;
  }

  /** 文字/图标轻阴影：在浅色与深色主题下都能把文字从背景中分离出来。 */
  private textShadowColor(): string {
    return themeStore.isDark ? '#CC000000' : '#B3FFFFFF';
  }

  private controlBg(): string {
    return themeStore.isDark ? '#1FFFFFFF' : '#14000000';
  }

  /** 播放条玻璃底色：与 Dock 的 headerGlass 同色系，低 alpha 只作轻色调，通透靠 backgroundEffect。 */
  private glassBg(): string {
    return themeStore.isDark ? '#1A1A1F73' : '#F7F7FA73';
  }

  /** 玻璃边缘高光：模拟折射的 1px 亮边，深浅主题各取合适对比度。 */
  private glassEdge(): string {
    return themeStore.isDark ? '#2EFFFFFF' : '#4DFFFFFF';
  }

  @Builder
  playButton() {
    Stack() {
      Image(playerStore.isPlaying ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
        .width(18)
        .height(18)
        .fillColor(themeStore.palette.text)
        .shadow({ radius: 3, color: this.textShadowColor(), offsetX: 0, offsetY: 1 })
    }
    .width(34)
    .height(34)
    .borderRadius(17)
    .backgroundColor(this.controlBg())
    .onClick(() => {
      playerStore.toggle();
    })
  }

  @Builder
  nextButton() {
    Stack() {
      Image($r('app.media.ic_next'))
        .width(17)
        .height(17)
        .fillColor(themeStore.palette.text)
        .shadow({ radius: 3, color: this.textShadowColor(), offsetX: 0, offsetY: 1 })
    }
    .width(32)
    .height(32)
    .borderRadius(16)
    .onClick(() => {
      playerStore.next(false);
    })
  }

  @Builder
  queueButton() {
    Stack() {
      Image($r('app.media.ic_queue'))
        .width(17)
        .height(17)
        .fillColor(themeStore.palette.text)
        .shadow({ radius: 3, color: this.textShadowColor(), offsetX: 0, offsetY: 1 })
    }
    .width(32)
    .height(32)
    .borderRadius(16)
    .onClick(() => {
      overlayStore.openSheet(SheetKind.QUEUE, '播放队列');
    })
  }

  build() {
    Column() {
      if (playerStore.current !== null) {
        Stack({ alignContent: Alignment.Top }) {
          Column() {
            // 有进度时才画顶部进度段；不画整条轨道，避免出现横线。
            if (this.hasProgress()) {
              Row() {
                Row()
                  .height(2)
                  .width(this.progressPercent())
                  .linearGradient({
                    angle: 90,
                    colors: [[themeStore.palette.brand, 0.0], [colorService.tintHex, 1.0]]
                  })
              }
              .width('100%')
              .height(2)
              .opacity(this.progressOpacity())
            }

            Row({ space: 10 }) {
              Artwork({
                seed: this.currentItem().coverSeed,
                artworkSize: 40,
                radius: 20,
                title: this.currentItem().title,
                showRing: playerStore.isPlaying,
                remoteUrl: playerStore.coverUri
              })

              Column({ space: 2 }) {
                Text(this.currentItem().title)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor(themeStore.palette.text)
                  .textShadow({ radius: 4, color: this.textShadowColor(), offsetX: 0, offsetY: 1 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.subtitleText())
                  .fontSize(10)
                  .fontColor(themeStore.palette.sub)
                  .textShadow({ radius: 4, color: this.textShadowColor(), offsetX: 0, offsetY: 1 })
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              this.playButton()
              this.nextButton()
              this.queueButton()
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 10, right: 8 })
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .height('100%')
        }
        .width('100%')
        .height(DockMetrics.PLAYER_HEIGHT)
        .borderRadius(DockMetrics.PLAYER_HEIGHT / 2)
        .backgroundColor(this.glassBg())
        .backgroundEffect({ radius: 24, saturation: 1.8, brightness: 1.1 })
        .border({ width: 0.8, color: this.glassEdge() })
        .shadow({ radius: 16, color: themeStore.isDark ? '#33000000' : '#1A000000', offsetX: 0, offsetY: 6 })
        .clip(true)
        .onClick(() => {
          overlayStore.openPlayer();
        })
      }
    }
    .width('100%')
  }

  private subtitleText(): string {
    const item: PlayableItem | null = playerStore.current;
    if (item === null) {
      return '';
    }
    if (playerStore.status === PlayerStatus.LOADING || playerStore.status === PlayerStatus.RESOLVING) {
      return '正在加载…';
    }
    if (playerStore.status === PlayerStatus.ERROR) {
      return playerStore.errorText.length > 0 ? playerStore.errorText : '播放异常';
    }
    if (item.isPodcast) {
      return `${item.subtitle} · ${Formatters.duration(playerStore.positionMs)}`;
    }
    return `${item.subtitle} · ${Formatters.duration(playerStore.positionMs)}/${Formatters.duration(playerStore.durationMs)}`;
  }
}

