/**
 * AVSession 系统实况窗：创建/激活 audio 类型会话，上报元数据与播放状态，
 * 并把系统播控中心/状态栏胶囊/锁屏下发的命令回传到应用内 Store。
 *
 * 设计要点：
 * - 会话对象全局单例，后台播放期间不释放；创建失败仅降级，不影响应用内播放。
 * - 元数据只在 assetId / 封面 / 歌词变化时重设；播放状态按 ~1s 节流。
 * - lyric 为 LRC 原文，截断到 40960 字节；无歌词不设置该字段。
 * - mediaImage 使用解码后的 PixelMap（≤512），失败则省略。
 */
import { wantAgent, WantAgent } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { image } from '@kit.ImageKit';
import { avSession } from '@kit.AVSessionKit';
import { AppConstants } from '../common/Constants';
import { AppContextHolder } from '../common/AppContextHolder';
import { Logger } from '../common/Logger';
import { PlayMode, PlayerStatus } from '../model/MediaModels';

const SCOPE: string = 'AvSession';
const SESSION_TAG: string = 'lm_player';
const MAX_LYRIC_BYTES: number = 40960;
const STATE_THROTTLE_MS: number = 1000;
const REQUEST_CODE: number = 2002;

/** 系统播控命令回调集合（由 PlayerStore 注入，避免服务层反向依赖 Store）。 */
export class AvCommandHandlers {
  onPlay: () => void = () => {
  };
  onPause: () => void = () => {
  };
  onStop: () => void = () => {
  };
  onNext: () => void = () => {
  };
  onPrevious: () => void = () => {
  };
  onSeek: (positionMs: number) => void = () => {
  };
  onFastForward: () => void = () => {
  };
  onRewind: () => void = () => {
  };
  onToggleFavorite: (assetId: string) => void = () => {
  };
  onLoopMode: (loopMode: number) => void = () => {
  };
}

/** 当前曲目的实况窗信息快照。 */
export class AvTrackInfo {
  assetId: string = '';
  title: string = '';
  artist: string = '';
  album: string = '';
  durationMs: number = 0;
  coverUri: string = '';
  lyric: string = '';
  isFavorite: boolean = false;
  activeItemId: number = 1;
}

export class AvSessionService {
  private session: avSession.AVSession | null = null;
  private handlers: AvCommandHandlers = new AvCommandHandlers();
  private creating: boolean = false;
  private activated: boolean = false;

  private lastAssetId: string = '';
  private lastCoverUri: string = '';
  private lastLyric: string = '';
  private lastLine: string = '';
  private lastStateAt: number = 0;
  private lastStateKey: string = '';

  private coverPixelMap: image.PixelMap | null = null;
  private lyricTimes: number[] = [];
  private lyricLines: string[] = [];

  get active(): boolean {
    return this.activated && this.session !== null;
  }

  bindHandlers(handlers: AvCommandHandlers): void {
    this.handlers = handlers;
  }

