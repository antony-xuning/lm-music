/**
 * 服务端 DTO 解析（扩展域：下载任务 / 播客 / 音源脚本 / 标签 / 歌词）。
 */
import { Utils } from '../common/Utils';
import {
  PodcastEpisode,
  PodcastFeed,
  ServerDownloadTask,
  SourcePlatform,
  SourceScript,
  TagCandidate,
  TagInfo
} from '../model/ServerModels';
import { EnvelopeRaw, ServerSchemas } from './ServerSchemas';

interface DownloadTaskRaw {
  id?: string | number;
  taskId?: string | number;
  name?: string;
  title?: string;
  songName?: string;
  singer?: string;
  artist?: string;
  album?: string;
  source?: string;
  platform?: string;
  songId?: string | number;
  platformId?: string;
  quality?: string;
  status?: string;
  state?: string;
  progress?: number | string;
  downloaded?: number | string;
  bytesDone?: number | string;
  total?: number | string;
  bytesTotal?: number | string;
  size?: number | string;
  speed?: number | string;
  speedKbps?: number | string;
  path?: string;
  filePath?: string;
  error?: string;
  message?: string;
  createdAt?: number | string;
  updatedAt?: number | string;
}

interface PodcastFeedRaw {
  id?: string | number;
  feedId?: string | number;
  title?: string;
  name?: string;
  author?: string;
  cover?: string;
  coverUrl?: string;
  image?: string;
  picUrl?: string;
  description?: string;
  summary?: string;
  episodeCount?: number | string;
  episodes?: Object[];
  subscribedAt?: number | string;
  createdAt?: number | string;
}

interface PodcastEpisodeRaw {
  id?: string | number;
  episodeId?: string | number;
  title?: string;
  name?: string;
  audioUrl?: string;
  url?: string;
  enclosure?: string;
  duration?: number | string;
  durationMs?: number | string;
  publishedAt?: number | string;
  pubDate?: string | number;
  date?: string | number;
  description?: string;
  summary?: string;
  feedId?: string | number;
}

interface SourcePlatformRaw {
  id?: string;
  name?: string;
  key?: string;
  label?: string;
  enabled?: boolean;
  active?: boolean;
  level?: string;
  health?: string;
  okRatio?: number | string;
  successRate?: number | string;
  avgMs?: number | string;
  avgTime?: number | string;
  lastError?: string;
  error?: string;
  qualitys?: string | string[];
}

interface SourceScriptRaw {
  id?: string | number;
  name?: string;
  title?: string;
  author?: string;
  version?: string;
  homepage?: string;
  url?: string;
  active?: boolean;
  enabled?: boolean;
  platforms?: Object[];
  health?: Object | string;
  probe?: Object;
  lastProbe?: string;
  okRatio?: number | string;
}

interface TagRaw {
  filePath?: string;
  path?: string;
  title?: string;
  artist?: string;
  album?: string;
  albumArtist?: string;
  year?: number | string;
  track?: number | string;
  trackNumber?: number | string;
  genre?: string;
  hasPicture?: boolean;
  picture?: boolean;
  hasLyric?: boolean;
  lyric?: boolean;
  lxlyric?: string;
  format?: string;
  duration?: number | string;
}

interface TagCandidateRaw {
  source?: string;
  platform?: string;
  title?: string;
  name?: string;
  artist?: string;
  singer?: string;
  album?: string;
  albumName?: string;
  cover?: string;
  coverUrl?: string;
  picUrl?: string;
  img?: string;
  matchScore?: number | string;
  score?: number | string;
}

export class ServerSchemasAux {
  static downloadTaskFrom(obj: Object): ServerDownloadTask {
    const raw: DownloadTaskRaw = obj as DownloadTaskRaw;
    const task: ServerDownloadTask = new ServerDownloadTask();
    task.id = ServerSchemas.str(raw.id, ServerSchemas.str(raw.taskId, ''));
    task.name = ServerSchemas.str(raw.name, ServerSchemas.str(raw.title,
      ServerSchemas.str(raw.songName, '未命名任务')));
    task.singer = ServerSchemas.str(raw.singer, ServerSchemas.str(raw.artist, ''));
    task.album = ServerSchemas.str(raw.album, '');
    task.source = ServerSchemas.str(raw.source, ServerSchemas.str(raw.platform, ''));
    task.platformId = ServerSchemas.str(raw.platformId, ServerSchemas.str(raw.songId, ''));
    task.quality = ServerSchemas.str(raw.quality, '');
    task.status = normalizeDownloadStatus(ServerSchemas.str(raw.status, ServerSchemas.str(raw.state, 'waiting')));
    task.bytesTotal = raw.bytesTotal !== undefined ? ServerSchemas.num(raw.bytesTotal, 0)
      : (raw.total !== undefined ? ServerSchemas.num(raw.total, 0) : ServerSchemas.num(raw.size, 0));
    task.bytesDone = raw.bytesDone !== undefined ? ServerSchemas.num(raw.bytesDone, 0)
      : (raw.downloaded !== undefined ? ServerSchemas.num(raw.downloaded, 0) : 0);
    const progress: number = ServerSchemas.num(raw.progress, -1);
    if (progress >= 0) {
      task.progress = progress <= 1 && progress > 0 ? progress * 100 : progress;
    } else if (task.bytesTotal > 0) {
      task.progress = task.bytesDone * 100 / task.bytesTotal;
    }
    task.progress = Math.max(0, Math.min(100, task.progress));
    task.speed = ServerSchemas.num(raw.speed, ServerSchemas.num(raw.speedKbps, 0));
    task.filePath = ServerSchemas.str(raw.filePath, ServerSchemas.str(raw.path, ''));
    task.error = ServerSchemas.str(raw.error, ServerSchemas.str(raw.message, ''));
    task.createdAt = ServerSchemas.num(raw.createdAt, 0);
    task.updatedAt = ServerSchemas.num(raw.updatedAt, 0);
    return task;
  }

