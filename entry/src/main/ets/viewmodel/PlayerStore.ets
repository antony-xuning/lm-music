/**
 * 播放状态 Store：队列、当前项、播放模式、进度，桥接 PlayerService。
 * 播放前先解析签名地址（服务器文件 / 在线来源），并异步加载封面与歌词。
 */
import { media } from '@kit.MediaKit';
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { ServerEndpoints } from '../common/ServerEndpoints';
import { Debouncer, Utils } from '../common/Utils';
import { JsonStore } from '../data/JsonStore';
import { PlayerDoc, PlayerItemRaw } from '../data/Schemas';
import { MediaSource, PlayableItem, PlayableKind, PlayMode, PlayModeHelper, PlayerStatus } from '../model/MediaModels';
import { PlayResult } from '../model/ServerModels';
import { AvCommandHandlers, AvTrackInfo, avSessionService } from '../service/AvSessionService';
import { backgroundPlaybackService } from '../service/BackgroundPlaybackService';
import { colorService } from '../service/ColorService';
import { coverService } from '../service/CoverService';
import { lyricService } from '../service/LyricService';
import { playUrlResolver } from '../service/PlayUrlResolver';
import { playerService } from '../service/PlayerService';
import { serverContext } from '../service/ServerContext';
import { settingsStore } from './SettingsStore';
import { themeStore } from './ThemeStore';

const SCOPE: string = 'PlayerStore';

type TrackListener = (item: PlayableItem) => void;
type ProgressListener = (item: PlayableItem, positionMs: number) => void;

@ObservedV2
export class PlayerStore {
  @Trace queue: PlayableItem[] = [];
  @Trace currentIndex: number = -1;
  @Trace status: PlayerStatus = PlayerStatus.IDLE;
  @Trace positionMs: number = 0;
  @Trace durationMs: number = 0;
  @Trace mode: PlayMode = PlayMode.LIST_LOOP;
  @Trace errorText: string = '';
  @Trace loading: boolean = false;
  @Trace lyricText: string = '';
  @Trace coverUri: string = '';
  @Trace resolving: boolean = false;

  private started: boolean = false;
  private pendingStartMs: number = 0;
  private persistDebouncer: Debouncer = new Debouncer(900);
  private progressDebouncer: Debouncer = new Debouncer(900);
  private trackListeners: TrackListener[] = [];
  private progressListeners: ProgressListener[] = [];
  private loadedKey: string = '';
  /** 暂停超时释放长时任务的定时器句柄；-1 表示未挂起。 */
  private pauseReleaseTimer: number = -1;
  private favoriteProvider: (songKey: string) => boolean = () => false;
  private favoriteToggler: (songKey: string) => void = () => {
  };

  init(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.bindAvSession();
    playerService.onPosition = (ms: number) => {
      this.positionMs = ms;
      this.progressDebouncer.run(() => {
        const item: PlayableItem | null = this.current;
        if (item !== null) {
          this.emitProgress(item, ms);
        }
      });
      this.syncSession(false);
    };
    playerService.onDuration = (ms: number) => {
      if (ms > 0) {
        this.durationMs = ms;
      }
    };
    playerService.onStateChanged = (state: media.AVPlayerState) => {
      this.applyPlayerState(state);
    };
    playerService.onCompleted = () => {
      this.status = PlayerStatus.COMPLETED;
      this.handleCompletion();
    };
    playerService.onError = (message: string) => {
      this.status = PlayerStatus.ERROR;
      this.errorText = message;
      this.loading = false;
      this.syncSession(true);
    };
    this.restore();
  }

  /** 播放状态变化：暂停挂起超时释放定时器；恢复播放立即重新申请长时任务。 */
  @Monitor('status')
  onStatusChange(): void {
    if (this.status === PlayerStatus.PLAYING) {
      this.cancelPauseRelease();
      backgroundPlaybackService.start();
    } else if (this.status === PlayerStatus.PAUSED) {
      this.schedulePauseRelease();
    } else {
      this.cancelPauseRelease();
    }
  }

