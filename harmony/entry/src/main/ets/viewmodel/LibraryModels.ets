/**
 * 曲库写回辅助：收藏条目、歌单快照、条目解析与纯函数工具。
 */
import { MediaSource, Song } from '../model/MediaModels';
import { PlaylistEntry } from '../model/ServerModels';
import { ServerSchemas, trackKeyOf } from '../data/ServerSchemas';
import { Utils } from '../common/Utils';
import { serverContext } from '../service/ServerContext';
export class FavoriteToggle {
  ok: boolean = false;
  favorite: boolean = false;
  message: string = '';
}

export class WriteOutcome {
  ok: boolean = false;
  message: string = '';
  playlistId: string = '';
}

interface FavoriteEntryRaw {
  key?: string;
  path?: string;
  filePath?: string;
  localPath?: string;
  name?: string;
  title?: string;
  singer?: string;
  artist?: string;
  source?: string;
  songId?: string | number;
  platform?: string;
}

export class FavoriteEntry {
  key: string = '';
  path: string = '';
  filePath: string = '';
  name: string = '';
  singer: string = '';
  source: string = '';
  songId: string = '';

  static fromSong(song: Song): FavoriteEntry {
    const entry: FavoriteEntry = new FavoriteEntry();
    entry.name = song.title;
    entry.singer = song.artist;
    entry.songId = song.platformSongId;
    entry.source = song.source === MediaSource.SERVER_FILE ? 'local' : song.platform;
    if (song.source === MediaSource.SERVER_FILE) {
      entry.key = song.filePath;
      entry.path = song.filePath;
      entry.filePath = song.filePath;
    } else {
      entry.key = `${song.platform}:${song.platformSongId}`;
      entry.path = '';
      entry.filePath = '';
    }
    return entry;
  }
}


/** 供视图使用的空结果提示。 */
export class LibraryNotice {
  static notConnected(): string {
    return '尚未连接柠檬音乐服务器';
  }
}

export interface PlaylistRawForPatch {
  id?: string | number;
  key?: string;
  name?: string;
  title?: string;
  trackKeys?: Object[];
  trackSnapshots?: Object;
  updatedAt?: number | string;
  playlistType?: string;
  type?: string;
  songId?: string | number;
}

export class PlaylistCreateBody {
  name: string = '';
  trackKeys: string[] = [];
  trackSnapshots: Record<string, Object> = {};
  updatedAt: number = 0;
  playlistType: string = 'custom';

  constructor(name: string, updatedAt: number) {
    this.name = name;
    this.updatedAt = updatedAt;
  }
}

export class TrackSnapshotBody {
  key: string = '';
  name: string = '';
  singer: string = '';
  album: string = '';
  localPath: string = '';
  picUrl: string = '';
  duration: number = 0;
  source: string = '';
  songId: string = '';

  constructor(song: Song) {
    this.name = song.title;
    this.singer = song.artist;
    this.album = song.album;
    this.duration = Math.round(song.durationMs / 1000);
    this.songId = song.platformSongId;
    this.source = song.source === MediaSource.SERVER_FILE ? 'local' : song.platform;
  }
}

export function parseObjectArray(text: string): Object[] {
  if (text.length === 0) {
    return [];
  }
  try {
    const parsed: Object = JSON.parse(text) as Object;
    if (Array.isArray(parsed)) {
      return parsed as Object[];
    }
    return [];
  } catch (error) {
    return [];
  }
}

export function favoriteKeyOf(entry: Object): string {
  if (typeof entry === 'string') {
    return entry;
  }
  const raw: FavoriteEntryRaw = entry as FavoriteEntryRaw;
  const direct: string = ServerSchemas.str(raw.key, '');
  if (direct.length > 0) {
    return direct;
  }
  const path: string = ServerSchemas.str(raw.filePath,
    ServerSchemas.str(raw.path, ServerSchemas.str(raw.localPath, '')));
  if (path.length > 0) {
    return path;
  }
  const source: string = ServerSchemas.str(raw.source, '');
  const songId: string = ServerSchemas.str(raw.songId, '');
  if (source.length > 0 && songId.length > 0) {
    return `${source}:${songId}`;
  }
  return '';
}

