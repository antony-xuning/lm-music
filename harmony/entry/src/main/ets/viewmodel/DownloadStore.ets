/**
 * 服务器下载任务 Store：任务列表、状态映射、轮询与动作。
 * 下载的是「服务器曲库文件」，不计入本机存储。
 */
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { ServerEndpoints } from '../common/ServerEndpoints';
import { JsonStore } from '../data/JsonStore';
import { ServerDownloadTask } from '../model/ServerModels';
import { Song } from '../model/MediaModels';
import { DownloadListResult, DownloadOpResult, ServerDownloadService } from '../service/ServerDownloadService';
import { settingsStore } from './SettingsStore';
import { syncStore } from './SyncStore';

const SCOPE: string = 'DownloadStore';
const POLL_MS: number = 3000;
const CACHE_FILE: string = AppConstants.FILE_DOWNLOADS;

interface TaskCacheRaw {
  id?: string;
  name?: string;
  singer?: string;
  album?: string;
  source?: string;
  platformId?: string;
  quality?: string;
  status?: string;
  progress?: number;
  bytesDone?: number;
  bytesTotal?: number;
  speed?: number;
  filePath?: string;
  error?: string;
  createdAt?: number;
  updatedAt?: number;
}

interface CacheDoc {
  schemaVersion?: number;
  tasks?: TaskCacheRaw[];
}

@ObservedV2
export class DownloadStore {
  @Trace tasks: ServerDownloadTask[] = [];
  @Trace loading: boolean = false;
  @Trace errorText: string = '';
  @Trace polling: boolean = false;
  @Trace lastUpdatedAt: number = 0;
  @Trace completedNotice: string = '';

  private started: boolean = false;
  private timerId: number = -1;
  private lastCompletedCount: number = 0;
  private pageVisible: boolean = false;

  init(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.restoreCache();
  }

  get activeCount(): number {
    let count: number = 0;
    for (let i = 0; i < this.tasks.length; i++) {
      const status: string = this.tasks[i].status;
      if (status === 'downloading' || status === 'waiting') {
        count++;
      }
    }
    return count;
  }

  get completedCount(): number {
    let count: number = 0;
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].status === 'completed') {
        count++;
      }
    }
    return count;
  }

  get grouped(): string[] {
    return ['下载中', '等待中', '已暂停', '已完成', '失败'];
  }

  tasksOf(label: string): ServerDownloadTask[] {
    const result: ServerDownloadTask[] = [];
    for (let i = 0; i < this.tasks.length; i++) {
      const status: string = this.tasks[i].status;
      const match: boolean = (label === '下载中' && status === 'downloading')
        || (label === '等待中' && status === 'waiting')
        || (label === '已暂停' && status === 'paused')
        || (label === '已完成' && status === 'completed')
        || (label === '失败' && status === 'failed');
      if (match) {
        result.push(this.tasks[i]);
      }
    }
    return result;
  }

  findTask(id: string): ServerDownloadTask | null {
    for (let i = 0; i < this.tasks.length; i++) {
      if (this.tasks[i].id === id) {
        return this.tasks[i];
      }
    }
    return null;
  }

  /** 页面可见时启动轮询（有活动任务才真正请求）。 */
  setPageVisible(visible: boolean): void {
    this.pageVisible = visible;
    if (visible) {
      this.refresh();
      this.ensurePolling();
    } else {
      this.stopPolling();
    }
  }

  private ensurePolling(): void {
    if (this.timerId >= 0) {
      return;
    }
    this.timerId = setInterval(() => {
      if (!this.pageVisible) {
        this.stopPolling();
        return;
      }
      if (this.activeCount === 0 && !this.loading) {
        this.stopPolling();
        return;
      }
      this.refresh();
    }, POLL_MS);
    this.polling = true;
  }

  private stopPolling(): void {
    if (this.timerId >= 0) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
    this.polling = false;
  }

  async refresh(): Promise<void> {
    if (!serverStoreCanRead()) {
      this.errorText = '尚未连接柠檬音乐服务器';
      return;
    }
    if (this.loading) {
      return;
    }
    this.loading = true;
    try {
      const result: DownloadListResult = await ServerDownloadService.list();
      if (!result.ok) {
        this.errorText = result.error.length > 0 ? result.error : '读取下载任务失败';
        return;
      }
      this.tasks = result.items;
      this.errorText = '';
      this.lastUpdatedAt = Date.now();
      this.persistCache();
      this.checkCompletion();
      if (this.activeCount > 0) {
        this.ensurePolling();
      }
    } finally {
      this.loading = false;
    }
  }

  private checkCompletion(): void {
    const completed: number = this.completedCount;
    if (completed > this.lastCompletedCount) {
      this.lastCompletedCount = completed;
      this.completedNotice = '下载完成，正在刷新曲库';
      syncStore.syncNow(true);
    } else if (this.lastCompletedCount === 0) {
      this.lastCompletedCount = completed;
    }
  }

  async addFromSong(song: Song, qualityLevel: string): Promise<DownloadOpResult> {
    if (!serverStoreCanRead()) {
      const blocked: DownloadOpResult = new DownloadOpResult();
      blocked.message = '尚未连接柠檬音乐服务器';
      return blocked;
    }
    const quality: string = ServerEndpoints.qualityKey(qualityLevel);
    const result: DownloadOpResult = await ServerDownloadService.add(song, quality);
    if (result.ok) {
      this.refresh();
    }
    return result;
  }

  async pause(id: string): Promise<DownloadOpResult> {
    const result: DownloadOpResult = await ServerDownloadService.pause(id);
    if (result.ok) {
      this.refresh();
    }
    return result;
  }

  async resume(id: string): Promise<DownloadOpResult> {
    const result: DownloadOpResult = await ServerDownloadService.resume(id);
    if (result.ok) {
      this.refresh();
    }
    return result;
  }

  async retry(id: string): Promise<DownloadOpResult> {
    const result: DownloadOpResult = await ServerDownloadService.retry(id);
    if (result.ok) {
      this.refresh();
    }
    return result;
  }

  async dismiss(id: string): Promise<DownloadOpResult> {
    const result: DownloadOpResult = await ServerDownloadService.dismiss(id);
    if (result.ok) {
      this.refresh();
    }
    return result;
  }

  async clearCompleted(): Promise<DownloadOpResult> {
    const result: DownloadOpResult = await ServerDownloadService.clearCompleted();
    if (result.ok) {
      this.refresh();
    }
    return result;
  }

  private restoreCache(): void {
    const text: string | null = JsonStore.readText(CACHE_FILE);
    if (text === null || text.length === 0) {
      return;
    }
    try {
      const doc: CacheDoc = JSON.parse(text) as CacheDoc;
      const raws: TaskCacheRaw[] = Array.isArray(doc.tasks) ? doc.tasks : [];
      const list: ServerDownloadTask[] = [];
      for (let i = 0; i < raws.length; i++) {
        list.push(fromCacheRaw(raws[i]));
      }
      this.tasks = list;
      this.lastCompletedCount = this.completedCount;
    } catch (error) {
      Logger.warn(SCOPE, 'download cache unreadable');
    }
  }

  private persistCache(): void {
    const raws: TaskCacheRaw[] = [];
    for (let i = 0; i < this.tasks.length; i++) {
      raws.push(toCacheRaw(this.tasks[i]));
    }
    const doc: CacheDoc = {
      schemaVersion: AppConstants.SCHEMA_VERSION,
      tasks: raws
    };
    JsonStore.writeText(CACHE_FILE, JSON.stringify(doc));
  }
}