  /** 暂停超过阈值后释放 audioPlayback 长时任务（省电）。 */
  private schedulePauseRelease(): void {
    this.cancelPauseRelease();
    if (!backgroundPlaybackService.active) {
      return;
    }
    this.pauseReleaseTimer = setTimeout(() => {
      this.pauseReleaseTimer = -1;
      if (this.status === PlayerStatus.PAUSED) {
        // 仅释放长时任务，AVSession 保持激活；恢复播放时 start() 幂等重申。
        backgroundPlaybackService.stop();
      }
    }, AppConstants.PAUSE_BACKGROUND_RELEASE_MS);
  }

  private cancelPauseRelease(): void {
    if (this.pauseReleaseTimer >= 0) {
      clearTimeout(this.pauseReleaseTimer);
      this.pauseReleaseTimer = -1;
    }
  }

  /** 收藏状态查询/切换由界面层注入，避免 Store 之间循环依赖。 */
  setFavoriteProvider(provider: (songKey: string) => boolean): void {
    this.favoriteProvider = provider;
  }

  setFavoriteToggler(toggler: (songKey: string) => void): void {
    this.favoriteToggler = toggler;
  }

  addTrackListener(listener: TrackListener): void {
    this.trackListeners.push(listener);
  }

  addProgressListener(listener: ProgressListener): void {
    this.progressListeners.push(listener);
  }

  private emitTrack(item: PlayableItem): void {
    for (let i = 0; i < this.trackListeners.length; i++) {
      this.trackListeners[i](item);
    }
  }

  private emitProgress(item: PlayableItem, positionMs: number): void {
    for (let i = 0; i < this.progressListeners.length; i++) {
      this.progressListeners[i](item, positionMs);
    }
  }

  private applyPlayerState(state: media.AVPlayerState): void {
    if (state === 'playing') {
      this.status = PlayerStatus.PLAYING;
      this.loading = false;
    } else if (state === 'paused') {
      this.status = PlayerStatus.PAUSED;
    } else if (state === 'completed') {
      this.status = PlayerStatus.COMPLETED;
    } else if (state === 'error') {
      this.status = PlayerStatus.ERROR;
      this.loading = false;
    }
    this.syncSession(true);
  }

  // ---------- AVSession / 后台播放 ----------

  /** 把系统播控命令映射回应用内播放器（不引入 Store 反向依赖）。 */
  private bindAvSession(): void {
    const handlers: AvCommandHandlers = new AvCommandHandlers();
    handlers.onPlay = () => {
      this.play();
    };
    handlers.onPause = () => {
      this.pause();
    };
    handlers.onStop = () => {
      this.stopFromSystem();
    };
    handlers.onNext = () => {
      this.next(false);
    };
    handlers.onPrevious = () => {
      this.previous();
    };
    handlers.onSeek = (positionMs: number) => {
      this.seek(positionMs);
    };
    handlers.onFastForward = () => {
      this.seekBy(AppConstants.STEP_15S);
    };
    handlers.onRewind = () => {
      this.seekBy(-AppConstants.STEP_15S);
    };
    handlers.onToggleFavorite = (assetId: string) => {
      this.toggleFavoriteForAsset(assetId);
    };
    handlers.onLoopMode = (loopMode: number) => {
      this.applySystemLoopMode(loopMode);
    };
    avSessionService.bindHandlers(handlers);
  }

  private songKeyOf(item: PlayableItem): string {
    return item.songId.length > 0 ? item.songId : item.id;
  }

  private favoriteOf(item: PlayableItem): boolean {
    try {
      return this.favoriteProvider(this.songKeyOf(item));
    } catch (error) {
      return false;
    }
  }

  private buildSessionTrack(item: PlayableItem): AvTrackInfo {
    const track: AvTrackInfo = new AvTrackInfo();
    track.assetId = item.id.length > 0 ? item.id : this.songKeyOf(item);
    track.title = item.title;
    track.artist = item.subtitle;
    track.durationMs = this.durationMs > 0 ? this.durationMs : item.durationMs;
    track.coverUri = this.coverUri;
    track.lyric = this.lyricText;
    track.isFavorite = this.favoriteOf(item);
    track.activeItemId = this.currentIndex + 1;
    return track;
  }

  /** 同步实况窗：force=true 用于切歌/状态/seek/收藏/循环模式变化。 */
  private syncSession(force: boolean): void {
    const item: PlayableItem | null = this.current;
    if (item === null) {
      return;
    }
    const track: AvTrackInfo = this.buildSessionTrack(item);
    avSessionService.sync(track, this.status, this.positionMs, this.mode, force).catch(() => {
      Logger.warn(SCOPE, 'av session sync failed');
    });
  }

