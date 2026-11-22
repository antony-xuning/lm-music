/**
 * 服务端接口层（扩展域）：发现、专辑/歌单详情、下载任务、播客、音源脚本。
 */
import { QueryPair, ServerEndpoints } from '../common/ServerEndpoints';
import { AppConstants } from '../common/Constants';
import { ListResult, ObjectResult, serverApi } from './ServerApi';

export class ServerApiCatalog {
  // ---------- 发现 ----------

  static discoverToplists(source: string): Promise<ListResult> {
    return serverApi.getList(ServerEndpoints.DISCOVER_TOPLISTS, [new QueryPair('source', source)]);
  }

  static discoverToplist(source: string, id: string, limit: number): Promise<ListResult> {
    return serverApi.getList(ServerEndpoints.DISCOVER_TOPLIST, [
      new QueryPair('source', source),
      new QueryPair('id', id),
      new QueryPair('limit', `${limit}`)
    ]);
  }

  static newSongs(source: string, limit: number): Promise<ListResult> {
    return serverApi.getList(ServerEndpoints.DISCOVER_NEW_SONGS, [
      new QueryPair('source', source),
      new QueryPair('limit', `${limit}`)
    ]);
  }

  static newAlbums(source: string, limit: number): Promise<ListResult> {
    return serverApi.getList(ServerEndpoints.DISCOVER_NEW_ALBUMS, [
      new QueryPair('source', source),
      new QueryPair('limit', `${limit}`)
    ]);
  }

  static recommendPlaylists(source: string, page: number, limit: number): Promise<ListResult> {
    return serverApi.getList(ServerEndpoints.PLAYLIST_RECOMMEND, [
      new QueryPair('source', source),
      new QueryPair('sort', 'hot'),
      new QueryPair('page', `${page}`),
      new QueryPair('limit', `${limit}`)
    ]);
  }

  static playlistDetail(source: string, id: string): Promise<ListResult> {
    return serverApi.getList(ServerEndpoints.PLAYLIST_DETAIL, [
      new QueryPair('source', source),
      new QueryPair('url', id)
    ]);
  }

  static albumDetail(source: string, id: string): Promise<ListResult> {
    return serverApi.getList(ServerEndpoints.ALBUM_DETAIL, [
      new QueryPair('source', source),
      new QueryPair('id', id)
    ]);
  }

  // ---------- 服务器下载任务 ----------

  static downloadList(): Promise<ListResult> {
    return serverApi.getList(ServerEndpoints.DOWNLOAD_LIST, []);
  }

  static downloadAdd(bodyJson: string): Promise<ObjectResult> {
    return serverApi.postObject(ServerEndpoints.DOWNLOAD_ADD, bodyJson);
  }

  static downloadAction(id: string, action: string): Promise<ObjectResult> {
    return serverApi.postObject(ServerEndpoints.downloadAction(id, action), '{}');
  }

  static downloadDismiss(id: string): Promise<ObjectResult> {
    return serverApi.postObject(ServerEndpoints.downloadDismiss(id), '{}');
  }

  static downloadClearCompleted(): Promise<ObjectResult> {
    return serverApi.postObject(ServerEndpoints.DOWNLOAD_CLEAR_COMPLETED, '{}');
  }

  // ---------- 播客 ----------

  static podcasts(): Promise<ListResult> {
    return serverApi.getList(ServerEndpoints.PODCASTS, []);
  }

  static episodes(id: string, page: number, limit: number): Promise<ListResult> {
    return serverApi.getList(ServerEndpoints.podcastEpisodes(id), [
      new QueryPair('page', `${page}`),
      new QueryPair('limit', `${limit}`)
    ]);
  }

  static subscribePodcast(bodyJson: string): Promise<ObjectResult> {
    return serverApi.postObject(ServerEndpoints.PODCASTS, bodyJson, AppConstants.RSS_TIMEOUT_MS);
  }

  static refreshPodcast(id: string): Promise<ObjectResult> {
    return serverApi.postObject(ServerEndpoints.podcastRefresh(id), '{}', AppConstants.RSS_TIMEOUT_MS);
  }

  static unsubscribePodcast(id: string): Promise<ObjectResult> {
    return serverApi.deleteObject(ServerEndpoints.podcastDelete(id));
  }

  // ---------- 音源脚本 ----------

  static sources(): Promise<ListResult> {
    return serverApi.getList(ServerEndpoints.SOURCE_LIST, []);
  }

  static activateSource(bodyJson: string): Promise<ObjectResult> {
    return serverApi.postObject(ServerEndpoints.SOURCE_ACTIVATE, bodyJson);
  }

  static deactivateSource(bodyJson: string): Promise<ObjectResult> {
    return serverApi.postObject(ServerEndpoints.SOURCE_DEACTIVATE, bodyJson);
  }

  static importSourceUrl(bodyJson: string): Promise<ObjectResult> {
    return serverApi.postObject(ServerEndpoints.SOURCE_IMPORT_URL, bodyJson, AppConstants.RSS_TIMEOUT_MS);
  }

  static importSource(bodyJson: string): Promise<ObjectResult> {
    return serverApi.postObject(ServerEndpoints.SOURCE_IMPORT, bodyJson, AppConstants.RSS_TIMEOUT_MS);
  }

  static sourcePlatform(id: string, bodyJson: string): Promise<ObjectResult> {
    return serverApi.postObject(ServerEndpoints.sourcePlatform(id), bodyJson);
  }
}
