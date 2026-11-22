/**
 * 本地扫描领域模型：首页模式、文件夹授权、本地曲目、扫描状态与索引文档。
 * 所有 Raw 结构仅用于 JSON 解析，必须经 LocalScanCodec 逐字段校验后使用。
 */
import { AppConstants } from '../common/Constants';

export enum HomeMode {
  LOCAL = 'local',
  SERVER = 'server'
}

export enum LocalScanPhase {
  IDLE = 'idle',
  SCANNING = 'scanning',
  DIFFING = 'diffing',
  DONE = 'done',
  CANCELLED = 'cancelled',
  ERROR = 'error'
}

export function parseHomeMode(value: string): HomeMode {
  return value === HomeMode.SERVER ? HomeMode.SERVER : HomeMode.LOCAL;
}

export function homeModeKey(mode: HomeMode): string {
  return mode === HomeMode.SERVER ? 'server' : 'local';
}

/** 用户授权并持久化的音乐文件夹。 */
export class LocalFolder {
  uri: string = '';
  displayName: string = '';
  addedAt: number = 0;
  lastScanAt: number = 0;
  fileCount: number = 0;
  invalid: boolean = false;
  error: string = '';
}

/** 扫描得到的本地曲目；uri 为用户文件 URI，可直接用于播放与封面定位。 */
export class LocalTrack {
  id: string = '';
  uri: string = '';
  folderUri: string = '';
  title: string = '';
  artist: string = '';
  album: string = '';
  fileName: string = '';
  durationMs: number = 0;
  format: string = '';
  sizeBytes: number = 0;
  mtime: number = 0;
  sampleRate: number = 0;
  bitDepth: number = 0;
  coverCacheKey: string = '';
  hasCover: boolean = false;
  addedAt: number = 0;
}

/** 一次扫描的完整状态快照（用于进度回调与结果传递）。 */
export class LocalScanState {
  phase: LocalScanPhase = LocalScanPhase.IDLE;
  currentFile: string = '';
  scanned: number = 0;
  discovered: number = 0;
  added: number = 0;
  updated: number = 0;
  removed: number = 0;
  errorCount: number = 0;
  errors: string[] = [];
  totalBytes: number = 0;
  startedAt: number = 0;
  finishedAt: number = 0;
}

/** 持久化文档：filesDir/data/local_index.json。 */
export class LocalIndexDoc {
  schemaVersion: number = AppConstants.LOCAL_INDEX_SCHEMA;
  folders: LocalFolder[] = [];
  tracks: LocalTrack[] = [];
  lastScanAt: number = 0;
}

// ---------------- Raw DTO（解析用） ----------------

export class LocalFolderRaw {
  uri?: string;
  displayName?: string;
  name?: string;
  addedAt?: number;
  lastScanAt?: number;
  fileCount?: number;
  invalid?: boolean;
  error?: string;
}

export class LocalTrackRaw {
  id?: string;
  uri?: string;
  folderUri?: string;
  title?: string;
  artist?: string;
  album?: string;
  fileName?: string;
  durationMs?: number;
  format?: string;
  sizeBytes?: number;
  mtime?: number;
  sampleRate?: number;
  bitDepth?: number;
  coverCacheKey?: string;
  hasCover?: boolean;
  addedAt?: number;
}

export class LocalIndexRaw {
  schemaVersion?: number;
  folders?: LocalFolderRaw[];
  tracks?: LocalTrackRaw[];
  lastScanAt?: number;
}

export class LocalScanCodec {
  static folderOf(raw: LocalFolderRaw): LocalFolder | null {
    const uri: string = typeof raw.uri === 'string' ? raw.uri : '';
    if (uri.length === 0) {
      return null;
    }
    const folder: LocalFolder = new LocalFolder();
    folder.uri = uri;
    folder.displayName = typeof raw.displayName === 'string' && raw.displayName.length > 0
      ? raw.displayName
      : (typeof raw.name === 'string' ? raw.name : LocalScanHelper.nameOfUri(uri));
    folder.addedAt = LocalScanHelper.num(raw.addedAt, 0);
    folder.lastScanAt = LocalScanHelper.num(raw.lastScanAt, 0);
    folder.fileCount = LocalScanHelper.num(raw.fileCount, 0);
    folder.invalid = raw.invalid === true;
    folder.error = typeof raw.error === 'string' ? raw.error : '';
    return folder;
  }

