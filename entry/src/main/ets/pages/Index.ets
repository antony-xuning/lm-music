/**
 * 唯一 @Entry 页面：Navigation(STACK) + Tabs 四页签 + 合并 Glass Dock + 覆盖层插槽。
 */
import { display } from '@kit.ArkUI';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BottomDock } from '../components/BottomDock';
import { MiniPlayer } from '../components/MiniPlayer';
import { CollapsedBar } from '../components/CollapsedBar';
import { AddToPlaylistSheet } from '../components/AddToPlaylistSheet';
import { ServerEditSheet } from '../components/ServerEditSheet';
import { HomeView } from '../views/HomeView';
import { LibraryView } from '../views/LibraryView';
import { DownloadView } from '../views/DownloadView';
import { SettingsView } from '../views/SettingsView';
import { PodcastHomeView } from '../views/PodcastHomeView';
import { SearchView } from '../views/SearchView';
import { searchStore } from '../viewmodel/SearchStore';
import { podcastStore } from '../viewmodel/PodcastStore';
import { PodcastShowParam } from '../model/UiModels';
import { downloadStore } from '../viewmodel/DownloadStore';
import { DiscoverCollectionParam, LibraryDetailParam } from '../model/UiModels';
import { FullscreenPlayer } from '../player/FullscreenPlayer';
import { LyricAdjustSheet, LyricPrefs } from '../player/LyricAdjustSheet';
import { QueueSheet } from '../player/QueueSheet';
import { PlayerMoreSheet } from '../player/PlayerMoreSheet';
import { SheetKind } from '../viewmodel/OverlayStore';
import { AppConstants, DockMetrics } from '../common/Constants';
import { ImmersiveGlass } from '../common/ImmersiveGlass';
import { themeStore } from '../viewmodel/ThemeStore';
import { layoutStore } from '../viewmodel/LayoutStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { PlayerTargetRect, PlayerTransitionPhase, playerTransition } from '../viewmodel/PlayerTransitionStore';
import { settingsStore } from '../viewmodel/SettingsStore';
import { libraryStore } from '../viewmodel/LibraryStore';
import { localScanStore } from '../viewmodel/LocalScanStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { scrollChrome } from '../viewmodel/ScrollChromeStore';
import { discoverStore } from '../viewmodel/DiscoverStore';
import { serverStore } from '../viewmodel/ServerStore';
import { syncStore } from '../viewmodel/SyncStore';
import { sourceStore } from '../viewmodel/SourceStore';
import { tagStore } from '../viewmodel/TagStore';
import { routeBridge } from '../viewmodel/RouteBridge';
import { Logger } from '../common/Logger';
import { LegacyMigration } from '../data/LegacyMigration';
import { ThemeMode } from '../model/SettingsModels';

const SCOPE: string = 'Index';

@Entry
@ComponentV2
struct Index {
  pathStack: NavPathStack = new NavPathStack();
  @Local sheetShown: boolean = false;
  @Local dockBarWidth: number = 360;
  /** 播放器所在层的实际宽高（vp）：随旋转/分屏变化，用于重算收缩落点。 */
  @Local stageWidth: number = 360;
  @Local stageHeight: number = 780;
  private closeTimer: number = -1;
  /** 保存回调引用，页面卸载时才能 display.off 成对解绑。 */
  private displayChangeCallback: (id: number) => void = () => {
  };

  aboutToAppear(): void {
    overlayStore.setSheetListener((visible: boolean) => {
      this.sheetShown = visible;
    });
    playerTransition.refreshReduceMotion();
    playerTransition.setHiddenListener(() => {
      overlayStore.syncPlayerVisible(false);
    });
    overlayStore.setPlayerPresenter({
      presentPlayer: () => {
        this.presentPlayer();
      },
      dismissPlayer: () => {
        this.dismissPlayer();
      }
    });
    layoutStore.attach(this.getUIContext());
    this.updateDockWidth();
    this.displayChangeCallback = (id: number): void => {
      this.updateDockWidth();
    };
    try {
      display.on('change', this.displayChangeCallback);
    } catch (error) {
      Logger.warn(SCOPE, 'display listener unavailable');
    }
    routeBridge.register((name: string, param: Object | null) => {
      if (param === null) {
        this.pathStack.pushPathByName(name, null);
      } else {
        this.pathStack.pushPathByName(name, param);
      }
    });
    this.bootstrap().catch((error: BusinessError) => {
      Logger.warn(SCOPE, `bootstrap failed: ${error.code}`);
    });
  }

