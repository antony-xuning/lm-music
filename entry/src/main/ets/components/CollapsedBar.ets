/**
 * 折叠态紧凑条（华为音乐风上滑折叠后的底部形态）。
 *
 * 左侧独立圆形首页钮与右侧播放器胶囊使用同一套背景折射玻璃参数，视觉与底部 Dock 一致；
 * 首页图标直接复用 Dock 首页页签的资源、选中色与缩放，不再使用品牌色光环/光晕。
 * 胶囊与底部 Dock 同色系（headerGlass 色值，alpha 略低更通透）+ 背景模糊，质感统一、
 * 不透底层花哨光斑；systemMaterial 通用属性在普通容器上真机可能全透明，故用确定性实色方案。
 * 无播放时胶囊常驻并显示占位内容（华为音乐式）。
 */
import { DockMetrics } from '../common/Constants';
import { ImmersiveGlass } from '../common/ImmersiveGlass';
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

  /** 空闲占位标题：无曲目时胶囊仍常驻（华为音乐式）。 */
  private displayTitle(): string {
    const item: PlayableItem | null = playerStore.current;
    return item !== null && item.title.length > 0 ? item.title : '暂无播放';
  }

  private goHome(): void {
    overlayStore.setTab(0);
    scrollChrome.reset(0);
    scrollChrome.requestHomeTop();
  }

  private subtitleText(): string {
    const item: PlayableItem | null = playerStore.current;
    if (item === null) {
      return '挑选一首喜欢的歌开始聆听';
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

  @Builder
  homeButton() {
    Stack() {
      // 折射渐变层。
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: ImmersiveGlass.barTint() })

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
    .backgroundColor(ImmersiveGlass.barBase())
    .backgroundEffect({ radius: 32, saturation: 1.35, brightness: 1.05 })
    .border({ width: 1, color: ImmersiveGlass.barEdge() })
    .shadow({ radius: 20, color: ImmersiveGlass.barShadow(), offsetX: 0, offsetY: 8 })
    .clip(true)
    .stateStyles({
      pressed: { .scale({ x: 0.9, y: 0.9 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 130, curve: Curve.EaseOut })
    .onClick(() => {
      this.goHome();
    })
  }

  /** 播放键：仅保留三角/双条图标本身，不再绘制外围玻璃珠圆底。 */
  @Builder
  playButton() {
    Stack() {
      if (playerStore.isPlaying) {
        Image($r('app.media.ic_pause'))
          .width(20)
          .height(20)
          .fillColor(themeStore.palette.text)
          .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })))
      } else {
        Image($r('app.media.ic_play'))
          .width(20)
          .height(20)
          .fillColor(themeStore.palette.text)
          .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })))
      }
    }
    .width(38)
    .height(38)
    .stateStyles({
      pressed: { .scale({ x: 0.86, y: 0.86 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
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
    }
    .width(32)
    .height(32)
    .borderRadius(16)
    .stateStyles({
      pressed: { .scale({ x: 0.86, y: 0.86 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
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
    }
    .width(32)
    .height(32)
    .borderRadius(16)
    .stateStyles({
      pressed: { .scale({ x: 0.86, y: 0.86 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onClick(() => {
      overlayStore.openSheet(SheetKind.QUEUE, '播放队列');
    })
  }

  @Builder
  playerPill() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 层 1：垂直折射渐变。
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: ImmersiveGlass.barTint() })

      // 层 2：内容行。（原顶部扫光层移除：与描边错位后呈游离白线。）
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
          Text(this.displayTitle())
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
      .width('100%')
      .height('100%')
      .padding({ left: 8, right: 6 })
      .alignItems(VerticalAlign.Center)
    }
    .layoutWeight(1)
    .height(DockMetrics.COLLAPSED_HEIGHT)
    .borderRadius(DockMetrics.COLLAPSED_HEIGHT / 2)
    .backgroundColor(ImmersiveGlass.barBase())
    .backgroundEffect({ radius: 32, saturation: 1.35, brightness: 1.05 })
    .border({ width: 1, color: ImmersiveGlass.barEdge() })
    .shadow({ radius: 20, color: ImmersiveGlass.barShadow(), offsetX: 0, offsetY: 8 })
    .clip(true)
    .stateStyles({
      pressed: { .scale({ x: 0.98, y: 0.98 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 130, curve: Curve.EaseOut })
    .onClick(() => {
      overlayStore.openPlayer();
    })
  }

  build() {
    Row({ space: DockMetrics.COLLAPSED_GAP }) {
      this.homeButton()

      this.playerPill()
    }
    .width('100%')
    .height(DockMetrics.COLLAPSED_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }
}
