/**
 * 服务端 DTO 与逐字段解析（核心域：会话 / 曲库 / 歌单 / 用户数据 / 发现）。
 * 统一兼容 data[] / data.list[] / data.data[] / list[] / 裸数组 五种信封。
 */
import { Utils } from '../common/Utils';
import { Album, Artist, MediaSource, Playlist, Song } from '../model/MediaModels';
import { PlaylistEntry, ServerSession } from '../model/ServerModels';
import { DiscoverToplistItem, DiscoverTrackItem } from '../model/UiModels';

export interface EnvelopeRaw {
  ok?: boolean;
  data?: Object;
  list?: Object[];
  total?: number | string;
  page?: number | string;
  limit?: number | string;
  unchanged?: boolean;
  revision?: string | number;
  url?: string;
  format?: string;
  local?: boolean;
  error?: string;
  message?: string;
  lxlyric?: string;
  lyric?: string;
  ylyric?: string;
  tlyric?: string;
  rlyric?: string;
  lyricText?: string;
}

interface LoginDataRaw {
  token?: string;
  accessToken?: string;
  expiresAt?: string | number;
  expiresIn?: number | string;
  user?: Object;
  ok?: boolean;
}

interface UserInfoRaw {
  id?: string | number;
  userId?: string | number;
  username?: string;
  name?: string;
  displayName?: string;
  role?: string;
}

interface TrackRaw {
  id?: string | number;
  filePath?: string;
  path?: string;
  fileName?: string;
  title?: string;
  name?: string;
  artist?: string;
  singer?: string;
  album?: string;
  albumArtist?: string;
  year?: number | string;
  genre?: string;
  duration?: number | string;
  durationMs?: number | string;
  format?: string;
  size?: number | string;
  sizeBytes?: number | string;
  mtime?: number | string;
  hasPicture?: boolean;
  hasLyrics?: boolean;
  hasLyric?: boolean;
  sampleRate?: number | string;
  bitsPerSample?: number | string;
  bitRate?: number | string;
  trackId?: string | number;
  addedAt?: number | string;
}

export interface OnlineTrackRaw {
  id?: string | number;
  name?: string;
  title?: string;
  singer?: string;
  artist?: string;
  album?: string;
  albumName?: string;
  albumId?: string | number;
  interval?: string | number;
  duration?: number | string;
  source?: string;
  songId?: string | number;
  songmid?: string;
  hash?: string;
  copyrightId?: string;
  musicId?: string;
  rid?: string | number;
  picUrl?: string;
  img?: string;
  cover?: string;
  coverUrl?: string;
  types?: string[];
  qualitys?: string | string[];
  lyric?: string;
  author?: string;
}

interface AlbumRaw {
  id?: string | number;
  name?: string;
  title?: string;
  album?: string;
  artist?: string;
  singer?: string;
  albumArtist?: string;
  year?: number | string;
  count?: number | string;
  songCount?: number | string;
  coverPath?: string;
  cover?: string;
  coverUrl?: string;
  picUrl?: string;
  img?: string;
  source?: string;
  platform?: string;
  publishTime?: string | number;
}

interface ArtistRaw {
  id?: string | number;
  name?: string;
  artist?: string;
  count?: number | string;
  songCount?: number | string;
  albumCount?: number | string;
  coverPath?: string;
  cover?: string;
  coverUrl?: string;
}

export interface PlaylistRawItem {
  id?: string | number;
  name?: string;
  title?: string;
  cover?: string;
  coverUrl?: string;
  picUrl?: string;
  img?: string;
  trackKeys?: Object[];
  trackSnapshots?: Object;
  tracks?: Object[];
  updatedAt?: number | string;
  updateTime?: string | number;
  playlistType?: string;
  type?: string;
  isFavorites?: boolean;
  songCount?: number | string;
  count?: number | string;
  source?: string;
}

