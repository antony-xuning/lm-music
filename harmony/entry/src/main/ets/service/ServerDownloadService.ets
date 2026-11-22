/**
 * 服务器下载任务服务：列表、提交、暂停/继续/重试/删除单条/清空已完成。
 * 未在实测中确认的写接口若返回 404/405，统一标记为「服务器不支持该操作」。
 */
import { MediaSource, Song } from '../model/MediaModels';
import { ApiErrorCode, ServerDownloadTask } from '../model/ServerModels';
import { ServerSchemasAux } from '../data/ServerSchemasAux';
import { ListResult, ObjectResult } from './ServerApi';
import { ServerApiCatalog } from './ServerApiCatalog';

export class DownloadListResult {
  ok: boolean = false;
  error: string = '';
  items: ServerDownloadTask[] = [];
}

export class DownloadOpResult {
  ok: boolean = false;
  unsupported: boolean = false;
  message: string = '';
}

class DownloadAddBody {
  name: string = '';
  title: string = '';
  singer: string = '';
  album: string = '';
  source: string = '';
  songId: string = '';
  platformId: string = '';
  quality: string = '';
  filePath: string = '';
  trackId: string = '';
  type: string = 'audio';

  constructor(song: Song, quality: string) {
    this.name = song.title;
    this.title = song.title;
    this.singer = song.artist;
    this.album = song.album;
    this.source = song.source === MediaSource.SERVER_FILE ? 'local' : song.platform;
    this.songId = song.platformSongId;
    this.platformId = song.platformSongId;
    this.quality = quality;
    this.filePath = song.filePath;
    this.trackId = song.trackId;
  }
}

export class ServerDownloadService {
  static async list(): Promise<DownloadListResult> {
    const result: DownloadListResult = new DownloadListResult();
    const response: ListResult = await ServerApiCatalog.downloadList();
    if (!response.ok) {
      result.error = response.message;
      return result;
    }
    for (let i = 0; i < response.items.length; i++) {
      const task: ServerDownloadTask = ServerSchemasAux.downloadTaskFrom(response.items[i]);
      if (task.id.length === 0) {
        task.id = `task_${i}_${task.name}`;
      }
      result.items.push(task);
    }
    result.ok = true;
    return result;
  }

  static async add(song: Song, quality: string): Promise<DownloadOpResult> {
    const body: string = JSON.stringify(new DownloadAddBody(song, quality));
    const response: ObjectResult = await ServerApiCatalog.downloadAdd(body);
    return toOpResult(response, '已提交下载任务');
  }

  static async pause(id: string): Promise<DownloadOpResult> {
    const response: ObjectResult = await ServerApiCatalog.downloadAction(id, 'pause');
    return toOpResult(response, '任务已暂停');
  }

  static async resume(id: string): Promise<DownloadOpResult> {
    const response: ObjectResult = await ServerApiCatalog.downloadAction(id, 'resume');
    return toOpResult(response, '任务已继续');
  }

  static async retry(id: string): Promise<DownloadOpResult> {
    const response: ObjectResult = await ServerApiCatalog.downloadAction(id, 'retry');
    return toOpResult(response, '任务已重新排队');
  }

  static async dismiss(id: string): Promise<DownloadOpResult> {
    const response: ObjectResult = await ServerApiCatalog.downloadDismiss(id);
    return toOpResult(response, '任务已删除');
  }

  static async clearCompleted(): Promise<DownloadOpResult> {
    const response: ObjectResult = await ServerApiCatalog.downloadClearCompleted();
    return toOpResult(response, '已清空已完成任务');
  }
}

function toOpResult(response: ObjectResult, successMessage: string): DownloadOpResult {
  const result: DownloadOpResult = new DownloadOpResult();
  if (response.ok) {
    result.ok = true;
    result.message = successMessage;
    return result;
  }
  result.unsupported = response.code === ApiErrorCode.NOT_FOUND
    || response.code === ApiErrorCode.UNSUPPORTED
    || response.code === ApiErrorCode.FORBIDDEN;
  result.message = result.unsupported ? '服务器不支持该操作' : response.message;
  return result;
}
