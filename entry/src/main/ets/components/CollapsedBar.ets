/**
 * 折叠态紧凑条（华为音乐风上滑折叠后的底部形态）。
 *
 * 左侧独立圆形首页钮（品牌色光环 + 光晕，与胶囊分离）；
 * 右侧独立玻璃胶囊：封面 + 标题/歌手 + 实心播放钮 + 下一首 + 队列；
 * 完全通透：只有 BlurStyle.Thin 背景模糊 + 柔和投影，不画任何描边/底色。
 * 无播放时只保留首页圆钮，不出现空播放器。
 */
import { DockMetrics } from '../common/Constants';
import { PlayableItem, PlayerStatus } from '../model/MediaModels';
import { overlayStore, SheetKind } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { scrollChrome } from '../viewmodel/ScrollChromeStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { Artwork } from './Artwork';

@ComponentV2
export struct CollapsedBar {
  private currentItem(): PlayableItem {
    const item: PlayableItem | null = playerStore.current;
    if (item === null) {
      return new PlayableItem();
    }
    return item;
  }

  private goHome(): void {
    overlayStore.setTab(0);
    scrollChrome.reset(0);
    scrollChrome.requestHomeTop();
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
    return item.subtitle.length > 0 ? item.subtitle : '未知歌手';
  }

  /** 文字/图标轻阴影：深浅色主题下都能把文字从背景中分离出来。 */
  private textShadowColor(): string {
    return themeStore.isDark ? '#CC000000' : '#B3FFFFFF';
  }

  private homeGlow(): string {
    return themeStore.isDark ? '#59FA2D48' : '#40FA2D48';
  }

  private playIconColor(): string {
    return themeStore.isDark ? '#111113' : '#FFFFFF';
  }

  private playBg(): string {
    return themeStore.isDark ? '#F2FFFFFF' : '#111113';
  }

  @Builder
  homeButton() {
    Stack() {
      Image($r('app.media.ic_home'))
        .width(22)
        .height(22)
        .fillColor(themeStore.palette.brand)
        .shadow({ radius: 10, color: this.homeGlow(), offsetX: 0, offsetY: 0 })
    }
    .width(DockMetrics.COLLAPSED_HEIGHT)
    .height(DockMetrics.COLLAPSED_HEIGHT)
    .borderRadius(DockMetrics.COLLAPSED_HEIGHT / 2)
    .backgroundBlurStyle(BlurStyle.Thin)
    .border({ width: 1.5, color: themeStore.isDark ? '#99FF7A45' : '#B3FA2D48' })
    .radialGradient({
      center: [DockMetrics.COLLAPSED_HEIGHT / 2, DockMetrics.COLLAPSED_HEIGHT / 2],
      radius: DockMetrics.COLLAPSED_HEIGHT / 2,
      colors: [
        ['#00FA2D48', 0.0],
        ['#14FA2D48', 0.62],
        ['#59FA2D48', 0.86],
        ['#CCFF7A45', 1.0]
      ]
    })
    .shadow({ radius: 18, color: this.homeGlow(), offsetX: 0, offsetY: 0 })
    .onClick(() => {
      this.goHome();
    })
  }

  @Builder
  playButton() {
    Stack() {
      Image(playerStore.isPlaying ? $r('app.media.ic_pause') : $r('app.media.ic_play'))
        .width(18)
        .height(18)
        .fillColor(this.playIconColor())
    }
    .width(38)
    .height(38)
    .borderRadius(19)
    .backgroundColor(this.playBg())
    .onClick(() => {
      playerStore.toggle();
    })
  }

  @Builder
  nextButton() {
    Stack() {
      Image($r('app.media.ic_next'))
        .width(19)
        .height(19)
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
        .width(19)
        .height(19)
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

  @Builder
  playerPill() {
    Row({ space: 8 }) {
      Artwork({
        seed: this.currentItem().coverSeed,
        artworkSize: 44,
        radius: 22,
        title: this.currentItem().title,
        showRing: playerStore.isPlaying,
        remoteUrl: playerStore.coverUri
      })

      Column({ space: 2 }) {
        Text(this.currentItem().title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor(themeStore.palette.text)
          .textShadow({ radius: 4, color: this.textShadowColor(), offsetX: 0, offsetY: 1 })
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.subtitleText())
          .fontSize(12)
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
    .layoutWeight(1)
    .height(DockMetrics.COLLAPSED_HEIGHT)
    .padding({ left: 8, right: 6 })
    .borderRadius(DockMetrics.COLLAPSED_HEIGHT / 2)
    .backgroundBlurStyle(BlurStyle.Thin)
    .shadow({ radius: 16, color: themeStore.isDark ? '#33000000' : '#1A000000', offsetX: 0, offsetY: 6 })
    .clip(true)
    .onClick(() => {
      overlayStore.openPlayer();
    })
  }

  build() {
    Row({ space: DockMetrics.COLLAPSED_GAP }) {
      this.homeButton()

      if (playerStore.current !== null) {
        this.playerPill()
      } else {
        Blank()
      }
    }
    .width('100%')
    .height(DockMetrics.COLLAPSED_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }
}
