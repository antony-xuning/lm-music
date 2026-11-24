/**
 * 全屏播放器叠层（华为音乐式沉浸布局）。
 *
 * 封面铺满整屏作为背景，底部依次为：歌词预览、标题/歌手、音质/来源徽章、
 * 操作行、进度条；点击歌词预览进入全歌词页（LyricsPanel 全屏滚动）。
 * 收缩/展开过渡：由 `progress`（0=迷你播放器/折叠胶囊矩形，1=全屏）驱动
 * 外层容器的尺寸/位移/圆角/透明度与内容缩放，内容按整屏尺寸只排一次、
 * 之后靠 scale 缩放，避免文字重排与封面闪白（FR-163/168）。
 */
import { GradientHelper } from '../common/Palette';
import { window } from '@kit.ArkUI';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { AppSlider } from '../components/AppSlider';
import { MediaSource, MediaSourceHelper, PlayableItem, PlayMode, PlayModeHelper, PlayerStatus, Song } from '../model/MediaModels';
import { LyricDoc, LyricLine } from '../model/LyricModels';
import { Formatters } from '../service/Formatters';
import { LyricParser } from '../service/LyricParser';
import { overlayStore, SheetKind } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { libraryStore } from '../viewmodel/LibraryStore';
import { PlayerTargetRect, playerTransition } from '../viewmodel/PlayerTransitionStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { DockMetrics } from '../common/Constants';
import { LyricsPanel } from './LyricsPanel';

@ComponentV2
export struct FullscreenPlayer {
  @Local fullLyrics: boolean = false;
  @Local dragOffset: number = 0;
  @Local dragValue: number = 0;
  @Local dragging: boolean = false;
  @Local previewDoc: LyricDoc = LyricDoc.empty();
  @Local previewIndex: number = -1;
  /** 状态栏高度：全屏时把封面背景向上延伸进状态栏，形成沉浸式效果。 */
  @Local topInset: number = 0;
  /** 收缩/展开进度：0 = 迷你播放器矩形，1 = 全屏。 */
  @Param progress: number = 1;
  @Param targetRect: PlayerTargetRect = new PlayerTargetRect();
  /** 播放器所在层的实时尺寸（旋转/分屏后随父组件更新，保证内容跟随窗口）。 */
  @Param stageWidthValue: number = 0;
  @Param stageHeightValue: number = 0;
  /**
   * 组件内部的补间值：progress 变化时用 animateTo 从当前值过渡到新值。
   * 直接对 @Param 做属性动画不生效（父组件同步不在动画上下文内），
   * 因此由本组件的 @Local 承载补间。
   */
  @Local morph: number = 0;

  private previewTrackId: string = '';
  private previewLyricText: string = '';
  private previewTimer: number = -1;

  aboutToAppear(): void {
    this.morph = this.progress;
    this.fullLyrics = false;
    this.resolveTopInset();
    playerTransition.notifyMounted();
    this.tickPreview();
    this.previewTimer = setInterval(() => {
      this.tickPreview();
    }, 280);
  }

