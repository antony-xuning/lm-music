/**
 * 播客服务：订阅列表、单集分页、新增订阅、刷新与取消订阅。
 */
import { PodcastEpisode, PodcastFeed } from '../model/ServerModels';
import { ServerSchemasAux } from '../data/ServerSchemasAux';
import { ListResult, ObjectResult } from './ServerApi';
import { ServerApiCatalog } from './ServerApiCatalog';

export class FeedListResult {
  ok: boolean = false;
  error: string = '';
  items: PodcastFeed[] = [];
}

export class EpisodeListResult {
  ok: boolean = false;
  error: string = '';
  items: PodcastEpisode[] = [];
}

export class PodcastOpResult {
  ok: boolean = false;
  message: string = '';
  unsupported: boolean = false;
}

class SubscribeBody {
  url: string = '';

  constructor(url: string) {
    this.url = url;
  }
}

export class PodcastService {
  static async feeds(): Promise<FeedListResult> {
    const result: FeedListResult = new FeedListResult();
    const response: ListResult = await ServerApiCatalog.podcasts();
    if (!response.ok) {
      result.error = response.message;
      return result;
    }
    for (let i = 0; i < response.items.length; i++) {
      const feed: PodcastFeed = ServerSchemasAux.podcastFeedFrom(response.items[i]);
      if (feed.id.length === 0) {
        feed.id = `feed_${i}`;
      }
      result.items.push(feed);
    }
    result.ok = true;
    return result;
  }

  static async episodes(feedId: string, page: number, limit: number): Promise<EpisodeListResult> {
    const result: EpisodeListResult = new EpisodeListResult();
    const response: ListResult = await ServerApiCatalog.episodes(feedId, page, limit);
    if (!response.ok) {
      result.error = response.message;
      return result;
    }
    for (let i = 0; i < response.items.length; i++) {
      result.items.push(ServerSchemasAux.podcastEpisodeFrom(response.items[i], feedId));
    }
    result.ok = true;
    return result;
  }

  static async subscribe(url: string): Promise<PodcastOpResult> {
    const response: ObjectResult = await ServerApiCatalog.subscribePodcast(JSON.stringify(new SubscribeBody(url)));
    return toOpResult(response, '订阅成功');
  }

  static async refresh(feedId: string): Promise<PodcastOpResult> {
    const response: ObjectResult = await ServerApiCatalog.refreshPodcast(feedId);
    return toOpResult(response, '已刷新节目');
  }

  static async unsubscribe(feedId: string): Promise<PodcastOpResult> {
    const response: ObjectResult = await ServerApiCatalog.unsubscribePodcast(feedId);
    return toOpResult(response, '已取消订阅');
  }
}

function toOpResult(response: ObjectResult, successMessage: string): PodcastOpResult {
  const result: PodcastOpResult = new PodcastOpResult();
  if (response.ok) {
    result.ok = true;
    result.message = successMessage;
    return result;
  }
  result.unsupported = response.status === 404 || response.status === 405;
  result.message = result.unsupported ? '服务器不支持该操作' : response.message;
  return result;
}
