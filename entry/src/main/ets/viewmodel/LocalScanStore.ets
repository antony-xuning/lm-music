/**
 * 本地曲库 Store：文件夹授权、扫描进度、本地曲目与首页模式。
 * 本地曲目同时合并进 LibraryStore（LOCAL 来源），供资料库与搜索使用。
 */
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { preferencesRepo } from '../data/PreferencesRepo';
import { LocalIndexStore } from '../data/LocalIndexStore';
import { MediaSource, Song } from '../model/MediaModels';
import {
  HomeMode,
  LocalFolder,
  LocalIndexDoc,
  LocalScanHelper,
  LocalScanPhase,
  LocalScanState,
  LocalTrack,
  homeModeKey,
  parseHomeMode
} from '../model/LocalScanModels';
import { MediaTagService } from '../service/MediaTagService';
import { ScanResult, localScanService } from '../service/LocalScanService';
import { libraryStore } from './LibraryStore';
import { serverStore } from './ServerStore';

const SCOPE: string = 'LocalScanStore';

@ObservedV2
export class LocalScanStore {
  @Trace folders: LocalFolder[] = [];
  @Trace tracks: LocalTrack[] = [];
  @Trace phase: LocalScanPhase = LocalScanPhase.IDLE;
  @Trace currentFile: string = '';
  @Trace scanned: number = 0;
  @Trace discovered: number = 0;
  @Trace addedCount: number = 0;
  @Trace updatedCount: number = 0;
  @Trace removedCount: number = 0;
  @Trace errorCount: number = 0;
  @Trace message: string = '';
  @Trace lastScanAt: number = 0;
  @Trace homeMode: HomeMode = HomeMode.LOCAL;
  @Trace initialized: boolean = false;
  @Trace busy: boolean = false;
  @Trace errorLines: string[] = [];
  @Trace serverAvailable: boolean = false;

  private started: boolean = false;

  async init(): Promise<void> {
    if (this.started) {
      return;
    }
    this.started = true;
    const doc: LocalIndexDoc = LocalIndexStore.load();
    this.folders = doc.folders;
    this.tracks = doc.tracks;
    this.lastScanAt = doc.lastScanAt;
    this.serverAvailable = serverStore.configured;
    await this.restoreMode();
    this.syncLibrary();
    this.initialized = true;
    if (this.folders.length > 0) {
      const activated: LocalFolder[] = await localScanService.activateSavedFolders(this.folders);
      this.folders = activated;
      this.saveIndex();
      this.syncLibrary();
    }
  }

  /** 服务器是否可用（已配置即视为可用，未登录时由服务器模式展示去登录）。 */
  async refreshServerAvailability(): Promise<void> {
    this.serverAvailable = serverStore.configured;
    if (!this.serverAvailable && this.homeMode === HomeMode.SERVER) {
      this.homeMode = HomeMode.LOCAL;
      await this.persistMode();
    }
  }

  private async restoreMode(): Promise<void> {
    const saved: string = await preferencesRepo.getString(AppConstants.PREF_KEY_HOME_MODE, '');
    if (!this.serverAvailable) {
      this.homeMode = HomeMode.LOCAL;
      return;
    }
    if (saved.length > 0) {
      this.homeMode = parseHomeMode(saved);
    } else {
      this.homeMode = HomeMode.SERVER;
    }
  }

  /** 实际生效的首页模式：无服务器时强制本地。 */
  get effectiveMode(): HomeMode {
    return this.serverAvailable ? this.homeMode : HomeMode.LOCAL;
  }

  get scanning(): boolean {
    return this.phase === LocalScanPhase.SCANNING || this.phase === LocalScanPhase.DIFFING;
  }

  get trackCount(): number {
    return this.tracks.length;
  }

  get folderCount(): number {
    return this.folders.length;
  }

