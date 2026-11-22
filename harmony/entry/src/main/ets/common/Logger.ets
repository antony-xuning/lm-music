import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 统一日志封装：所有模块通过该入口输出 hilog，并对凭据类字段做脱敏。
 * 禁止在任何日志中出现密码、Token、ticket 查询参数与完整 Authorization 头。
 */
const DOMAIN: number = 0x4C4D;
const TAG: string = 'LMPlayer';
const SENSITIVE_KEYS: string[] = ['password', 'token', 'authorization', 'ticket', 'secret', 'cookie'];

export class Logger {
  /** 脱敏：移除查询串中的 ticket、Bearer 值，以及字面量敏感字段。 */
  static redact(message: string): string {
    if (message.length === 0) {
      return message;
    }
    let result: string = message;
    const lower: string = result.toLowerCase();
    for (let i = 0; i < SENSITIVE_KEYS.length; i++) {
      const key: string = SENSITIVE_KEYS[i];
      let index: number = lower.indexOf(`${key}=`);
      let guard: number = 0;
      while (index >= 0 && guard < 8) {
        const tail: string = result.substring(index + key.length + 1);
        const endToken: number = tail.indexOf('&');
        const endSpace: number = tail.indexOf(' ');
        let end: number = tail.length;
        if (endToken >= 0 && endToken < end) {
          end = endToken;
        }
        if (endSpace >= 0 && endSpace < end) {
          end = endSpace;
        }
        result = result.substring(0, index + key.length + 1) + '***' + tail.substring(end);
        guard++;
        index = result.toLowerCase().indexOf(`${key}=`, index + key.length + 1);
      }
    }
    if (result.toLowerCase().indexOf('bearer ') >= 0) {
      const at: number = result.toLowerCase().indexOf('bearer ');
      const tail: string = result.substring(at + 7);
      const endSpace: number = tail.indexOf(' ');
      result = result.substring(0, at + 7) + '***' + (endSpace >= 0 ? tail.substring(endSpace) : '');
    }
    return result;
  }

  static debug(scope: string, message: string): void {
    hilog.debug(DOMAIN, TAG, '[%{public}s] %{public}s', scope, Logger.redact(message));
  }

  static info(scope: string, message: string): void {
    hilog.info(DOMAIN, TAG, '[%{public}s] %{public}s', scope, Logger.redact(message));
  }

  static warn(scope: string, message: string): void {
    hilog.warn(DOMAIN, TAG, '[%{public}s] %{public}s', scope, Logger.redact(message));
  }

  static error(scope: string, message: string): void {
    hilog.error(DOMAIN, TAG, '[%{public}s] %{public}s', scope, Logger.redact(message));
  }
}
