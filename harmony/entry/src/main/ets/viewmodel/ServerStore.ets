/**
 * 服务器连接 Store：连接状态、延迟、当前用户、会话恢复与 401 统一处理。
 */
import { Logger } from '../common/Logger';
import { ConnectionState } from '../model/ServerModels';
import { ServerConfig } from '../model/SettingsModels';
import { LoginOutcome, serverManager } from '../service/ServerManager';
import { serverApi } from '../service/ServerApi';
import { serverContext } from '../service/ServerContext';
import { settingsStore } from './SettingsStore';

const SCOPE: string = 'ServerStore';

@ObservedV2
export class ServerStore {
  @Trace state: ConnectionState = ConnectionState.IDLE;
  @Trace latencyMs: number = 0;
  @Trace errorText: string = '';
  @Trace username: string = '';
  @Trace displayName: string = '';
  @Trace busy: boolean = false;
  @Trace initialized: boolean = false;
  @Trace authNotified: boolean = false;
  @Trace authenticated: boolean = false;

  constructor() {
    serverApi.setAuthExpiredListener(() => {
      this.handleUnauthorized();
    });
  }

  async init(): Promise<void> {
    if (this.initialized) {
      return;
    }
    const server: ServerConfig | null = settingsStore.activeServer;
    if (server === null) {
      this.state = ConnectionState.IDLE;
      this.initialized = true;
      return;
    }
    serverContext.load(server);
    this.authenticated = server.token.length > 0;
    this.username = server.username;
    this.displayName = server.displayName;
    if (server.token.length === 0) {
      this.state = ConnectionState.IDLE;
      this.initialized = true;
      return;
    }
    this.state = ConnectionState.CONNECTING;
    const startedAt: number = Date.now();
    const ok: boolean = await serverManager.restoreSession(server);
    if (ok) {
      this.state = ConnectionState.ONLINE;
      this.latencyMs = Date.now() - startedAt;
      this.username = serverContext.username;
      this.displayName = serverContext.displayName;
      this.errorText = '';
      settingsStore.persistNow();
      Logger.info(SCOPE, 'session restored');
    } else {
      this.state = server.statusState === 'authExpired'
        ? ConnectionState.AUTH_EXPIRED : ConnectionState.OFFLINE;
      this.authenticated = server.statusState !== 'authExpired' && server.token.length > 0;
      this.errorText = server.statusState === 'authExpired' ? '登录已过期，请重新输入密码' : '无法连接服务器';
      settingsStore.persistNow();
    }
    this.initialized = true;
  }

  get activeServer(): ServerConfig | null {
    return settingsStore.activeServer;
  }

  get configured(): boolean {
    return this.activeServer !== null && this.activeServer.url.length > 0;
  }

  get online(): boolean {
    return this.state === ConnectionState.ONLINE;
  }

  get sessionExpired(): boolean {
    return this.state === ConnectionState.AUTH_EXPIRED;
  }

  get canRead(): boolean {
    return this.configured && this.authenticated && serverContext.hasToken;
  }

  /** 连接测试 + 登录 + 持久化。 */
  async testAndLogin(server: ServerConfig, password: string): Promise<LoginOutcome> {
    this.busy = true;
    this.state = ConnectionState.CONNECTING;
    try {
      const outcome: LoginOutcome = await serverManager.login(server, password);
      if (outcome.ok) {
        settingsStore.saveServer(server);
        settingsStore.activateServer(server.id);
        this.state = ConnectionState.ONLINE;
        this.authenticated = true;
        this.latencyMs = outcome.latencyMs;
        this.username = server.username;
        this.displayName = server.displayName.length > 0 ? server.displayName : server.username;
        this.errorText = '';
        this.authNotified = false;
      } else {
        this.state = ConnectionState.ERROR;
        this.errorText = outcome.message;
        if (server.token.length === 0) {
          settingsStore.saveServer(server);
        }
      }
      return outcome;
    } finally {
      this.busy = false;
    }
  }

  /** 用已保存 Token 校验会话（重启后）。 */
  async refreshSession(): Promise<boolean> {
    const server: ServerConfig | null = this.activeServer;
    if (server === null) {
      return false;
    }
    const ok: boolean = await serverManager.restoreSession(server);
    this.authenticated = ok;
    if (ok) {
      this.state = ConnectionState.ONLINE;
      this.errorText = '';
    } else if (server.statusState === 'authExpired') {
      this.state = ConnectionState.AUTH_EXPIRED;
      this.errorText = '登录已过期，请重新输入密码';
    } else {
      this.state = ConnectionState.OFFLINE;
      this.errorText = '无法连接服务器';
    }
    return ok;
  }

  async logout(): Promise<void> {
    const server: ServerConfig | null = this.activeServer;
    if (server !== null) {
      server.token = '';
      server.tokenExpiresAt = 0;
      server.statusState = 'idle';
      server.displayName = '';
      settingsStore.persistNow();
    }
    serverManager.logout();
    this.authenticated = false;
    this.state = ConnectionState.IDLE;
    this.latencyMs = 0;
    this.errorText = '';
    this.username = '';
    this.displayName = '';
    this.authNotified = false;
  }

  markOnline(trackCount: number): void {
    this.state = ConnectionState.ONLINE;
    this.errorText = '';
    const server: ServerConfig | null = this.activeServer;
    if (server !== null) {
      server.statusState = 'online';
      server.trackCount = trackCount;
      server.lastConnectedAt = Date.now();
    }
  }

  markOffline(message: string): void {
    if (this.state !== ConnectionState.AUTH_EXPIRED) {
      this.state = ConnectionState.OFFLINE;
    }
    this.errorText = message;
  }

  handleUnauthorized(): void {
    this.state = ConnectionState.AUTH_EXPIRED;
    this.errorText = '登录已过期，请重新输入密码';
    const server: ServerConfig | null = this.activeServer;
    if (server !== null) {
      server.token = '';
      server.tokenExpiresAt = 0;
      server.statusState = 'authExpired';
      settingsStore.persistNow();
    }
    serverContext.clearSession();
    this.authenticated = false;
    this.authNotified = true;
  }

  /** 会话过期提示只触发一次，由设置页读取。 */
  consumeAuthNotice(): boolean {
    if (this.authNotified) {
      this.authNotified = false;
      return true;
    }
    return false;
  }
}

export const serverStore: ServerStore = new ServerStore();