  /** 去重专辑数（非平凡 getter，供首页副标题展示收录统计）。 */
  get albumCount(): number {
    const albums: Set<string> = new Set<string>();
    for (let i = 0; i < this.tracks.length; i++) {
      const name: string = this.tracks[i].album.trim();
      if (name.length > 0) {
        albums.add(name);
      }
    }
    return albums.size;
  }

  get totalBytes(): number {
    let sum: number = 0;
    for (let i = 0; i < this.tracks.length; i++) {
      sum += this.tracks[i].sizeBytes;
    }
    return sum;
  }

  get hasTracks(): boolean {
    return this.tracks.length > 0;
  }

  get phaseLabel(): string {
    return LocalScanHelper.phaseLabel(this.phase);
  }

  get invalidFolderCount(): number {
    let count: number = 0;
    for (let i = 0; i < this.folders.length; i++) {
      if (this.folders[i].invalid) {
        count++;
      }
    }
    return count;
  }

  /** 最近添加：按索引时间倒序，最多 20 首。 */
  get recentTracks(): LocalTrack[] {
    const sorted: LocalTrack[] = this.tracks.slice();
    sorted.sort((a: LocalTrack, b: LocalTrack): number => b.addedAt - a.addedAt);
    return sorted.slice(0, 20);
  }

  get allTracks(): LocalTrack[] {
    const sorted: LocalTrack[] = this.tracks.slice();
    sorted.sort((a: LocalTrack, b: LocalTrack): number => a.title.localeCompare(b.title));
    return sorted;
  }

  async setMode(mode: HomeMode): Promise<void> {
    if (mode === HomeMode.SERVER && !this.serverAvailable) {
      return;
    }
    if (this.homeMode === mode) {
      return;
    }
    this.homeMode = mode;
    await this.persistMode();
  }

  private async persistMode(): Promise<void> {
    await preferencesRepo.putString(AppConstants.PREF_KEY_HOME_MODE, homeModeKey(this.homeMode));
  }

  /** 添加文件夹并立即扫描。 */
  async addFolder(): Promise<boolean> {
    if (this.busy) {
      this.message = '扫描进行中，请稍后添加';
      return false;
    }
    const folder: LocalFolder | null = await localScanService.pickFolder();
    if (folder === null) {
      this.message = '已取消选择文件夹';
      return false;
    }
    for (let i = 0; i < this.folders.length; i++) {
      if (this.folders[i].uri === folder.uri) {
        this.message = '该文件夹已在本地曲库中';
        return false;
      }
    }
    this.folders = this.folders.concat([folder]);
    this.saveIndex();
    this.message = `已添加「${folder.displayName}」，开始扫描…`;
    await this.scan(folder.uri);
    return true;
  }

  /** 扫描全部文件夹。 */
  async scanAll(): Promise<void> {
    await this.scan('');
  }

  /** 重新扫描单个文件夹。 */
  async rescanFolder(folderUri: string): Promise<void> {
    await this.scan(folderUri);
  }

  private async scan(targetFolderUri: string): Promise<void> {
    if (this.busy) {
      this.message = '扫描正在进行中';
      return;
    }
    if (this.folders.length === 0) {
      this.message = '还没有音乐文件夹，请先添加';
      return;
    }
    this.busy = true;
    this.message = '正在扫描…';
    this.errorLines = [];
    try {
      const result: ScanResult = await localScanService.scan(this.folders, this.tracks, targetFolderUri,
        (state: LocalScanState) => {
          this.applyProgress(state);
        });
      if (result.cancelled) {
        this.phase = LocalScanPhase.CANCELLED;
        this.message = result.message;
        return;
      }
      this.applyResult(result);
    } catch (error) {
      Logger.error(SCOPE, 'scan failed');
      this.phase = LocalScanPhase.ERROR;
      this.message = '扫描失败，请重试';
    } finally {
      this.busy = false;
    }
  }

  cancel(): void {
    if (!this.busy) {
      return;
    }
    localScanService.cancel();
    this.message = '正在取消扫描…';
  }