function serverStoreCanRead(): boolean {
  return settingsStore.activeServer !== null && settingsStore.activeServer.token.length > 0;
}

function toCacheRaw(task: ServerDownloadTask): TaskCacheRaw {
  return {
    id: task.id,
    name: task.name,
    singer: task.singer,
    album: task.album,
    source: task.source,
    platformId: task.platformId,
    quality: task.quality,
    status: task.status,
    progress: task.progress,
    bytesDone: task.bytesDone,
    bytesTotal: task.bytesTotal,
    speed: task.speed,
    filePath: task.filePath,
    error: task.error,
    createdAt: task.createdAt,
    updatedAt: task.updatedAt
  };
}

function fromCacheRaw(raw: TaskCacheRaw): ServerDownloadTask {
  const task: ServerDownloadTask = new ServerDownloadTask();
  task.id = typeof raw.id === 'string' ? raw.id : '';
  task.name = typeof raw.name === 'string' ? raw.name : '未命名任务';
  task.singer = typeof raw.singer === 'string' ? raw.singer : '';
  task.album = typeof raw.album === 'string' ? raw.album : '';
  task.source = typeof raw.source === 'string' ? raw.source : '';
  task.platformId = typeof raw.platformId === 'string' ? raw.platformId : '';
  task.quality = typeof raw.quality === 'string' ? raw.quality : '';
  task.status = typeof raw.status === 'string' ? raw.status : 'waiting';
  task.progress = typeof raw.progress === 'number' ? raw.progress : 0;
  task.bytesDone = typeof raw.bytesDone === 'number' ? raw.bytesDone : 0;
  task.bytesTotal = typeof raw.bytesTotal === 'number' ? raw.bytesTotal : 0;
  task.speed = typeof raw.speed === 'number' ? raw.speed : 0;
  task.filePath = typeof raw.filePath === 'string' ? raw.filePath : '';
  task.error = typeof raw.error === 'string' ? raw.error : '';
  task.createdAt = typeof raw.createdAt === 'number' ? raw.createdAt : 0;
  task.updatedAt = typeof raw.updatedAt === 'number' ? raw.updatedAt : 0;
  return task;
}

export const downloadStore: DownloadStore = new DownloadStore();
