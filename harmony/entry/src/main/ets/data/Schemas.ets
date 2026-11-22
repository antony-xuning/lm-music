/**
 * 持久化 DTO 与编解码：JSON 取出后先落成 Raw 结构，再逐字段校验转成严格模型。
 * 所有 Raw 类型仅用于数据层，UI 与 Store 只接触 model/ 下的领域模型。
 */
import { MediaSource, Playlist, Song, SongDownloadState } from '../model/MediaModels';
import { PlaylistEntry } from '../model/ServerModels';
import { DownloadStatus, DownloadTask } from '../model/DownloadModels';

export interface SongRaw {
  id?: string;
  title?: string;
  artist?: string;
  artistId?: string;
  album?: string;
  albumId?: string;
  durationMs?: number;
  audioRef?: string;
  source?: string;
  coverSeed?: number;
  format?: string;
  bitRate?: number;
  sizeBytes?: number;
  addedAt?: number;
  lastPlayedAt?: number;
  playCount?: number;
  lyricText?: string;
  downloadState?: string;
  localPath?: string;
  isFavorite?: boolean;
  filePath?: string;
  trackId?: string;
  platform?: string;
  platformSongId?: string;
  coverUrl?: string;
  qualitys?: string;
  mtime?: number;
  hasPicture?: boolean;
  hasLyric?: boolean;
  trackKey?: string;
  serverId?: string;
}

export interface PlaylistEntryRaw {
  key?: string;
  platform?: string;
  songId?: string;
  name?: string;
  singer?: string;
  album?: string;
  localPath?: string;
  picUrl?: string;
  lyric?: string;
  durationMs?: number;
  qualitys?: string[];
  snapshotJson?: string;
  hasSnapshot?: boolean;
}

export interface PlaylistRaw {
  id?: string;
  name?: string;
  coverSeed?: number;
  coverUrl?: string;
  isCloud?: boolean;
  editable?: boolean;
  readOnly?: boolean;
  isFavorites?: boolean;
  platform?: string;
  songIds?: string[];
  entries?: PlaylistEntryRaw[];
  updatedAt?: number;
  serverId?: string;
  remoteSnapshotJson?: string;
}

export interface LibraryDoc {
  schemaVersion?: number;
  localSongs?: SongRaw[];
  playlists?: PlaylistRaw[];
  favoriteIds?: string[];
  recentIds?: string[];
}

export interface TaskRaw {
  id?: string;
  songId?: string;
  title?: string;
  artist?: string;
  coverSeed?: number;
  quality?: string;
  status?: string;
  progress?: number;
  bytesDone?: number;
  bytesTotal?: number;
  speedKbps?: number;
  completedAt?: number;
  localPath?: string;
}

export interface DownloadsDoc {
  schemaVersion?: number;
  tasks?: TaskRaw[];
}

export interface SubscriptionRaw {
  showId?: string;
  subscribedAt?: number;
}

export interface EpisodeProgressRaw {
  episodeId?: string;
  progressMs?: number;
  updatedAt?: number;
}

export interface PodcastsDoc {
  schemaVersion?: number;
  subscriptions?: SubscriptionRaw[];
  progress?: EpisodeProgressRaw[];
}

export interface PlayerItemRaw {
  id?: string;
  kind?: string;
  songId?: string;
  episodeId?: string;
  showId?: string;
  title?: string;
  subtitle?: string;
  coverSeed?: number;
  coverUrl?: string;
  audioRef?: string;
  durationMs?: number;
  isHiRes?: boolean;
  mediaSource?: string;
  filePath?: string;
  trackId?: string;
  platform?: string;
  platformSongId?: string;
  qualitys?: string;
  serverId?: string;
  lyricText?: string;
}

export interface PlayerDoc {
  schemaVersion?: number;
  queue?: PlayerItemRaw[];
  currentIndex?: number;
  mode?: string;
  positionMs?: number;
}

function asString(value: string | undefined, fallback: string): string {
  return typeof value === 'string' ? value : fallback;
}

function asNumber(value: number | undefined, fallback: number): number {
  return typeof value === 'number' && !Number.isNaN(value) ? value : fallback;
}

function asBoolean(value: boolean | undefined, fallback: boolean): boolean {
  return typeof value === 'boolean' ? value : fallback;
}

function asStringArray(value: string[] | undefined): string[] {
  if (!Array.isArray(value)) {
    return [];
  }
  const result: string[] = [];
  for (let i = 0; i < value.length; i++) {
    if (typeof value[i] === 'string') {
      result.push(value[i]);
    }
  }
  return result;
}

function parseMediaSource(value: string): MediaSource {
  if (value === MediaSource.SERVER_FILE) {
    return MediaSource.SERVER_FILE;
  }
  if (value === MediaSource.ONLINE) {
    return MediaSource.ONLINE;
  }
  if (value === MediaSource.PODCAST) {
    return MediaSource.PODCAST;
  }
  return MediaSource.LOCAL;
}

