/**
 * 当前激活服务器的运行时上下文：基础地址、Token、过期时间与内存密码。
 * 密码只存在于内存，进程结束后丢失；Token 由 SettingsStore 持久化。
 */
import { ServerConfig } from '../model/SettingsModels';
import { ServerEndpoints } from '../common/ServerEndpoints';

class ServerContextHolder {
  baseUrl: string = '';
  serverId: string = '';
  username: string = '';
  token: string = '';
  expiresAt: number = 0;
  password: string = '';
  displayName: string = '';

  load(config: ServerConfig): void {
    this.baseUrl = ServerEndpoints.normalizeBase(config.url);
    this.serverId = config.id;
    this.username = config.username;
    this.token = config.token;
    this.expiresAt = config.tokenExpiresAt;
    this.displayName = config.displayName;
  }

  clear(): void {
    this.baseUrl = '';
    this.serverId = '';
    this.username = '';
    this.token = '';
    this.expiresAt = 0;
    this.password = '';
    this.displayName = '';
  }

  get configured(): boolean {
    return this.baseUrl.length > 0;
  }

  get hasToken(): boolean {
    return this.token.length > 0;
  }

  setSession(token: string, expiresAt: number, password: string): void {
    this.token = token;
    this.expiresAt = expiresAt;
    if (password.length > 0) {
      this.password = password;
    }
  }

  clearSession(): void {
    this.token = '';
    this.expiresAt = 0;
    this.password = '';
  }

  /** 携带鉴权的请求头。Token 不写日志。 */
  authHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    headers['Accept'] = 'application/json';
    if (this.token.length > 0) {
      headers['Authorization'] = `Bearer ${this.token}`;
    }
    return headers;
  }
}

export const serverContext: ServerContextHolder = new ServerContextHolder();
