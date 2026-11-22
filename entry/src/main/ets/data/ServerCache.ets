/**
 * 按服务器命名空间隔离的曲库快照缓存。
 * 写入使用「临时文件 → 重命名」的原子替换；解析失败时回退为空快照，不破坏旧数据。
 */
import { JsonStore } from './JsonStore';
import { Album, Artist, Playlist, Song } from '../model/MediaModels';
import { Logger } from '../common/Logger';
import { AppConstants } from '../common/Constants';
import { PlaylistRaw, SchemaCodec, SongRaw } from './Schemas';

const SCOPE: string = 'ServerCache';

interface AlbumStore {
  id?: string;
  title?: string;
  artist?: string;
  artistId?: string;
  coverSeed?: number;
  coverUrl?: string;
  coverPath?: string;
  year?: number;
  count?: number;
  platform?: string;
}

interface ArtistStore {
  id?: string;
  name?: string;
  coverSeed?: number;
  coverUrl?: string;
  coverPath?: string;
  songCount?: number;
  albumCount?: number;
}

interface SnapshotDoc {
  schemaVersion?: number;
  serverId?: string;
  syncedAt?: number;
  revision?: string;
  tracks?: SongRaw[];
  albums?: AlbumStore[];
  artists?: ArtistStore[];
  playlists?: PlaylistRaw[];
  favoritesJson?: string;
  playlistsJson?: string;
  recentJson?: string;
}

export class ServerSnapshot {
  serverId: string = '';
  syncedAt: number = 0;
  revision: string = '';
  songs: Song[] = [];
  albums: Album[] = [];
  artists: Artist[] = [];
  playlists: Playlist[] = [];
  favoritesJson: string = '';
  playlistsJson: string = '';
  recentJson: string = '';
}

function safeId(serverId: string): string {
  const digits: string = serverId.replace(/[^a-zA-Z0-9_-]/g, '_');
  return digits.length > 0 ? digits : 'default';
}

export class ServerCache {
  static fileName(serverId: string): string {
    return `${AppConstants.FILE_SERVER_PREFIX}${safeId(serverId)}.json`;
  }

  static read(serverId: string): ServerSnapshot | null {
    const text: string | null = JsonStore.readText(ServerCache.fileName(serverId));
    if (text === null || text.length === 0) {
      return null;
    }
    try {
      const doc: SnapshotDoc = JSON.parse(text) as SnapshotDoc;
      const snapshot: ServerSnapshot = new ServerSnapshot();
      snapshot.serverId = typeof doc.serverId === 'string' ? doc.serverId : serverId;
      snapshot.syncedAt = typeof doc.syncedAt === 'number' ? doc.syncedAt : 0;
      snapshot.revision = typeof doc.revision === 'string' ? doc.revision : '';
      const tracks: SongRaw[] = Array.isArray(doc.tracks) ? doc.tracks : [];
      const songs: Song[] = [];
      for (let i = 0; i < tracks.length; i++) {
        const song: Song = SchemaCodec.fromSongRaw(tracks[i]);
        if (song.id.length > 0) {
          songs.push(song);
        }
      }
      snapshot.songs = songs;
      const albums: AlbumStore[] = Array.isArray(doc.albums) ? doc.albums : [];
      const albumList: Album[] = [];
      for (let i = 0; i < albums.length; i++) {
        const raw: AlbumStore = albums[i];
        const album: Album = new Album();
        album.id = typeof raw.id === 'string' ? raw.id : '';
        album.title = typeof raw.title === 'string' ? raw.title : '未知专辑';
        album.artist = typeof raw.artist === 'string' ? raw.artist : '';
        album.artistId = typeof raw.artistId === 'string' ? raw.artistId : '';
        album.coverSeed = typeof raw.coverSeed === 'number' ? raw.coverSeed : 0;
        album.coverUrl = typeof raw.coverUrl === 'string' ? raw.coverUrl : '';
        album.coverPath = typeof raw.coverPath === 'string' ? raw.coverPath : '';
        album.year = typeof raw.year === 'number' ? raw.year : 0;
        album.count = typeof raw.count === 'number' ? raw.count : 0;
        album.platform = typeof raw.platform === 'string' ? raw.platform : '';
        albumList.push(album);
      }
      snapshot.albums = albumList;
      const artists: ArtistStore[] = Array.isArray(doc.artists) ? doc.artists : [];
      const artistList: Artist[] = [];
      for (let i = 0; i < artists.length; i++) {
        const raw: ArtistStore = artists[i];
        const artist: Artist = new Artist();
        artist.id = typeof raw.id === 'string' ? raw.id : '';
        artist.name = typeof raw.name === 'string' ? raw.name : '未知歌手';
        artist.coverSeed = typeof raw.coverSeed === 'number' ? raw.coverSeed : 0;
        artist.coverUrl = typeof raw.coverUrl === 'string' ? raw.coverUrl : '';
        artist.coverPath = typeof raw.coverPath === 'string' ? raw.coverPath : '';
        artist.songCount = typeof raw.songCount === 'number' ? raw.songCount : 0;
        artist.albumCount = typeof raw.albumCount === 'number' ? raw.albumCount : 0;
        artistList.push(artist);
      }
      snapshot.artists = artistList;
      const playlists: PlaylistRaw[] = Array.isArray(doc.playlists) ? doc.playlists : [];
      const playlistList: Playlist[] = [];
      for (let i = 0; i < playlists.length; i++) {
        playlistList.push(SchemaCodec.fromPlaylistRaw(playlists[i]));
      }
      snapshot.playlists = playlistList;
      snapshot.favoritesJson = typeof doc.favoritesJson === 'string' ? doc.favoritesJson : '';
      snapshot.playlistsJson = typeof doc.playlistsJson === 'string' ? doc.playlistsJson : '';
      snapshot.recentJson = typeof doc.recentJson === 'string' ? doc.recentJson : '';
      return snapshot;
    } catch (error) {
      Logger.warn(SCOPE, `snapshot corrupted: ${ServerCache.fileName(serverId)}`);
      return null;
    }
  }

