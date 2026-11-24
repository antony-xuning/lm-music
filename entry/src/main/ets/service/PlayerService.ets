/**
 * 播放服务：单例 AVPlayer，支持 rawfile 与沙箱文件，操作串行化。
 * UI 层不直接接触 AVPlayer，统一通过 PlayerStore → PlayerService。
 */
import { media } from '@kit.MediaKit';
import { fileIo } from '@kit.CoreFileKit';
import { resourceManager } from '@kit.LocalizationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';

const SCOPE: string = 'PlayerService';
const STATE_TIMEOUT: number = 8000;

type StateListener = (state: media.AVPlayerState) => void;

class PlayerService {
  private player: media.AVPlayer | null = null;
  private state: media.AVPlayerState = 'idle';
  private waiters: StateListener[] = [];
  private rawFd: resourceManager.RawFileDescriptor | null = null;
  private rawPath: string = '';
  private sandboxFd: number = -1;
  private userFd: number = -1;
  private chain: Promise<void> = Promise.resolve();
  private pendingRef: string = '';

  onPosition: ((ms: number) => void) | null = null;
  onDuration: ((ms: number) => void) | null = null;
  onStateChanged: ((state: media.AVPlayerState) => void) | null = null;
  onCompleted: (() => void) | null = null;
  onError: ((message: string) => void) | null = null;

  /** 串行执行，避免 reset / 设源 / prepare 交错。 */
  private enqueue(action: () => Promise<void>): Promise<void> {
    this.chain = this.chain.then(action).catch((error: BusinessError) => {
      Logger.error(SCOPE, `operation failed: ${error.code}`);
    });
    return this.chain;
  }

  async preparePlayer(): Promise<void> {
    await this.ensurePlayer();
  }

  private async ensurePlayer(): Promise<void> {
    if (this.player !== null) {
      return;
    }
    try {
      const player: media.AVPlayer = await media.createAVPlayer();
      player.on('stateChange', (state: media.AVPlayerState) => {
        this.state = state;
        const listeners: StateListener[] = this.waiters;
        this.waiters = [];
        for (let i = 0; i < listeners.length; i++) {
          listeners[i](state);
        }
        if (this.onStateChanged !== null) {
          this.onStateChanged(state);
        }
        if (state === 'completed' && this.onCompleted !== null) {
          this.onCompleted();
        }
      });
      player.on('timeUpdate', (time: number) => {
        if (this.onPosition !== null) {
          this.onPosition(time);
        }
      });
      player.on('durationUpdate', (duration: number) => {
        if (this.onDuration !== null) {
          this.onDuration(duration);
        }
      });
      player.on('error', (error: BusinessError) => {
        Logger.error(SCOPE, `player error: ${error.code} ${error.message}`);
        if (this.onError !== null) {
          this.onError(`音频播放失败（${error.code}）`);
        }
      });
      this.player = player;
      this.state = player.state;
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(SCOPE, `createAVPlayer failed: ${err.code}`);
      if (this.onError !== null) {
        this.onError('播放器初始化失败');
      }
    }
  }

  private awaitState(target: media.AVPlayerState): Promise<boolean> {
    if (this.state === target) {
      return Promise.resolve(true);
    }
    return new Promise<boolean>((resolve) => {
      let settled: boolean = false;
      let listener: StateListener = (state: media.AVPlayerState): void => {
      };
      const timer: number = setTimeout(() => {
        if (!settled) {
          settled = true;
          // 超时后必须摘掉 waiter，否则快速切歌会持续累积悬挂回调。
          const index: number = this.waiters.indexOf(listener);
          if (index >= 0) {
            this.waiters.splice(index, 1);
          }
          resolve(this.state === target);
        }
      }, STATE_TIMEOUT);
      listener = (state: media.AVPlayerState): void => {
        if (state === target && !settled) {
          settled = true;
          clearTimeout(timer);
          resolve(true);
        }
      };
      this.waiters.push(listener);
    });
  }

  /** 打开新的音频源并播放。 */
  load(ref: string, startMs: number, autoPlay: boolean, headers: Record<string, string> | null = null): Promise<void> {
    // 入队前就登记目标曲目：快速连续切歌时，中间那些已过时的 load 出队后直接跳过。
    this.pendingRef = ref;
    return this.enqueue(async () => {
      await this.ensurePlayer();
      if (this.pendingRef !== ref) {
        return;
      }
      const player: media.AVPlayer | null = this.player;
      if (player === null) {
        return;
      }
      if (this.state !== 'idle') {
        await player.reset();
        await this.awaitState('idle');
      }
      this.closeDescriptors();
      const opened: boolean = await this.assignSource(ref, headers);
      if (!opened) {
        if (this.onError !== null) {
          this.onError('音频文件不可用');
        }
        return;
      }
      const initialized: boolean = await this.awaitState('initialized');
      if (!initialized) {
        if (this.onError !== null) {
          this.onError('音频无法解码');
        }
        return;
      }
      try {
        await player.prepare();
      } catch (error) {
        const err = error as BusinessError;
        Logger.error(SCOPE, `prepare failed: ${err.code}`);
        if (this.onError !== null) {
          this.onError('音频无法解码');
        }
        return;
      }
      await this.awaitState('prepared');
      if (startMs > 0) {
        try {
          player.seek(startMs, media.SeekMode.SEEK_CLOSEST);
        } catch (error) {
          Logger.warn(SCOPE, 'initial seek failed');
        }
      }
      if (this.onDuration !== null && player.duration > 0) {
        this.onDuration(player.duration);
      }
      if (!autoPlay) {
        return;
      }
      try {
        await player.play();
      } catch (error) {
        const err = error as BusinessError;
        Logger.error(SCOPE, `play failed: ${err.code}`);
        if (this.onError !== null) {
          this.onError('播放失败，请稍后重试');
        }
      }
    });
  }