  aboutToDisappear(): void {
    if (this.closeTimer >= 0) {
      clearTimeout(this.closeTimer);
      this.closeTimer = -1;
    }
    try {
      display.off('change', this.displayChangeCallback);
    } catch (error) {
      Logger.warn(SCOPE, 'display listener off failed');
    }
    layoutStore.detach();
    overlayStore.setSheetListener(() => {
    });
    overlayStore.setPlayerPresenter(null);
    playerTransition.setHiddenListener(() => {
    });
    routeBridge.register(null);
  }

  private updateDockWidth(): void {
    try {
      const info: display.Display = display.getDefaultDisplaySync();
      const widthVp: number = this.getUIContext().px2vp(info.width);
      const target: number = widthVp - 16;
      if (target > 120) {
        this.dockBarWidth = target;
      }
    } catch (error) {
      Logger.warn(SCOPE, 'display info unavailable');
    }
  }

  private lengthToNumber(value: Length): number {
    if (typeof value === 'number') {
      return value;
    }
    if (typeof value === 'string') {
      const parsed: number = Number.parseFloat(value);
      return Number.isNaN(parsed) ? 0 : parsed;
    }
    return 0;
  }

  /** 布局层尺寸变化（旋转/分屏/安全区切换）：同步舞台尺寸并重算底栏宽度。 */
  private syncStageSize(area: Area): void {
    const width: number = this.lengthToNumber(area.width);
    const height: number = this.lengthToNumber(area.height);
    if (width <= 0 || height <= 0) {
      return;
    }
    const target: number = width - 16;
    // onAreaChange 在滚动/动画中也会回调；1vp 内抖动直接忽略，避免重建整棵 Navigation 树。
    if (Math.abs(width - this.stageWidth) < 1 && Math.abs(height - this.stageHeight) < 1
      && (target <= 120 || Math.abs(target - this.dockBarWidth) < 1)) {
      return;
    }
    this.stageWidth = width;
    this.stageHeight = height;
    if (target > 120) {
      this.dockBarWidth = target;
    }
  }

  /**
   * 收缩/展开的目标矩形：默认态为迷你播放器胶囊（高 60，底距 miniPlayerBottomOffset），
   * 折叠态为右侧播放器胶囊（跳过左侧首页圆钮与间距）。全部按当前层尺寸实时计算。
   */
  private computePlayerRect(collapsed: boolean): PlayerTargetRect {
    const screenWidth: number = this.stageWidth > 0 ? this.stageWidth : 360;
    const screenHeight: number = this.stageHeight > 0 ? this.stageHeight : 780;
    let width: number = Math.max(0, Math.min(this.dockBarWidth, screenWidth - 16));
    const height: number = collapsed ? DockMetrics.COLLAPSED_HEIGHT : DockMetrics.PLAYER_HEIGHT;
    const bottomOffset: number = collapsed ? DockMetrics.collapsedBottomOffset() : DockMetrics.miniPlayerBottomOffset();
    let x: number = (screenWidth - width) / 2;
    if (collapsed) {
      const homeInset: number = DockMetrics.COLLAPSED_HEIGHT + DockMetrics.COLLAPSED_GAP;
      x += homeInset;
      width = Math.max(0, width - homeInset);
    }
    const rect: PlayerTargetRect = new PlayerTargetRect();
    rect.update(x, screenHeight - bottomOffset - height, width, height,
      screenWidth, screenHeight);
    return rect;
  }

  /** 打开播放器：迷你/折叠胶囊立即隐藏，播放器从它的矩形放大到全屏。 */
  private presentPlayer(): void {
    if (this.closeTimer >= 0) {
      clearTimeout(this.closeTimer);
      this.closeTimer = -1;
    }
    if (playerTransition.phase === PlayerTransitionPhase.OPENING) {
      return;
    }
    playerTransition.refreshReduceMotion();
    playerTransition.open(this.computePlayerRect(scrollChrome.collapsed), scrollChrome.collapsed,
      playerStore.current !== null);
  }

  /** 关闭播放器：浮层先收起，再缩回当前迷你/折叠胶囊矩形后卸载。 */
  private dismissPlayer(): void {
    if (!playerTransition.visible) {
      overlayStore.syncPlayerVisible(false);
      return;
    }
    if (overlayStore.sheetVisible) {
      overlayStore.closeSheet();
      if (this.closeTimer >= 0) {
        clearTimeout(this.closeTimer);
      }
      this.closeTimer = setTimeout(() => {
        this.closeTimer = -1;
        this.shrinkPlayer();
      }, 200);
      return;
    }
    this.shrinkPlayer();
  }