  static podcastFeedFrom(obj: Object): PodcastFeed {
    const raw: PodcastFeedRaw = obj as PodcastFeedRaw;
    const feed: PodcastFeed = new PodcastFeed();
    feed.id = ServerSchemas.str(raw.id, ServerSchemas.str(raw.feedId, ''));
    feed.title = ServerSchemas.str(raw.title, ServerSchemas.str(raw.name, '未命名播客'));
    feed.author = ServerSchemas.str(raw.author, '');
    feed.coverUrl = ServerSchemas.str(raw.coverUrl, ServerSchemas.str(raw.cover,
      ServerSchemas.str(raw.image, ServerSchemas.str(raw.picUrl, ''))));
    feed.description = ServerSchemas.str(raw.description, ServerSchemas.str(raw.summary, ''));
    feed.episodeCount = raw.episodeCount !== undefined ? ServerSchemas.num(raw.episodeCount, 0)
      : ServerSchemas.asArray(raw.episodes).length;
    feed.subscribedAt = ServerSchemas.num(raw.subscribedAt, ServerSchemas.num(raw.createdAt, 0));
    return feed;
  }

  static podcastEpisodeFrom(obj: Object, feedId: string): PodcastEpisode {
    const raw: PodcastEpisodeRaw = obj as PodcastEpisodeRaw;
    const episode: PodcastEpisode = new PodcastEpisode();
    episode.feedId = ServerSchemas.str(raw.feedId, feedId);
    episode.id = ServerSchemas.str(raw.id, ServerSchemas.str(raw.episodeId, ''));
    episode.title = ServerSchemas.str(raw.title, ServerSchemas.str(raw.name, '未命名单集'));
    episode.audioUrl = ServerSchemas.str(raw.audioUrl, ServerSchemas.str(raw.url,
      ServerSchemas.str(raw.enclosure, '')));
    episode.durationMs = raw.durationMs !== undefined ? ServerSchemas.num(raw.durationMs, 0)
      : ServerSchemas.secondsToMs(ServerSchemas.num(raw.duration, 0));
    episode.publishedAt = raw.publishedAt !== undefined ? ServerSchemas.expiresAtMs(raw.publishedAt)
      : ServerSchemas.expiresAtMs(raw.pubDate !== undefined ? raw.pubDate : raw.date);
    episode.description = ServerSchemas.str(raw.description, ServerSchemas.str(raw.summary, ''));
    if (episode.id.length === 0) {
      episode.id = `${feedId}_${Utils.stableId(episode.title)}`;
    }
    return episode;
  }

  static sourceScriptFrom(obj: Object): SourceScript {
    const raw: SourceScriptRaw = obj as SourceScriptRaw;
    const script: SourceScript = new SourceScript();
    script.id = ServerSchemas.str(raw.id, '');
    script.name = ServerSchemas.str(raw.name, ServerSchemas.str(raw.title, '未命名脚本'));
    script.author = ServerSchemas.str(raw.author, '');
    script.version = ServerSchemas.str(raw.version, '');
    script.homepage = ServerSchemas.str(raw.homepage, ServerSchemas.str(raw.url, ''));
    script.active = ServerSchemas.bool(raw.active, ServerSchemas.bool(raw.enabled, true));
    script.lastProbe = ServerSchemas.str(raw.lastProbe, '');
    const platforms: Object[] = ServerSchemas.asArray(raw.platforms);
    for (let i = 0; i < platforms.length; i++) {
      script.platforms.push(ServerSchemasAux.sourcePlatformFrom(platforms[i]));
    }
    const health: Object | string | undefined = raw.health;
    if (typeof health === 'string') {
      script.health = health;
    } else if (health !== undefined) {
      const healthRaw: SourcePlatformRaw = health as SourcePlatformRaw;
      script.health = ServerSchemas.str(healthRaw.level, ServerSchemas.str(healthRaw.health, ''));
    }
    if (script.health.length === 0) {
      const ratio: number = ServerSchemas.num(raw.okRatio, -1);
      if (ratio >= 0) {
        script.health = ratio >= 0.9 ? 'good' : (ratio >= 0.6 ? 'fair' : 'poor');
      } else {
        script.health = script.active ? 'unknown' : 'disabled';
      }
    }
    return script;
  }