export interface SnapshotRaw {
  key?: string;
  name?: string;
  title?: string;
  singer?: string;
  artist?: string;
  album?: string;
  albumName?: string;
  localPath?: string;
  path?: string;
  filePath?: string;
  picUrl?: string;
  img?: string;
  cover?: string;
  lyric?: string;
  duration?: number | string;
  durationMs?: number | string;
  interval?: string | number;
  qualitys?: string | string[];
  source?: string;
  songId?: string | number;
  songmid?: string;
  hash?: string;
  copyrightId?: string;
}

interface UserDataRaw {
  favorites?: Object[];
  playlists?: Object[];
  favoriteAlbums?: Object[];
  favoriteArtists?: Object[];
  recentPlays?: Object[];
  revision?: string | number;
  unchanged?: boolean;
}

export class UserDataParsed {
  favorites: Object[] = [];
  playlists: Object[] = [];
  favoriteAlbums: Object[] = [];
  favoriteArtists: Object[] = [];
  recentPlays: Object[] = [];
  revision: string = '';
}

export class ServerSchemas {
  static parseRoot(text: string): Object {
    return JSON.parse(text) as Object;
  }

  static asArray(value: Object | undefined): Object[] {
    if (value === undefined) {
      return [];
    }
    if (Array.isArray(value)) {
      return value as Object[];
    }
    return [];
  }

  /** 兼容 data[] / data.list[] / data.data[] / list[] / 裸数组。 */
  static listOf(root: Object): Object[] {
    if (Array.isArray(root)) {
      return root as Object[];
    }
    const env: EnvelopeRaw = root as EnvelopeRaw;
    const data: Object | undefined = env.data;
    if (data !== undefined) {
      if (Array.isArray(data)) {
        return data as Object[];
      }
      const nested: EnvelopeRaw = data as EnvelopeRaw;
      const nestedList: Object[] | undefined = nested.list;
      if (nestedList !== undefined && Array.isArray(nestedList)) {
        return nestedList as Object[];
      }
      const nestedData: Object | undefined = nested.data;
      if (nestedData !== undefined && Array.isArray(nestedData)) {
        return nestedData as Object[];
      }
    }
    const rootList: Object[] | undefined = env.list;
    if (rootList !== undefined && Array.isArray(rootList)) {
      return rootList as Object[];
    }
    return [];
  }

  /** 取信封里的 data 对象（若 data 是数组则返回原 root）。 */
  static dataObject(root: Object): Object {
    const env: EnvelopeRaw = root as EnvelopeRaw;
    const data: Object | undefined = env.data;
    if (data !== undefined && !Array.isArray(data)) {
      return data;
    }
    return root;
  }

  static str(value: string | number | boolean | undefined, fallback: string): string {
    if (typeof value === 'string') {
      return value.length > 0 ? value : fallback;
    }
    if (typeof value === 'number') {
      return `${value}`;
    }
    return fallback;
  }

  static num(value: string | number | boolean | undefined, fallback: number): number {
    if (typeof value === 'number' && !Number.isNaN(value)) {
      return value;
    }
    if (typeof value === 'string') {
      const parsed: number = Number.parseFloat(value);
      return Number.isNaN(parsed) ? fallback : parsed;
    }
    return fallback;
  }

  static bool(value: boolean | string | number | undefined, fallback: boolean): boolean {
    if (typeof value === 'boolean') {
      return value;
    }
    if (typeof value === 'number') {
      return value !== 0;
    }
    if (typeof value === 'string') {
      const lower: string = value.toLowerCase();
      if (lower === 'true' || lower === '1' || lower === 'yes') {
        return true;
      }
      if (lower === 'false' || lower === '0' || lower === 'no') {
        return false;
      }
    }
    return fallback;
  }

  static strings(value: string | string[] | undefined): string[] {
    if (Array.isArray(value)) {
      const result: string[] = [];
      for (let i = 0; i < value.length; i++) {
        if (typeof value[i] === 'string') {
          result.push(value[i]);
        }
      }
      return result;
    }
    if (typeof value === 'string') {
      const trimmed: string = value.trim();
      if (trimmed.length === 0) {
        return [];
      }
      return trimmed.split(' ');
    }
    return [];
  }

  static secondsToMs(value: number): number {
    if (value <= 0) {
      return 0;
    }
    return Math.round(value * 1000);
  }

