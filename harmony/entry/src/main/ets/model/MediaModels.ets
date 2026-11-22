/**
 * 媒体领域模型：歌曲 / 专辑 / 歌手 / 歌单 / 可播放项 / 播放模式。
 */
import { PlaylistEntry } from './ServerModels';

export enum MediaSource {
  LOCAL = 'local',
  SERVER_FILE = 'serverFile',
  ONLINE = 'online',
  PODCAST = 'podcast'
}

export enum SongDownloadState {
  NONE = 'none',
  DONE = 'done',
  PAUSED = 'paused',
  FAILED = 'failed'
}

export enum PlayableKind {
  SONG = 'song',
  EPISODE = 'episode'
}

export enum PlayMode {
  LIST_LOOP = 'listLoop',
  SINGLE_LOOP = 'singleLoop',
  SEQUENTIAL = 'sequential',
  SHUFFLE = 'shuffle'
}

export enum PlayerStatus {
  IDLE = 'idle',
  RESOLVING = 'resolving',
  LOADING = 'loading',
  PLAYING = 'playing',
  PAUSED = 'paused',
  COMPLETED = 'completed',
  ERROR = 'error'
}

@ObservedV2
export class Song {
  id: string = '';
  @Trace title: string = '';
  @Trace artist: string = '';
  artistId: string = '';
  @Trace album: string = '';
  albumId: string = '';
  @Trace durationMs: number = 0;
  @Trace audioRef: string = '';
  source: MediaSource = MediaSource.LOCAL;
  @Trace coverSeed: number = 0;
  @Trace format: string = 'AUDIO';
  @Trace bitRate: number = 320;
  @Trace sizeBytes: number = 0;
  @Trace isFavorite: boolean = false;
  @Trace addedAt: number = 0;
  @Trace lastPlayedAt: number = 0;
  @Trace playCount: number = 0;
  @Trace lyricText: string = '';
  @Trace downloadState: SongDownloadState = SongDownloadState.NONE;
  localPath: string = '';

  // 服务端 / 在线来源字段
  filePath: string = '';
  trackId: string = '';
  platform: string = '';
  platformSongId: string = '';
  @Trace coverUrl: string = '';
  qualitys: string = '';
  mtime: number = 0;
  @Trace hasPicture: boolean = false;
  hasLyric: boolean = false;
  trackKey: string = '';
  serverId: string = '';

  get isLocal(): boolean {
    return this.source === MediaSource.LOCAL;
  }

  get isOnline(): boolean {
    return this.source === MediaSource.ONLINE;
  }

  get isServerFile(): boolean {
    return this.source === MediaSource.SERVER_FILE;
  }
}

export class Album {
  id: string = '';
  title: string = '';
  artist: string = '';
  artistId: string = '';
  coverSeed: number = 0;
  coverUrl: string = '';
  coverPath: string = '';
  year: number = 0;
  songIds: string[] = [];
  count: number = 0;
  platform: string = '';
  remoteId: string = '';
}

export class Artist {
  id: string = '';
  name: string = '';
  coverSeed: number = 0;
  coverUrl: string = '';
  coverPath: string = '';
  albumCount: number = 0;
  songCount: number = 0;
}

export class Playlist {
  id: string = '';
  name: string = '';
  coverSeed: number = 0;
  coverUrl: string = '';
  isCloud: boolean = false;
  editable: boolean = true;
  readOnly: boolean = false;
  isFavorites: boolean = false;
  songIds: string[] = [];
  entries: PlaylistEntry[] = [];
  updatedAt: number = 0;
  serverId: string = '';
  remoteSnapshotJson: string = '';
  platform: string = '';
}

/** 队列元素：音乐与播客统一模型。 */
export class PlayableItem {
  id: string = '';
  kind: PlayableKind = PlayableKind.SONG;
  songId: string = '';
  episodeId: string = '';
  showId: string = '';
  title: string = '';
  subtitle: string = '';
  coverSeed: number = 0;
  coverUrl: string = '';
  audioRef: string = '';
  durationMs: number = 0;
  isHiRes: boolean = false;

  // 播放解析所需字段
  mediaSource: MediaSource = MediaSource.LOCAL;
  filePath: string = '';
  trackId: string = '';
  platform: string = '';
  platformSongId: string = '';
  qualitys: string = '';
  serverId: string = '';
  lyricText: string = '';
  mtime: number = 0;
  hasPicture: boolean = false;

  static fromSong(song: Song): PlayableItem {
    const item: PlayableItem = new PlayableItem();
    item.id = song.id;
    item.kind = PlayableKind.SONG;
    item.songId = song.id;
    item.title = song.title;
    item.subtitle = song.artist;
    item.coverSeed = song.coverSeed;
    item.coverUrl = song.coverUrl;
    item.audioRef = song.audioRef;
    item.durationMs = song.durationMs;
    item.isHiRes = song.bitRate >= 1411;
    item.mediaSource = song.source;
    item.filePath = song.filePath;
    item.trackId = song.trackId;
    item.platform = song.platform;
    item.platformSongId = song.platformSongId;
    item.qualitys = song.qualitys;
    item.serverId = song.serverId;
    item.lyricText = song.lyricText;
    item.mtime = song.mtime;
    item.hasPicture = song.hasPicture;
    return item;
  }

  get isPodcast(): boolean {
    return this.kind === PlayableKind.EPISODE;
  }
}

export class MediaSourceHelper {
  static label(source: MediaSource): string {
    if (source === MediaSource.LOCAL) {
      return '本地';
    }
    if (source === MediaSource.SERVER_FILE) {
      return '服务器';
    }
    if (source === MediaSource.ONLINE) {
      return '在线';
    }
    return '播客';
  }

  static badgeTone(source: MediaSource): string {
    if (source === MediaSource.LOCAL) {
      return 'success';
    }
    if (source === MediaSource.SERVER_FILE) {
      return 'brand';
    }
    if (source === MediaSource.ONLINE) {
      return 'warn';
    }
    return 'glass';
  }
}

export class PlayModeHelper {
  static label(mode: PlayMode): string {
    if (mode === PlayMode.SINGLE_LOOP) {
      return '单曲循环';
    }
    if (mode === PlayMode.SEQUENTIAL) {
      return '顺序播放';
    }
    if (mode === PlayMode.SHUFFLE) {
      return '随机播放';
    }
    return '列表循环';
  }

  static next(mode: PlayMode): PlayMode {
    if (mode === PlayMode.LIST_LOOP) {
      return PlayMode.SINGLE_LOOP;
    }
    if (mode === PlayMode.SINGLE_LOOP) {
      return PlayMode.SEQUENTIAL;
    }
    if (mode === PlayMode.SEQUENTIAL) {
      return PlayMode.SHUFFLE;
    }
    return PlayMode.LIST_LOOP;
  }

  static icon(mode: PlayMode): Resource {
    if (mode === PlayMode.SINGLE_LOOP) {
      return $r('app.media.ic_repeat_one');
    }
    if (mode === PlayMode.SEQUENTIAL) {
      return $r('app.media.ic_next');
    }
    if (mode === PlayMode.SHUFFLE) {
      return $r('app.media.ic_shuffle');
    }
    return $r('app.media.ic_repeat');
  }
}
