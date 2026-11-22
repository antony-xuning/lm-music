/**
 * 服务端领域模型：会话、连接状态、在线来源、曲库实体、写回条目、同步状态、
 * 服务器下载任务、播客、音源脚本与标签快照。
 * 仅存放数据结构与轻量工具方法，不发起网络请求。
 */

/** 连接状态机：idle → connecting → online / offline / authExpired / error。 */
export enum ConnectionState {
  IDLE = 'idle',
  CONNECTING = 'connecting',
  ONLINE = 'online',
  OFFLINE = 'offline',
  AUTH_EXPIRED = 'authExpired',
  ERROR = 'error'
}

export class ConnectionStatus {
  state: ConnectionState = ConnectionState.IDLE;
  latencyMs: number = 0;
  errorCode: string = '';
  errorMessage: string = '';
  lastConnectedAt: number = 0;
}

export class ServerSession {
  token: string = '';
  expiresAt: number = 0;
  userId: string = '';
  username: string = '';
  displayName: string = '';
  role: string = '';
  lastVerifiedAt: number = 0;

  get valid(): boolean {
    return this.token.length > 0 && (this.expiresAt <= 0 || this.expiresAt > Date.now());
  }
}

/** 在线来源条目（歌单中的 wy:/kw: 条目或搜索结果）。 */
export class OnlineRef {
  platform: string = '';
  songId: string = '';
  songmid: string = '';
  hash: string = '';
  copyrightId: string = '';
  musicId: string = '';
  rid: string = '';
  picUrl: string = '';
  lyric: string = '';
  qualitys: string[] = [];

  /** 用于构造 play/url 请求体的平台主键。 */
  platformKey(): string {
    if (this.songId.length > 0) {
      return this.songId;
    }
    if (this.songmid.length > 0) {
      return this.songmid;
    }
    if (this.hash.length > 0) {
      return this.hash;
    }
    if (this.copyrightId.length > 0) {
      return this.copyrightId;
    }
    return this.musicId;
  }
}

/** 服务器文件曲目快照（同步中间态；LibraryStore 会转成 Song）。 */
export class ServerTrack {
  id: string = '';
  filePath: string = '';
  trackId: string = '';
  title: string = '';
  artist: string = '';
  album: string = '';
  albumArtist: string = '';
  year: number = 0;
  genre: string = '';
  durationMs: number = 0;
  format: string = '';
  sizeBytes: number = 0;
  sampleRate: number = 0;
  bitDepth: number = 0;
  mtime: number = 0;
  hasPicture: boolean = false;
  hasLyric: boolean = false;
  addedAt: number = 0;
}

export class ServerAlbum {
  id: string = '';
  name: string = '';
  artist: string = '';
  year: number = 0;
  count: number = 0;
  coverPath: string = '';
  source: string = '';
}

export class ServerArtist {
  id: string = '';
  name: string = '';
  count: number = 0;
  coverPath: string = '';
}

/** 歌单条目：保留服务端原始 key 与快照，支持双向写回。 */
export class PlaylistEntry {
  key: string = '';
  platform: string = '';
  songId: string = '';
  name: string = '';
  singer: string = '';
  album: string = '';
  localPath: string = '';
  picUrl: string = '';
  lyric: string = '';
  durationMs: number = 0;
  qualitys: string[] = [];
  snapshotJson: string = '';
  hasSnapshot: boolean = false;

  get isOnline(): boolean {
    return this.platform.length > 0 && this.localPath.length === 0;
  }
}

export class ServerPlaylist {
  id: string = '';
  name: string = '';
  coverUrl: string = '';
  trackKeys: string[] = [];
  entries: PlaylistEntry[] = [];
  updatedAt: number = 0;
  isFavorites: boolean = false;
  editable: boolean = true;
}

export class ServerUserData {
  favoritesJson: string = '';
  playlistsJson: string = '';
  favoriteCount: number = 0;
  recentCount: number = 0;
  revision: string = '';
}

export enum SyncPhase {
  IDLE = 'idle',
  CONNECTING = 'connecting',
  TRACKS = 'tracks',
  ALBUMS = 'albums',
  ARTISTS = 'artists',
  PLAYLISTS = 'playlists',
  USERDATA = 'userdata',
  WRITING = 'writing',
  DONE = 'done',
  ERROR = 'error'
}

