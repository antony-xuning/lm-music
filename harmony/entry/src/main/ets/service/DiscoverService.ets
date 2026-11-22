/**
 * 发现页数据服务：榜单列表/榜单曲目/新歌/新碟/推荐歌单与歌单、专辑详情解析。
 */
import { Album, MediaSource, Playlist, Song } from '../model/MediaModels';
import { DiscoverToplistItem } from '../model/UiModels';
import { PlaylistRawItem, ServerSchemas } from '../data/ServerSchemas';
import { ListResult } from './ServerApi';
import { ServerApiCatalog } from './ServerApiCatalog';

export class ToplistPayload {
  ok: boolean = false;
  error: string = '';
  items: DiscoverToplistItem[] = [];
}

export class SongPayload {
  ok: boolean = false;
  error: string = '';
  items: Song[] = [];
}

export class AlbumPayload {
  ok: boolean = false;
  error: string = '';
  items: Album[] = [];
}

export class PlaylistPayload {
  ok: boolean = false;
  error: string = '';
  items: Playlist[] = [];
}

interface CardRaw {
  id?: string | number;
  name?: string;
  title?: string;
  cover?: string;
  coverUrl?: string;
  picUrl?: string;
  img?: string;
  url?: string;
  author?: string;
  creator?: string;
  songCount?: number | string;
  count?: number | string;
  total?: number | string;
  updateTime?: string | number;
  intro?: string;
  description?: string;
}

export class DiscoverService {
  static async toplists(source: string): Promise<ToplistPayload> {
    const payload: ToplistPayload = new ToplistPayload();
    const result: ListResult = await ServerApiCatalog.discoverToplists(source);
    if (!result.ok) {
      payload.error = result.message;
      return payload;
    }
    for (let i = 0; i < result.items.length; i++) {
      payload.items.push(ServerSchemas.toplistFrom(result.items[i], source));
    }
    payload.ok = true;
    return payload;
  }

  static async toplistSongs(source: string, id: string, limit: number = 100): Promise<SongPayload> {
    const payload: SongPayload = new SongPayload();
    const result: ListResult = await ServerApiCatalog.discoverToplist(source, id, limit);
    if (!result.ok) {
      payload.error = result.message;
      return payload;
    }
    for (let i = 0; i < result.items.length; i++) {
      payload.items.push(ServerSchemas.onlineSongFrom(result.items[i], source));
    }
    payload.ok = true;
    return payload;
  }

  static async newSongs(source: string, limit: number = 20): Promise<SongPayload> {
    const payload: SongPayload = new SongPayload();
    const result: ListResult = await ServerApiCatalog.newSongs(source, limit);
    if (!result.ok) {
      payload.error = result.message;
      return payload;
    }
    for (let i = 0; i < result.items.length; i++) {
      payload.items.push(ServerSchemas.onlineSongFrom(result.items[i], source));
    }
    payload.ok = true;
    return payload;
  }

  static async newAlbums(source: string, limit: number = 12): Promise<AlbumPayload> {
    const payload: AlbumPayload = new AlbumPayload();
    const result: ListResult = await ServerApiCatalog.newAlbums(source, limit);
    if (!result.ok) {
      payload.error = result.message;
      return payload;
    }
    for (let i = 0; i < result.items.length; i++) {
      const album: Album = ServerSchemas.albumFrom(result.items[i]);
      if (album.platform.length === 0) {
        album.platform = source;
      }
      payload.items.push(album);
    }
    payload.ok = true;
    return payload;
  }

  static async recommendPlaylists(source: string, page: number = 1, limit: number = 10): Promise<PlaylistPayload> {
    const payload: PlaylistPayload = new PlaylistPayload();
    const result: ListResult = await ServerApiCatalog.recommendPlaylists(source, page, limit);
    if (!result.ok) {
      payload.error = result.message;
      return payload;
    }
    for (let i = 0; i < result.items.length; i++) {
      payload.items.push(cardPlaylist(result.items[i], source));
    }
    payload.ok = true;
    return payload;
  }

  static async playlistSongs(source: string, id: string): Promise<SongPayload> {
    const payload: SongPayload = new SongPayload();
    const result: ListResult = await ServerApiCatalog.playlistDetail(source, id);
    if (!result.ok) {
      payload.error = result.message;
      return payload;
    }
    for (let i = 0; i < result.items.length; i++) {
      payload.items.push(ServerSchemas.onlineSongFrom(result.items[i], source));
    }
    payload.ok = true;
    return payload;
  }

  static async albumSongs(source: string, id: string): Promise<SongPayload> {
    const payload: SongPayload = new SongPayload();
    const result: ListResult = await ServerApiCatalog.albumDetail(source, id);
    if (!result.ok) {
      payload.error = result.message;
      return payload;
    }
    for (let i = 0; i < result.items.length; i++) {
      payload.items.push(ServerSchemas.onlineSongFrom(result.items[i], source));
    }
    payload.ok = true;
    return payload;
  }
}

function cardPlaylist(obj: Object, source: string): Playlist {
  const raw: CardRaw = obj as CardRaw;
  const playlist: Playlist = new Playlist();
  const name: string = ServerSchemas.str(raw.name, ServerSchemas.str(raw.title, '推荐歌单'));
  playlist.name = name;
  const idText: string = ServerSchemas.str(raw.id, ServerSchemas.str(raw.url, name));
  playlist.id = idText;
  playlist.platform = source;
  playlist.coverUrl = ServerSchemas.str(raw.coverUrl, ServerSchemas.str(raw.cover,
    ServerSchemas.str(raw.picUrl, ServerSchemas.str(raw.img, ''))));
  playlist.coverSeed = Math.abs(raw.id !== undefined ? ServerSchemas.num(raw.id, name.length) : name.length) % 12;
  playlist.isCloud = true;
  playlist.editable = false;
  playlist.readOnly = true;
  playlist.songIds = [];
  const count: number = ServerSchemas.num(raw.songCount, ServerSchemas.num(raw.count, ServerSchemas.num(raw.total, 0)));
  playlist.remoteSnapshotJson = `${count}`;
  return playlist;
}

/** 供 UI 计算歌单曲目数（推荐歌单卡片使用 remoteSnapshotJson 暂存数量）。 */
export function playlistCardCount(playlist: Playlist): number {
  const parsed: number = Number.parseInt(playlist.remoteSnapshotJson, 10);
  return Number.isNaN(parsed) ? playlist.entries.length : parsed;
}

export function toSourceSongs(items: Song[], source: string): Song[] {
  for (let i = 0; i < items.length; i++) {
    if (items[i].platform.length === 0) {
      items[i].platform = source;
    }
    if (items[i].source !== MediaSource.ONLINE) {
      items[i].source = MediaSource.ONLINE;
    }
  }
  return items;
}