  private shrinkPlayer(): void {
    if (!playerTransition.visible) {
      return;
    }
    playerTransition.refreshReduceMotion();
    playerTransition.close(this.computePlayerRect(scrollChrome.collapsed), scrollChrome.collapsed,
      playerStore.current !== null);
  }


  private async bootstrap(): Promise<void> {
    try {
      await LegacyMigration.runOnce();
    } catch (error) {
      Logger.warn(SCOPE, 'migration failed');
    }
    // 依赖顺序：设置 → 服务器会话/上下文 → 依赖 serverContext 的曲库快照 → 其余 Store。
    // 原顺序在 serverStore.init() 之前调用 loadSnapshot()，serverId 为空导致首帧曲库为空。
    try {
      await settingsStore.init();
    } catch (error) {
      Logger.warn(SCOPE, 'settings init failed');
    }
    LyricPrefs.restore();
    themeStore.setColorModeApplier((mode: ThemeMode) => {
      this.applyColorMode(mode);
    });
    themeStore.setMode(settingsStore.prefs.themeMode);
    themeStore.setScale(settingsStore.prefs.uiScale);
    themeStore.setBlur(settingsStore.prefs.blurAlpha);

    try {
      await serverStore.init();
    } catch (error) {
      Logger.warn(SCOPE, 'server init failed');
    }
    libraryStore.init();
    libraryStore.loadSnapshot();
    downloadStore.init();
    podcastStore.init();
    searchStore.init().catch((error: BusinessError) => {
      Logger.warn(SCOPE, `search init failed: ${error.code}`);
    });
    playerStore.init();
    playerStore.setFavoriteProvider((songKey: string): boolean => libraryStore.isFavorite(songKey));
    playerStore.setFavoriteToggler((songKey: string): void => {
      libraryStore.toggleFavorite(songKey);
    });
    localScanStore.init().catch((error: BusinessError) => {
      Logger.warn(SCOPE, `local scan init failed: ${error.code}`);
    });
    discoverStore.init();
    if (serverStore.canRead) {
      sourceStore.load();
    }
    if (serverStore.online) {
      syncStore.syncNow(false);
    }
    if (serverStore.sessionExpired) {
      Logger.warn(SCOPE, 'session expired, please re-login');
    }
  }

  onBackPress(): boolean {
    return overlayStore.handleBack(this.pathStack.size()).consumed;
  }

  /** 让系统材质（沉浸光感）与实况窗跟随应用主题，避免深色应用配浅色玻璃。 */
  private applyColorMode(mode: ThemeMode): void {
    try {
      const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext;
      if (ctx === null) {
        return;
      }
      const app = ctx.getApplicationContext();
      if (mode === ThemeMode.DARK) {
        app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
      } else if (mode === ThemeMode.LIGHT) {
        app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      } else {
        app.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      }
    } catch (error) {
      Logger.warn(SCOPE, 'applyColorMode failed');
    }
  }

  @Builder
  tabItem(index: number, title: string, icon: Resource) {
    BottomDock({
      itemIndex: index,
      itemTitle: title,
      itemIcon: icon,
      selected: overlayStore.tabIndex === index,
      iconColor: themeStore.surfacePalette.sub,
      activeColor: themeStore.palette.brand
    })
  }

  /** 悬浮页签点击：切页签并复位滚动；播放器内的副本额外收起播放器。 */
  private dockTap(index: number, closePlayer: boolean): void {
    overlayStore.setTab(index);
    scrollChrome.reset(index);
    if (index === 0) {
      discoverStore.reloadIfStale();
    }
    if (closePlayer) {
      overlayStore.closePlayer();
    }
  }

  @Builder
  dockItem(index: number, title: string, icon: Resource, closePlayer: boolean) {
    Column() {
      this.tabItem(index, title, icon)
    }
    .layoutWeight(1)
    .height('100%')
    .stateStyles({
      pressed: { .scale({ x: 0.92, y: 0.92 }).opacity(0.85) },
      normal: { .scale({ x: 1, y: 1 }).opacity(1) }
    })
    .animation({ duration: 120, curve: Curve.EaseOut })
    .onClick(() => {
      this.dockTap(index, closePlayer);
    })
  }