export class SchemaCodec {
  static toSongRaw(song: Song): SongRaw {
    const raw: SongRaw = {
      id: song.id,
      title: song.title,
      artist: song.artist,
      artistId: song.artistId,
      album: song.album,
      albumId: song.albumId,
      durationMs: song.durationMs,
      audioRef: song.audioRef,
      source: song.source,
      coverSeed: song.coverSeed,
      format: song.format,
      bitRate: song.bitRate,
      sizeBytes: song.sizeBytes,
      addedAt: song.addedAt,
      lastPlayedAt: song.lastPlayedAt,
      playCount: song.playCount,
      lyricText: song.lyricText,
      downloadState: song.downloadState,
      localPath: song.localPath,
      isFavorite: song.isFavorite,
      filePath: song.filePath,
      trackId: song.trackId,
      platform: song.platform,
      platformSongId: song.platformSongId,
      coverUrl: song.coverUrl,
      qualitys: song.qualitys,
      mtime: song.mtime,
      hasPicture: song.hasPicture,
      hasLyric: song.hasLyric,
      trackKey: song.trackKey,
      serverId: song.serverId
    };
    return raw;
  }

  static fromSongRaw(raw: SongRaw): Song {
    const song: Song = new Song();
    song.id = asString(raw.id, '');
    song.title = asString(raw.title, '未命名歌曲');
    song.artist = asString(raw.artist, '未知歌手');
    song.artistId = asString(raw.artistId, '');
    song.album = asString(raw.album, '未知专辑');
    song.albumId = asString(raw.albumId, '');
    song.durationMs = Math.max(asNumber(raw.durationMs, 0), 0);
    song.audioRef = asString(raw.audioRef, '');
    song.source = parseMediaSource(asString(raw.source, MediaSource.LOCAL));
    song.coverSeed = asNumber(raw.coverSeed, 0);
    song.format = asString(raw.format, 'AUDIO');
    song.bitRate = asNumber(raw.bitRate, 320);
    song.sizeBytes = asNumber(raw.sizeBytes, 0);
    song.addedAt = asNumber(raw.addedAt, Date.now());
    song.lastPlayedAt = asNumber(raw.lastPlayedAt, 0);
    song.playCount = asNumber(raw.playCount, 0);
    song.lyricText = asString(raw.lyricText, '');
    song.localPath = asString(raw.localPath, '');
    song.isFavorite = asBoolean(raw.isFavorite, false);
    song.filePath = asString(raw.filePath, '');
    song.trackId = asString(raw.trackId, '');
    song.platform = asString(raw.platform, '');
    song.platformSongId = asString(raw.platformSongId, '');
    song.coverUrl = asString(raw.coverUrl, '');
    song.qualitys = asString(raw.qualitys, '');
    song.mtime = asNumber(raw.mtime, 0);
    song.hasPicture = asBoolean(raw.hasPicture, false);
    song.hasLyric = asBoolean(raw.hasLyric, false);
    song.trackKey = asString(raw.trackKey, '');
    song.serverId = asString(raw.serverId, '');
    const downloadState: string = asString(raw.downloadState, SongDownloadState.NONE);
    if (downloadState === 'done') {
      song.downloadState = SongDownloadState.DONE;
    } else if (downloadState === 'paused') {
      song.downloadState = SongDownloadState.PAUSED;
    } else if (downloadState === 'failed') {
      song.downloadState = SongDownloadState.FAILED;
    } else {
      song.downloadState = SongDownloadState.NONE;
    }
    return song;
  }

  static toPlaylistEntryRaw(entry: PlaylistEntry): PlaylistEntryRaw {
    return {
      key: entry.key,
      platform: entry.platform,
      songId: entry.songId,
      name: entry.name,
      singer: entry.singer,
      album: entry.album,
      localPath: entry.localPath,
      picUrl: entry.picUrl,
      lyric: entry.lyric,
      durationMs: entry.durationMs,
      qualitys: entry.qualitys,
      snapshotJson: entry.snapshotJson,
      hasSnapshot: entry.hasSnapshot
    };
  }

  static fromPlaylistEntryRaw(raw: PlaylistEntryRaw): PlaylistEntry {
    const entry: PlaylistEntry = new PlaylistEntry();
    entry.key = asString(raw.key, '');
    entry.platform = asString(raw.platform, '');
    entry.songId = asString(raw.songId, '');
    entry.name = asString(raw.name, '未知曲目');
    entry.singer = asString(raw.singer, '');
    entry.album = asString(raw.album, '');
    entry.localPath = asString(raw.localPath, '');
    entry.picUrl = asString(raw.picUrl, '');
    entry.lyric = asString(raw.lyric, '');
    entry.durationMs = asNumber(raw.durationMs, 0);
    entry.qualitys = asStringArray(raw.qualitys);
    entry.snapshotJson = asString(raw.snapshotJson, '');
    entry.hasSnapshot = asBoolean(raw.hasSnapshot, entry.snapshotJson.length > 0);
    return entry;
  }

