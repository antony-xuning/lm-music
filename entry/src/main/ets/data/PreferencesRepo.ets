/**
 * 用户首选项封装：设置、服务器配置、搜索历史三组键。
 */
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';

const SCOPE: string = 'PreferencesRepo';

class PreferencesRepo {
  private store: preferences.Preferences | null = null;
  private pending: Promise<void> | null = null;

  async ensure(): Promise<boolean> {
    if (this.store !== null) {
      return true;
    }
    if (this.pending === null) {
      this.pending = this.open();
    }
    await this.pending;
    return this.store !== null;
  }

  private async open(): Promise<void> {
    const context: common.UIAbilityContext | null = AppContextHolder.context;
    if (context === null) {
      Logger.warn(SCOPE, 'context not ready');
      return;
    }
    try {
      this.store = await preferences.getPreferences(context, AppConstants.PREF_STORE_NAME);
    } catch (error) {
      Logger.error(SCOPE, `open failed: ${JSON.stringify(error)}`);
      this.store = null;
    }
  }

  async getString(key: string, fallback: string): Promise<string> {
    const ok: boolean = await this.ensure();
    if (!ok || this.store === null) {
      return fallback;
    }
    try {
      const value = await this.store.get(key, fallback);
      return typeof value === 'string' ? value : fallback;
    } catch (error) {
      return fallback;
    }
  }

  async putString(key: string, value: string): Promise<void> {
    const ok: boolean = await this.ensure();
    if (!ok || this.store === null) {
      return;
    }
    try {
      await this.store.put(key, value);
      await this.store.flush();
    } catch (error) {
      Logger.error(SCOPE, `put ${key} failed: ${JSON.stringify(error)}`);
    }
  }

  async remove(key: string): Promise<void> {
    const ok: boolean = await this.ensure();
    if (!ok || this.store === null) {
      return;
    }
    try {
      await this.store.delete(key);
      await this.store.flush();
    } catch (error) {
      Logger.warn(SCOPE, `delete ${key} failed`);
    }
  }
}

export const preferencesRepo: PreferencesRepo = new PreferencesRepo();