  /**
   * 悬浮页签栏：与迷你播放器完全同配方的玻璃胶囊。
   * 弃用 Tabs.barFloatingStyle 的 systemMaterial —— 真机上会被系统染成偏黄实色，
   * 且与迷你播放器的通透观感不一致；改用确定性模糊 + 折射渐变保证深浅主题一致。
   */
  @Builder
  glassDock(closePlayer: boolean) {
    Stack({ alignContent: Alignment.TopStart }) {
      // 层 1：垂直折射渐变。
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({ angle: 180, colors: ImmersiveGlass.barTint() })

      // 层 1.5：沉浸光感——封面主色环境光，光源居中向两端扩散，随换曲实时变色。
      Column()
        .width('100%')
        .height('100%')
        .radialGradient({
          center: ['50%', '60%'],
          radius: '75%',
          colors: ImmersiveGlass.ambientStops()
        })

      // 层 2：页签内容。（原顶部扫光层移除：与描边错位后呈游离白线。）
      Row() {
        this.dockItem(0, '首页', $r('app.media.ic_home'), closePlayer)
        this.dockItem(1, '资料库', $r('app.media.ic_library'), closePlayer)
        this.dockItem(2, '下载', $r('app.media.ic_download'), closePlayer)
        this.dockItem(3, '设置', $r('app.media.ic_settings'), closePlayer)
      }
      .width('100%')
      .height('100%')
    }
    .width(this.dockBarWidth)
    .height(DockMetrics.TAB_BAR_HEIGHT)
    .borderRadius(DockMetrics.TAB_BAR_HEIGHT / 2)
    .backgroundColor(ImmersiveGlass.barBase())
    .backgroundEffect({ radius: 32, saturation: 1.35, brightness: 1.05 })
    .border({ width: 1, color: ImmersiveGlass.barEdge() })
    .shadow({ radius: 26, color: ImmersiveGlass.ambientGlow(), offsetX: 0, offsetY: 10 })
    .clip(true)
    .margin({ bottom: DockMetrics.BOTTOM_MARGIN })
    .transition(TransitionEffect.OPACITY.animation({ duration: 160 }))
  }