  static toPlaylistRaw(playlist: Playlist): PlaylistRaw {
    const entries: PlaylistEntryRaw[] = [];
    for (let i = 0; i < playlist.entries.length; i++) {
      entries.push(SchemaCodec.toPlaylistEntryRaw(playlist.entries[i]));
    }
    const raw: PlaylistRaw = {
      id: playlist.id,
      name: playlist.name,
      coverSeed: playlist.coverSeed,
      coverUrl: playlist.coverUrl,
      isCloud: playlist.isCloud,
      editable: playlist.editable,
      readOnly: playlist.readOnly,
      isFavorites: playlist.isFavorites,
      platform: playlist.platform,
      songIds: playlist.songIds,
      entries: entries,
      updatedAt: playlist.updatedAt,
      serverId: playlist.serverId,
      remoteSnapshotJson: playlist.remoteSnapshotJson
    };
    return raw;
  }

  static fromPlaylistRaw(raw: PlaylistRaw): Playlist {
    const playlist: Playlist = new Playlist();
    playlist.id = asString(raw.id, '');
    playlist.name = asString(raw.name, '未命名歌单');
    playlist.coverSeed = asNumber(raw.coverSeed, 0);
    playlist.coverUrl = asString(raw.coverUrl, '');
    playlist.isCloud = asBoolean(raw.isCloud, false);
    playlist.editable = asBoolean(raw.editable, true);
    playlist.readOnly = asBoolean(raw.readOnly, false);
    playlist.isFavorites = asBoolean(raw.isFavorites, false);
    playlist.platform = asString(raw.platform, '');
    playlist.songIds = asStringArray(raw.songIds);
    playlist.updatedAt = asNumber(raw.updatedAt, Date.now());
    playlist.serverId = asString(raw.serverId, '');
    playlist.remoteSnapshotJson = asString(raw.remoteSnapshotJson, '');
    const rawEntries: PlaylistEntryRaw[] = Array.isArray(raw.entries) ? raw.entries : [];
    const entries: PlaylistEntry[] = [];
    for (let i = 0; i < rawEntries.length; i++) {
      entries.push(SchemaCodec.fromPlaylistEntryRaw(rawEntries[i]));
    }
    playlist.entries = entries;
    return playlist;
  }

  static toTaskRaw(task: DownloadTask): TaskRaw {
    const raw: TaskRaw = {
      id: task.id,
      songId: task.songId,
      title: task.title,
      artist: task.artist,
      coverSeed: task.coverSeed,
      quality: task.quality,
      status: task.status,
      progress: task.progress,
      bytesDone: task.bytesDone,
      bytesTotal: task.bytesTotal,
      speedKbps: task.speedKbps,
      completedAt: task.completedAt,
      localPath: task.localPath
    };
    return raw;
  }

  static fromTaskRaw(raw: TaskRaw): DownloadTask {
    const task: DownloadTask = new DownloadTask();
    task.id = asString(raw.id, '');
    task.songId = asString(raw.songId, '');
    task.title = asString(raw.title, '未命名任务');
    task.artist = asString(raw.artist, '未知歌手');
    task.coverSeed = asNumber(raw.coverSeed, 0);
    task.quality = asString(raw.quality, 'FLAC');
    task.progress = Math.min(100, Math.max(0, asNumber(raw.progress, 0)));
    task.bytesTotal = asNumber(raw.bytesTotal, 0);
    task.bytesDone = asNumber(raw.bytesDone, 0);
    task.speedKbps = asNumber(raw.speedKbps, 0);
    task.completedAt = asNumber(raw.completedAt, 0);
    task.localPath = asString(raw.localPath, '');
    const status: string = asString(raw.status, DownloadStatus.WAITING);
    if (status === 'downloading') {
      task.status = DownloadStatus.DOWNLOADING;
    } else if (status === 'paused') {
      task.status = DownloadStatus.PAUSED;
    } else if (status === 'completed') {
      task.status = DownloadStatus.COMPLETED;
    } else if (status === 'failed') {
      task.status = DownloadStatus.FAILED;
    } else {
      task.status = DownloadStatus.WAITING;
    }
    return task;
  }
}

export interface PreferencesRaw {
  themeMode?: string;
  uiScale?: number;
  blurAlpha?: number;
  bottomBarAnim?: string;
  autoPlay?: boolean;
  autoFallbackLocal?: boolean;
  autoLaunch?: boolean;
  defaultQuality?: string;
  downloadTarget?: string;
  embedCover?: boolean;
  embedLyric?: boolean;
  saveLrc?: boolean;
  onlineSource?: string;
  showRecentlyPlayed?: boolean;
  showRecentlyAdded?: boolean;
  showAlbums?: boolean;
  showArtists?: boolean;
  showFavorites?: boolean;
}

export interface ServerRaw {
  id?: string;
  name?: string;
  type?: string;
  url?: string;
  username?: string;
  token?: string;
  tokenExpiresAt?: number;
  displayName?: string;
  statusState?: string;
  lastConnectedAt?: number;
  lastSyncAt?: number;
  trackCount?: number;
  syncMode?: string;
  isActive?: boolean;
}
