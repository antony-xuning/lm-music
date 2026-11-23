/**
 * 折叠态紧凑条（华为音乐风上滑折叠后的底部形态）。
 *
 * 左侧独立圆形首页钮与右侧播放器胶囊使用同一套背景折射玻璃参数，视觉与底部 Dock 一致；
 * 首页图标直接复用 Dock 首页页签的资源、选中色与缩放，不再使用品牌色光环/光晕。
 * 胶囊与底部 Dock 同色系（headerGlass 色值，alpha 略低更通透）+ 背景模糊，质感统一、
 * 不透底层花哨光斑；systemMaterial 通用属性在普通容器上真机可能全透明，故用确定性实色方案。
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

  private playIconColor(): string {
    return themeStore.isDark ? '#111113' : '#FFFFFF';
  }

  private playBg(): string {
    return themeStore.isDark ? '#F2FFFFFF' : '#111113';
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
  homeButton() {
    Stack() {
      // 与 BottomDock 首页页签一致：同一资源、选中品牌色、选中态缩放与偏移。
      Image($r('app.media.ic_home'))
        .width(20)
        .height(20)
        .fillColor(themeStore.palette.brand)
        .scale({ x: 1.16, y: 1.16 })
        .translate({ y: -2 })
    }
    .width(DockMetrics.COLLAPSED_HEIGHT)
    .height(DockMetrics.COLLAPSED_HEIGHT)
    .borderRadius(DockMetrics.COLLAPSED_HEIGHT / 2)
    .backgroundColor(this.glassBg())
    .backgroundEffect({ radius: 24, saturation: 1.8, brightness: 1.1 })
    .border({ width: 0.8, color: this.glassEdge() })
    .shadow({ radius: 16, color: themeStore.isDark ? '#33000000' : '#1A000000', offsetX: 0, offsetY: 6 })
    .clip(true)
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
    .backgroundColor(this.glassBg())
    .backgroundEffect({ radius: 24, saturation: 1.8, brightness: 1.1 })
    .border({ width: 0.8, color: this.glassEdge() })
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