  private async assignSource(ref: string, headers: Record<string, string> | null): Promise<boolean> {
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      return false;
    }
    try {
      if (ref.startsWith('rawfile:')) {
        const relative: string = ref.substring('rawfile:'.length);
        const context = AppContextHolder.context;
        if (context === null) {
          return false;
        }
        const descriptor: resourceManager.RawFileDescriptor = context.resourceManager.getRawFdSync(relative);
        this.rawFd = descriptor;
        this.rawPath = relative;
        player.fdSrc = {
          fd: descriptor.fd,
          offset: descriptor.offset,
          length: descriptor.length
        };
        return true;
      }
      if (ref.startsWith(AppConstants.SANDBOX_PREFIX)) {
        const relative: string = ref.substring(AppConstants.SANDBOX_PREFIX.length);
        const path: string = `${AppContextHolder.filesDir}/${relative}`;
        const file = fileIo.openSync(path, fileIo.OpenMode.READ_ONLY);
        this.sandboxFd = file.fd;
        const stat = fileIo.statSync(path);
        player.fdSrc = {
          fd: file.fd,
          offset: 0,
          length: stat.size
        };
        return true;
      }
      if (ref.startsWith(AppConstants.USER_FILE_PREFIX)) {
        // 用户文件 URI（文件夹扫描曲目）：优先 fdSrc，失败回退 URL。
        try {
          const userFile = fileIo.openSync(ref, fileIo.OpenMode.READ_ONLY);
          const info = fileIo.statSync(userFile.fd);
          this.userFd = userFile.fd;
          player.fdSrc = {
            fd: userFile.fd,
            offset: 0,
            length: info.size
          };
          return true;
        } catch (error) {
          const err = error as BusinessError;
          Logger.warn(SCOPE, `open user uri failed: ${err.code}`);
          player.url = ref;
          return true;
        }
      }
      if (ref.length > 0) {
        if (headers !== null) {
          const mediaSource: media.MediaSource = await media.createMediaSourceWithUrl(ref, headers);
          await player.setMediaSource(mediaSource);
        } else {
          player.url = ref;
        }
        return true;
      }
      return false;
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(SCOPE, `assign source failed: ${err.code} ${ref}`);
      return false;
    }
  }

  private closeDescriptors(): void {
    if (this.rawFd !== null) {
      try {
        const context = AppContextHolder.context;
        if (context !== null) {
          context.resourceManager.closeRawFdSync(this.rawPath);
        }
      } catch (error) {
        Logger.warn(SCOPE, 'closeRawFd failed');
      }
      this.rawFd = null;
      this.rawPath = '';
    }
    if (this.sandboxFd >= 0) {
      try {
        fileIo.closeSync(this.sandboxFd);
      } catch (error) {
        Logger.warn(SCOPE, 'close fd failed');
      }
      this.sandboxFd = -1;
    }
    if (this.userFd >= 0) {
      try {
        fileIo.closeSync(this.userFd);
      } catch (error) {
        Logger.warn(SCOPE, 'close user fd failed');
      }
      this.userFd = -1;
    }
  }

  play(): void {
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      return;
    }
    try {
      player.play();
    } catch (error) {
      Logger.warn(SCOPE, 'play ignored');
    }
  }

  pause(): void {
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      return;
    }
    try {
      player.pause();
    } catch (error) {
      Logger.warn(SCOPE, 'pause ignored');
    }
  }

  seek(ms: number): void {
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      return;
    }
    try {
      player.seek(ms, media.SeekMode.SEEK_CLOSEST);
    } catch (error) {
      Logger.warn(SCOPE, 'seek ignored');
    }
  }

  setSpeed(rate: number): void {
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      return;
    }
    try {
      player.setSpeed(rate);
    } catch (error) {
      Logger.warn(SCOPE, 'setSpeed ignored');
    }
  }

  stop(): void {
    const player: media.AVPlayer | null = this.player;
    if (player === null) {
      return;
    }
    try {
      player.stop();
      player.reset();
    } catch (error) {
      Logger.warn(SCOPE, 'stop ignored');
    }
    // stop 后若不再 load（切歌取消、退后台、退出应用），fd 不能一直挂着。
    this.closeDescriptors();
  }

  async release(): Promise<void> {
    const player: media.AVPlayer | null = this.player;
    this.player = null;
    this.closeDescriptors();
    if (player !== null) {
      try {
        await player.release();
      } catch (error) {
        Logger.warn(SCOPE, 'release failed');
      }
    }
  }

  get currentState(): media.AVPlayerState {
    return this.state;
  }

  get currentRef(): string {
    return this.pendingRef;
  }
}

export const playerService: PlayerService = new PlayerService();