  private toggleFavoriteForAsset(assetId: string): void {
    const item: PlayableItem | null = this.current;
    if (item === null) {
      return;
    }
    const currentAsset: string = this.buildSessionTrack(item).assetId;
    if (assetId.length > 0 && assetId !== currentAsset) {
      return;
    }
    try {
      this.favoriteToggler(this.songKeyOf(item));
    } catch (error) {
      Logger.warn(SCOPE, 'toggle favorite from session failed');
    }
    setTimeout(() => {
      this.syncSession(true);
    }, 600);
  }

  private applySystemLoopMode(loopMode: number): void {
    if (loopMode === 1) {
      this.setMode(PlayMode.SINGLE_LOOP);
    } else if (loopMode === 0) {
      this.setMode(PlayMode.SEQUENTIAL);
    } else if (loopMode === 3) {
      this.setMode(PlayMode.SHUFFLE);
    } else {
      this.setMode(PlayMode.LIST_LOOP);
    }
  }

  /** 系统播控「停止」：停止播放并结束实况窗与长时任务（保留队列）。 */
  stopFromSystem(): void {
    playerService.stop();
    this.status = PlayerStatus.PAUSED;
    this.positionMs = 0;
    this.loading = false;
    // 播放器已 reset，下次播放需重新解析并加载音源。
    this.loadedKey = '';
    backgroundPlaybackService.stop();
    avSessionService.destroy();
  }


  get current(): PlayableItem | null {
    if (this.currentIndex < 0 || this.currentIndex >= this.queue.length) {
      return null;
    }
    return this.queue[this.currentIndex];
  }

  get isPlaying(): boolean {
    return this.status === PlayerStatus.PLAYING;
  }

  get hasQueue(): boolean {
    return this.queue.length > 0;
  }

  get isPodcast(): boolean {
    const item: PlayableItem | null = this.current;
    return item !== null && item.kind === PlayableKind.EPISODE;
  }

  get progressRatio(): number {
    if (this.durationMs <= 0) {
      return 0;
    }
    return Utils.clamp(this.positionMs / this.durationMs, 0, 1);
  }

  private itemKey(item: PlayableItem): string {
    return `${item.kind}|${item.id}|${item.mediaSource}|${item.filePath}|${item.platformSongId}`;
  }

  loadQueueAt(items: PlayableItem[], startIndex: number, startMs: number, autoPlay: boolean): void {
    if (items.length === 0) {
      return;
    }
    const index: number = Utils.clamp(startIndex, 0, items.length - 1);
    this.queue = items.slice();
    this.currentIndex = index;
    this.positionMs = startMs;
    this.durationMs = items[index].durationMs;
    this.errorText = '';
    this.pendingStartMs = startMs;
    this.startCurrent(autoPlay);
    this.persist();
  }

  loadQueue(items: PlayableItem[], startIndex: number, autoPlay: boolean = true): void {
    if (items.length === 0) {
      return;
    }
    const index: number = Utils.clamp(startIndex, 0, items.length - 1);
    this.queue = items.slice();
    this.currentIndex = index;
    this.positionMs = 0;
    this.durationMs = items[index].durationMs;
    this.errorText = '';
    this.startCurrent(autoPlay);
    this.persist();
  }

  playItem(item: PlayableItem, autoPlay: boolean = true): void {
    this.queue = [item];
    this.currentIndex = 0;
    this.positionMs = 0;
    this.durationMs = item.durationMs;
    this.errorText = '';
    this.startCurrent(autoPlay);
    this.persist();
  }

  playById(item: PlayableItem): void {
    for (let i = 0; i < this.queue.length; i++) {
      if (this.queue[i].id === item.id && this.queue[i].kind === item.kind) {
        this.currentIndex = i;
        this.startCurrent(true);
        return;
      }
    }
    this.queue = this.queue.concat([item]);
    this.currentIndex = this.queue.length - 1;
    this.startCurrent(true);
  }

  addToQueue(items: PlayableItem[]): void {
    if (items.length === 0) {
      return;
    }
    this.queue = this.queue.concat(items);
    if (this.currentIndex < 0) {
      this.currentIndex = 0;
      this.startCurrent(false);
    }
    this.persist();
  }

