/**
 * 服务端接口层（核心域）：健康检查、登录、会话校验、曲库、用户数据写回、播放地址、标签与歌词。
 * 统一注入 Bearer Token；401 时若仍持有内存密码则自动重登一次并重放请求。
 */
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { QueryPair, ServerEndpoints } from '../common/ServerEndpoints';
import { EnvelopeRaw, ServerSchemas } from '../data/ServerSchemas';
import { ApiErrorCode, ServerSession } from '../model/ServerModels';
import { HttpTextResult, HttpClient } from './HttpClient';
import { serverContext } from './ServerContext';

const SCOPE: string = 'ServerApi';

export class TextResult {
  ok: boolean = false;
  status: number = 0;
  text: string = '';
  code: string = ApiErrorCode.UNKNOWN;
  message: string = '';
}

export class ObjectResult {
  ok: boolean = false;
  status: number = 0;
  value: Object | null = null;
  code: string = ApiErrorCode.UNKNOWN;
  message: string = '';
}

export class ListResult {
  ok: boolean = false;
  status: number = 0;
  items: Object[] = [];
  total: number = 0;
  code: string = ApiErrorCode.UNKNOWN;
  message: string = '';
}

export class SessionResult {
  ok: boolean = false;
  session: ServerSession = new ServerSession();
  code: string = ApiErrorCode.UNKNOWN;
  message: string = '';
}

/** 401 会话失效回调（由 ServerManager/ServerStore 注册，全局只提示一次）。 */
type AuthExpiredListener = () => void;

class LoginBody {
  username: string = '';
  password: string = '';
  remember: boolean = false;

  constructor(username: string, password: string, remember: boolean) {
    this.username = username;
    this.password = password;
    this.remember = remember;
  }
}

class TagReadBody {
  filePath: string = '';
  path: string = '';

  constructor(filePath: string) {
    this.filePath = filePath;
    this.path = filePath;
  }
}

class ServerApiImpl {
  private authExpiredListener: AuthExpiredListener | null = null;
  private reloginInFlight: boolean = false;

  setAuthExpiredListener(listener: AuthExpiredListener | null): void {
    this.authExpiredListener = listener;
  }

  private absolute(path: string, pairs: QueryPair[]): string {
    return `${ServerEndpoints.join(serverContext.baseUrl, path)}${ServerEndpoints.buildQuery(pairs)}`;
  }

  /** 底层发送；处理 401 单次重登。 */
  private async send(method: string, path: string, pairs: QueryPair[], body: string, timeoutMs: number,
    auth: boolean, allowRelogin: boolean): Promise<HttpTextResult> {
    const headers: Record<string, string> = auth ? serverContext.authHeaders() : { 'Accept': 'application/json' };
    const url: string = this.absolute(path, pairs);
    const first: HttpTextResult = await HttpClient.requestText(method, url, headers, body, timeoutMs);
    if (first.ok || first.status !== 401 || !allowRelogin) {
      return first;
    }
    if (serverContext.password.length === 0) {
      this.notifyExpired();
      return first;
    }
    const relogged: boolean = await this.relogin();
    if (!relogged) {
      this.notifyExpired();
      return first;
    }
    const retryHeaders: Record<string, string> = auth ? serverContext.authHeaders() : { 'Accept': 'application/json' };
    const second: HttpTextResult = await HttpClient.requestText(method, url, retryHeaders, body, timeoutMs);
    if (second.status === 401) {
      this.notifyExpired();
    }
    return second;
  }

  private notifyExpired(): void {
    if (this.authExpiredListener !== null) {
      this.authExpiredListener();
    }
  }

  private async relogin(): Promise<boolean> {
    if (this.reloginInFlight) {
      return false;
    }
    this.reloginInFlight = true;
    try {
      const result: SessionResult = await this.login(serverContext.username, serverContext.password, true);
      return result.ok && result.session.token.length > 0;
    } finally {
      this.reloginInFlight = false;
    }
  }

  private toTextResult(raw: HttpTextResult): TextResult {
    const result: TextResult = new TextResult();
    result.ok = raw.ok;
    result.status = raw.status;
    result.text = raw.text;
    result.code = raw.error.code;
    result.message = raw.error.message;
    if (raw.ok && !looksLikeJson(raw.text)) {
      result.ok = false;
      result.code = ApiErrorCode.BAD_RESPONSE;
      result.message = '返回内容不是柠檬音乐服务，请检查地址';
    }
    return result;
  }

