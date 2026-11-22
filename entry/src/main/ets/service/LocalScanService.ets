/**
 * 本地扫描服务：文件夹选择与持久授权、递归列目录、标签/封面提取、增量 diff 与取消。
 * 扫描结果先在内存构建，结束后一次性原子写入 local_index.json。
 */
import { picker, fileShare, fileIo, fileUri, ListFileOptions } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { Limiter } from '../common/Utils';
import {
  LocalFolder,
  LocalIndexDoc,
  LocalScanHelper,
  LocalScanPhase,
  LocalScanState,
  LocalTrack
} from '../model/LocalScanModels';
import { LocalIndexStore } from '../data/LocalIndexStore';
import { LocalTrackTags, MediaTagService } from './MediaTagService';

const SCOPE: string = 'LocalScanService';

class AudioEntry {
  uri: string = '';
  path: string = '';
  folderUri: string = '';
  fileName: string = '';
  sizeBytes: number = 0;
  mtime: number = 0;
}

export class ScanResult {
  ok: boolean = false;
  cancelled: boolean = false;
  busy: boolean = false;
  message: string = '';
  folders: LocalFolder[] = [];
  tracks: LocalTrack[] = [];
  lastScanAt: number = 0;
  added: number = 0;
  updated: number = 0;
  removed: number = 0;
  errorCount: number = 0;
  errors: string[] = [];
  totalBytes: number = 0;
}

type ScanProgressListener = (state: LocalScanState) => void;

class LocalScanServiceImpl {
  private cancelFlag: boolean = false;
  private running: boolean = false;
  private lastEmitAt: number = 0;

