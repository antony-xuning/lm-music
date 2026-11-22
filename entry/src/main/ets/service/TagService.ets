/**
 * 服务器标签服务：读取标签、在线匹配候选、应用候选、写回标签。
 * 仅对服务器本地文件开放；写操作前需二次确认。
 */
import { TagCandidate, TagInfo } from '../model/ServerModels';
import { ServerSchemas } from '../data/ServerSchemas';
import { ServerSchemasAux } from '../data/ServerSchemasAux';
import { ObjectResult, serverApi } from './ServerApi';

export class TagReadResult {
  ok: boolean = false;
  error: string = '';
  info: TagInfo = new TagInfo();
}

export class TagMatchResult {
  ok: boolean = false;
  error: string = '';
  candidates: TagCandidate[] = [];
}

export class TagOpResult {
  ok: boolean = false;
  error: string = '';
}

class TagMatchBody {
  filePath: string = '';
  path: string = '';
  fileName: string = '';
  keyword: string = '';
  title: string = '';
  artist: string = '';
  album: string = '';
  source: string = 'kw';

  constructor(info: TagInfo, source: string) {
    this.filePath = info.filePath;
    this.path = info.filePath;
    this.fileName = info.filePath.substring(info.filePath.lastIndexOf('/') + 1);
    this.keyword = `${info.artist} ${info.title}`.trim();
    this.title = info.title;
    this.artist = info.artist;
    this.album = info.album;
    this.source = source;
  }
}

class TagApplyBody {
  filePath: string = '';
  path: string = '';
  source: string = '';
  match: Object = new Object();

  constructor(info: TagInfo, candidate: TagCandidate) {
    this.filePath = info.filePath;
    this.path = info.filePath;
    this.source = candidate.source;
    this.match = JSON.parse(candidate.rawJson) as Object;
  }
}

class TagWriteBody {
  filePath: string = '';
  path: string = '';
  title: string = '';
  artist: string = '';
  album: string = '';
  albumArtist: string = '';
  year: number = 0;
  track: number = 0;
  genre: string = '';
  lyric: string = '';

  constructor(info: TagInfo) {
    this.filePath = info.filePath;
    this.path = info.filePath;
    this.title = info.title;
    this.artist = info.artist;
    this.album = info.album;
    this.albumArtist = info.albumArtist;
    this.year = info.year;
    this.track = info.track;
    this.genre = info.genre;
    this.lyric = '';
  }
}

export class TagService {
  static async read(filePath: string): Promise<TagReadResult> {
    const result: TagReadResult = new TagReadResult();
    const response: ObjectResult = await serverApi.tagRead(filePath);
    if (!response.ok || response.value === null) {
      result.error = response.message.length > 0 ? response.message : '读取标签失败';
      return result;
    }
    const info: TagInfo = ServerSchemasAux.tagInfoFrom(ServerSchemas.dataObject(response.value));
    if (info.filePath.length === 0) {
      info.filePath = filePath;
    }
    const lyricText: string = ServerSchemasAux.lyricTextFrom(response.value);
    if (lyricText.length > 0) {
      info.lyric = lyricText;
      info.hasLyric = true;
    }
    result.info = info;
    result.ok = true;
    return result;
  }

  static async match(info: TagInfo, source: string): Promise<TagMatchResult> {
    const result: TagMatchResult = new TagMatchResult();
    const response: ObjectResult = await serverApi.tagMatch(JSON.stringify(new TagMatchBody(info, source)));
    if (!response.ok || response.value === null) {
      result.error = response.message.length > 0 ? response.message : '在线匹配失败';
      return result;
    }
    const items: Object[] = ServerSchemasAuxList(response.value);
    for (let i = 0; i < items.length; i++) {
      result.candidates.push(ServerSchemasAux.tagCandidateFrom(items[i], source));
    }
    result.ok = true;
    return result;
  }

  static async applyCandidate(info: TagInfo, candidate: TagCandidate): Promise<TagReadResult> {
    const result: TagReadResult = new TagReadResult();
    const response: ObjectResult = await serverApi.tagMatchApply(JSON.stringify(new TagApplyBody(info, candidate)));
    if (!response.ok || response.value === null) {
      result.error = response.message.length > 0 ? response.message : '应用候选失败';
      return result;
    }
    const applied: TagInfo = ServerSchemasAux.tagInfoFrom(response.value);
    if (applied.filePath.length === 0) {
      applied.filePath = info.filePath;
    }
    if (applied.title.length === 0) {
      applied.title = candidate.title;
    }
    if (applied.artist.length === 0) {
      applied.artist = candidate.artist;
    }
    if (applied.album.length === 0) {
      applied.album = candidate.album;
    }
    result.info = applied;
    result.ok = true;
    return result;
  }

  static async write(info: TagInfo): Promise<TagOpResult> {
    const result: TagOpResult = new TagOpResult();
    const response: ObjectResult = await serverApi.tagWrite(JSON.stringify(new TagWriteBody(info)));
    if (!response.ok) {
      result.error = response.message.length > 0 ? response.message : '写入标签失败';
      return result;
    }
    result.ok = true;
    return result;
  }
}

/** match-apply 返回可能是数组或对象，统一成数组。 */
function ServerSchemasAuxList(root: Object): Object[] {
  if (Array.isArray(root)) {
    return root as Object[];
  }
  const env = root as MatchEnvelope;
  if (env.data !== undefined) {
    return ServerSchemasAuxList(env.data);
  }
  if (env.list !== undefined && Array.isArray(env.list)) {
    return env.list as Object[];
  }
  if (env.match !== undefined) {
    return [env.match];
  }
  const single: Object[] = [root];
  return single;
}

interface MatchEnvelope {
  data?: Object;
  list?: Object[];
  match?: Object;
}