  static sourcePlatformFrom(obj: Object): SourcePlatform {
    const raw: SourcePlatformRaw = obj as SourcePlatformRaw;
    const platform: SourcePlatform = new SourcePlatform();
    platform.id = ServerSchemas.str(raw.id, ServerSchemas.str(raw.key, ServerSchemas.str(raw.name, '')));
    platform.label = ServerSchemas.str(raw.label, platform.id);
    platform.enabled = ServerSchemas.bool(raw.enabled, ServerSchemas.bool(raw.active, true));
    platform.level = ServerSchemas.str(raw.level, ServerSchemas.str(raw.health, ''));
    platform.okRatio = ServerSchemas.num(raw.okRatio, ServerSchemas.num(raw.successRate, 0));
    platform.avgMs = ServerSchemas.num(raw.avgMs, ServerSchemas.num(raw.avgTime, 0));
    platform.lastError = ServerSchemas.str(raw.lastError, ServerSchemas.str(raw.error, ''));
    platform.qualitys = ServerSchemas.strings(raw.qualitys);
    return platform;
  }

  static tagInfoFrom(obj: Object): TagInfo {
    const raw: TagRaw = obj as TagRaw;
    const info: TagInfo = new TagInfo();
    info.filePath = ServerSchemas.str(raw.filePath, ServerSchemas.str(raw.path, ''));
    info.title = ServerSchemas.str(raw.title, '');
    info.artist = ServerSchemas.str(raw.artist, '');
    info.album = ServerSchemas.str(raw.album, '');
    info.albumArtist = ServerSchemas.str(raw.albumArtist, '');
    info.year = ServerSchemas.num(raw.year, 0);
    info.track = ServerSchemas.num(raw.track, ServerSchemas.num(raw.trackNumber, 0));
    info.genre = ServerSchemas.str(raw.genre, '');
    info.hasPicture = ServerSchemas.bool(raw.hasPicture, ServerSchemas.bool(raw.picture, false));
    info.hasLyric = ServerSchemas.bool(raw.hasLyric, ServerSchemas.bool(raw.lyric, false));
    info.lyric = ServerSchemas.str(raw.lxlyric, '');
    info.format = ServerSchemas.str(raw.format, '');
    info.durationMs = ServerSchemas.secondsToMs(ServerSchemas.num(raw.duration, 0));
    return info;
  }

  static tagCandidateFrom(obj: Object, defaultSource: string): TagCandidate {
    const raw: TagCandidateRaw = obj as TagCandidateRaw;
    const candidate: TagCandidate = new TagCandidate();
    candidate.source = ServerSchemas.str(raw.source, ServerSchemas.str(raw.platform, defaultSource));
    candidate.title = ServerSchemas.str(raw.title, ServerSchemas.str(raw.name, ''));
    candidate.artist = ServerSchemas.str(raw.artist, ServerSchemas.str(raw.singer, ''));
    candidate.album = ServerSchemas.str(raw.album, ServerSchemas.str(raw.albumName, ''));
    candidate.coverUrl = ServerSchemas.str(raw.coverUrl, ServerSchemas.str(raw.cover,
      ServerSchemas.str(raw.picUrl, ServerSchemas.str(raw.img, ''))));
    candidate.matchScore = ServerSchemas.num(raw.matchScore, ServerSchemas.num(raw.score, 0));
    candidate.rawJson = JSON.stringify(obj);
    return candidate;
  }

  static lyricTextFrom(root: Object): string {
    const source: Object = ServerSchemas.dataObject(root);
    const text: string = firstLyricField(source as EnvelopeRaw);
    if (text.length > 0) {
      return text;
    }
    return firstLyricField(root as EnvelopeRaw);
  }
}

function firstLyricField(raw: EnvelopeRaw): string {
  const candidates: string[] = [
    ServerSchemas.str(raw.lxlyric, ''),
    ServerSchemas.str(raw.lyric, ''),
    ServerSchemas.str(raw.ylyric, ''),
    ServerSchemas.str(raw.tlyric, ''),
    ServerSchemas.str(raw.rlyric, ''),
    ServerSchemas.str(raw.lyricText, '')
  ];
  for (let i = 0; i < candidates.length; i++) {
    if (candidates[i].length > 0) {
      return candidates[i];
    }
  }
  return '';
}

export function normalizeDownloadStatus(status: string): string {
  const lower: string = status.toLowerCase();
  if (lower.startsWith('await') || lower === 'waiting' || lower === 'queued' || lower === 'pending') {
    return 'waiting';
  }
  if (lower === 'downloading' || lower === 'running' || lower === 'active') {
    return 'downloading';
  }
  if (lower === 'paused' || lower === 'pause') {
    return 'paused';
  }
  if (lower === 'completed' || lower === 'done' || lower === 'finished' || lower === 'success') {
    return 'completed';
  }
  if (lower === 'failed' || lower === 'error' || lower === 'failure') {
    return 'failed';
  }
  return 'waiting';
}