  /** 兼容 "mm:ss" 与秒数两种时长格式。 */
  static intervalToMs(value: string | number | undefined): number {
    if (typeof value === 'number') {
      return ServerSchemas.secondsToMs(value);
    }
    if (typeof value === 'string') {
      const text: string = value.trim();
      if (text.length === 0) {
        return 0;
      }
      const colon: number = text.indexOf(':');
      if (colon >= 0) {
        const minutes: number = Number.parseInt(text.substring(0, colon), 10);
        const seconds: number = Number.parseInt(text.substring(colon + 1), 10);
        if (Number.isNaN(minutes) || Number.isNaN(seconds)) {
          return 0;
        }
        return (minutes * 60 + seconds) * 1000;
      }
      const numeric: number = Number.parseFloat(text);
      return Number.isNaN(numeric) ? 0 : ServerSchemas.secondsToMs(numeric);
    }
    return 0;
  }

  /** 兼容毫秒 / 秒 / ISO 字符串三种过期时间格式。 */
  static expiresAtMs(value: string | number | undefined): number {
    if (typeof value === 'number' && !Number.isNaN(value)) {
      return value > 100000000000 ? value : value * 1000;
    }
    if (typeof value === 'string' && value.length > 0) {
      const numeric: number = Number.parseFloat(value);
      if (!Number.isNaN(numeric) && value.indexOf('-') < 0 && value.indexOf('T') < 0) {
        return numeric > 100000000000 ? numeric : numeric * 1000;
      }
      const parsed: number = Date.parse(value);
      return Number.isNaN(parsed) ? 0 : parsed;
    }
    return 0;
  }

  /** 将 trackKey 拆成 platform + 主体（wy:123 → ['wy','123']）。 */
  static splitKey(key: string): string[] {
    const index: number = key.indexOf(':');
    if (index <= 0) {
      return ['', key];
    }
    return [key.substring(0, index), key.substring(index + 1)];
  }

  // ---------- 会话 ----------

  static parseSession(root: Object): ServerSession {
    const env: EnvelopeRaw = root as EnvelopeRaw;
    let source: Object = root;
    const data: Object | undefined = env.data;
    if (data !== undefined && !Array.isArray(data)) {
      source = data;
    }
    const raw: LoginDataRaw = source as LoginDataRaw;
    const rootRaw: LoginDataRaw = root as LoginDataRaw;
    const session: ServerSession = new ServerSession();
    session.token = ServerSchemas.str(raw.token, ServerSchemas.str(rootRaw.token, ''));
    if (session.token.length === 0) {
      session.token = ServerSchemas.str(raw.accessToken, '');
    }
    session.expiresAt = ServerSchemas.expiresAtMs(raw.expiresAt !== undefined ? raw.expiresAt : rootRaw.expiresAt);
    if (session.expiresAt <= 0 && raw.expiresIn !== undefined) {
      session.expiresAt = Date.now() + ServerSchemas.num(raw.expiresIn, 2592000) * 1000;
    }
    const userObj: Object | undefined = raw.user !== undefined ? raw.user : rootRaw.user;
    if (userObj !== undefined) {
      const user: UserInfoRaw = userObj as UserInfoRaw;
      session.userId = ServerSchemas.str(user.id !== undefined ? user.id : user.userId, '');
      session.username = ServerSchemas.str(user.username, '');
      session.displayName = ServerSchemas.str(user.displayName,
        ServerSchemas.str(user.name, ServerSchemas.str(user.username, '')));
      session.role = ServerSchemas.str(user.role, '');
    }
    session.lastVerifiedAt = Date.now();
    return session;
  }

  // ---------- 曲库 ----------