  /** 读取状态栏避让高度（vp），用于把封面背景延伸进状态栏。 */
  private resolveTopInset(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      return;
    }
    window.getLastWindow(ctx).then((win: window.Window) => {
      const area: window.AvoidArea = win.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      this.topInset = this.getUIContext().px2vp(area.topRect.height);
    }).catch(() => {});
  }
  aboutToDisappear(): void {
    playerTransition.notifyUnmounted();
    this.fullLyrics = false;
    if (this.previewTimer >= 0) {
      clearInterval(this.previewTimer);
      this.previewTimer = -1;
    }
  }

  /** progress 变化（打开/关闭/中断）：从当前补间值平滑过渡到目标值。 */
  @Monitor('progress')
  onProgressChange(monitor: IMonitor): void {
    const target: number = this.progress;
    if (Math.abs(target - this.morph) < 0.0005) {
      this.morph = target;
      return;
    }
    this.getUIContext().animateTo({
      duration: playerTransition.animationDuration,
      curve: Curve.FastOutSlowIn
    }, () => {
      this.morph = target;
    });
  }

  private stageWidth(): number {
    if (this.stageWidthValue > 1) {
      return this.stageWidthValue;
    }
    return this.targetRect.screenWidth > 1 ? this.targetRect.screenWidth : 360;
  }

  private stageHeight(): number {
    if (this.stageHeightValue > 1) {
      return this.stageHeightValue;
    }
    return this.targetRect.screenHeight > 1 ? this.targetRect.screenHeight : 780;
  }

  private morphProgress(): number {
    const value: number = this.morph;
    return value < 0 ? 0 : (value > 1 ? 1 : value);
  }

  private lerp(from: number, to: number, ratio: number): number {
    return from + (to - from) * ratio;
  }

  private morphWidth(): number {
    const target: number = this.targetRect.width > 0 ? this.targetRect.width : this.stageWidth();
    return this.lerp(target, this.stageWidth(), this.morphProgress());
  }

  private morphHeight(): number {
    const target: number = this.targetRect.height > 0 ? this.targetRect.height : this.stageHeight();
    const result: number = this.lerp(target, this.stageHeight(), this.morphProgress());
    return result;
  }

  private morphX(): number {
    return this.lerp(this.targetRect.left, 0, this.morphProgress());
  }

  private morphY(): number {
    return this.lerp(this.targetRect.top, 0, this.morphProgress());
  }

  /** 起点为胶囊圆角（高/2），全屏时归零；目标接近整屏（降级）时全程无圆角。 */
  private morphRadius(): number {
    const target: number = this.targetRect.height;
    if (target <= 0 || target > this.stageHeight() * 0.85) {
      return 0;
    }
    return this.lerp(target / 2, 0, this.morphProgress());
  }

  private contentScaleX(): number {
    const stage: number = this.stageWidth();
    return stage > 1 ? this.morphWidth() / stage : 1;
  }

  private contentScaleY(): number {
    const stage: number = this.stageHeight();
    return stage > 1 ? this.morphHeight() / stage : 1;
  }

  /** 透明度随 progress 快速拉满，避免缩放初期出现半透明重影。 */
  private morphOpacity(): number {
    return Math.min(1, this.morphProgress() * 5);
  }

  private current(): PlayableItem | null {
    return playerStore.current;
  }

  private titleText(): string {
    const item: PlayableItem | null = this.current();
    return item !== null ? item.title : '未在播放';
  }

  private subtitleText(): string {
    const item: PlayableItem | null = this.current();
    if (item === null) {
      return '';
    }
    return item.isPodcast ? `${item.subtitle} · 播客` : item.subtitle;
  }

  private coverUri(): string {
    if (playerStore.coverUri.length > 0) {
      return playerStore.coverUri;
    }
    const item: PlayableItem | null = this.current();
    return item !== null ? item.coverUrl : '';
  }

  private artworkSeed(): number {
    const item: PlayableItem | null = this.current();
    return item !== null ? item.coverSeed : 0;
  }

  private qualityText(): string {
    const item: PlayableItem | null = this.current();
    if (item === null) {
      return '';
    }
    if (item.qualitys.length > 0) {
      return item.qualitys;
    }
    if (item.songId.length > 0) {
      const song: Song | null = libraryStore.findSong(item.songId);
      if (song !== null) {
        return Formatters.qualityBadge(song.format, song.bitRate);
      }
    }
    return item.isPodcast ? '播客音频' : '';
  }

  private sourceOfItem(): MediaSource {
    const item: PlayableItem | null = this.current();
    return item !== null ? item.mediaSource : MediaSource.LOCAL;
  }

  private liked(): boolean {
    const item: PlayableItem | null = this.current();
    if (item === null || item.songId.length === 0) {
      return false;
    }
    return libraryStore.isFavorite(item.songId);
  }

  private sliderValue(): number {
    if (this.dragging) {
      return this.dragValue;
    }
    return playerStore.positionMs;
  }

  private sliderMax(): number {
    return playerStore.durationMs > 0 ? playerStore.durationMs : 18000;
  }

  private reloadPreviewIfNeeded(): void {
    const item: PlayableItem | null = this.current();
    const trackId: string = item !== null ? item.id : '';
    const text: string = playerStore.lyricText;
    if (trackId === this.previewTrackId && text === this.previewLyricText) {
      return;
    }
    this.previewTrackId = trackId;
    this.previewLyricText = text;
    this.previewDoc = LyricParser.parse(text);
    this.previewIndex = -1;
  }

  private tickPreview(): void {
    this.reloadPreviewIfNeeded();
    if (!this.previewDoc.isSynced) {
      return;
    }
    const index: number = LyricParser.activeIndex(this.previewDoc, playerStore.positionMs,
      overlayStore.lyricOffsetMs);
    if (index !== this.previewIndex) {
      this.previewIndex = index;
    }
  }

  private previewLine(): string {
    if (!this.previewDoc.isSynced || this.previewDoc.lines.length === 0) {
      return '';
    }
    const index: number = this.previewIndex < 0 ? 0 : this.previewIndex;
    if (index >= this.previewDoc.lines.length) {
      return '';
    }
    return this.previewDoc.lines[index].text;
  }

  private nextLine(): string {
    if (!this.previewDoc.isSynced) {
      return '';
    }
    const index: number = (this.previewIndex < 0 ? 0 : this.previewIndex) + 1;
    if (index >= this.previewDoc.lines.length) {
      return '';
    }
    const line: LyricLine = this.previewDoc.lines[index];
    return line.text;
  }

  private openLyrics(): void {
    if (this.fullLyrics) {
      return;
    }
    this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.fullLyrics = true;
    });
  }

  private closeLyrics(): void {
    if (!this.fullLyrics) {
      return;
    }
    this.getUIContext().animateTo({ duration: 200, curve: Curve.EaseOut }, () => {
      this.fullLyrics = false;
    });
  }

  private collapseOrBack(): void {
    if (this.fullLyrics) {
      this.closeLyrics();
      return;
    }
    overlayStore.closePlayer();
  }

  private toggleFavorite(): void {
    const item: PlayableItem | null = this.current();
    if (item === null || item.songId.length === 0) {
      return;
    }
    libraryStore.toggleFavorite(item.songId).then((outcome) => {
      ConfirmDialog.toast(this.getUIContext(), outcome.message);
    });
  }
  @Builder
  navButton(icon: Resource, action: number) {
    Stack() {
      Image(icon)
        .width(20)
        .height(20)
        .fillColor('#FFFFFF')
    }
    .width(38)
    .height(38)
    .borderRadius(19)
    .backgroundColor('#1FFFFFFF')
    .stateStyles({
      pressed: { .scale({ x: 0.86, y: 0.86 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onClick(() => {
      if (action === 0) {
        this.collapseOrBack();
      } else if (action === 1) {
        this.closeLyrics();
      } else {
        overlayStore.openSheet(SheetKind.MORE, '更多操作');
      }
    })
  }

  /** 参考稿样式：无底色纯图标按钮（action：0 收起 1 返回歌词 2 更多 3 切换播放模式）。 */
  @Builder
  plainButton(icon: Resource, action: number) {
    Stack() {
      Image(icon)
        .width(22)
        .height(22)
        .fillColor('#FFFFFF')
    }
    .width(42)
    .height(42)
    .stateStyles({
      pressed: { .scale({ x: 0.86, y: 0.86 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onClick(() => {
      if (action === 0) {
        this.collapseOrBack();
      } else if (action === 1) {
        this.closeLyrics();
      } else if (action === 2) {
        overlayStore.openSheet(SheetKind.MORE, '更多操作');
      } else {
        playerStore.cycleMode();
        ConfirmDialog.toast(this.getUIContext(), PlayModeHelper.label(playerStore.mode));
      }
    })
  }

  /** 播放模式按钮：图标随模式缩放淡切（列表循环 / 单曲循环 / 随机播放）。 */
  @Builder
  modeButton() {
    Stack() {
      if (playerStore.mode === PlayMode.SINGLE_LOOP) {
        Image($r('app.media.ic_repeat_one'))
          .width(22)
          .height(22)
          .fillColor('#FFFFFF')
          .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })))
      } else if (playerStore.mode === PlayMode.SHUFFLE) {
        Image($r('app.media.ic_shuffle'))
          .width(22)
          .height(22)
          .fillColor('#FFFFFF')
          .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })))
      } else {
        Image($r('app.media.ic_repeat'))
          .width(22)
          .height(22)
          .fillColor('#FFFFFF')
          .transition(TransitionEffect.OPACITY.animation({ duration: 180, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })))
      }
    }
    .width(42)
    .height(42)
    .stateStyles({
      pressed: { .scale({ x: 0.86, y: 0.86 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onClick(() => {
      playerStore.cycleMode();
      ConfirmDialog.toast(this.getUIContext(), PlayModeHelper.label(playerStore.mode));
    })
  }

  @Builder
  artworkBackground() {
    Stack({ alignContent: Alignment.TopStart }) {
      if (this.coverUri().length > 0) {
        Image(this.coverUri())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      } else {
        Column()
          .width('100%')
          .height('100%')
          .linearGradient({
            angle: 150,
            colors: [[GradientHelper.pair(this.artworkSeed()).start, 0.0],
              [GradientHelper.pair(this.artworkSeed()).end, 0.55], ['#0B0B10', 1.0]]
          })
      }

      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          // 参考稿效果：封面中上部保持鲜亮，向下渐隐为深色承托文字与控件。
          angle: 180,
          colors: [['#40000000', 0.0], ['#14000000', 0.30], ['#B30B0B10', 0.64],
            ['#F20B0B10', 0.90], ['#F70B0B10', 1.0]]
        })
    }
    .width('100%')
    .height(this.stageHeight() + this.topInset)
    .offset({ y: -this.topInset })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }
  @Builder
  coverHeader() {
    Row({ space: 6 }) {
      this.plainButton($r('app.media.ic_chevron_down'), 0)
      Blank()
      this.modeButton()
      this.plainButton($r('app.media.ic_more'), 2)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 8 })
    .alignItems(VerticalAlign.Center)
    .gesture(
      PanGesture({ direction: PanDirection.Vertical })
        .onActionUpdate((event: GestureEvent) => {
          this.dragOffset = Math.max(event.offsetY, 0);
        })
        .onActionEnd(() => {
          if (this.dragOffset > 90) {
            overlayStore.closePlayer();
          }
          this.dragOffset = 0;
        })
    )
  }
  @Builder
  lyricsHeader() {
    Row({ space: 12 }) {
      this.navButton($r('app.media.ic_back'), 1)

      Column({ space: 2 }) {
        Text(this.titleText())
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.subtitleText())
          .fontSize(11)
          .fontColor('#B3FFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('Aa')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .borderRadius(16)
        .backgroundColor('#1FFFFFFF')
        .stateStyles({
          pressed: { .scale({ x: 0.92, y: 0.92 }) },
          normal: { .scale({ x: 1, y: 1 }) }
        })
        .animation({ duration: 120, curve: Curve.EaseOut })
        .onClick(() => {
          overlayStore.openSheet(SheetKind.LYRIC_ADJUST, '歌词显示');
        })

      this.navButton($r('app.media.ic_more'), 2)
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 8, bottom: 6 })
    .alignItems(VerticalAlign.Center)
  }
  @Builder
  lyricsPreview() {
    Column({ space: 8 }) {
      if (this.previewDoc.isSynced) {
        Text(this.previewLine())
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
        Text(this.nextLine())
          .fontSize(17)
          .fontColor('#A6FFFFFF')
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
          .textAlign(TextAlign.Start)
      } else {
        Text('暂无歌词')
          .fontSize(21)
          .fontWeight(FontWeight.Medium)
          .fontColor('#D9FFFFFF')
          .width('100%')
        Text('点击查看歌词')
          .fontSize(13)
          .fontColor('#80FFFFFF')
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .padding({ top: 6, bottom: 6 })
    .onClick(() => {
      this.openLyrics();
    })
  }
  @Builder
  titleBlock() {
    Column({ space: 7 }) {
      Text(this.titleText())
        .fontSize(themeStore.font(30))
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .textAlign(TextAlign.Start)

      Row({ space: 8 }) {
        Text(this.subtitleText())
          .fontSize(themeStore.font(14))
          .fontColor('#CCFFFFFF')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)

        // 参考稿中歌手右侧的 VIP 样式徽章，此处承载音源标识。
        Text(MediaSourceHelper.label(this.sourceOfItem()))
          .fontSize(10)
          .fontColor(themeStore.palette.brand)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .borderRadius(6)
          .border({ width: 1, color: themeStore.palette.brand })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
  @Builder
  badges() {
    Row({ space: 8 }) {
      if (this.qualityText().length > 0) {
        Row() {
          Text('音质')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#3A2A12')
            .padding({ left: 9, right: 8, top: 5, bottom: 5 })
            .backgroundColor('#F0D9A8')
          Text(this.qualityText())
            .fontSize(11)
            .fontColor('#F0D9A8')
            .padding({ left: 8, right: 9, top: 5, bottom: 5 })
            .backgroundColor('#40301C')
        }
        .borderRadius(7)
        .clip(true)
      }
    }
    .width('100%')
  }
  @Builder
  heartButton() {
    Stack() {
      if (this.liked()) {
        Image($r('app.media.ic_heart_fill'))
          .width(24)
          .height(24)
          .fillColor(themeStore.palette.brand)
          .transition(TransitionEffect.OPACITY.animation({ duration: 240, curve: Curve.Friction })
            .combine(TransitionEffect.scale({ x: 1.5, y: 1.5 })))
      } else {
        Image($r('app.media.ic_heart'))
          .width(24)
          .height(24)
          .fillColor('#F2FFFFFF')
          .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.75, y: 0.75 })))
      }
    }
    .width(44)
    .height(44)
    .borderRadius(22)
    .stateStyles({
      pressed: { .scale({ x: 0.86, y: 0.86 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onClick(() => {
      this.toggleFavorite();
    })
  }

  @Builder
  queueButton() {
    Stack() {
      Image($r('app.media.ic_queue'))
        .width(23)
        .height(23)
        .fillColor('#F2FFFFFF')
    }
    .width(44)
    .height(44)
    .borderRadius(22)
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
  prevButton() {
    if (playerStore.isPodcast) {
      Stack() {
        Text('-15')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F2FFFFFF')
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .stateStyles({
        pressed: { .scale({ x: 0.86, y: 0.86 }) },
        normal: { .scale({ x: 1, y: 1 }) }
      })
      .animation({ duration: 120, curve: Curve.EaseOut })
      .onClick(() => {
        playerStore.seekBy(-15000);
      })
    } else {
      Stack() {
        Image($r('app.media.ic_prev'))
          .width(24)
          .height(24)
          .fillColor('#F2FFFFFF')
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .stateStyles({
        pressed: { .scale({ x: 0.86, y: 0.86 }) },
        normal: { .scale({ x: 1, y: 1 }) }
      })
      .animation({ duration: 120, curve: Curve.EaseOut })
      .onClick(() => {
        playerStore.previous();
      })
    }
  }

  @Builder
  nextButton() {
    if (playerStore.isPodcast) {
      Stack() {
        Text('+15')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#F2FFFFFF')
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .stateStyles({
        pressed: { .scale({ x: 0.86, y: 0.86 }) },
        normal: { .scale({ x: 1, y: 1 }) }
      })
      .animation({ duration: 120, curve: Curve.EaseOut })
      .onClick(() => {
        playerStore.seekBy(15000);
      })
    } else {
      Stack() {
        Image($r('app.media.ic_next'))
          .width(24)
          .height(24)
          .fillColor('#F2FFFFFF')
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .stateStyles({
        pressed: { .scale({ x: 0.86, y: 0.86 }) },
        normal: { .scale({ x: 1, y: 1 }) }
      })
      .animation({ duration: 120, curve: Curve.EaseOut })
      .onClick(() => {
        playerStore.next(false);
      })
    }
  }

  @Builder
  playButton(size: number, iconSize: number) {
    Stack() {
      if (playerStore.status === PlayerStatus.PLAYING) {
        Image($r('app.media.ic_pause'))
          .width(iconSize)
          .height(iconSize)
          .fillColor('#111113')
          .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })))
      } else {
        Image($r('app.media.ic_play'))
          .width(iconSize)
          .height(iconSize)
          .fillColor('#111113')
          .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })))
      }
    }
    .width(size)
    .height(size)
    .borderRadius(size / 2)
    .backgroundColor('#F2FFFFFF')
    .shadow({ radius: 16, color: '#40000000', offsetX: 0, offsetY: 6 })
    .stateStyles({
      pressed: { .scale({ x: 0.9, y: 0.9 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onClick(() => {
      playerStore.toggle();
    })
  }

  /** 参考稿样式：白色大胶囊播放/暂停键。 */
  @Builder
  pillPlayButton() {
    Stack() {
      if (playerStore.status === PlayerStatus.PLAYING) {
        Image($r('app.media.ic_pause'))
          .width(24)
          .height(24)
          .fillColor('#111113')
          .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })))
      } else {
        Image($r('app.media.ic_play'))
          .width(24)
          .height(24)
          .fillColor('#111113')
          .transition(TransitionEffect.OPACITY.animation({ duration: 160, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.7, y: 0.7 })))
      }
    }
    .width(78)
    .height(54)
    .borderRadius(27)
    .backgroundColor('#F5FFFFFF')
    .shadow({ radius: 18, color: '#4D000000', offsetX: 0, offsetY: 8 })
    .stateStyles({
      pressed: { .scale({ x: 0.94, y: 0.94 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onClick(() => {
      playerStore.toggle();
    })
  }

  @Builder
  actionRow() {
    Row({ space: 8 }) {
      this.heartButton()
      this.queueButton()
      Stack() {
        Image($r('app.media.ic_more'))
          .width(22)
          .height(22)
          .fillColor('#F2FFFFFF')
      }
      .width(44)
      .height(44)
      .borderRadius(22)
      .stateStyles({
        pressed: { .scale({ x: 0.86, y: 0.86 }) },
        normal: { .scale({ x: 1, y: 1 }) }
      })
      .animation({ duration: 120, curve: Curve.EaseOut })
      .onClick(() => {
        overlayStore.openSheet(SheetKind.MORE, '更多操作');
      })

      Blank()

      this.pillPlayButton()
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ right: 2 })
  }

  @Builder
  progressBlock(compact: boolean) {
    Column({ space: 4 }) {
      AppSlider({
        sliderValue: this.sliderValue(),
        minValue: 0,
        maxValue: this.sliderMax(),
        stepValue: 100,
        accent: '#FFFFFF',
        trackColor: '#33FFFFFF',
        onValueChange: (value: number) => {
          this.dragging = true;
          this.dragValue = value;
        },
        onValueFinish: (value: number) => {
          playerStore.seek(value);
          this.dragging = false;
        }
      })

      Row() {
        Text(Formatters.duration(this.sliderValue()))
          .fontSize(compact ? 10 : 11)
          .fontColor('#B3FFFFFF')
        Blank()
        Text(Formatters.duration(this.sliderMax()))
          .fontSize(compact ? 10 : 11)
          .fontColor('#B3FFFFFF')
      }
      .width('100%')
    }
    .width('100%')
  }

  @Builder
  bottomBlock() {
    Column({ space: 10 }) {
      // 参考稿：歌词预览/标题/徽章区域左右滑动切歌（播客为 ±15s），
      // 进度条与按钮不在此区域内，避免手势冲突。
      Column({ space: 10 }) {
        this.lyricsPreview()
        this.titleBlock()
        this.badges()
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .gesture(
        SwipeGesture({ direction: SwipeDirection.Horizontal, fingers: 1 })
          .onAction((event: GestureEvent) => {
            if (event.offsetX < 0) {
              if (playerStore.isPodcast) {
                playerStore.seekBy(15000);
              } else {
                playerStore.next(false);
              }
            } else if (playerStore.isPodcast) {
              playerStore.seekBy(-15000);
            } else {
              playerStore.previous();
            }
          })
      )

      this.actionRow()
      this.progressBlock(false)
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    // 底部保留悬浮页签栏（Index 中渲染的 dock 副本），内容避让其高度。
    .padding({ left: 22, right: 22, bottom: DockMetrics.BOTTOM_MARGIN + DockMetrics.TAB_BAR_HEIGHT +
      DockMetrics.CONTENT_BREATHING + 8 })
  }

  @Builder
  coverView() {
    Column() {
      this.coverHeader()
      Blank()
      this.bottomBlock()
    }
    .width('100%')
    .height('100%')
    .translate({ y: this.dragOffset })
    .transition(TransitionEffect.OPACITY.animation({ duration: 160 }))
  }

  @Builder
  lyricsView() {
    Stack({ alignContent: Alignment.TopStart }) {
      Column()
        .width('100%')
        .height(this.stageHeight() + this.topInset)
        .offset({ y: -this.topInset })
        .backgroundColor('#6B0B0B10')
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Column() {
        this.lyricsHeader()

        Column() {
          LyricsPanel({ idleColor: '#99FFFFFF' })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 8, right: 8 })

        Column({ space: 8 }) {
          this.progressBlock(true)
          Row({ space: 30 }) {
            this.prevButton()
            this.playButton(52, 21)
            this.nextButton()
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(VerticalAlign.Center)
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 4, bottom: DockMetrics.BOTTOM_MARGIN +
          DockMetrics.TAB_BAR_HEIGHT + DockMetrics.CONTENT_BREATHING + 8 })
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .translate({ y: this.dragOffset })
    .transition(TransitionEffect.OPACITY.animation({ duration: 160 }))
  }

  build() {
    // 外层铺满：收缩/展开时由 morph box 的尺寸 + 位移 + 圆角 + 内容缩放完成过渡。
    Stack({ alignContent: Alignment.TopStart }) {
      Stack({ alignContent: Alignment.TopStart }) {
        // 内容按整屏尺寸只排版一次（不随过渡重排），由 scale 跟随容器缩放。
        Stack({ alignContent: Alignment.TopStart }) {
          this.artworkBackground()

          if (this.fullLyrics) {
            this.lyricsView()
          } else {
            this.coverView()
          }
        }
        .width(this.stageWidth())
        .height(this.stageHeight())
        .scale({ x: this.contentScaleX(), y: this.contentScaleY(), centerX: 0, centerY: 0 })
      }
      .width(this.morphWidth())
      .height(this.morphHeight())
      .offset({ x: this.morphX(), y: this.morphY() })
      .borderRadius(this.morphRadius())
      .opacity(this.morphOpacity())
      .clip(this.morphProgress() < 0.999)
      .backgroundColor(themeStore.palette.bg)
    }
    .width('100%')
    .height('100%')
  }
}