  replaceQueue(items: PlayableItem[], autoPlay: boolean): void {
    if (items.length === 0) {
      this.clear();
      return;
    }
    this.queue = items.slice();
    this.currentIndex = 0;
    this.startCurrent(autoPlay);
    this.persist();
  }

  private async startCurrent(autoPlay: boolean): Promise<void> {
    const item: PlayableItem | null = this.current;
    if (item === null) {
      return;
    }
    const startMs: number = this.pendingStartMs;
    this.pendingStartMs = 0;
    this.loading = true;
    this.resolving = true;
    this.errorText = '';
    this.lyricText = '';
    this.coverUri = '';
    this.status = PlayerStatus.RESOLVING;
    this.emitTrack(item);
    this.syncSession(true);
    if (autoPlay) {
      backgroundPlaybackService.start();
    }
    this.loadLyric(item);
    this.loadCover(item);
    const quality: string = ServerEndpoints.qualityKey(settingsStore.prefs.defaultQuality);
    const resolved: PlayResult = await playUrlResolver.resolve(item, quality);
    if (this.current !== item) {
      return;
    }
    this.resolving = false;
    if (resolved.url.length === 0) {
      this.loading = false;
      this.status = PlayerStatus.ERROR;
      this.errorText = '无法获取播放地址，请检查网络或音源';
      return;
    }
    this.loadedKey = this.itemKey(item);
    this.status = PlayerStatus.LOADING;
    const headers: Record<string, string> | null = resolved.useAuthHeader ? serverContext.authHeaders() : null;
    await playerService.load(resolved.url, startMs, autoPlay, headers);
    this.loading = false;
    if (!autoPlay) {
      this.status = PlayerStatus.PAUSED;
    }
  }

  private async loadLyric(item: PlayableItem): Promise<void> {
    const text: string = await lyricService.lyricFor(item, null);
    if (this.current !== item) {
      return;
    }
    this.lyricText = text;
    this.syncSession(false);
  }

  private async loadCover(item: PlayableItem): Promise<void> {
    if (item.mediaSource === MediaSource.LOCAL) {
      // 本地导入与文件夹扫描曲目：封面来自沙箱 / 本地封面缓存，无需远端请求。
      if (this.current === item) {
        this.coverUri = item.coverUrl;
        colorService.setCover(this.coverUri, themeStore.isDark);
        this.syncSession(false);
      }
      return;
    }
    const uri: string = await coverService.uriForItem(item);
    if (this.current !== item) {
      return;
    }
    this.coverUri = uri;
    colorService.setCover(uri, themeStore.isDark);
    this.syncSession(false);
  }

  /** 解析失败 / 播放失败时重试当前曲目。 */
  retry(): void {
    const item: PlayableItem | null = this.current;
    if (item === null) {
      return;
    }
    playUrlResolver.invalidate(item, ServerEndpoints.qualityKey(settingsStore.prefs.defaultQuality));
    this.startCurrent(true);
  }

  toggle(): void {
    const item: PlayableItem | null = this.current;
    if (item === null) {
      return;
    }
    if (this.loadedKey.length === 0 || this.loadedKey !== this.itemKey(item)) {
      this.startCurrent(true);
      return;
    }
    if (this.status === PlayerStatus.PLAYING) {
      playerService.pause();
      this.status = PlayerStatus.PAUSED;
    } else if (this.status === PlayerStatus.ERROR) {
      this.retry();
    } else {
      playerService.play();
      this.status = PlayerStatus.PLAYING;
      backgroundPlaybackService.start();
    }
    this.syncSession(true);
  }

  play(): void {
    if (this.current === null) {
      return;
    }
    playerService.play();
    this.status = PlayerStatus.PLAYING;
    backgroundPlaybackService.start();
    this.syncSession(true);
  }

  pause(): void {
    playerService.pause();
    this.status = PlayerStatus.PAUSED;
    this.syncSession(true);
  }

