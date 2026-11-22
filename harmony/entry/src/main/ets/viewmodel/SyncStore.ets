/**
 * 同步 Store：同步阶段、进度、最后成功时间与错误；触发一次性整库同步。
 */
import { Logger } from '../common/Logger';
import { ServerSnapshot } from '../data/ServerCache';
import { ConnectionState, SyncPhase } from '../model/ServerModels';
import { SyncOutcome, serverSync } from '../service/ServerSync';
import { libraryStore } from './LibraryStore';
import { serverStore } from './ServerStore';
import { settingsStore } from './SettingsStore';

const SCOPE: string = 'SyncStore';

@ObservedV2
export class SyncStore {
  @Trace phase: SyncPhase = SyncPhase.IDLE;
  @Trace fetched: number = 0;
  @Trace total: number = 0;
  @Trace lastSuccessAt: number = 0;
  @Trace error: string = '';
  @Trace busy: boolean = false;

  get hasData(): boolean {
    return libraryStore.serverSongs.length > 0;
  }

  get label(): string {
    if (this.busy) {
      if (this.total > 0) {
        return `正在同步 ${this.fetched}/${this.total}`;
      }
      return '正在同步…';
    }
    if (this.phase === SyncPhase.ERROR && this.error.length > 0) {
      return `同步失败：${this.error}`;
    }
    if (this.lastSuccessAt > 0) {
      return '已同步';
    }
    return '尚未同步';
  }

  async syncNow(force: boolean = false): Promise<boolean> {
    const server = serverStore.activeServer;
    if (server === null) {
      this.error = '尚未配置服务器';
      this.phase = SyncPhase.ERROR;
      return false;
    }
    if (this.busy) {
      return false;
    }
    if (!force && this.lastSuccessAt > 0 && Date.now() - this.lastSuccessAt < 60000) {
      return true;
    }
    if (serverStore.state !== ConnectionState.ONLINE) {
      this.error = serverStore.errorText.length > 0 ? serverStore.errorText : '服务器未连接';
      this.phase = SyncPhase.ERROR;
      return false;
    }
    this.busy = true;
    this.error = '';
    this.fetched = 0;
    this.total = 0;
    this.phase = SyncPhase.CONNECTING;
    try {
      const outcome: SyncOutcome = await serverSync.run(server.id, (phase: SyncPhase, fetched: number,
        total: number) => {
        this.phase = phase;
        this.fetched = fetched;
        this.total = total;
      });
      if (outcome.ok && outcome.snapshot !== null) {
        const snapshot: ServerSnapshot = outcome.snapshot;
        libraryStore.applySnapshot(snapshot);
        this.lastSuccessAt = snapshot.syncedAt;
        this.phase = SyncPhase.DONE;
        this.error = '';
        settingsStore.setSyncMeta(server.id, snapshot.syncedAt, snapshot.songs.length);
        serverStore.markOnline(snapshot.songs.length);
        Logger.info(SCOPE, `sync success: ${snapshot.songs.length}`);
        return true;
      }
      this.phase = SyncPhase.ERROR;
      this.error = outcome.error.length > 0 ? outcome.error : '同步失败';
      if (this.error.indexOf('无法连接') >= 0) {
        serverStore.markOffline(this.error);
      }
      return false;
    } finally {
      this.busy = false;
    }
  }

  reset(): void {
    this.phase = SyncPhase.IDLE;
    this.fetched = 0;
    this.total = 0;
    this.error = '';
  }
}

export const syncStore: SyncStore = new SyncStore();