  /** 拉起系统文件夹选择器并做持久化授权。 */
  async pickFolder(): Promise<LocalFolder | null> {
    const context = AppContextHolder.context;
    if (context === null) {
      Logger.warn(SCOPE, 'context not ready');
      return null;
    }
    const options: picker.DocumentSelectOptions = new picker.DocumentSelectOptions();
    options.maxSelectNumber = 1;
    options.selectMode = picker.DocumentSelectMode.FOLDER;
    options.allowsMulFolderSelection = false;
    let uris: string[] = [];
    try {
      const documentPicker: picker.DocumentViewPicker = new picker.DocumentViewPicker(context);
      uris = await documentPicker.select(options);
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `folder picker failed: ${err.code}`);
      return null;
    }
    if (uris.length === 0) {
      return null;
    }
    const uri: string = uris[0];
    await this.persist(uri);
    const folder: LocalFolder = new LocalFolder();
    folder.uri = uri;
    folder.displayName = LocalScanHelper.nameOfUri(uri);
    folder.addedAt = Date.now();
    return folder;
  }

  private async persist(uri: string): Promise<boolean> {
    if (!this.canPersist()) {
      Logger.warn(SCOPE, 'folder authorization unsupported, temporary permission only');
      return false;
    }
    const policy: fileShare.PolicyInfo = {
      uri: uri,
      operationMode: fileShare.OperationMode.READ_MODE
    };
    try {
      await fileShare.persistPermission([policy]);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `persistPermission failed: ${err.code}`);
      return false;
    }
  }

  private canPersist(): boolean {
    try {
      return canIUse('SystemCapability.FileManagement.AppFileService.FolderAuthorization');
    } catch (error) {
      return false;
    }
  }

  /** 冷启动激活已持久化授权；失败的目录标记 invalid 并保留索引数据。 */
  async activateSavedFolders(folders: LocalFolder[]): Promise<LocalFolder[]> {
    const result: LocalFolder[] = [];
    for (let i = 0; i < folders.length; i++) {
      const folder: LocalFolder = folders[i];
      const activated: boolean = await this.activate(folder.uri);
      if (!activated) {
        folder.invalid = true;
        folder.error = '授权已失效，请重新添加该文件夹';
      } else if (this.listRelative(folder.uri) === null) {
        folder.invalid = true;
        folder.error = '文件夹不可访问或已不存在';
      } else {
        folder.invalid = false;
        folder.error = '';
      }
      result.push(folder);
    }
    return result;
  }

  private async activate(uri: string): Promise<boolean> {
    if (!this.canPersist()) {
      // 无持久授权能力时，依赖本次会话的临时授权。
      return this.listRelative(uri) !== null;
    }
    const policy: fileShare.PolicyInfo = {
      uri: uri,
      operationMode: fileShare.OperationMode.READ_MODE
    };
    try {
      await fileShare.activatePermission([policy]);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `activatePermission failed: ${err.code}`);
      if (err.code === 13900001 || err.code === 13900012) {
        const repersisted: boolean = await this.persist(uri);
        if (repersisted) {
          return true;
        }
      }
      return false;
    }
  }

  /** 扫描全部文件夹（或指定单个文件夹），返回新索引与增量统计。 */
  async scan(folders: LocalFolder[], previousTracks: LocalTrack[], targetFolderUri: string,
    onProgress: ScanProgressListener): Promise<ScanResult> {
    const result: ScanResult = new ScanResult();
    if (this.running) {
      result.busy = true;
      result.message = '扫描正在进行中';
      return result;
    }
    this.running = true;
    this.cancelFlag = false;
    this.lastEmitAt = 0;
    const startedAt: number = Date.now();
    const state: LocalScanState = new LocalScanState();
    state.phase = LocalScanPhase.SCANNING;
    state.startedAt = startedAt;
    onProgress(state);

    const targets: LocalFolder[] = [];
    for (let i = 0; i < folders.length; i++) {
      if (targetFolderUri.length === 0 || folders[i].uri === targetFolderUri) {
        targets.push(folders[i]);
      }
    }
    const scannedFolderUris: Set<string> = new Set<string>();
    const targetSet: Set<string> = new Set<string>();
    for (let i = 0; i < targets.length; i++) {
      targetSet.add(targets[i].uri);
    }
    const entries: AudioEntry[] = [];
    const seen: Set<string> = new Set<string>();
    const updatedFolders: LocalFolder[] = [];
    let folderErrorCount: number = 0;

    for (let i = 0; i < folders.length; i++) {
      const folder: LocalFolder = folders[i];
      if (!targetSet.has(folder.uri)) {
        updatedFolders.push(folder);
        continue;
      }
      const activated: boolean = await this.activate(folder.uri);
      const relatives: string[] | null = activated ? this.listRelative(folder.uri) : null;
      if (relatives === null) {
        folder.invalid = true;
        folder.error = '文件夹不可访问，请重新授权';
        folderErrorCount++;
        state.errorCount = folderErrorCount;
        state.errors.push(`${folder.displayName}：${folder.error}`);
        updatedFolders.push(folder);
        continue;
      }
      folder.invalid = false;
      folder.error = '';
      scannedFolderUris.add(folder.uri);
      const folderPath: string = this.pathOfUri(folder.uri);
      let fileCount: number = 0;
      for (let k = 0; k < relatives.length; k++) {
        const relative: string = relatives[k];
        const fileName: string = LocalScanHelper.nameOfPath(relative);
        if (!LocalScanHelper.isAudioFile(fileName)) {
          continue;
        }
        const entry: AudioEntry = new AudioEntry();
        entry.fileName = fileName;
        entry.folderUri = folder.uri;
        entry.uri = this.joinUri(folder.uri, relative);
        entry.path = folderPath.length > 0 ? `${folderPath}/${this.trimLeading(relative)}` : '';
        const stat: fileIo.Stat | null = this.statOf(entry.uri, entry.path);
        if (stat === null) {
          folderErrorCount++;
          state.errorCount = folderErrorCount;
          state.errors.push(`${fileName}：无法读取文件信息`);
          continue;
        }
        entry.sizeBytes = stat.size;
        entry.mtime = stat.mtime;
        if (seen.has(entry.uri)) {
          continue;
        }
        seen.add(entry.uri);
        entries.push(entry);
        fileCount++;
      }
      folder.fileCount = fileCount;
      folder.lastScanAt = Date.now();
      updatedFolders.push(folder);
      state.discovered = entries.length;
      this.emit(state, onProgress, false);
    }

    // 逐文件读取标签：并发 ≤3，取消后跳过剩余文件。
    const limiter: Limiter = new Limiter(AppConstants.SCAN_CONCURRENCY);
    const slots: (LocalTrack | null)[] = [];
    for (let i = 0; i < entries.length; i++) {
      slots.push(null);
    }
    const previousByUri: Map<string, LocalTrack> = new Map<string, LocalTrack>();
    for (let i = 0; i < previousTracks.length; i++) {
      previousByUri.set(previousTracks[i].uri, previousTracks[i]);
    }
    const tasks: Promise<void>[] = [];
    for (let index = 0; index < entries.length; index++) {
      const entry: AudioEntry = entries[index];
      tasks.push(limiter.run(async (): Promise<void> => {
        if (this.cancelFlag) {
          return;
        }
        const previous: LocalTrack | undefined = previousByUri.get(entry.uri);
        slots[index] = await this.buildTrack(entry, previous);
        state.scanned = state.scanned + 1;
        state.currentFile = entry.fileName;
        this.emit(state, onProgress, false);
      }));
    }
    await Promise.all(tasks);

    const cancelled: boolean = this.cancelFlag;
    if (cancelled) {
      // 取消时绝不写索引，保留上一次的完整结果。
      result.cancelled = true;
      result.ok = false;
      result.folders = folders;
      result.tracks = previousTracks;
      result.message = '已取消扫描，保留上次索引';
      state.phase = LocalScanPhase.CANCELLED;
      this.emit(state, onProgress, true);
      this.running = false;
      this.cancelFlag = false;
      return result;
    }
    const nextTracks: LocalTrack[] = [];
    const keptOther: LocalTrack[] = [];
    const nextUris: Set<string> = new Set<string>();
    for (let i = 0; i < slots.length; i++) {
      const track: LocalTrack | null = slots[i];
      if (track !== null) {
        nextTracks.push(track);
        nextUris.add(track.uri);
      }
    }
    for (let i = 0; i < previousTracks.length; i++) {
      const previous: LocalTrack = previousTracks[i];
      if (!scannedFolderUris.has(previous.folderUri)) {
        keptOther.push(previous);
      }
    }

    state.phase = cancelled ? LocalScanPhase.CANCELLED : LocalScanPhase.DIFFING;
    this.emit(state, onProgress, true);

    let added: number = 0;
    let updated: number = 0;
    for (let i = 0; i < nextTracks.length; i++) {
      const previous: LocalTrack | undefined = previousByUri.get(nextTracks[i].uri);
      if (previous === undefined) {
        added++;
      } else if (previous.sizeBytes !== nextTracks[i].sizeBytes || previous.mtime !== nextTracks[i].mtime) {
        updated++;
      }
    }
    let removed: number = 0;
    for (let i = 0; i < previousTracks.length; i++) {
      const previous: LocalTrack = previousTracks[i];
      if (scannedFolderUris.has(previous.folderUri) && !nextUris.has(previous.uri)) {
        removed++;
      }
    }

    const merged: LocalTrack[] = nextTracks.concat(keptOther);
    let totalBytes: number = 0;
    for (let i = 0; i < merged.length; i++) {
      totalBytes += merged[i].sizeBytes;
    }
    const finishedAt: number = Date.now();
    state.scanned = nextTracks.length;
    state.discovered = nextTracks.length;
    state.added = added;
    state.updated = updated;
    state.removed = removed;
    state.totalBytes = totalBytes;
    state.finishedAt = finishedAt;
    state.phase = cancelled ? LocalScanPhase.CANCELLED : LocalScanPhase.DONE;

    const doc: LocalIndexDoc = new LocalIndexDoc();
    doc.folders = updatedFolders;
    doc.tracks = merged;
    doc.lastScanAt = finishedAt;
    const saved: boolean = LocalIndexStore.save(doc);

    result.ok = saved && !cancelled;
    result.cancelled = cancelled;
    result.folders = updatedFolders;
    result.tracks = merged;
    result.lastScanAt = finishedAt;
    result.added = added;
    result.updated = updated;
    result.removed = removed;
    result.errorCount = state.errorCount;
    result.errors = state.errors.slice(0, 8);
    result.totalBytes = totalBytes;
    result.message = this.resultMessage(saved, cancelled, added, updated, removed, state.errorCount);
    state.phase = cancelled ? LocalScanPhase.CANCELLED : (saved ? LocalScanPhase.DONE : LocalScanPhase.ERROR);
    this.emit(state, onProgress, true);
    this.running = false;
    this.cancelFlag = false;
    return result;
  }

  private resultMessage(saved: boolean, cancelled: boolean, added: number, updated: number,
    removed: number, errors: number): string {
    if (cancelled) {
      return '已取消扫描，保留上次索引';
    }
    if (!saved) {
      return '索引写入失败，本次扫描结果未保存';
    }
    const parts: string[] = [`新增 ${added}`];
    if (updated > 0) {
      parts.push(`更新 ${updated}`);
    }
    if (removed > 0) {
      parts.push(`移除 ${removed}`);
    }
    if (errors > 0) {
      parts.push(`跳过 ${errors} 个异常`);
    }
    return `扫描完成：${parts.join(' · ')}`;
  }

  cancel(): void {
    this.cancelFlag = true;
  }

  get isRunning(): boolean {
    return this.running;
  }

  /** 移除文件夹：撤销持久化授权，索引由 Store 更新。 */
  async removeFolder(folderUri: string): Promise<boolean> {
    if (!this.canPersist()) {
      return true;
    }
    const policy: fileShare.PolicyInfo = {
      uri: folderUri,
      operationMode: fileShare.OperationMode.READ_MODE
    };
    try {
      await fileShare.revokePermission([policy]);
      return true;
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `revokePermission failed: ${err.code}`);
      return false;
    }
  }

  private async buildTrack(entry: AudioEntry, previous: LocalTrack | undefined): Promise<LocalTrack> {
    const track: LocalTrack = new LocalTrack();
    track.uri = entry.uri;
    track.folderUri = entry.folderUri;
    track.fileName = entry.fileName;
    track.sizeBytes = entry.sizeBytes;
    track.mtime = entry.mtime;
    track.format = LocalScanHelper.formatOf(entry.fileName);
    track.id = LocalScanHelper.trackIdOf(entry.uri);
    track.addedAt = previous !== undefined && previous.addedAt > 0 ? previous.addedAt : Date.now();
    if (previous !== undefined && previous.sizeBytes === entry.sizeBytes && previous.mtime === entry.mtime
      && previous.title.length > 0) {
      // 文件未变化：直接复用上次的标签与封面键。
      track.title = previous.title;
      track.artist = previous.artist;
      track.album = previous.album;
      track.durationMs = previous.durationMs;
      track.sampleRate = previous.sampleRate;
      track.bitDepth = previous.bitDepth;
      track.coverCacheKey = previous.coverCacheKey;
      track.hasCover = previous.hasCover;
      return track;
    }
    const cacheKey: string = MediaTagService.coverKeyFor(entry.uri, entry.sizeBytes, entry.mtime);
    const tags: LocalTrackTags = await MediaTagService.read(entry.uri, entry.path, cacheKey);
    const fileArtist: string = LocalScanHelper.artistOfFile(entry.fileName);
    track.title = tags.title.length > 0 ? tags.title : LocalScanHelper.titleOfFile(entry.fileName);
    track.artist = tags.artist.length > 0 ? tags.artist : (fileArtist.length > 0 ? fileArtist : '未知歌手');
    track.album = tags.album.length > 0 ? tags.album : '未知专辑';
    track.durationMs = tags.durationMs;
    track.sampleRate = tags.sampleRate;
    track.bitDepth = tags.bitDepth;
    track.coverCacheKey = tags.coverCacheKey;
    track.hasCover = tags.hasCover;
    return track;
  }

  private emit(state: LocalScanState, listener: ScanProgressListener, force: boolean): void {
    const now: number = Date.now();
    if (!force && now - this.lastEmitAt < AppConstants.SCAN_PROGRESS_INTERVAL_MS) {
      return;
    }
    this.lastEmitAt = now;
    const copy: LocalScanState = new LocalScanState();
    copy.phase = state.phase;
    copy.currentFile = state.currentFile;
    copy.scanned = state.scanned;
    copy.discovered = state.discovered;
    copy.added = state.added;
    copy.updated = state.updated;
    copy.removed = state.removed;
    copy.errorCount = state.errorCount;
    copy.errors = state.errors.slice(0, 8);
    copy.totalBytes = state.totalBytes;
    copy.startedAt = state.startedAt;
    copy.finishedAt = state.finishedAt;
    listener(copy);
  }

  /** 递归列出目录；优先 URI，失败回退 fileUri 解析出的绝对路径。 */
  private listRelative(folderUri: string): string[] | null {
    const options: ListFileOptions = { recursion: true };
    try {
      return fileIo.listFileSync(folderUri, options);
    } catch (error) {
      Logger.warn(SCOPE, 'list by uri failed, fallback to path');
    }
    const path: string = this.pathOfUri(folderUri);
    if (path.length > 0) {
      try {
        return fileIo.listFileSync(path, options);
      } catch (error) {
        Logger.warn(SCOPE, 'list by path failed');
      }
    }
    return null;
  }

  private pathOfUri(uri: string): string {
    try {
      const parsed: fileUri.FileUri = new fileUri.FileUri(uri);
      return parsed.path;
    } catch (error) {
      return '';
    }
  }

  private joinUri(folderUri: string, relative: string): string {
    const base: string = folderUri.endsWith('/') ? folderUri.substring(0, folderUri.length - 1) : folderUri;
    const tail: string = this.trimLeading(relative);
    const segments: string[] = tail.split('/');
    const encoded: string[] = [];
    for (let i = 0; i < segments.length; i++) {
      if (segments[i].length > 0) {
        encoded.push(encodeURIComponent(segments[i]));
      }
    }
    return `${base}/${encoded.join('/')}`;
  }

  private trimLeading(relative: string): string {
    return relative.startsWith('/') ? relative.substring(1) : relative;
  }

  private statOf(uri: string, path: string): fileIo.Stat | null {
    try {
      return fileIo.statSync(uri);
    } catch (error) {
      if (path.length > 0) {
        try {
          return fileIo.statSync(path);
        } catch (inner) {
          return null;
        }
      }
      return null;
    }
  }
}

export const localScanService: LocalScanServiceImpl = new LocalScanServiceImpl();

