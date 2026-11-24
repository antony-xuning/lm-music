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
import { ImmersiveGlass } from '../common/ImmersiveGlass';
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

  /** 空闲占位标题：无曲目时胶囊仍常驻（华为音乐式）。 */
  private displayTitle(): string {
    const item: PlayableItem | null = playerStore.current;
    return item !== null && item.title.length > 0 ? item.title : '暂无播放';
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

  /** 播放键：仅保留三角/双条图标本身，不再绘制外围玻璃珠圆底。 */
  @Builder
  playButton() {
    Stack() {
      if (playerStore.isPlaying) {
        Image($r('app.media.ic_pause'))
          .width(24)
          .height(24)
          .fillColor(themeStore.palette.text)
          .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })))
      } else {
        Image($r('app.media.ic_play'))
          .width(24)
          .height(24)
          .fillColor(themeStore.palette.text)
          .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })))
      }
    }
    .width(40)
    .height(40)
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
        .width(20)
        .height(20)
        .fillColor(themeStore.palette.text)
    }
    .width(36)
    .height(36)
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
        .width(20)
        .height(20)
        .fillColor(themeStore.palette.text)
    }
    .width(36)
    .height(36)
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

  build() {
    Column() {
      Stack({ alignContent: Alignment.TopStart }) {
          // 层 1：垂直折射渐变（顶部受光、中部通透、底部微沉）。
          Column()
            .width('100%')
            .height('100%')
            .linearGradient({ angle: 180, colors: ImmersiveGlass.barTint() })

          // 层 1.5：沉浸光感——封面主色环境光，光源落在封面处向胶囊四周扩散；
          // 播放时点亮、暂停时收敛，随换曲实时变色。
          Column()
            .width('100%')
            .height('100%')
            .radialGradient({
              center: [30, DockMetrics.PLAYER_HEIGHT / 2],
              radius: 130,
              colors: ImmersiveGlass.ambientStops()
            })
            .opacity(playerStore.isPlaying ? 1 : 0.55)
            .animation({ duration: 600, curve: Curve.EaseInOut })

          // 层 2：内容（进度段 + 控件行）。（原顶部扫光层移除：与描边错位后呈游离白线。）
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
                Text(this.displayTitle())
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
        .backgroundColor(ImmersiveGlass.barBase())
        .backgroundEffect({ radius: 32, saturation: 1.35, brightness: 1.05 })
        .border({ width: 1, color: ImmersiveGlass.barEdge() })
        .shadow({ radius: 26, color: ImmersiveGlass.ambientGlow(), offsetX: 0, offsetY: 10 })
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
    .width('100%')
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
    if (item.isPodcast) {
      return `${item.subtitle} · ${Formatters.duration(playerStore.positionMs)}`;
    }
    return `${item.subtitle} · ${Formatters.duration(playerStore.positionMs)}/${Formatters.duration(playerStore.durationMs)}`;
  }
}