  static write(snapshot: ServerSnapshot): void {
    const tracks: SongRaw[] = [];
    for (let i = 0; i < snapshot.songs.length; i++) {
      tracks.push(SchemaCodec.toSongRaw(snapshot.songs[i]));
    }
    const albums: AlbumStore[] = [];
    for (let i = 0; i < snapshot.albums.length; i++) {
      const album: Album = snapshot.albums[i];
      const raw: AlbumStore = {
        id: album.id,
        title: album.title,
        artist: album.artist,
        artistId: album.artistId,
        coverSeed: album.coverSeed,
        coverUrl: album.coverUrl,
        coverPath: album.coverPath,
        year: album.year,
        count: album.count,
        platform: album.platform
      };
      albums.push(raw);
    }
    const artists: ArtistStore[] = [];
    for (let i = 0; i < snapshot.artists.length; i++) {
      const artist: Artist = snapshot.artists[i];
      const raw: ArtistStore = {
        id: artist.id,
        name: artist.name,
        coverSeed: artist.coverSeed,
        coverUrl: artist.coverUrl,
        coverPath: artist.coverPath,
        songCount: artist.songCount,
        albumCount: artist.albumCount
      };
      artists.push(raw);
    }
    const playlists: PlaylistRaw[] = [];
    for (let i = 0; i < snapshot.playlists.length; i++) {
      playlists.push(SchemaCodec.toPlaylistRaw(snapshot.playlists[i]));
    }
    const doc: SnapshotDoc = {
      schemaVersion: AppConstants.SCHEMA_VERSION,
      serverId: snapshot.serverId,
      syncedAt: snapshot.syncedAt,
      revision: snapshot.revision,
      tracks: tracks,
      albums: albums,
      artists: artists,
      playlists: playlists,
      favoritesJson: snapshot.favoritesJson,
      playlistsJson: snapshot.playlistsJson,
      recentJson: snapshot.recentJson
    };
    JsonStore.writeText(ServerCache.fileName(snapshot.serverId), JSON.stringify(doc));
  }

  static remove(serverId: string): void {
    JsonStore.remove(ServerCache.fileName(serverId));
  }
}