  static trackFrom(obj: Object, serverId: string): Song {
    const raw: TrackRaw = obj as TrackRaw;
    const song: Song = new Song();
    const filePath: string = ServerSchemas.str(raw.filePath, ServerSchemas.str(raw.path, ''));
    song.filePath = filePath;
    song.trackKey = filePath;
    song.id = `srv_${Utils.stableId(filePath.length > 0 ? filePath : ServerSchemas.str(raw.fileName, ''))}`;
    song.title = ServerSchemas.str(raw.title, ServerSchemas.str(raw.name, '未知曲目'));
    song.artist = ServerSchemas.str(raw.artist, ServerSchemas.str(raw.singer, '未知歌手'));
    song.album = ServerSchemas.str(raw.album, '未知专辑');
    song.albumId = `alb_${Utils.stableId(song.album)}`;
    song.artistId = `art_${Utils.stableId(song.artist)}`;
    song.durationMs = raw.durationMs !== undefined
      ? ServerSchemas.num(raw.durationMs, 0) : ServerSchemas.secondsToMs(ServerSchemas.num(raw.duration, 0));
    song.format = ServerSchemas.str(raw.format, 'AUDIO').toUpperCase();
    song.sizeBytes = raw.sizeBytes !== undefined
      ? ServerSchemas.num(raw.sizeBytes, 0) : ServerSchemas.num(raw.size, 0);
    const bitRate: number = ServerSchemas.num(raw.bitRate, 0);
    if (bitRate > 0) {
      song.bitRate = bitRate >= 1000 ? Math.round(bitRate / 1000) : Math.round(bitRate);
    } else {
      song.bitRate = song.format === 'FLAC' ? 1411 : 320;
    }
    song.mtime = ServerSchemas.num(raw.mtime, 0);
    song.hasPicture = ServerSchemas.bool(raw.hasPicture, false);
    song.hasLyric = ServerSchemas.bool(raw.hasLyrics, ServerSchemas.bool(raw.hasLyric, false));
    song.trackId = ServerSchemas.str(raw.trackId, '');
    song.addedAt = raw.addedAt !== undefined ? ServerSchemas.secondsToMs(ServerSchemas.num(raw.addedAt, 0))
      : song.mtime;
    if (song.addedAt <= 0) {
      song.addedAt = song.mtime;
    }
    song.coverSeed = Utils.hashString(song.title + song.artist) % 12;
    song.source = MediaSource.SERVER_FILE;
    song.audioRef = `srv:${filePath}`;
    song.serverId = serverId;
    const sampleRate: number = ServerSchemas.num(raw.sampleRate, 0);
    const bits: number = ServerSchemas.num(raw.bitsPerSample, 0);
    if (sampleRate > 0) {
      song.qualitys = `${Math.round(sampleRate / 1000)}kHz/${bits}bit`;
    }
    return song;
  }

  static onlineSongFrom(obj: Object, defaultSource: string): Song {
    const raw: OnlineTrackRaw = obj as OnlineTrackRaw;
    const song: Song = new Song();
    song.platform = ServerSchemas.str(raw.source, defaultSource);
    const platformId: string = ServerSchemas.str(raw.songId, ServerSchemas.str(raw.songmid,
      ServerSchemas.str(raw.hash, ServerSchemas.str(raw.copyrightId, ServerSchemas.str(raw.musicId, '')))));
    song.platformSongId = platformId;
    song.title = ServerSchemas.str(raw.name, ServerSchemas.str(raw.title, '未知歌曲'));
    song.artist = ServerSchemas.str(raw.singer, ServerSchemas.str(raw.artist, '未知歌手'));
    song.album = ServerSchemas.str(raw.album, ServerSchemas.str(raw.albumName, ''));
    song.albumId = `alb_${Utils.stableId(song.album.length > 0 ? song.album : song.title)}`;
    song.artistId = `art_${Utils.stableId(song.artist)}`;
    song.durationMs = raw.interval !== undefined
      ? ServerSchemas.intervalToMs(raw.interval) : ServerSchemas.secondsToMs(ServerSchemas.num(raw.duration, 0));
    song.coverUrl = ServerSchemas.str(raw.picUrl, ServerSchemas.str(raw.img,
      ServerSchemas.str(raw.cover, ServerSchemas.str(raw.coverUrl, ''))));
    const qualityList: string[] = ServerSchemas.strings(raw.qualitys);
    song.qualitys = qualityList.length > 0 ? qualityList.join(' ') : ServerSchemas.strings(raw.types).join(' ');
    song.lyricText = ServerSchemas.str(raw.lyric, '');
    song.id = `on_${Utils.stableId(`${song.platform}|${platformId.length > 0 ? platformId : song.title}`)}`;
    song.trackKey = `${song.platform}:${platformId}`;
    song.source = MediaSource.ONLINE;
    song.audioRef = `online:${song.platform}:${platformId}`;
    song.format = guessQualityLabel(song.qualitys);
    song.bitRate = song.format === 'FLAC' ? 1411 : 320;
    song.coverSeed = Utils.hashString(song.title + song.artist) % 12;
    song.addedAt = Date.now();
    return song;
  }

