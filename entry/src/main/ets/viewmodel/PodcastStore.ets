/**
 * 播客 Store：服务端订阅列表、单集分页、本机播放进度与单集播放。
 */
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { JsonStore } from '../data/JsonStore';
import { EpisodeProgressRaw, PodcastsDoc } from '../data/Schemas';
import { MediaSource, PlayableItem, PlayableKind } from '../model/MediaModels';
import { PodcastEpisode, PodcastFeed } from '../model/ServerModels';
import {
  EpisodeListResult,
  FeedListResult,
  PodcastOpResult,
  PodcastService
} from '../service/PodcastService';
import { playerStore } from './PlayerStore';
import { serverStore } from './ServerStore';

const SCOPE: string = 'PodcastStore';
const PAGE_SIZE: number = 30;

interface ProgressEntry {
  episodeId: string;
  progressMs: number;
}

@ObservedV2
export class PodcastStore {
  @Trace feeds: PodcastFeed[] = [];
  @Trace loading: boolean = false;
  @Trace errorText: string = '';
  @Trace currentFeedId: string = '';
  @Trace currentEpisodes: PodcastEpisode[] = [];
  @Trace episodesLoading: boolean = false;
  @Trace episodesError: string = '';
  @Trace hasMoreEpisodes: boolean = true;
  @Trace busy: boolean = false;

  private started: boolean = false;
  private progress: Map<string, number> = new Map<string, number>();
  private pageByFeed: Map<string, number> = new Map<string, number>();

  init(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.loadProgress();
    playerStore.addProgressListener((item: PlayableItem, positionMs: number) => {
      if (item.kind === PlayableKind.EPISODE && item.episodeId.length > 0) {
        this.saveProgress(item.episodeId, positionMs);
      }
    });
  }

  get subscribedCount(): number {
    return this.feeds.length;
  }

  findFeed(id: string): PodcastFeed | null {
    for (let i = 0; i < this.feeds.length; i++) {
      if (this.feeds[i].id === id) {
        return this.feeds[i];
      }
    }
    return null;
  }

  findEpisode(id: string): PodcastEpisode | null {
    for (let i = 0; i < this.currentEpisodes.length; i++) {
      if (this.currentEpisodes[i].id === id) {
        return this.currentEpisodes[i];
      }
    }
    return null;
  }

  progressOf(episodeId: string): number {
    const value: number | undefined = this.progress.get(episodeId);
    return value !== undefined ? value : 0;
  }

  async loadFeeds(): Promise<void> {
    if (!serverStore.canRead) {
      this.errorText = '尚未连接柠檬音乐服务器';
      this.feeds = [];
      return;
    }
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.errorText = '';
    try {
      const result: FeedListResult = await PodcastService.feeds();
      if (result.ok) {
        this.feeds = result.items;
      } else {
        this.errorText = result.error.length > 0 ? result.error : '读取订阅失败';
      }
    } finally {
      this.loading = false;
    }
  }

  async loadEpisodes(feedId: string, reset: boolean): Promise<void> {
    if (this.episodesLoading) {
      return;
    }
    if (reset) {
      this.currentFeedId = feedId;
      this.currentEpisodes = [];
      this.pageByFeed.set(feedId, 0);
      this.hasMoreEpisodes = true;
    }
    if (!this.hasMoreEpisodes && !reset) {
      return;
    }
    this.episodesLoading = true;
    this.episodesError = '';
    const page: number = (this.pageByFeed.get(feedId) !== undefined ? this.pageByFeed.get(feedId) as number : 0) + 1;
    try {
      const result: EpisodeListResult = await PodcastService.episodes(feedId, page, PAGE_SIZE);
      if (!result.ok) {
        this.episodesError = result.error.length > 0 ? result.error : '读取单集失败';
        return;
      }
      const merged: PodcastEpisode[] = reset ? [] : this.currentEpisodes.slice();
      for (let i = 0; i < result.items.length; i++) {
        merged.push(result.items[i]);
      }
      this.currentEpisodes = merged;
      this.pageByFeed.set(feedId, page);
      this.hasMoreEpisodes = result.items.length >= PAGE_SIZE;
    } finally {
      this.episodesLoading = false;
    }
  }

