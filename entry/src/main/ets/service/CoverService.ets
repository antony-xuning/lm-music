/**
 * 封面缓存：服务器封面经鉴权下载后落盘到 cacheDir/covers，
 * 在线封面按外链 URL 下载。命中缓存不重复请求；失败返回空串由 Artwork 回退渐变。
 */
import { fileIo } from '@kit.CoreFileKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { ServerEndpoints } from '../common/ServerEndpoints';
import { Limiter, Utils } from '../common/Utils';
import { MediaSource, PlayableItem, Song } from '../model/MediaModels';
import { HttpBytesResult, HttpClient } from './HttpClient';
import { serverContext } from './ServerContext';

const SCOPE: string = 'CoverService';

class CoverService {
  private inFlight: Map<string, Promise<string>> = new Map<string, Promise<string>>();
  private limiter: Limiter = new Limiter(AppConstants.COVER_CONCURRENCY);

  private dir(): string {
    return `${AppContextHolder.cacheDir}/${AppConstants.COVER_CACHE_DIR}`;
  }

  private ensureDir(): string {
    const dir: string = this.dir();
    try {
      if (dir.length > 5 && !fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
    } catch (error) {
      Logger.warn(SCOPE, 'create cover dir failed');
    }
    return dir;
  }

  /** 服务器文件封面 URL（带 mtime 版本）。 */
  static serverCoverUrl(filePath: string, mtime: number): string {
    const encoded: string = encodeURIComponent(filePath);
    const version: string = mtime > 0 ? `${mtime}` : '0';
    return `${ServerEndpoints.join(serverContext.baseUrl, ServerEndpoints.TAG_COVER)}?path=${encoded}&v=${version}`;
  }

  /** 返回可直接用于 Image 的 file:// URI，失败返回空串。 */
  async uriForSong(song: Song): Promise<string> {
    if (song.source === MediaSource.SERVER_FILE) {
      if (song.filePath.length === 0) {
        return '';
      }
      const key: string = `cover|${song.serverId}|${song.filePath}|${song.mtime}`;
      return this.fetch(key, CoverService.serverCoverUrl(song.filePath, song.mtime), true);
    }
    if (song.coverUrl.length > 0) {
      return this.uriForUrl(song.coverUrl);
    }
    return '';
  }

  async uriForUrl(url: string): Promise<string> {
    if (url.length === 0) {
      return '';
    }
    return this.fetch(`url|${url}`, url, false);
  }

  /** 队列元素封面（无需回查曲库）。 */
  async uriForItem(item: PlayableItem): Promise<string> {
    if (item.mediaSource === MediaSource.SERVER_FILE) {
      if (item.filePath.length === 0) {
        return '';
      }
      const key: string = `cover|${item.serverId}|${item.filePath}|${item.mtime}`;
      return this.fetch(key, CoverService.serverCoverUrl(item.filePath, item.mtime), true);
    }
    if (item.coverUrl.length > 0) {
      return this.uriForUrl(item.coverUrl);
    }
    return '';
  }

  private async fetch(key: string, url: string, auth: boolean): Promise<string> {
    const cached: string = this.cachedPath(key);
    if (cached.length > 0) {
      return `file://${cached}`;
    }
    const pending: Promise<string> | undefined = this.inFlight.get(key);
    if (pending !== undefined) {
      return pending;
    }
    const task: Promise<string> = this.download(key, url, auth);
    this.inFlight.set(key, task);
    try {
      return await task;
    } finally {
      this.inFlight.delete(key);
    }
  }

  private cachedPath(key: string): string {
    const dir: string = this.ensureDir();
    const base: string = `${dir}/${Utils.stableId(key)}`;
    const extensions: string[] = ['jpg', 'png', 'gif', 'webp'];
    for (let i = 0; i < extensions.length; i++) {
      const candidate: string = `${base}.${extensions[i]}`;
      try {
        if (fileIo.accessSync(candidate)) {
          return candidate;
        }
      } catch (error) {
        Logger.warn(SCOPE, 'access cover failed');
      }
    }
    return '';
  }

  private async download(key: string, url: string, auth: boolean): Promise<string> {
    let value: string = '';
    await this.limiter.run(async () => {
      value = await this.downloadNow(key, url, auth);
    });
    return value;
  }

  private async downloadNow(key: string, url: string, auth: boolean): Promise<string> {
    const headers: Record<string, string> = auth ? serverContext.authHeaders() : {};
    const result: HttpBytesResult = await HttpClient.requestBytes(url, headers, AppConstants.COVER_TIMEOUT_MS);
    if (!result.ok || result.bytes.byteLength === 0) {
      return '';
    }
    const ext: string = sniffExtension(result.bytes);
    const path: string = `${this.ensureDir()}/${Utils.stableId(key)}.${ext}`;
    try {
      const file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE
        | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, result.bytes);
      } finally {
        fileIo.closeSync(file);
      }
      this.pruneIfNeeded();
      return `file://${path}`;
    } catch (error) {
      Logger.warn(SCOPE, 'write cover failed');
      return '';
    }
  }

  /** 文件数超过上限时按修改时间删除最旧的一批。 */
  private pruneIfNeeded(): void {
    const dir: string = this.ensureDir();
    try {
      const names: string[] = fileIo.listFileSync(dir);
      if (names.length <= AppConstants.COVER_CACHE_MAX_FILES) {
        return;
      }
      const times: number[] = [];
      for (let i = 0; i < names.length; i++) {
        try {
          times.push(fileIo.statSync(`${dir}/${names[i]}`).mtime);
        } catch (error) {
          times.push(0);
        }
      }
      const order: number[] = [];
      for (let i = 0; i < names.length; i++) {
        order.push(i);
      }
      order.sort((a: number, b: number) => times[a] - times[b]);
      const removeCount: number = Math.max(names.length - AppConstants.COVER_CACHE_MAX_FILES, 0);
      for (let i = 0; i < removeCount; i++) {
        try {
          fileIo.unlinkSync(`${dir}/${names[order[i]]}`);
        } catch (error) {
          Logger.warn(SCOPE, 'prune cover failed');
        }
      }
    } catch (error) {
      Logger.warn(SCOPE, 'list cover dir failed');
    }
  }
}

function sniffExtension(bytes: ArrayBuffer): string {
  const view: Uint8Array = new Uint8Array(bytes);
  if (view.length >= 3 && view[0] === 0xFF && view[1] === 0xD8) {
    return 'jpg';
  }
  if (view.length >= 4 && view[0] === 0x89 && view[1] === 0x50) {
    return 'png';
  }
  if (view.length >= 3 && view[0] === 0x47 && view[1] === 0x49) {
    return 'gif';
  }
  if (view.length >= 4 && view[0] === 0x52 && view[1] === 0x49) {
    return 'webp';
  }
  return 'jpg';
}

export const coverService: CoverService = new CoverService();
