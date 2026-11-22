/**
 * 服务器会话管理：连接测试（探活 + 登录）、会话校验、退出登录与写操作串行锁。
 * 密码只保存在 serverContext 内存中，不写入任何持久化文件或日志。
 */
import { ApiErrorCode, ServerSession } from '../model/ServerModels';
import { ServerConfig } from '../model/SettingsModels';
import { ObjectResult, SessionResult, serverApi } from './ServerApi';
import { serverContext } from './ServerContext';

export class LoginOutcome {
  ok: boolean = false;
  message: string = '';
  latencyMs: number = 0;
  session: ServerSession = new ServerSession();
}

class ServerManagerImpl {
  private writeChain: Promise<void> = Promise.resolve();

  /** 写操作串行执行，避免并发读改写相互覆盖。 */
  exclusive(task: () => Promise<void>): Promise<void> {
    this.writeChain = this.writeChain.then(task).catch(() => {
    });
    return this.writeChain;
  }

  /** 健康探活：先 /api/health，失败回退 /api/auth/me 判定服务是否在线。 */
  async probe(): Promise<LoginOutcome> {
    const outcome: LoginOutcome = new LoginOutcome();
    const startedAt: number = Date.now();
    const health: ObjectResult = await serverApi.health();
    if (health.ok) {
      outcome.ok = true;
      outcome.latencyMs = Date.now() - startedAt;
      return outcome;
    }
    if (health.code === ApiErrorCode.BAD_RESPONSE) {
      outcome.message = '该地址不是柠檬音乐服务';
      return outcome;
    }
    const me: SessionResult = await serverApi.me();
    if (me.ok || me.code === ApiErrorCode.UNAUTHORIZED) {
      outcome.ok = true;
      outcome.latencyMs = Date.now() - startedAt;
      return outcome;
    }
    outcome.message = health.message.length > 0 ? health.message : '无法连接服务器';
    return outcome;
  }

  /** 连接测试：探活 → 登录取 Token → /api/auth/me 校验。 */
  async login(config: ServerConfig, password: string): Promise<LoginOutcome> {
    serverContext.load(config);
    serverContext.password = '';
    const probe: LoginOutcome = await this.probe();
    if (!probe.ok) {
      return probe;
    }
    const startedAt: number = Date.now();
    const result: SessionResult = await serverApi.login(config.username, password, true);
    if (!result.ok) {
      const outcome: LoginOutcome = new LoginOutcome();
      outcome.ok = false;
      if (result.code === ApiErrorCode.UNAUTHORIZED) {
        outcome.message = '账号或密码错误';
      } else {
        outcome.message = result.message.length > 0 ? result.message : '登录失败';
      }
      return outcome;
    }
    serverContext.setSession(result.session.token, result.session.expiresAt, password);
    config.token = result.session.token;
    config.tokenExpiresAt = result.session.expiresAt;
    config.displayName = result.session.displayName.length > 0
      ? result.session.displayName : result.session.username;
    config.username = result.session.username.length > 0 ? result.session.username : config.username;
    config.lastConnectedAt = Date.now();
    config.statusState = 'online';
    const verify: SessionResult = await serverApi.me();
    const outcome: LoginOutcome = new LoginOutcome();
    outcome.ok = true;
    outcome.latencyMs = Date.now() - startedAt;
    outcome.session = result.session;
    outcome.message = verify.ok ? '连接成功' : '连接成功（会话校验未通过，稍后自动重试）';
    return outcome;
  }

  /** 冷启动恢复：用已保存 Token 校验会话。 */
  async restoreSession(config: ServerConfig): Promise<boolean> {
    serverContext.load(config);
    if (config.token.length === 0) {
      return false;
    }
    const me: SessionResult = await serverApi.me();
    if (me.ok) {
      if (me.session.username.length === 0) {
        me.session.username = config.username;
      }
      if (me.session.expiresAt > 0) {
        config.tokenExpiresAt = me.session.expiresAt;
      }
      if (me.session.displayName.length > 0) {
        config.displayName = me.session.displayName;
      }
      config.statusState = 'online';
      config.lastConnectedAt = Date.now();
      return true;
    }
    if (me.code === ApiErrorCode.UNAUTHORIZED) {
      config.statusState = 'authExpired';
    }
    return false;
  }

  logout(): void {
    serverContext.clearSession();
  }

  clearAll(): void {
    serverContext.clear();
  }
}


export const serverManager: ServerManagerImpl = new ServerManagerImpl();