  async subscribe(url: string): Promise<PodcastOpResult> {
    const trimmed: string = url.trim();
    if (trimmed.length === 0) {
      const result: PodcastOpResult = new PodcastOpResult();
      result.message = '请输入 RSS 地址';
      return result;
    }
    this.busy = true;
    try {
      const result: PodcastOpResult = await PodcastService.subscribe(trimmed);
      if (result.ok) {
        await this.loadFeeds();
      }
      return result;
    } finally {
      this.busy = false;
    }
  }

  async refreshFeed(feedId: string): Promise<PodcastOpResult> {
    this.busy = true;
    try {
      const result: PodcastOpResult = await PodcastService.refresh(feedId);
      if (result.ok) {
        await this.loadEpisodes(feedId, true);
        await this.loadFeeds();
      }
      return result;
    } finally {
      this.busy = false;
    }
  }

  async unsubscribe(feedId: string): Promise<PodcastOpResult> {
    this.busy = true;
    try {
      const result: PodcastOpResult = await PodcastService.unsubscribe(feedId);
      if (result.ok) {
        const kept: PodcastFeed[] = [];
        for (let i = 0; i < this.feeds.length; i++) {
          if (this.feeds[i].id !== feedId) {
            kept.push(this.feeds[i]);
          }
        }
        this.feeds = kept;
      }
      return result;
    } finally {
      this.busy = false;
    }
  }

  /** 单集播放：队列为当前节目的单集列表，从记录进度续播。 */
  playEpisode(feed: PodcastFeed, episode: PodcastEpisode): void {
    const items: PlayableItem[] = [];
    let startIndex: number = 0;
    const list: PodcastEpisode[] = this.currentFeedId === feed.id ? this.currentEpisodes : [episode];
    for (let i = 0; i < list.length; i++) {
      const item: PlayableItem = new PlayableItem();
      item.id = `ep_${list[i].id}`;
      item.kind = PlayableKind.EPISODE;
      item.episodeId = list[i].id;
      item.showId = feed.id;
      item.title = list[i].title;
      item.subtitle = feed.title;
      item.coverSeed = Math.abs(feed.title.length + i) % 12;
      item.coverUrl = feed.coverUrl;
      item.audioRef = list[i].audioUrl;
      item.durationMs = list[i].durationMs;
      item.mediaSource = MediaSource.PODCAST;
      items.push(item);
      if (list[i].id === episode.id) {
        startIndex = i;
      }
    }
    const resumeMs: number = Math.max(0, this.progressOf(episode.id) - 1000);
    playerStore.loadQueueAt(items, startIndex, resumeMs, true);
  }

  saveProgress(episodeId: string, positionMs: number): void {
    const previous: number = this.progressOf(episodeId);
    if (Math.abs(previous - positionMs) < 1500) {
      return;
    }
    this.progress.set(episodeId, positionMs);
    this.persistProgress();
  }

  private loadProgress(): void {
    const text: string | null = JsonStore.readText(AppConstants.FILE_PODCASTS);
    if (text === null || text.length === 0) {
      return;
    }
    try {
      const doc: PodcastsDoc = JSON.parse(text) as PodcastsDoc;
      const raws: EpisodeProgressRaw[] = Array.isArray(doc.progress) ? doc.progress : [];
      for (let i = 0; i < raws.length; i++) {
        const raw: EpisodeProgressRaw = raws[i];
        if (typeof raw.episodeId === 'string' && typeof raw.progressMs === 'number') {
          this.progress.set(raw.episodeId, raw.progressMs);
        }
      }
    } catch (error) {
      Logger.warn(SCOPE, 'podcast progress unreadable');
    }
  }

  private persistProgress(): void {
    const raws: EpisodeProgressRaw[] = [];
    this.progress.forEach((value: number, key: string) => {
      const raw: EpisodeProgressRaw = {
        episodeId: key,
        progressMs: value,
        updatedAt: Date.now()
      };
      raws.push(raw);
    });
    const doc: PodcastsDoc = {
      schemaVersion: AppConstants.SCHEMA_VERSION,
      subscriptions: [],
      progress: raws
    };
    JsonStore.writeText(AppConstants.FILE_PODCASTS, JSON.stringify(doc));
  }
}


export const podcastStore: PodcastStore = new PodcastStore();