  next(auto: boolean = false): void {
    const size: number = this.queue.length;
    if (size === 0) {
      return;
    }
    if (this.mode === PlayMode.SINGLE_LOOP && auto) {
      this.seek(0);
      playerService.play();
      this.status = PlayerStatus.PLAYING;
      this.syncSession(true);
      return;
    }
    if (this.mode === PlayMode.SEQUENTIAL && auto && this.currentIndex >= size - 1) {
      this.status = PlayerStatus.COMPLETED;
      this.positionMs = this.durationMs;
      this.syncSession(true);
      this.persist();
      return;
    }
    if (this.mode === PlayMode.SHUFFLE) {
      this.currentIndex = Utils.randomOther(size, this.currentIndex);
    } else {
      this.currentIndex = (this.currentIndex + 1) % size;
    }
    this.positionMs = 0;
    this.startCurrent(true);
    this.persist();
  }

  previous(): void {
    if (this.queue.length === 0) {
      return;
    }
    if (this.positionMs > 3000) {
      this.seek(0);
      return;
    }
    const size: number = this.queue.length;
    this.currentIndex = (this.currentIndex - 1 + size) % size;
    this.positionMs = 0;
    this.startCurrent(true);
    this.persist();
  }

  seek(positionMs: number): void {
    const target: number = Utils.clamp(positionMs, 0, Math.max(this.durationMs, 0));
    this.positionMs = target;
    playerService.seek(target);
    this.syncSession(true);
  }

  seekBy(deltaMs: number): void {
    this.seek(this.positionMs + deltaMs);
  }

  setMode(mode: PlayMode): void {
    this.mode = mode;
    this.persist();
    this.syncSession(true);
  }

  cycleMode(): void {
    this.setMode(PlayModeHelper.next(this.mode));
  }

  removeFromQueue(index: number): void {
    if (index < 0 || index >= this.queue.length) {
      return;
    }
    const wasCurrent: boolean = index === this.currentIndex;
    const next: PlayableItem[] = [];
    for (let i = 0; i < this.queue.length; i++) {
      if (i !== index) {
        next.push(this.queue[i]);
      }
    }
    this.queue = next;
    if (next.length === 0) {
      this.clear();
      return;
    }
    if (wasCurrent) {
      this.currentIndex = Math.min(index, next.length - 1);
      this.startCurrent(true);
    } else if (index < this.currentIndex) {
      this.currentIndex = this.currentIndex - 1;
    }
    this.persist();
  }

  clear(): void {
    this.queue = [];
    this.currentIndex = -1;
    this.status = PlayerStatus.IDLE;
    this.positionMs = 0;
    this.durationMs = 0;
    this.errorText = '';
    this.lyricText = '';
    this.coverUri = '';
    this.loadedKey = '';
    playerService.stop();
    backgroundPlaybackService.stop();
    avSessionService.destroy();
    this.persist();
  }

  handleMissingCurrentFile(): void {
    this.status = PlayerStatus.ERROR;
    this.errorText = '文件已被删除，已切换到下一首';
    if (this.queue.length > 1) {
      this.next(true);
    } else {
      this.clear();
      this.errorText = '文件已被删除，队列已清空';
    }
  }

  private handleCompletion(): void {
    const item: PlayableItem | null = this.current;
    if (item !== null) {
      this.emitProgress(item, this.durationMs);
    }
    this.next(true);
  }

  private restore(): void {
    const text: string | null = JsonStore.readText(AppConstants.FILE_PLAYER);
    if (text === null) {
      return;
    }
    try {
      const doc = JSON.parse(text) as PlayerDoc;
      const rawQueue: PlayerItemRaw[] = Array.isArray(doc.queue) ? doc.queue : [];
      const restored: PlayableItem[] = [];
      for (let i = 0; i < rawQueue.length; i++) {
        const item: PlayableItem | null = fromRawItem(rawQueue[i]);
        if (item !== null) {
          restored.push(item);
        }
      }
      this.queue = restored;
      this.currentIndex = restored.length > 0 ? Utils.clamp(
        typeof doc.currentIndex === 'number' ? doc.currentIndex : 0, 0, restored.length - 1) : -1;
      this.mode = fromMode(typeof doc.mode === 'string' ? doc.mode : 'listLoop');
      this.positionMs = typeof doc.positionMs === 'number' ? doc.positionMs : 0;
      if (this.current !== null) {
        this.durationMs = this.current.durationMs;
        this.status = PlayerStatus.PAUSED;
      }
    } catch (error) {
      Logger.warn(SCOPE, 'restore player state failed');
      JsonStore.remove(AppConstants.FILE_PLAYER);
    }
  }