export function removeFavorite(entries: Object[], song: Song): void {
  const key: string = song.source === MediaSource.SERVER_FILE
    ? song.filePath : `${song.platform}:${song.platformSongId}`;
  const prefixed: string = `local:${key}`;
  for (let i = entries.length - 1; i >= 0; i--) {
    const candidate: string = favoriteKeyOf(entries[i]);
    if (candidate === key || candidate === prefixed) {
      entries.splice(i, 1);
    }
  }
}

export function findPlaylistRaw(entries: Object[], name: string): PlaylistRawForPatch | null {
  for (let i = 0; i < entries.length; i++) {
    const raw: PlaylistRawForPatch = entries[i] as PlaylistRawForPatch;
    const candidate: string = ServerSchemas.str(raw.name, ServerSchemas.str(raw.title, ''));
    if (candidate === name) {
      return raw;
    }
  }
  return null;
}

export function songTrackKey(song: Song): string {
  if (song.source === MediaSource.SERVER_FILE) {
    return `local:${song.filePath}`;
  }
  if (song.source === MediaSource.ONLINE) {
    return `${song.platform}:${song.platformSongId}`;
  }
  return `local:${song.localPath}`;
}

export function trackSnapshotOf(song: Song): TrackSnapshotBody {
  const snapshot: TrackSnapshotBody = new TrackSnapshotBody(song);
  snapshot.key = songTrackKey(song);
  snapshot.localPath = song.source === MediaSource.SERVER_FILE ? song.filePath : song.localPath;
  return snapshot;
}

export function entryFromJson(json: string): PlaylistEntry | null {
  try {
    const parsed: Object = JSON.parse(json) as Object;
    const raw: PlaylistRawForPatch = parsed as PlaylistRawForPatch;
    let key: string = ServerSchemas.str(raw.key, '');
    if (key.length === 0) {
      key = ServerSchemas.str(raw.name, '');
    }
    return ServerSchemas.playlistEntryFrom(key, parsed);
  } catch (error) {
    return null;
  }
}

export function songFromEntry(entry: PlaylistEntry, serverId: string): Song {
  const song: Song = new Song();
  song.title = entry.name;
  song.artist = entry.singer.length > 0 ? entry.singer : '未知歌手';
  song.album = entry.album.length > 0 ? entry.album : '未知专辑';
  song.durationMs = entry.durationMs;
  song.coverUrl = entry.picUrl;
  song.lyricText = entry.lyric;
  song.qualitys = entry.qualitys.join(' ');
  if (entry.platform.length > 0) {
    song.source = MediaSource.ONLINE;
    song.platform = entry.platform;
    song.platformSongId = entry.songId;
    song.id = `on_${Utils.stableId(`${entry.platform}|${entry.songId}`)}`;
    song.audioRef = `online:${entry.platform}:${entry.songId}`;
    song.trackKey = `${entry.platform}:${entry.songId}`;
    song.format = 'AUDIO';
  } else {
    song.source = MediaSource.SERVER_FILE;
    song.filePath = entry.localPath;
    song.id = `srv_${Utils.stableId(entry.localPath)}`;
    song.audioRef = `srv:${entry.localPath}`;
    song.trackKey = entry.localPath;
    song.format = 'AUDIO';
  }
  song.serverId = serverId;
  song.albumId = `alb_${Utils.stableId(song.album)}`;
  song.artistId = `art_${Utils.stableId(song.artist)}`;
  song.coverSeed = Utils.hashString(song.title + song.artist) % 12;
  return song;
}

export function serverStoreReady(): boolean {
  return serverContext.configured && serverContext.hasToken;
}
