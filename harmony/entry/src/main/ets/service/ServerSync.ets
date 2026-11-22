/**
 * 曲库同步：分页拉取曲目 / 专辑 / 歌手，再拉取用户数据与歌单。
 * 任一页失败即整体失败并保留旧快照；全部成功才一次性写入本地缓存。
 */
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { ServerCache, ServerSnapshot } from '../data/ServerCache';
import { ListResult, TextResult, serverApi } from './ServerApi';
import { ServerSchemas, UserDataParsed } from '../data/ServerSchemas';
import { Playlist, Song } from '../model/MediaModels';
import { SyncPhase } from '../model/ServerModels';

const SCOPE: string = 'ServerSync';

type PhaseListener = (phase: SyncPhase, fetched: number, total: number) => void;

export class SyncOutcome {
  ok: boolean = false;
  error: string = '';
  snapshot: ServerSnapshot | null = null;
}

class PageOutcome {
  ok: boolean = false;
  items: Object[] = [];
  error: string = '';
  total: number = 0;
}

class ServerSyncImpl {
  private running: boolean = false;

  get busy(): boolean {
    return this.running;
  }

  async run(serverId: string, listener: PhaseListener): Promise<SyncOutcome> {
    const outcome: SyncOutcome = new SyncOutcome();
    if (this.running) {
      outcome.error = '正在同步中';
      return outcome;
    }
    this.running = true;
    try {
      listener(SyncPhase.TRACKS, 0, 0);
      const trackPage: PageOutcome = await this.collectTracks(listener);
      if (!trackPage.ok) {
        outcome.error = trackPage.error;
        return outcome;
      }
      const songs: Song[] = [];
      for (let i = 0; i < trackPage.items.length; i++) {
        songs.push(ServerSchemas.trackFrom(trackPage.items[i], serverId));
      }

      listener(SyncPhase.ALBUMS, 0, 0);
      const albumPage: PageOutcome = await this.collectMeta('/albums', listener);
      if (!albumPage.ok) {
        outcome.error = albumPage.error;
        return outcome;
      }
      listener(SyncPhase.ARTISTS, 0, 0);
      const artistPage: PageOutcome = await this.collectMeta('/artists', listener);
      if (!artistPage.ok) {
        outcome.error = artistPage.error;
        return outcome;
      }

      listener(SyncPhase.USERDATA, 0, 0);
      const userText: TextResult = await serverApi.userDataText();
      if (!userText.ok) {
        outcome.error = userText.message.length > 0 ? userText.message : '读取用户数据失败';
        return outcome;
      }
      const userParsed: UserDataParsed = ServerSchemas.parseUserData(ServerSchemas.parseRoot(userText.text));

      listener(SyncPhase.PLAYLISTS, 0, 0);
      let playlistRaws: Object[] = userParsed.playlists;
      if (playlistRaws.length === 0) {
        const fallback: TextResult = await serverApi.playlistsText();
        if (fallback.ok) {
          playlistRaws = ServerSchemas.listOf(ServerSchemas.parseRoot(fallback.text));
        }
      }
      const playlists: Playlist[] = [];
      for (let i = 0; i < playlistRaws.length; i++) {
        playlists.push(ServerSchemas.playlistFrom(playlistRaws[i], serverId));
      }

      listener(SyncPhase.WRITING, songs.length, songs.length);
      const snapshot: ServerSnapshot = new ServerSnapshot();
      snapshot.serverId = serverId;
      snapshot.syncedAt = Date.now();
      snapshot.revision = userParsed.revision;
      snapshot.songs = songs;
      snapshot.albums = [];
      snapshot.artists = [];
      snapshot.playlists = playlists;
      snapshot.favoritesJson = JSON.stringify(userParsed.favorites);
      snapshot.playlistsJson = '';
      snapshot.recentJson = JSON.stringify(userParsed.recentPlays);
      for (let i = 0; i < albumPage.items.length; i++) {
        snapshot.albums.push(ServerSchemas.albumFrom(albumPage.items[i]));
      }
      for (let i = 0; i < artistPage.items.length; i++) {
        snapshot.artists.push(ServerSchemas.artistFrom(artistPage.items[i]));
      }
      ServerCache.write(snapshot);
      outcome.ok = true;
      outcome.snapshot = snapshot;
      listener(SyncPhase.DONE, songs.length, songs.length);
      Logger.info(SCOPE, `sync done: ${songs.length} tracks, ${playlists.length} playlists`);
      return outcome;
    } finally {
      this.running = false;
    }
  }

  private async collectTracks(listener: PhaseListener): Promise<PageOutcome> {
    const result: PageOutcome = new PageOutcome();
    const seen: Set<string> = new Set<string>();
    let page: number = 1;
    let fetched: number = 0;
    let total: number = 0;
    while (page <= AppConstants.SYNC_MAX_PAGES) {
      const response: ListResult = await serverApi.tracks(page, AppConstants.SYNC_PAGE_SIZE);
      if (!response.ok) {
        result.error = response.message.length > 0 ? response.message : '曲库同步失败';
        return result;
      }
      if (response.total > 0) {
        total = response.total;
      }
      let added: number = 0;
      for (let i = 0; i < response.items.length; i++) {
        const song: Song = ServerSchemas.trackFrom(response.items[i], '');
        const key: string = song.filePath.length > 0 ? song.filePath : song.id;
        if (!seen.has(key)) {
          seen.add(key);
          result.items.push(response.items[i]);
          added++;
        }
      }
      fetched += added;
      listener(SyncPhase.TRACKS, fetched, total);
      if (response.items.length < AppConstants.SYNC_PAGE_SIZE || added === 0) {
        break;
      }
      if (total > 0 && fetched >= total) {
        break;
      }
      page++;
    }
    result.ok = true;
    result.total = total;
    return result;
  }

  private async collectMeta(kind: string, listener: PhaseListener): Promise<PageOutcome> {
    const result: PageOutcome = new PageOutcome();
    let page: number = 1;
    let fetched: number = 0;
    while (page <= AppConstants.SYNC_MAX_PAGES) {
      const response: ListResult = kind === '/albums'
        ? await serverApi.albums(page, AppConstants.SYNC_META_PAGE_SIZE)
        : await serverApi.artists(page, AppConstants.SYNC_META_PAGE_SIZE);
      if (!response.ok) {
        result.error = response.message.length > 0 ? response.message : '曲库同步失败';
        return result;
      }
      for (let i = 0; i < response.items.length; i++) {
        result.items.push(response.items[i]);
      }
      fetched += response.items.length;
      listener(kind === '/albums' ? SyncPhase.ALBUMS : SyncPhase.ARTISTS, fetched, response.total);
      if (response.items.length < AppConstants.SYNC_META_PAGE_SIZE || response.items.length === 0) {
        break;
      }
      if (response.total > 0 && fetched >= response.total) {
        break;
      }
      page++;
    }
    result.ok = true;
    return result;
  }
}

export const serverSync: ServerSyncImpl = new ServerSyncImpl();
