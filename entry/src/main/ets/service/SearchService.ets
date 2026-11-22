/**
 * 本地搜索：在已同步曲库与本地曲目中过滤（忽略大小写与首尾空白）。
 */
import { Album, Playlist, Song } from '../model/MediaModels';
import { SearchResult, SearchScope } from '../model/UiModels';

export class SearchService {
  static search(keyword: string, scope: SearchScope, songs: Song[], albums: Album[],
    playlists: Playlist[]): SearchResult {
    const result: SearchResult = new SearchResult();
    result.scope = scope;
    const key: string = keyword.trim().toLowerCase();
    result.keyword = key;
    if (key.length === 0) {
      return result;
    }
    if (scope === SearchScope.SONG) {
      for (let i = 0; i < songs.length; i++) {
        const song: Song = songs[i];
        if (song.title.toLowerCase().indexOf(key) >= 0
          || song.artist.toLowerCase().indexOf(key) >= 0
          || song.album.toLowerCase().indexOf(key) >= 0) {
          result.songs.push(song);
        }
      }
    }
    if (scope === SearchScope.ALBUM) {
      for (let i = 0; i < albums.length; i++) {
        const album: Album = albums[i];
        if (album.title.toLowerCase().indexOf(key) >= 0 || album.artist.toLowerCase().indexOf(key) >= 0) {
          result.albums.push(album);
        }
      }
    }
    if (scope === SearchScope.PLAYLIST) {
      for (let i = 0; i < playlists.length; i++) {
        const playlist: Playlist = playlists[i];
        if (playlist.name.toLowerCase().indexOf(key) >= 0) {
          result.playlists.push(playlist);
        }
      }
    }
    return result;
  }

  static scopeLabel(scope: SearchScope): string {
    if (scope === SearchScope.ALBUM) {
      return '专辑';
    }
    if (scope === SearchScope.PLAYLIST) {
      return '歌单';
    }
    return '歌曲';
  }

  static scopes(): SearchScope[] {
    return [SearchScope.SONG, SearchScope.ALBUM, SearchScope.PLAYLIST];
  }
}
