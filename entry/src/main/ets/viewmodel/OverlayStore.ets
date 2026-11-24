/**
 * 叠层 Store：播放器 / 搜索 / 播客覆盖层、半模态浮层与统一返回消费。
 * 返回优先级：半模态 → 播放器 → 搜索/播客 → 路由栈（交给 Navigation）→ 系统退出。
 */
import { LyricTheme } from '../model/LyricModels';

export enum SheetKind {
  NONE = 'none',
  LYRIC_ADJUST = 'lyricAdjust',
  QUEUE = 'queue',
  MORE = 'more',
  ADD_PLAYLIST = 'addPlaylist',
  SERVER_EDIT = 'serverEdit'
}

export class BackResult {
  consumed: boolean = false;
}

/**
 * 播放器呈递者：由 Index 实现，把「打开/关闭播放器」转发到收缩/展开过渡。
 * 未注册时退化为直接切换可见性（无动画）。
 */
export interface PlayerPresenter {
  presentPlayer: () => void;
  dismissPlayer: () => void;
}

@ObservedV2
export class OverlayStore {
  @Trace tabIndex: number = 0;
  @Trace playerVisible: boolean = false;
  @Trace searchVisible: boolean = false;
  @Trace podcastVisible: boolean = false;
  @Trace sheetKind: SheetKind = SheetKind.NONE;
  @Trace sheetTitle: string = '';
  @Trace sheetVisible: boolean = false;
  @Trace addToPlaylistIds: string[] = [];
  /** 服务器编辑浮层：空串表示新增，否则为待编辑的 ServerConfig.id。 */
  @Trace serverEditId: string = '';

  private sheetListener: (visible: boolean) => void = () => {
  };
  private playerPresenter: PlayerPresenter | null = null;

  /** 半模态显隐回调：由 Index 注册，直接驱动 bindSheet 的状态变量。 */
  setSheetListener(listener: (visible: boolean) => void): void {
    this.sheetListener = listener;
  }

  /** 播放器呈递回调：Index 注册后，打开/关闭走收缩/展开过渡。 */
  setPlayerPresenter(presenter: PlayerPresenter | null): void {
    this.playerPresenter = presenter;
  }

  /** 过渡结束后同步可见性（不触发呈递回调，避免递归）。 */
  syncPlayerVisible(value: boolean): void {
    this.playerVisible = value;
  }

  // 歌词调节（持久化于 preferences）
  @Trace lyricFontSize: number = 18;
  @Trace lyricOffsetMs: number = 0;
  @Trace lyricTheme: LyricTheme = LyricTheme.CLASSIC;

  get overlayVisible(): boolean {
    return this.playerVisible || this.searchVisible || this.podcastVisible;
  }

  setTab(index: number): void {
    this.tabIndex = index;
  }

  openPlayer(): void {
    this.playerVisible = true;
    if (this.playerPresenter !== null) {
      this.playerPresenter.presentPlayer();
    }
  }

  closePlayer(): void {
    if (this.playerPresenter !== null && this.playerVisible) {
      this.playerPresenter.dismissPlayer();
      return;
    }
    this.playerVisible = false;
  }

  openSearch(): void {
    this.searchVisible = true;
  }

  closeSearch(): void {
    this.searchVisible = false;
  }

  openPodcast(): void {
    this.podcastVisible = true;
  }

  closePodcast(): void {
    this.podcastVisible = false;
  }

  openSheet(kind: SheetKind, title: string): void {
    this.sheetKind = kind;
    this.sheetTitle = title;
    this.sheetVisible = true;
    this.sheetListener(true);
  }

  openAddToPlaylist(ids: string[]): void {
    this.addToPlaylistIds = ids.slice();
    this.openSheet(SheetKind.ADD_PLAYLIST, '加入歌单');
  }

  /** 打开服务器编辑浮层：serverId 为空时新增，否则编辑对应服务器。 */
  openServerEdit(serverId: string): void {
    this.serverEditId = serverId;
    this.openSheet(SheetKind.SERVER_EDIT, serverId.length > 0 ? '编辑服务器' : '添加服务器');
  }

  closeSheet(): void {
    // 先驱动关闭动画，保留 sheetKind 让面板在收起过程中仍有内容，
    // 避免半模态区域瞬间变空、留下空白面板。
    this.sheetVisible = false;
    this.sheetListener(false);
  }

  setLyricFontSize(size: number): void {
    this.lyricFontSize = size;
  }

  setLyricOffset(offsetMs: number): void {
    this.lyricOffsetMs = offsetMs;
  }

  setLyricTheme(theme: LyricTheme): void {
    this.lyricTheme = theme;
  }

  /** 消费返回事件；返回 true 表示已被应用消费。 */
  handleBack(routeDepth: number): BackResult {
    const result: BackResult = new BackResult();
    if (this.sheetVisible) {
      this.closeSheet();
      result.consumed = true;
      return result;
    }
    if (this.playerVisible) {
      this.closePlayer();
      result.consumed = true;
      return result;
    }
    if (this.searchVisible) {
      this.closeSearch();
      result.consumed = true;
      return result;
    }
    if (this.podcastVisible) {
      this.closePodcast();
      result.consumed = true;
      return result;
    }
    if (routeDepth > 0) {
      result.consumed = false;
      return result;
    }
    if (this.tabIndex !== 0) {
      this.tabIndex = 0;
      result.consumed = true;
      return result;
    }
    return result;
  }
}

export const overlayStore: OverlayStore = new OverlayStore();