  static folderRaw(folder: LocalFolder): LocalFolderRaw {
    const raw: LocalFolderRaw = new LocalFolderRaw();
    raw.uri = folder.uri;
    raw.displayName = folder.displayName;
    raw.addedAt = folder.addedAt;
    raw.lastScanAt = folder.lastScanAt;
    raw.fileCount = folder.fileCount;
    raw.invalid = folder.invalid;
    raw.error = folder.error;
    return raw;
  }

  static trackOf(raw: LocalTrackRaw): LocalTrack | null {
    const uri: string = typeof raw.uri === 'string' ? raw.uri : '';
    if (uri.length === 0) {
      return null;
    }
    const track: LocalTrack = new LocalTrack();
    track.uri = uri;
    track.folderUri = typeof raw.folderUri === 'string' ? raw.folderUri : '';
    track.fileName = typeof raw.fileName === 'string' ? raw.fileName : LocalScanHelper.nameOfUri(uri);
    track.title = typeof raw.title === 'string' && raw.title.length > 0
      ? raw.title : LocalScanHelper.titleOfFile(track.fileName);
    track.artist = typeof raw.artist === 'string' ? raw.artist : '';
    track.album = typeof raw.album === 'string' ? raw.album : '';
    track.durationMs = LocalScanHelper.num(raw.durationMs, 0);
    track.format = typeof raw.format === 'string' ? raw.format : LocalScanHelper.formatOf(track.fileName);
    track.sizeBytes = LocalScanHelper.num(raw.sizeBytes, 0);
    track.mtime = LocalScanHelper.num(raw.mtime, 0);
    track.sampleRate = LocalScanHelper.num(raw.sampleRate, 0);
    track.bitDepth = LocalScanHelper.num(raw.bitDepth, 0);
    track.coverCacheKey = typeof raw.coverCacheKey === 'string' ? raw.coverCacheKey : '';
    track.hasCover = raw.hasCover === true;
    track.addedAt = LocalScanHelper.num(raw.addedAt, 0);
    track.id = typeof raw.id === 'string' && raw.id.length > 0
      ? raw.id : LocalScanHelper.trackIdOf(uri);
    return track;
  }

  static trackRaw(track: LocalTrack): LocalTrackRaw {
    const raw: LocalTrackRaw = new LocalTrackRaw();
    raw.id = track.id;
    raw.uri = track.uri;
    raw.folderUri = track.folderUri;
    raw.title = track.title;
    raw.artist = track.artist;
    raw.album = track.album;
    raw.fileName = track.fileName;
    raw.durationMs = track.durationMs;
    raw.format = track.format;
    raw.sizeBytes = track.sizeBytes;
    raw.mtime = track.mtime;
    raw.sampleRate = track.sampleRate;
    raw.bitDepth = track.bitDepth;
    raw.coverCacheKey = track.coverCacheKey;
    raw.hasCover = track.hasCover;
    raw.addedAt = track.addedAt;
    return raw;
  }

  static docFrom(text: string): LocalIndexDoc | null {
    if (text.length === 0) {
      return null;
    }
    let raw: LocalIndexRaw;
    try {
      raw = JSON.parse(text) as LocalIndexRaw;
    } catch (error) {
      return null;
    }
    if (raw === null || raw === undefined) {
      return null;
    }
    const doc: LocalIndexDoc = new LocalIndexDoc();
    const version: number = LocalScanHelper.num(raw.schemaVersion, 0);
    doc.schemaVersion = version > 0 ? version : AppConstants.LOCAL_INDEX_SCHEMA;
    doc.lastScanAt = LocalScanHelper.num(raw.lastScanAt, 0);
    const folderRaws: LocalFolderRaw[] = Array.isArray(raw.folders) ? raw.folders : [];
    for (let i = 0; i < folderRaws.length; i++) {
      const folder: LocalFolder | null = LocalScanCodec.folderOf(folderRaws[i]);
      if (folder !== null) {
        doc.folders.push(folder);
      }
    }
    const trackRaws: LocalTrackRaw[] = Array.isArray(raw.tracks) ? raw.tracks : [];
    for (let i = 0; i < trackRaws.length; i++) {
      const track: LocalTrack | null = LocalScanCodec.trackOf(trackRaws[i]);
      if (track !== null) {
        doc.tracks.push(track);
      }
    }
    return doc;
  }