  @Builder
  sheetContent() {
    if (overlayStore.sheetKind === SheetKind.LYRIC_ADJUST) {
      LyricAdjustSheet()
    } else if (overlayStore.sheetKind === SheetKind.QUEUE) {
      QueueSheet()
    } else if (overlayStore.sheetKind === SheetKind.MORE) {
      PlayerMoreSheet()
    } else if (overlayStore.sheetKind === SheetKind.ADD_PLAYLIST) {
      AddToPlaylistSheet({
        songIds: overlayStore.addToPlaylistIds,
        onClose: () => {
          overlayStore.closeSheet();
        },
        onDone: (message: string) => {
          overlayStore.closeSheet();
          Logger.info(SCOPE, message);
        }
      })
    } else if (overlayStore.sheetKind === SheetKind.SERVER_EDIT) {
      ServerEditSheet()
    }
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(themeStore.palette.bg)
          .linearGradient({ angle: ImmersiveGlass.ANGLE, colors: ImmersiveGlass.backdrop() })
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        Tabs({ index: overlayStore.tabIndex, barPosition: BarPosition.End }) {
          TabContent() {
            HomeView({
              onOpenCollection: (param: DiscoverCollectionParam) => {
                this.pathStack.pushPathByName(AppConstants.ROUTE_DISCOVER_COLLECTION, param);
              }
            })
          }
          .tabBar(this.tabItem(0, '首页', $r('app.media.ic_home')))

          TabContent() {
            LibraryView({
              onOpenDetail: (param: LibraryDetailParam) => {
                this.pathStack.pushPathByName(AppConstants.ROUTE_LIBRARY_DETAIL, param);
              }
            })
          }
          .tabBar(this.tabItem(1, '资料库', $r('app.media.ic_library')))

          TabContent() {
            DownloadView()
          }
          .tabBar(this.tabItem(2, '下载', $r('app.media.ic_download')))

          TabContent() {
            SettingsView({
              onOpenRoute: (route: string) => {
                this.pathStack.pushPathByName(route, null);
              }
            })
          }
          .tabBar(this.tabItem(3, '设置', $r('app.media.ic_settings')))
        }
        .barPosition(BarPosition.End)
        .barMode(BarMode.Fixed)
        .barOverlap(true)
        // 系统悬浮材质在真机上底色偏黄，改为下方自绘玻璃胶囊；Tabs 仅负责页面切换。
        .barHeight(0)
        .animation({ duration: 220, curve: Curve.EaseOut })
        .scrollable(true)
        .animationDuration(220)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .onChange((index: number) => {
          overlayStore.setTab(index);
          scrollChrome.reset(index);
          if (index === 0) {
            discoverStore.reloadIfStale();
          }
        })

        // 默认态：自绘玻璃页签栏，与迷你播放器共用同一套通透配方（替代系统悬浮材质）。
        if (!scrollChrome.collapsed &&
          (!playerTransition.visible || playerTransition.progress <= 0.01)) {
          this.glassDock(false)
        }

        // 默认态：独立迷你播放器胶囊常驻悬浮在页签栏上方 8vp（双层玻璃），
        // 无曲目时显示占位内容（华为音乐式常驻播放条）。
        // 打开动画起步那一两帧保留胶囊（此时播放器还只是同位置的透明小卡），
        // 之后隐藏；关闭动画落到矩形后才重新出现，避免双影（FR-164）。
        if (!scrollChrome.collapsed &&
          (!playerTransition.visible || playerTransition.progress <= 0.01)) {
          Column() {
            MiniPlayer()
          }
          .width(this.dockBarWidth)
          .height(DockMetrics.PLAYER_HEIGHT)
          .margin({ bottom: DockMetrics.miniPlayerBottomOffset() })
          .transition(TransitionEffect.OPACITY.animation({ duration: 160 })
            .combine(TransitionEffect.translate({ y: '12%' })))
        }

        // 折叠态：页签栏与完整播放器隐藏，底部只保留紧凑胶囊。
        if (scrollChrome.collapsed &&
          (!playerTransition.visible || playerTransition.progress <= 0.01)) {
          Column() {
            CollapsedBar()
          }
          .width(this.dockBarWidth)
          .height(DockMetrics.COLLAPSED_HEIGHT)
          .margin({ bottom: DockMetrics.collapsedBottomOffset() })
          .transition(TransitionEffect.OPACITY.animation({ duration: 160 })
            .combine(TransitionEffect.translate({ y: '40%' })))
        }


        if (overlayStore.podcastVisible) {
          PodcastHomeView({
            onOpenShow: (showId: string) => {
              overlayStore.closePodcast();
              this.pathStack.pushPathByName(AppConstants.ROUTE_PODCAST_SHOW, PodcastShowParam.create(showId));
            },
            onOpenManage: () => {
              overlayStore.closePodcast();
              this.pathStack.pushPathByName(AppConstants.ROUTE_PODCAST_MANAGE, null);
            }
          })
            .transition(TransitionEffect.OPACITY.animation({ duration: 200 })
              .combine(TransitionEffect.translate({ y: '6%' })))
        }

        if (overlayStore.searchVisible) {
          SearchView({
            onOpenCollection: (param: DiscoverCollectionParam) => {
              overlayStore.closeSearch();
              this.pathStack.pushPathByName(AppConstants.ROUTE_DISCOVER_COLLECTION, param);
            }
          })
            .transition(TransitionEffect.OPACITY.animation({ duration: 180 }))
        }

        // 播放器展开后的点击阻断层：过渡期间（含收缩到一半时）底下的列表/页签不响应。
        if (playerTransition.transitioning) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor(Color.Transparent)
            .onClick(() => {
            })
        }

        // 全屏播放器：单一 progress 驱动收缩/展开过渡（不再使用透明度/位移转场）。
        if (playerTransition.visible) {
          FullscreenPlayer({
            progress: playerTransition.progress,
            targetRect: playerTransition.targetRect,
            stageWidthValue: this.stageWidth,
            stageHeightValue: this.stageHeight
          })
        }

        // 播放详情页底部保留悬浮页签栏（参考稿效果）：
        // 仅在展开动画完成后出现，收缩动画一开始即隐藏，避免与迷你播放器双影。
        if (playerTransition.visible && playerTransition.progress >= 0.999 &&
          !playerTransition.animating) {
          this.glassDock(true)
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange((oldArea: Area, newArea: Area) => {
        this.syncStageSize(newArea);
      })
      .bindSheet(this.sheetShown, this.sheetContent(), {
        dragBar: false,
        showClose: false,
        backgroundColor: Color.Transparent,
        height: SheetSize.MEDIUM,
        onDisappear: () => {
          overlayStore.closeSheet();
        }
      })
    }
    .mode(NavigationMode.Stack)
    .hideTitleBar(true)
    .hideToolBar(true)
    .backgroundColor(themeStore.palette.bg)
  }
}