  async removeFolder(folder: LocalFolder): Promise<void> {
    if (this.busy) {
      this.message = '扫描进行中，请稍后再移除文件夹';
      return;
    }
    const revoked: boolean = await localScanService.removeFolder(folder.uri);
    const keptFolders: LocalFolder[] = [];
    for (let i = 0; i < this.folders.length; i++) {
      if (this.folders[i].uri !== folder.uri) {
        keptFolders.push(this.folders[i]);
      }
    }
    const keptTracks: LocalTrack[] = [];
    for (let i = 0; i < this.tracks.length; i++) {
      if (this.tracks[i].folderUri !== folder.uri) {
        keptTracks.push(this.tracks[i]);
      }
    }
    this.folders = keptFolders;
    this.tracks = keptTracks;
    this.saveIndex();
    this.syncLibrary();
    this.message = revoked ? `已移除「${folder.displayName}」` : `已移除「${folder.displayName}」（授权撤销失败）`;
  }

  private applyProgress(state: LocalScanState): void {
    this.phase = state.phase;
    this.currentFile = state.currentFile;
    this.scanned = state.scanned;
    this.discovered = state.discovered;
    this.addedCount = state.added;
    this.updatedCount = state.updated;
    this.removedCount = state.removed;
    this.errorCount = state.errorCount;
    this.errorLines = state.errors;
  }

  private applyResult(result: ScanResult): void {
    this.folders = result.folders;
    this.tracks = result.tracks;
    this.lastScanAt = result.lastScanAt;
    this.addedCount = result.added;
    this.updatedCount = result.updated;
    this.removedCount = result.removed;
    this.errorCount = result.errorCount;
    this.errorLines = result.errors;
    this.phase = result.cancelled ? LocalScanPhase.CANCELLED
      : (result.ok ? LocalScanPhase.DONE : LocalScanPhase.ERROR);
    this.message = result.message;
    this.syncLibrary();
  }

  private saveIndex(): void {
    const doc: LocalIndexDoc = new LocalIndexDoc();
    doc.folders = this.folders;
    doc.tracks = this.tracks;
    doc.lastScanAt = this.lastScanAt;
    LocalIndexStore.save(doc);
  }

  private syncLibrary(): void {
    libraryStore.setScannedSongs(this.songsFrom(this.tracks));
  }

  /** 把本地扫描曲目转成 Song（LOCAL 来源，播放使用用户文件 URI）。 */
  songsFrom(tracks: LocalTrack[]): Song[] {
    const songs: Song[] = [];
    for (let i = 0; i < tracks.length; i++) {
      const track: LocalTrack = tracks[i];
      if (track.uri.length === 0) {
        continue;
      }
      const song: Song = new Song();
      song.id = track.id.length > 0 ? track.id : LocalScanHelper.trackIdOf(track.uri);
      song.title = track.title.length > 0 ? track.title : LocalScanHelper.titleOfFile(track.fileName);
      song.artist = track.artist.length > 0 ? track.artist : '未知歌手';
      song.album = track.album.length > 0 ? track.album : '未知专辑';
      song.artistId = `scan_artist_${LocalScanHelper.stableId(song.artist)}`;
      song.albumId = `scan_album_${LocalScanHelper.stableId(song.album)}`;
      song.durationMs = track.durationMs;
      song.audioRef = track.uri;
      song.filePath = track.uri;
      song.localPath = '';
      song.source = MediaSource.LOCAL;
      song.coverSeed = Math.abs(track.fileName.length * 7 + track.title.length);
      song.coverUrl = MediaTagService.coverUriOf(track);
      song.hasPicture = track.hasCover;
      song.format = track.format.length > 0 ? track.format.toUpperCase() : 'AUDIO';
      song.bitRate = 0;
      song.sizeBytes = track.sizeBytes;
      song.mtime = track.mtime;
      song.addedAt = track.addedAt;
      songs.push(song);
    }
    return songs;
  }
}

export const localScanStore: LocalScanStore = new LocalScanStore();