  static albumFrom(obj: Object): Album {
    const raw: AlbumRaw = obj as AlbumRaw;
    const album: Album = new Album();
    const name: string = ServerSchemas.str(raw.name, ServerSchemas.str(raw.title,
      ServerSchemas.str(raw.album, '未知专辑')));
    album.title = name;
    album.artist = ServerSchemas.str(raw.artist, ServerSchemas.str(raw.singer, '未知歌手'));
    album.id = `alb_${Utils.stableId(name)}`;
    album.remoteId = ServerSchemas.str(raw.id, '');
    album.coverPath = ServerSchemas.str(raw.coverPath, '');
    album.coverUrl = ServerSchemas.str(raw.coverUrl, ServerSchemas.str(raw.cover,
      ServerSchemas.str(raw.picUrl, ServerSchemas.str(raw.img, ''))));
    album.year = ServerSchemas.num(raw.year, 0);
    album.count = raw.count !== undefined ? ServerSchemas.num(raw.count, 0) : ServerSchemas.num(raw.songCount, 0);
    album.platform = ServerSchemas.str(raw.source, ServerSchemas.str(raw.platform, ''));
    album.coverSeed = Utils.hashString(name + album.artist) % 12;
    album.artistId = `art_${Utils.stableId(album.artist)}`;
    return album;
  }

  static artistFrom(obj: Object): Artist {
    const raw: ArtistRaw = obj as ArtistRaw;
    const name: string = ServerSchemas.str(raw.name, ServerSchemas.str(raw.artist, '未知歌手'));
    const artist: Artist = new Artist();
    artist.name = name;
    artist.id = `art_${Utils.stableId(name)}`;
    artist.songCount = ServerSchemas.num(raw.count, ServerSchemas.num(raw.songCount, 0));
    artist.albumCount = ServerSchemas.num(raw.albumCount, 0);
    artist.coverPath = ServerSchemas.str(raw.coverPath, '');
    artist.coverUrl = ServerSchemas.str(raw.coverUrl, ServerSchemas.str(raw.cover, ''));
    artist.coverSeed = Utils.hashString(name) % 12;
    return artist;
  }

  static playlistFrom(obj: Object, serverId: string): Playlist {
    const raw: PlaylistRawItem = obj as PlaylistRawItem;
    const playlist: Playlist = new Playlist();
    playlist.name = ServerSchemas.str(raw.name, ServerSchemas.str(raw.title, '未命名歌单'));
    playlist.id = `pl_${Utils.stableId(`${serverId}|${playlist.name}`)}`;
    playlist.serverId = serverId;
    playlist.coverUrl = ServerSchemas.str(raw.coverUrl, ServerSchemas.str(raw.cover,
      ServerSchemas.str(raw.picUrl, ServerSchemas.str(raw.img, ''))));
    playlist.coverSeed = Utils.hashString(playlist.name) % 12;
    playlist.platform = ServerSchemas.str(raw.source, '');
    playlist.updatedAt = raw.updatedAt !== undefined
      ? ServerSchemas.secondsToMs(ServerSchemas.num(raw.updatedAt, 0)) : 0;
    playlist.isFavorites = ServerSchemas.bool(raw.isFavorites, false);
    playlist.isCloud = false;
    playlist.editable = !playlist.isFavorites;
    const keys: Object[] = ServerSchemas.asArray(raw.trackKeys);
    const snapshots: Object | undefined = raw.trackSnapshots;
    const snapshotMap: Record<string, Object> = snapshots !== undefined
      ? snapshots as Record<string, Object> : {};
    const entries: PlaylistEntry[] = [];
    const songIds: string[] = [];
    for (let i = 0; i < keys.length; i++) {
      const key: string = trackKeyOf(keys[i]);
      if (key.length === 0) {
        continue;
      }
      const snapshot: Object | undefined = snapshotMap[key];
      const entry: PlaylistEntry = ServerSchemas.playlistEntryFrom(key, snapshot);
      entries.push(entry);
      songIds.push(entry.songId);
    }
    playlist.entries = entries;
    playlist.songIds = songIds;
    return playlist;
  }