  private toObjectResult(raw: HttpTextResult): ObjectResult {
    const result: ObjectResult = new ObjectResult();
    result.status = raw.status;
    if (!raw.ok) {
      result.code = raw.error.code;
      result.message = raw.error.message;
      return result;
    }
    const parsed: Object | null = HttpClient.parseJson(raw.text);
    if (parsed === null) {
      result.code = ApiErrorCode.BAD_RESPONSE;
      result.message = '返回内容不是柠檬音乐服务，请检查地址';
      return result;
    }
    result.ok = true;
    result.value = parsed;
    return result;
  }

  private toListResult(raw: HttpTextResult): ListResult {
    const result: ListResult = new ListResult();
    result.status = raw.status;
    if (!raw.ok) {
      result.code = raw.error.code;
      result.message = raw.error.message;
      return result;
    }
    const parsed: Object | null = HttpClient.parseJson(raw.text);
    if (parsed === null) {
      result.code = ApiErrorCode.BAD_RESPONSE;
      result.message = '返回内容不是柠檬音乐服务，请检查地址';
      return result;
    }
    result.ok = true;
    result.items = ServerSchemas.listOf(parsed);
    const env: EnvelopeRaw = parsed as EnvelopeRaw;
    result.total = ServerSchemas.num(env.total, 0);
    if (result.total <= 0) {
      const data: Object | undefined = env.data;
      if (data !== undefined && !Array.isArray(data)) {
        const nested: EnvelopeRaw = data as EnvelopeRaw;
        result.total = ServerSchemas.num(nested.total, 0);
      }
    }
    return result;
  }

  // ---------- 基础请求 ----------

  async getText(path: string, pairs: QueryPair[], timeoutMs: number = AppConstants.READ_TIMEOUT_MS,
    auth: boolean = true): Promise<TextResult> {
    const raw: HttpTextResult = await this.send('GET', path, pairs, '', timeoutMs, auth, auth);
    return this.toTextResult(raw);
  }

  async getObject(path: string, pairs: QueryPair[]): Promise<ObjectResult> {
    const raw: HttpTextResult = await this.send('GET', path, pairs, '', AppConstants.READ_TIMEOUT_MS, true, true);
    return this.toObjectResult(raw);
  }

  async getList(path: string, pairs: QueryPair[]): Promise<ListResult> {
    const raw: HttpTextResult = await this.send('GET', path, pairs, '', AppConstants.READ_TIMEOUT_MS, true, true);
    return this.toListResult(raw);
  }

  async postObject(path: string, bodyJson: string, timeoutMs: number = AppConstants.READ_TIMEOUT_MS,
    auth: boolean = true): Promise<ObjectResult> {
    const raw: HttpTextResult = await this.send('POST', path, [], bodyJson, timeoutMs, auth, auth);
    return this.toObjectResult(raw);
  }

  async putObject(path: string, bodyJson: string): Promise<ObjectResult> {
    const raw: HttpTextResult = await this.send('PUT', path, [], bodyJson, AppConstants.READ_TIMEOUT_MS, true, true);
    return this.toObjectResult(raw);
  }

  async deleteObject(path: string): Promise<ObjectResult> {
    const raw: HttpTextResult = await this.send('DELETE', path, [], '', AppConstants.READ_TIMEOUT_MS, true, true);
    return this.toObjectResult(raw);
  }

  // ---------- 鉴权 ----------

  async health(): Promise<ObjectResult> {
    return this.getObject(ServerEndpoints.HEALTH, []);
  }

  async login(username: string, password: string, remember: boolean): Promise<SessionResult> {
    const result: SessionResult = new SessionResult();
    const body: string = JSON.stringify(new LoginBody(username, password, remember));
    const raw: HttpTextResult = await this.send('POST', ServerEndpoints.LOGIN, [], body,
      AppConstants.LOGIN_TIMEOUT_MS, false, false);
    if (!raw.ok) {
      result.code = raw.error.code;
      result.message = raw.error.message;
      Logger.warn(SCOPE, `login failed status=${raw.status}`);
      return result;
    }
    const parsed: Object | null = HttpClient.parseJson(raw.text);
    if (parsed === null) {
      result.code = ApiErrorCode.BAD_RESPONSE;
      result.message = '返回内容不是柠檬音乐服务，请检查地址';
      return result;
    }
    const session: ServerSession = ServerSchemas.parseSession(parsed);
    if (session.token.length === 0) {
      result.code = ApiErrorCode.BAD_RESPONSE;
      result.message = '登录响应缺少 Token，可能不是柠檬音乐服务';
      return result;
    }
    if (session.username.length === 0) {
      session.username = username;
    }
    result.ok = true;
    result.session = session;
    return result;
  }