  static docToJson(doc: LocalIndexDoc): string {
    const raw: LocalIndexRaw = new LocalIndexRaw();
    raw.schemaVersion = doc.schemaVersion;
    raw.lastScanAt = doc.lastScanAt;
    const folders: LocalFolderRaw[] = [];
    for (let i = 0; i < doc.folders.length; i++) {
      folders.push(LocalScanCodec.folderRaw(doc.folders[i]));
    }
    const tracks: LocalTrackRaw[] = [];
    for (let i = 0; i < doc.tracks.length; i++) {
      tracks.push(LocalScanCodec.trackRaw(doc.tracks[i]));
    }
    raw.folders = folders;
    raw.tracks = tracks;
    return JSON.stringify(raw);
  }
}

export class LocalScanHelper {
  private static audioExtCache: string[] = AppConstants.LOCAL_AUDIO_EXTENSIONS;

  static num(value: number | undefined, fallback: number): number {
    if (value === undefined || value === null || Number.isNaN(value)) {
      return fallback;
    }
    return value;
  }

  static isAudioFile(name: string): boolean {
    const format: string = LocalScanHelper.formatOf(name);
    return format.length > 0 && LocalScanHelper.audioExtCache.indexOf(format) >= 0;
  }

  static formatOf(name: string): string {
    const dot: number = name.lastIndexOf('.');
    if (dot < 0 || dot === name.length - 1) {
      return '';
    }
    return name.substring(dot + 1).toLowerCase();
  }

  static stripExtension(name: string): string {
    const dot: number = name.lastIndexOf('.');
    return dot > 0 ? name.substring(0, dot) : name;
  }

  static nameOfUri(uri: string): string {
    const cleaned: string = uri.endsWith('/') ? uri.substring(0, uri.length - 1) : uri;
    const index: number = cleaned.lastIndexOf('/');
    const raw: string = index >= 0 ? cleaned.substring(index + 1) : cleaned;
    try {
      const decoded: string = decodeURIComponent(raw);
      return decoded.length > 0 ? decoded : '音乐文件夹';
    } catch (error) {
      return raw.length > 0 ? raw : '音乐文件夹';
    }
  }

  static nameOfPath(path: string): string {
    const normalized: string = path.replace(/\\/g, '/');
    const index: number = normalized.lastIndexOf('/');
    return index >= 0 ? normalized.substring(index + 1) : normalized;
  }

  /** 文件名推导：支持「歌手 - 标题」，否则整名作为标题。 */
  static titleOfFile(fileName: string): string {
    const base: string = LocalScanHelper.stripExtension(fileName);
    const parsed: string = LocalScanHelper.artistOfFile(base).length > 0
      ? base.substring(base.indexOf(' - ') + 3) : base;
    return parsed.trim().length > 0 ? parsed.trim() : '未知曲目';
  }

  static artistOfFile(fileName: string): string {
    const base: string = LocalScanHelper.stripExtension(fileName);
    const index: number = base.indexOf(' - ');
    if (index <= 0) {
      return '';
    }
    return base.substring(0, index).trim();
  }

  static trackIdOf(uri: string): string {
    return `${AppConstants.LOCAL_TRACK_PREFIX}${LocalScanHelper.stableId(uri)}`;
  }

  static stableId(text: string): string {
    let first: number = 0x811C9DC5;
    let second: number = 0x01000193;
    for (let i = 0; i < text.length; i++) {
      const code: number = text.charCodeAt(i);
      first = ((first ^ code) * 16777619) | 0;
      second = ((second ^ code) * 109951163) | 0;
    }
    return LocalScanHelper.hex(first) + LocalScanHelper.hex(second);
  }

  private static hex(value: number): string {
    const text: string = (value >>> 0).toString(16);
    return text.length >= 8 ? text.substring(0, 8) : '00000000'.substring(0, 8 - text.length) + text;
  }

  static formatBytes(bytes: number): string {
    if (bytes <= 0) {
      return '0 B';
    }
    if (bytes < 1024) {
      return `${Math.round(bytes)} B`;
    }
    const kb: number = bytes / 1024;
    if (kb < 1024) {
      return `${kb.toFixed(1)} KB`;
    }
    const mb: number = kb / 1024;
    if (mb < 1024) {
      return `${mb.toFixed(1)} MB`;
    }
    return `${(mb / 1024).toFixed(2)} GB`;
  }

  static phaseLabel(phase: LocalScanPhase): string {
    if (phase === LocalScanPhase.SCANNING) {
      return '正在扫描';
    }
    if (phase === LocalScanPhase.DIFFING) {
      return '正在更新索引';
    }
    if (phase === LocalScanPhase.DONE) {
      return '扫描完成';
    }
    if (phase === LocalScanPhase.CANCELLED) {
      return '已取消';
    }
    if (phase === LocalScanPhase.ERROR) {
      return '扫描失败';
    }
    return '尚未扫描';
  }
}