  static playlistEntryFrom(key: string, snapshot: Object | undefined): PlaylistEntry {
    const entry: PlaylistEntry = new PlaylistEntry();
    entry.key = key;
    const parts: string[] = ServerSchemas.splitKey(key);
    const prefix: string = parts[0];
    const body: string = parts[1];
    entry.snapshotJson = snapshot !== undefined ? JSON.stringify(snapshot) : '';
    entry.hasSnapshot = snapshot !== undefined;
    if (prefix === 'local' || prefix === 'file' || prefix === '') {
      entry.localPath = body;
      entry.platform = '';
    } else {
      entry.platform = prefix;
      entry.songId = body;
    }
    if (snapshot !== undefined) {
      const raw: SnapshotRaw = snapshot as SnapshotRaw;
      entry.name = ServerSchemas.str(raw.name, ServerSchemas.str(raw.title, ''));
      entry.singer = ServerSchemas.str(raw.singer, ServerSchemas.str(raw.artist, ''));
      entry.album = ServerSchemas.str(raw.album, ServerSchemas.str(raw.albumName, ''));
      const localPath: string = ServerSchemas.str(raw.localPath,
        ServerSchemas.str(raw.path, ServerSchemas.str(raw.filePath, '')));
      if (localPath.length > 0 && entry.localPath.length === 0) {
        entry.localPath = localPath;
      }
      entry.picUrl = ServerSchemas.str(raw.picUrl, ServerSchemas.str(raw.img, ServerSchemas.str(raw.cover, '')));
      entry.lyric = ServerSchemas.str(raw.lyric, '');
      entry.durationMs = raw.durationMs !== undefined ? ServerSchemas.num(raw.durationMs, 0)
        : (raw.interval !== undefined ? ServerSchemas.intervalToMs(raw.interval)
          : ServerSchemas.secondsToMs(ServerSchemas.num(raw.duration, 0)));
      entry.qualitys = ServerSchemas.strings(raw.qualitys);
      const songId: string = ServerSchemas.str(raw.songId, ServerSchemas.str(raw.songmid,
        ServerSchemas.str(raw.hash, ServerSchemas.str(raw.copyrightId, ''))));
      if (entry.songId.length === 0 && songId.length > 0) {
        entry.songId = songId;
      }
      if (entry.platform.length === 0) {
        entry.platform = ServerSchemas.str(raw.source, '');
      }
    }
    if (entry.name.length === 0) {
      entry.name = entry.localPath.length > 0 ? fileNameOf(entry.localPath) : '未知曲目';
    }
    return entry;
  }

  static parseUserData(root: Object): UserDataParsed {
    const parsed: UserDataParsed = new UserDataParsed();
    const source: Object = ServerSchemas.dataObject(root);
    const raw: UserDataRaw = source as UserDataRaw;
    parsed.favorites = ServerSchemas.asArray(raw.favorites);
    parsed.playlists = ServerSchemas.asArray(raw.playlists);
    parsed.favoriteAlbums = ServerSchemas.asArray(raw.favoriteAlbums);
    parsed.favoriteArtists = ServerSchemas.asArray(raw.favoriteArtists);
    parsed.recentPlays = ServerSchemas.asArray(raw.recentPlays);
    parsed.revision = ServerSchemas.str(raw.revision, '');
    return parsed;
  }

  // ---------- 发现 / 搜索 ----------

