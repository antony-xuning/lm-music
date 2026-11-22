/**
 * 歌词服务：服务器文件先读 /api/tag/read（内嵌或同名 .lrc），为空再请求 /api/play/lyric；
 * 在线曲目优先使用搜索结果自带的歌词，否则请求 /api/play/lyric；
 * 本地曲目无歌词时按「标题 + 歌手」在服务器曲库搜索匹配，再拉取歌词。结果做内存 LRU。
 */
import { MediaSource, PlayableItem, Song } from '../model/MediaModels';
import { ServerEndpoints } from '../common/ServerEndpoints';
import { Utils } from '../common/Utils';
import { ServerSchemas } from '../data/ServerSchemas';
import { ServerSchemasAux } from '../data/ServerSchemasAux';
import { settingsStore } from '../viewmodel/SettingsStore';
import { serverApi } from './ServerApi';
import { playUrlResolver } from './PlayUrlResolver';

const MAX_CACHE: number = 50;

class LyricService {
  private cache: Map<string, string> = new Map<string, string>();

  private keyOf(item: PlayableItem): string {
    return Utils.stableId(`${item.mediaSource}|${item.platform}|${item.filePath}|${item.platformSongId}|${item.id}`);
  }

  cached(item: PlayableItem): string | null {
    const key: string = this.keyOf(item);
    const value: string | undefined = this.cache.get(key);
    return value !== undefined ? value : null;
  }

  /** 返回歌词原文，无歌词返回空串。 */
  async lyricFor(item: PlayableItem, song: Song | null): Promise<string> {
    const key: string = this.keyOf(item);
    const cachedValue: string | undefined = this.cache.get(key);
    if (cachedValue !== undefined) {
      return cachedValue;
    }
    let text: string = item.lyricText;
    if (text.length === 0 && song !== null) {
      text = song.lyricText;
    }
    if (text.length === 0 && item.mediaSource === MediaSource.SERVER_FILE) {
      const read = await serverApi.tagRead(item.filePath);
      if (read.ok && read.value !== null) {
        text = ServerSchemasAux.lyricTextFrom(read.value);
      }
    }
    if (text.length === 0 && item.mediaSource === MediaSource.LOCAL) {
      text = await this.searchOnlineLyric(item);
    }
    if (text.length === 0 && item.mediaSource !== MediaSource.LOCAL) {
      const response = await serverApi.lyric(playUrlResolver.bodyForLyric(item, 'flac'));
      if (response.ok && response.value !== null) {
        text = ServerSchemasAux.lyricTextFrom(response.value);
      }
    }
    this.remember(key, text);
    return text;
  }

  /** 本地曲目：用标题 + 歌手在服务器搜索，匹配到在线曲目后取歌词。 */
  private async searchOnlineLyric(item: PlayableItem): Promise<string> {
    const artist: string = item.subtitle === '未知歌手' || item.subtitle === '本地导入' ? '' : item.subtitle;
    const keyword: string = `${item.title} ${artist}`.trim();
    if (keyword.length === 0) {
      return '';
    }
    try {
      const source: string = ServerEndpoints.platformCode(settingsStore.prefs.onlineSource);
      const response = await serverApi.searchSongs(keyword, source, 1, 10);
      if (!response.ok) {
        return '';
      }
      const songs: Song[] = [];
      for (let i = 0; i < response.items.length; i++) {
        songs.push(ServerSchemas.onlineSongFrom(response.items[i], source));
      }
      const match: Song | null = this.bestMatch(item, songs);
      if (match === null) {
        return '';
      }
      if (match.lyricText.length > 0) {
        return match.lyricText;
      }
      const lyricItem: PlayableItem = PlayableItem.fromSong(match);
      const lyricResponse = await serverApi.lyric(playUrlResolver.bodyForLyric(lyricItem, 'flac'));
      if (lyricResponse.ok && lyricResponse.value !== null) {
        return ServerSchemasAux.lyricTextFrom(lyricResponse.value);
      }
    } catch (error) {
      return '';
    }
    return '';
  }

  /** 标题/歌手/时长综合匹配，避免把近似结果的高亮歌词贴到本地曲目上。 */
  private bestMatch(item: PlayableItem, songs: Song[]): Song | null {
    const title: string = this.normalize(item.title);
    const artist: string = this.normalize(item.subtitle === '未知歌手' ? '' : item.subtitle);
    if (title.length === 0) {
      return null;
    }
    let best: Song | null = null;
    let bestScore: number = 0;
    for (let i = 0; i < songs.length; i++) {
      const songTitle: string = this.normalize(songs[i].title);
      const songArtist: string = this.normalize(songs[i].artist);
      let score: number = 0;
      if (songTitle === title) {
        score += 4;
      } else if (songTitle.includes(title) || title.includes(songTitle)) {
        score += 2;
      }
      if (artist.length > 0 && songArtist.length > 0) {
        if (songArtist === artist) {
          score += 3;
        } else if (songArtist.includes(artist) || artist.includes(songArtist)) {
          score += 1;
        }
      }
      if (item.durationMs > 0 && songs[i].durationMs > 0 &&
        Math.abs(item.durationMs - songs[i].durationMs) <= 5000) {
        score += 1;
      }
      if (score > bestScore) {
        bestScore = score;
        best = songs[i];
      }
    }
    return bestScore >= 4 ? best : null;
  }

  /** 只保留汉字、字母、数字，忽略空格与标点差异。 */
  private normalize(text: string): string {
    const lower: string = text.toLowerCase();
    let out: string = '';
    for (let i = 0; i < lower.length; i++) {
      const ch: string = lower.charAt(i);
      if ((ch >= 'a' && ch <= 'z') || (ch >= '0' && ch <= '9') || (ch >= '\u4e00' && ch <= '\u9fff')) {
        out += ch;
      }
    }
    return out;
  }

  private remember(key: string, text: string): void {
    if (this.cache.size >= MAX_CACHE) {
      let first: string = '';
      this.cache.forEach((value: string, mapKey: string) => {
        if (first.length === 0) {
          first = mapKey;
        }
      });
      if (first.length > 0) {
        this.cache.delete(first);
      }
    }
    this.cache.set(key, text);
  }

  clear(): void {
    this.cache.clear();
  }
}

export const lyricService: LyricService = new LyricService();