  /** 创建（或复用）并激活 audio 会话；失败返回 null。 */
  async ensureActive(): Promise<avSession.AVSession | null> {
    if (this.session !== null) {
      if (!this.activated) {
        await this.activate(this.session);
      }
      return this.session;
    }
    if (this.creating) {
      return null;
    }
    const context = AppContextHolder.context;
    if (context === null) {
      Logger.warn(SCOPE, 'context unavailable, skip AVSession');
      return null;
    }
    this.creating = true;
    try {
      const session: avSession.AVSession = await avSession.createAVSession(context, SESSION_TAG, 'audio');
      this.session = session;
      this.registerCommands(session);
      await this.setLaunchAbility(session);
      await this.activate(session);
      Logger.info(SCOPE, `session created: ${session.sessionId}`);
      return session;
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `createAVSession failed: ${err.code}`);
      this.session = null;
      this.activated = false;
      return null;
    } finally {
      this.creating = false;
    }
  }

  private async activate(session: avSession.AVSession): Promise<void> {
    try {
      await session.activate();
      this.activated = true;
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `activate failed: ${err.code}`);
    }
  }

  private async setLaunchAbility(session: avSession.AVSession): Promise<void> {
    try {
      const info: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: AppConstants.BUNDLE_NAME,
            abilityName: 'EntryAbility'
          }
        ],
        actionType: wantAgent.OperationType.START_ABILITY,
        requestCode: REQUEST_CODE,
        actionFlags: [wantAgent.WantAgentFlags.UPDATE_PRESENT_FLAG]
      };
      const agent: WantAgent = await wantAgent.getWantAgent(info);
      await session.setLaunchAbility(agent);
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `setLaunchAbility failed: ${err.code}`);
    }
  }

  private registerCommands(session: avSession.AVSession): void {
    try {
      session.on('play', () => {
        this.handlers.onPlay();
      });
      session.on('pause', () => {
        this.handlers.onPause();
      });
      session.on('stop', () => {
        this.handlers.onStop();
      });
      session.on('playNext', () => {
        this.handlers.onNext();
      });
      session.on('playPrevious', () => {
        this.handlers.onPrevious();
      });
      session.on('seek', (time: number) => {
        this.handlers.onSeek(time);
      });
      session.on('fastForward', () => {
        this.handlers.onFastForward();
      });
      session.on('rewind', () => {
        this.handlers.onRewind();
      });
      session.on('toggleFavorite', (assetId: string) => {
        this.handlers.onToggleFavorite(assetId);
      });
      session.on('setLoopMode', (mode: avSession.LoopMode) => {
        this.handlers.onLoopMode(mode);
      });
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `register commands failed: ${err.code}`);
    }
  }

  /**
   * 同步当前曲目信息与播放状态。
   * force=true 时忽略节流（切歌、播放/暂停、seek、收藏、循环模式变化）。
   */
  async sync(track: AvTrackInfo, status: PlayerStatus, positionMs: number,
    mode: PlayMode, force: boolean): Promise<void> {
    if (track.assetId.length === 0) {
      return;
    }
    const session: avSession.AVSession | null = await this.ensureActive();
    if (session === null) {
      return;
    }
    const metadataDirty: boolean = track.assetId !== this.lastAssetId
      || track.coverUri !== this.lastCoverUri
      || track.lyric !== this.lastLyric;
    if (metadataDirty) {
      this.stageLyric(track.lyric);
      await this.applyMetadata(session, track);
    } else {
      const line: string = this.lineAt(positionMs);
      if (line.length > 0 && line !== this.lastLine) {
        this.lastLine = line;
        await this.applyLyricLine(session, track, line);
      }
    }
    await this.applyPlaybackState(session, track, status, positionMs, mode, force);
  }

  /** 曲目被清空 / 停止播放时销毁会话并清理封面资源。 */
  async destroy(): Promise<void> {
    const session: avSession.AVSession | null = this.session;
    this.session = null;
    this.activated = false;
    this.lastAssetId = '';
    this.lastCoverUri = '';
    this.lastLyric = '';
    this.lastLine = '';
    this.lastStateKey = '';
    this.lyricTimes = [];
    this.lyricLines = [];
    this.releaseCover();
    if (session === null) {
      return;
    }
    try {
      await session.deactivate();
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `deactivate failed: ${err.code}`);
    }
    try {
      await session.destroy();
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `destroy failed: ${err.code}`);
    }
  }

  private async applyMetadata(session: avSession.AVSession, track: AvTrackInfo): Promise<void> {
    const meta: avSession.AVMetadata = {
      assetId: track.assetId,
      title: track.title,
      artist: track.artist,
      duration: track.durationMs
    };
    if (track.album.length > 0) {
      meta.album = track.album;
    }
    const pixel: image.PixelMap | null = await this.resolveCover(track.coverUri);
    if (pixel !== null) {
      meta.mediaImage = pixel;
    }
    const lrc: string = AvSessionService.truncateLyric(track.lyric);
    if (lrc.length > 0) {
      meta.lyric = lrc;
    }
    const line: string = this.lineAt(0);
    if (line.length > 0) {
      meta.singleLyricText = AvSessionService.truncateLyric(line);
    }
    try {
      await session.setAVMetadata(meta);
      this.lastAssetId = track.assetId;
      this.lastCoverUri = track.coverUri;
      this.lastLyric = track.lyric;
      this.lastLine = line;
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `setAVMetadata failed: ${err.code}`);
    }
  }

  private async applyLyricLine(session: avSession.AVSession, track: AvTrackInfo, line: string): Promise<void> {
    const meta: avSession.AVMetadata = {
      assetId: track.assetId,
      singleLyricText: AvSessionService.truncateLyric(line)
    };
    try {
      await session.setAVMetadata(meta);
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `setAVMetadata(lyric) failed: ${err.code}`);
    }
  }

  private async applyPlaybackState(session: avSession.AVSession, track: AvTrackInfo,
    status: PlayerStatus, positionMs: number, mode: PlayMode, force: boolean): Promise<void> {
    const stateCode: avSession.PlaybackState = AvSessionService.mapState(status);
    const loopMode: avSession.LoopMode = AvSessionService.mapLoopMode(mode);
    const key: string = `${track.assetId}|${stateCode}|${mode}|${track.isFavorite}`;
    const now: number = Date.now();
    if (!force && key === this.lastStateKey && now - this.lastStateAt < STATE_THROTTLE_MS) {
      return;
    }
    this.lastStateAt = now;
    this.lastStateKey = key;
    const state: avSession.AVPlaybackState = {
      state: stateCode,
      speed: 1.0,
      bufferedTime: positionMs,
      loopMode: loopMode,
      isFavorite: track.isFavorite,
      activeItemId: track.activeItemId,
      position: {
        elapsedTime: positionMs,
        updateTime: now
      }
    };
    try {
      await session.setAVPlaybackState(state);
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `setAVPlaybackState failed: ${err.code}`);
    }
  }

  private stageLyric(lyric: string): void {
    this.lyricTimes = [];
    this.lyricLines = [];
    if (lyric.length === 0) {
      return;
    }
    const rows: string[] = lyric.split('\n');
    for (let i = 0; i < rows.length; i++) {
      const parsed: ParsedLyricRow | null = AvSessionService.parseLyricRow(rows[i]);
      if (parsed !== null) {
        this.lyricTimes.push(parsed.timeMs);
        this.lyricLines.push(parsed.text);
      }
    }
  }

  private lineAt(positionMs: number): string {
    if (this.lyricTimes.length === 0) {
      return '';
    }
    let index: number = -1;
    for (let i = 0; i < this.lyricTimes.length; i++) {
      if (this.lyricTimes[i] <= positionMs) {
        index = i;
      } else {
        break;
      }
    }
    if (index < 0) {
      return '';
    }
    return this.lyricLines[index];
  }

  private async resolveCover(coverUri: string): Promise<image.PixelMap | null> {
    if (coverUri.length === 0) {
      return null;
    }
    if (coverUri === this.lastCoverUri && this.coverPixelMap !== null) {
      return this.coverPixelMap;
    }
    let source: image.ImageSource | null = null;
    try {
      source = image.createImageSource(coverUri);
      const options: image.DecodingOptions = {
        desiredSize: { width: 512, height: 512 }
      };
      const pixel: image.PixelMap = await source.createPixelMap(options);
      this.releaseCover();
      this.coverPixelMap = pixel;
      return pixel;
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `decode cover failed: ${err.code}`);
      return null;
    } finally {
      if (source !== null) {
        try {
          await source.release();
        } catch (error) {
          Logger.warn(SCOPE, 'release image source failed');
        }
      }
    }
  }

  private releaseCover(): void {
    if (this.coverPixelMap === null) {
      return;
    }
    try {
      this.coverPixelMap.release();
    } catch (error) {
      Logger.warn(SCOPE, 'release cover pixel map failed');
    }
    this.coverPixelMap = null;
  }

  private static mapState(status: PlayerStatus): avSession.PlaybackState {
    if (status === PlayerStatus.PLAYING) {
      return avSession.PlaybackState.PLAYBACK_STATE_PLAY;
    }
    if (status === PlayerStatus.PAUSED) {
      return avSession.PlaybackState.PLAYBACK_STATE_PAUSE;
    }
    if (status === PlayerStatus.LOADING || status === PlayerStatus.RESOLVING) {
      return avSession.PlaybackState.PLAYBACK_STATE_BUFFERING;
    }
    if (status === PlayerStatus.COMPLETED) {
      return avSession.PlaybackState.PLAYBACK_STATE_COMPLETED;
    }
    if (status === PlayerStatus.ERROR) {
      return avSession.PlaybackState.PLAYBACK_STATE_ERROR;
    }
    return avSession.PlaybackState.PLAYBACK_STATE_IDLE;
  }

  private static mapLoopMode(mode: PlayMode): avSession.LoopMode {
    if (mode === PlayMode.SINGLE_LOOP) {
      return avSession.LoopMode.LOOP_MODE_SINGLE;
    }
    if (mode === PlayMode.SEQUENTIAL) {
      return avSession.LoopMode.LOOP_MODE_SEQUENCE;
    }
    if (mode === PlayMode.SHUFFLE) {
      return avSession.LoopMode.LOOP_MODE_SHUFFLE;
    }
    return avSession.LoopMode.LOOP_MODE_LIST;
  }

  /** LRC 原文按 UTF-8 字节截断到 40960 字节以内。 */
  static truncateLyric(text: string): string {
    if (text.length === 0) {
      return '';
    }
    let bytes: number = 0;
    let end: number = 0;
    for (let i = 0; i < text.length; i++) {
      const code: number = text.charCodeAt(i);
      let size: number = 1;
      if (code > 0x7FF) {
        size = 3;
      } else if (code > 0x7F) {
        size = 2;
      }
      if (bytes + size > MAX_LYRIC_BYTES) {
        break;
      }
      bytes = bytes + size;
      end = i + 1;
    }
    return text.substring(0, end);
  }

  /** 解析单行 LRC（例如 [00:12.34]歌词），无时间戳返回 null。 */
  private static parseLyricRow(row: string): ParsedLyricRow | null {
    const trimmed: string = row.trim();
    if (trimmed.length < 6 || trimmed.charAt(0) !== '[') {
      return null;
    }
    const close: number = trimmed.indexOf(']');
    if (close < 0) {
      return null;
    }
    const stamp: string = trimmed.substring(1, close);
    const parts: string[] = stamp.split(':');
    if (parts.length < 2) {
      return null;
    }
    const minutes: number = Number.parseInt(parts[0], 10);
    const secondsRaw: string = parts[1];
    const dotIndex: number = secondsRaw.indexOf('.') >= 0 ? secondsRaw.indexOf('.') : secondsRaw.indexOf(':');
    const secondsText: string = dotIndex >= 0 ? secondsRaw.substring(0, dotIndex) : secondsRaw;
    const fractionText: string = dotIndex >= 0 ? secondsRaw.substring(dotIndex + 1) : '';
    const seconds: number = Number.parseInt(secondsText, 10);
    let fraction: number = Number.parseInt(fractionText.length > 0 ? fractionText : '0', 10);
    if (Number.isNaN(minutes) || Number.isNaN(seconds) || Number.isNaN(fraction)) {
      return null;
    }
    if (fractionText.length === 2) {
      fraction = fraction * 10;
    } else if (fractionText.length === 1) {
      fraction = fraction * 100;
    }
    const text: string = trimmed.substring(close + 1).trim();
    if (text.length === 0) {
      return null;
    }
    const parsed: ParsedLyricRow = new ParsedLyricRow();
    parsed.timeMs = minutes * 60000 + seconds * 1000 + fraction;
    parsed.text = text;
    return parsed;
  }

}

/** 单行歌词解析结果。 */
class ParsedLyricRow {
  timeMs: number = 0;
  text: string = '';
}

export const avSessionService: AvSessionService = new AvSessionService();