  static toplistFrom(obj: Object, defaultSource: string): DiscoverToplistItem {
    const raw: PlaylistRawItem = obj as PlaylistRawItem;
    const item: DiscoverToplistItem = new DiscoverToplistItem();
    item.name = ServerSchemas.str(raw.name, ServerSchemas.str(raw.title, '排行榜'));
    item.id = ServerSchemas.str(raw.id, Utils.stableId(item.name));
    item.coverUrl = ServerSchemas.str(raw.coverUrl, ServerSchemas.str(raw.cover,
      ServerSchemas.str(raw.picUrl, ServerSchemas.str(raw.img, ''))));
    item.updateTime = ServerSchemas.str(raw.updateTime, '');
    item.source = ServerSchemas.str(raw.source, defaultSource);
    item.count = ServerSchemas.num(raw.songCount, ServerSchemas.num(raw.count, 0));
    item.seed = Utils.hashString(item.name) % 12;
    return item;
  }

  static discoverTrackFrom(obj: Object, defaultSource: string): DiscoverTrackItem {
    const raw: OnlineTrackRaw = obj as OnlineTrackRaw;
    const item: DiscoverTrackItem = new DiscoverTrackItem();
    item.name = ServerSchemas.str(raw.name, ServerSchemas.str(raw.title, '未知歌曲'));
    item.subtitle = ServerSchemas.str(raw.singer, ServerSchemas.str(raw.artist, ''));
    item.album = ServerSchemas.str(raw.album, ServerSchemas.str(raw.albumName, ''));
    item.source = ServerSchemas.str(raw.source, defaultSource);
    item.platformId = ServerSchemas.str(raw.songId, ServerSchemas.str(raw.songmid,
      ServerSchemas.str(raw.hash, ServerSchemas.str(raw.copyrightId, ''))));
    item.id = `on_${Utils.stableId(`${item.source}|${item.platformId.length > 0 ? item.platformId : item.name}`)}`;
    item.durationMs = raw.interval !== undefined ? ServerSchemas.intervalToMs(raw.interval)
      : ServerSchemas.secondsToMs(ServerSchemas.num(raw.duration, 0));
    item.coverUrl = ServerSchemas.str(raw.picUrl, ServerSchemas.str(raw.img,
      ServerSchemas.str(raw.cover, ServerSchemas.str(raw.coverUrl, ''))));
    item.qualitys = ServerSchemas.strings(raw.qualitys).join(' ');
    item.seed = Utils.hashString(item.name + item.subtitle) % 12;
    return item;
  }
}

export function trackKeyOf(entry: Object): string {
  if (typeof entry === 'string') {
    return entry;
  }
  const raw: SnapshotRaw = entry as SnapshotRaw;
  const key: string = ServerSchemas.str(raw.key, '');
  if (key.length > 0) {
    return key;
  }
  const path: string = ServerSchemas.str(raw.localPath, ServerSchemas.str(raw.path,
    ServerSchemas.str(raw.filePath, '')));
  if (path.length > 0) {
    return `local:${path}`;
  }
  const platform: string = ServerSchemas.str(raw.source, '');
  const songId: string = ServerSchemas.str(raw.songId, ServerSchemas.str(raw.songmid,
    ServerSchemas.str(raw.hash, ServerSchemas.str(raw.copyrightId, ''))));
  if (platform.length > 0 && songId.length > 0) {
    return `${platform}:${songId}`;
  }
  return '';
}

function fileNameOf(path: string): string {
  const index: number = path.lastIndexOf('/');
  if (index >= 0 && index < path.length - 1) {
    return path.substring(index + 1);
  }
  return path;
}

function guessQualityLabel(qualitys: string): string {
  const lower: string = qualitys.toLowerCase();
  if (lower.indexOf('flac') >= 0 || lower.indexOf('lossless') >= 0) {
    return 'FLAC';
  }
  if (lower.indexOf('320') >= 0) {
    return 'MP3 320K';
  }
  if (lower.indexOf('128') >= 0) {
    return 'MP3 128K';
  }
  return 'AUDIO';
}
