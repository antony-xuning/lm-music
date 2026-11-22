/**
 * 唯一 @Entry 页面：Navigation(STACK) + Tabs 四页签 + 合并 Glass Dock + 覆盖层插槽。
 */
import { display, uiMaterial } from '@kit.ArkUI';
import { common, ConfigurationConstant } from '@kit.AbilityKit';
import { BottomDock } from '../components/BottomDock';
import { MiniPlayer } from '../components/MiniPlayer';
import { CollapsedBar } from '../components/CollapsedBar';
import { AddToPlaylistSheet } from '../components/AddToPlaylistSheet';
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
    try {
      display.on('change', (id: number) => {
        this.updateDockWidth();
      });
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
    this.bootstrap();
  }

  aboutToDisappear(): void {
    if (this.closeTimer >= 0) {
      clearTimeout(this.closeTimer);
      this.closeTimer = -1;
    }
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
    this.stageWidth = width;
    this.stageHeight = height;
    const target: number = width - 16;
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
    libraryStore.init();
    downloadStore.init();
    podcastStore.init();
    searchStore.init();
    playerStore.init();
    playerStore.setFavoriteProvider((songKey: string): boolean => libraryStore.isFavorite(songKey));
    playerStore.setFavoriteToggler((songKey: string): void => {
      libraryStore.toggleFavorite(songKey);
    });
    LyricPrefs.restore();
    await settingsStore.init();
    themeStore.setColorModeApplier((mode: ThemeMode) => {
      this.applyColorMode(mode);
    });
    themeStore.setMode(settingsStore.prefs.themeMode);
    themeStore.setScale(settingsStore.prefs.uiScale);
    themeStore.setBlur(settingsStore.prefs.blurAlpha);
    await serverStore.init();
    libraryStore.loadSnapshot();
    localScanStore.init();
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

  /** 折叠态隐藏悬浮页签栏（barHeight 0），展开态固定 64。 */
  private tabBarHeight(): number {
    return scrollChrome.collapsed ? 0 : DockMetrics.TAB_BAR_HEIGHT;
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
    }
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Bottom }) {
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(themeStore.palette.bg)
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
        .barHeight(this.tabBarHeight())
        .animation({ duration: 220, curve: Curve.EaseOut })
        .barFloatingStyle({
          barWidth: {
            smallBarWidth: this.dockBarWidth,
            mediumBarWidth: this.dockBarWidth,
            largeBarWidth: this.dockBarWidth
          },
          barSideMargin: 8,
          barBottomMargin: DockMetrics.BOTTOM_MARGIN,
          systemMaterial: new uiMaterial.ImmersiveMaterial({
            style: uiMaterial.ImmersiveStyle.THIN,
            interactive: true
          })
        })
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

        // 默认态：独立迷你播放器胶囊悬浮在页签栏上方 8vp（双层玻璃）。
        // 打开动画起步那一两帧保留胶囊（此时播放器还只是同位置的透明小卡），
        // 之后隐藏；关闭动画落到矩形后才重新出现，避免双影（FR-164）。
        if (!scrollChrome.collapsed && playerStore.current !== null &&
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