  async me(): Promise<SessionResult> {
    const result: SessionResult = new SessionResult();
    const raw: HttpTextResult = await this.send('GET', ServerEndpoints.ME, [], '',
      AppConstants.CONNECT_TIMEOUT_MS, true, true);
    if (!raw.ok) {
      result.code = raw.error.code;
      result.message = raw.error.message;
      return result;
    }
    const parsed: Object | null = HttpClient.parseJson(raw.text);
    if (parsed === null) {
      result.code = ApiErrorCode.BAD_RESPONSE;
      result.message = '返回内容不是柠檬音乐服务';
      return result;
    }
    const session: ServerSession = ServerSchemas.parseSession(parsed);
    if (session.token.length === 0) {
      session.token = serverContext.token;
    }
    if (session.expiresAt <= 0) {
      session.expiresAt = serverContext.expiresAt;
    }
    result.ok = true;
    result.session = session;
    return result;
  }

  // ---------- 曲库 ----------

  async tracks(page: number, limit: number): Promise<ListResult> {
    return this.getList(ServerEndpoints.TRACKS, [
      new QueryPair('page', `${page}`),
      new QueryPair('limit', `${limit}`)
    ]);
  }

  async albums(page: number, limit: number): Promise<ListResult> {
    return this.getList(ServerEndpoints.ALBUMS, [
      new QueryPair('page', `${page}`),
      new QueryPair('limit', `${limit}`)
    ]);
  }

  async artists(page: number, limit: number): Promise<ListResult> {
    return this.getList(ServerEndpoints.ARTISTS, [
      new QueryPair('page', `${page}`),
      new QueryPair('limit', `${limit}`)
    ]);
  }

  async userDataText(): Promise<TextResult> {
    return this.getText(ServerEndpoints.USER_DATA, []);
  }

  async playlistsText(): Promise<TextResult> {
    return this.getText(ServerEndpoints.PLAYLISTS, []);
  }

  /** 整表写回收藏：bodyJson 形如 {"favorites":[...]}。 */
  async saveUserData(bodyJson: string): Promise<ObjectResult> {
    return this.putObject(ServerEndpoints.USER_DATA, bodyJson);
  }

  /** 整表写回歌单：bodyJson 形如 {"playlists":[...]}。 */
  async savePlaylists(bodyJson: string): Promise<ObjectResult> {
    return this.putObject(ServerEndpoints.PLAYLISTS, bodyJson);
  }

  // ---------- 播放 / 标签 / 歌词 ----------

  async playUrl(bodyJson: string): Promise<ObjectResult> {
    return this.postObject(ServerEndpoints.PLAY_URL, bodyJson);
  }

  playLocalUrl(path: string): string {
    return this.absolute(ServerEndpoints.PLAY_LOCAL, [new QueryPair('path', path)]);
  }

  async tagRead(filePath: string): Promise<ObjectResult> {
    const body: string = JSON.stringify(new TagReadBody(filePath));
    return this.postObject(ServerEndpoints.TAG_READ, body);
  }

  async tagMatch(bodyJson: string): Promise<ObjectResult> {
    return this.postObject(ServerEndpoints.TAG_MATCH, bodyJson);
  }

  async tagMatchApply(bodyJson: string): Promise<ObjectResult> {
    return this.postObject(ServerEndpoints.TAG_MATCH_APPLY, bodyJson);
  }

  async tagWrite(bodyJson: string): Promise<ObjectResult> {
    return this.postObject(ServerEndpoints.TAG_WRITE, bodyJson);
  }

  async lyric(bodyJson: string): Promise<ObjectResult> {
    return this.postObject(ServerEndpoints.PLAY_LYRIC, bodyJson);
  }

  async searchSongs(keyword: string, source: string, page: number, limit: number): Promise<ListResult> {
    return this.getList(ServerEndpoints.SEARCH, [
      new QueryPair('keyword', keyword),
      new QueryPair('source', source),
      new QueryPair('page', `${page}`),
      new QueryPair('limit', `${limit}`)
    ]);
  }

  async searchAlbums(keyword: string, source: string, page: number, limit: number): Promise<ListResult> {
    return this.getList(ServerEndpoints.SEARCH_ALBUM, [
      new QueryPair('keyword', keyword),
      new QueryPair('source', source),
      new QueryPair('page', `${page}`),
      new QueryPair('limit', `${limit}`)
    ]);
  }

  async searchPlaylists(keyword: string, source: string, page: number, limit: number): Promise<ListResult> {
    return this.getList(ServerEndpoints.SEARCH_PLAYLIST, [
      new QueryPair('keyword', keyword),
      new QueryPair('source', source),
      new QueryPair('page', `${page}`),
      new QueryPair('limit', `${limit}`)
    ]);
  }
}

function looksLikeJson(text: string): boolean {
  const trimmed: string = text.trim();
  if (trimmed.length === 0) {
    return false;
  }
  const first: string = trimmed.substring(0, 1);
  return first === '{' || first === '[';
}

export const serverApi: ServerApiImpl = new ServerApiImpl();