  persist(): void {
    this.persistDebouncer.run(() => {
      this.persistNow();
    });
  }

  persistNow(): void {
    const rawQueue: PlayerItemRaw[] = [];
    for (let i = 0; i < this.queue.length; i++) {
      const item: PlayableItem = this.queue[i];
      const raw: PlayerItemRaw = {
        id: item.id,
        kind: item.kind,
        songId: item.songId,
        episodeId: item.episodeId,
        showId: item.showId,
        title: item.title,
        subtitle: item.subtitle,
        coverSeed: item.coverSeed,
        coverUrl: item.coverUrl,
        audioRef: item.audioRef,
        durationMs: item.durationMs,
        isHiRes: item.isHiRes,
        mediaSource: item.mediaSource,
        filePath: item.filePath,
        trackId: item.trackId,
        platform: item.platform,
        platformSongId: item.platformSongId,
        qualitys: item.qualitys,
        serverId: item.serverId,
        lyricText: item.lyricText
      };
      rawQueue.push(raw);
    }
    const doc: PlayerDoc = {
      schemaVersion: AppConstants.SCHEMA_VERSION,
      queue: rawQueue,
      currentIndex: this.currentIndex,
      mode: this.mode,
      positionMs: this.positionMs
    };
    JsonStore.writeText(AppConstants.FILE_PLAYER, JSON.stringify(doc));
  }
}

function fromRawItem(raw: PlayerItemRaw): PlayableItem | null {
  if (typeof raw.audioRef !== 'string' || raw.audioRef.length === 0) {
    return null;
  }
  const item: PlayableItem = new PlayableItem();
  item.id = typeof raw.id === 'string' ? raw.id : '';
  item.kind = raw.kind === 'episode' ? PlayableKind.EPISODE : PlayableKind.SONG;
  item.songId = typeof raw.songId === 'string' ? raw.songId : '';
  item.episodeId = typeof raw.episodeId === 'string' ? raw.episodeId : '';
  item.showId = typeof raw.showId === 'string' ? raw.showId : '';
  item.title = typeof raw.title === 'string' ? raw.title : '未知曲目';
  item.subtitle = typeof raw.subtitle === 'string' ? raw.subtitle : '';
  item.coverSeed = typeof raw.coverSeed === 'number' ? raw.coverSeed : 0;
  item.coverUrl = typeof raw.coverUrl === 'string' ? raw.coverUrl : '';
  item.audioRef = raw.audioRef;
  item.durationMs = typeof raw.durationMs === 'number' ? raw.durationMs : 0;
  item.isHiRes = raw.isHiRes === true;
  item.mediaSource = parseSource(raw.mediaSource);
  item.filePath = typeof raw.filePath === 'string' ? raw.filePath : '';
  item.trackId = typeof raw.trackId === 'string' ? raw.trackId : '';
  item.platform = typeof raw.platform === 'string' ? raw.platform : '';
  item.platformSongId = typeof raw.platformSongId === 'string' ? raw.platformSongId : '';
  item.qualitys = typeof raw.qualitys === 'string' ? raw.qualitys : '';
  item.serverId = typeof raw.serverId === 'string' ? raw.serverId : '';
  item.lyricText = typeof raw.lyricText === 'string' ? raw.lyricText : '';
  return item;
}

function parseSource(value: string | undefined): MediaSource {
  if (value === MediaSource.SERVER_FILE) {
    return MediaSource.SERVER_FILE;
  }
  if (value === MediaSource.ONLINE) {
    return MediaSource.ONLINE;
  }
  if (value === MediaSource.PODCAST) {
    return MediaSource.PODCAST;
  }
  return MediaSource.LOCAL;
}

function fromMode(mode: string): PlayMode {
  if (mode === 'singleLoop') {
    return PlayMode.SINGLE_LOOP;
  }
  if (mode === 'sequential') {
    return PlayMode.SEQUENTIAL;
  }
  if (mode === 'shuffle') {
    return PlayMode.SHUFFLE;
  }
  return PlayMode.LIST_LOOP;
}

export const playerStore: PlayerStore = new PlayerStore();