export class SyncState {
  phase: SyncPhase = SyncPhase.IDLE;
  fetched: number = 0;
  total: number = 0;
  error: string = '';
  lastSuccessAt: number = 0;
}

export class ServerDownloadTask {
  id: string = '';
  name: string = '';
  singer: string = '';
  album: string = '';
  source: string = '';
  platformId: string = '';
  quality: string = '';
  status: string = 'waiting';
  progress: number = 0;
  bytesDone: number = 0;
  bytesTotal: number = 0;
  speed: number = 0;
  filePath: string = '';
  error: string = '';
  createdAt: number = 0;
  updatedAt: number = 0;
}

export class PodcastFeed {
  id: string = '';
  title: string = '';
  author: string = '';
  coverUrl: string = '';
  description: string = '';
  episodeCount: number = 0;
  subscribedAt: number = 0;
}

export class PodcastEpisode {
  id: string = '';
  feedId: string = '';
  title: string = '';
  audioUrl: string = '';
  durationMs: number = 0;
  publishedAt: number = 0;
  description: string = '';
}

export class SourcePlatform {
  id: string = '';
  label: string = '';
  enabled: boolean = true;
  level: string = '';
  okRatio: number = 0;
  avgMs: number = 0;
  lastError: string = '';
  qualitys: string[] = [];
}

export class SourceScript {
  id: string = '';
  name: string = '';
  author: string = '';
  version: string = '';
  homepage: string = '';
  active: boolean = true;
  health: string = '';
  platforms: SourcePlatform[] = [];
  lastProbe: string = '';
}

export class TagInfo {
  filePath: string = '';
  title: string = '';
  artist: string = '';
  album: string = '';
  albumArtist: string = '';
  year: number = 0;
  track: number = 0;
  genre: string = '';
  hasPicture: boolean = false;
  hasLyric: boolean = false;
  lyric: string = '';
  format: string = '';
  durationMs: number = 0;
}

export class TagCandidate {
  source: string = '';
  title: string = '';
  artist: string = '';
  album: string = '';
  coverUrl: string = '';
  matchScore: number = 0;
  rawJson: string = '';
}

export class CoverRef {
  key: string = '';
  cachePath: string = '';
  mtime: number = 0;
  updatedAt: number = 0;
}

/** play/url 解析结果。 */
export class PlayResult {
  url: string = '';
  format: string = '';
  local: boolean = false;
  useAuthHeader: boolean = false;
}

/** 统一接口错误：code 取 HttpClient 的错误分类。 */
export class ApiError {
  code: string = '';
  message: string = '';
  status: number = 0;

  constructor(code: string, message: string, status: number = 0) {
    this.code = code;
    this.message = message;
    this.status = status;
  }
}

export enum ApiErrorCode {
  OFFLINE = 'OFFLINE',
  TIMEOUT = 'TIMEOUT',
  UNAUTHORIZED = 'UNAUTHORIZED',
  FORBIDDEN = 'FORBIDDEN',
  NOT_FOUND = 'NOT_FOUND',
  SERVER_ERROR = 'SERVER_ERROR',
  BAD_RESPONSE = 'BAD_RESPONSE',
  UNSUPPORTED = 'UNSUPPORTED',
  INVALID_INPUT = 'INVALID_INPUT',
  UNKNOWN = 'UNKNOWN'
}

export class ApiErrorHelper {
  static message(code: string): string {
    if (code === ApiErrorCode.OFFLINE) {
      return '无法连接服务器，请检查网络与地址';
    }
    if (code === ApiErrorCode.TIMEOUT) {
      return '请求超时，请稍后重试';
    }
    if (code === ApiErrorCode.UNAUTHORIZED) {
      return '登录已过期，请重新登录';
    }
    if (code === ApiErrorCode.FORBIDDEN) {
      return '没有权限执行该操作';
    }
    if (code === ApiErrorCode.NOT_FOUND) {
      return '服务器不支持该操作';
    }
    if (code === ApiErrorCode.SERVER_ERROR) {
      return '服务器返回错误，请稍后重试';
    }
    if (code === ApiErrorCode.BAD_RESPONSE) {
      return '返回内容不是柠檬音乐服务，请检查地址';
    }
    if (code === ApiErrorCode.UNSUPPORTED) {
      return '服务器不支持该操作';
    }
    if (code === ApiErrorCode.INVALID_INPUT) {
      return '输入有误，请检查后重试';
    }
    return '请求失败，请重试';
  }
}
