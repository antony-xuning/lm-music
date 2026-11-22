/**
 * 音源脚本 Store：脚本列表、健康信息、启停/导入/平台开关动作。
 */
import { Logger } from '../common/Logger';
import { SourceScript } from '../model/ServerModels';
import { SourceListResult, SourceOpResult, SourceService } from '../service/SourceService';
import { serverStore } from './ServerStore';

const SCOPE: string = 'SourceStore';

@ObservedV2
export class SourceStore {
  @Trace scripts: SourceScript[] = [];
  @Trace loading: boolean = false;
  @Trace errorText: string = '';
  @Trace busy: boolean = false;
  @Trace lastLoadedAt: number = 0;

  async load(): Promise<void> {
    if (!serverStore.canRead) {
      this.errorText = '尚未连接柠檬音乐服务器';
      this.scripts = [];
      return;
    }
    if (this.loading) {
      return;
    }
    this.loading = true;
    this.errorText = '';
    try {
      const result: SourceListResult = await SourceService.list();
      if (result.ok) {
        this.scripts = result.items;
        this.lastLoadedAt = Date.now();
      } else {
        this.errorText = result.error.length > 0 ? result.error : '读取音源列表失败';
      }
    } finally {
      this.loading = false;
    }
  }

  findScript(id: string): SourceScript | null {
    for (let i = 0; i < this.scripts.length; i++) {
      if (this.scripts[i].id === id) {
        return this.scripts[i];
      }
    }
    return null;
  }

  async toggleActive(script: SourceScript): Promise<SourceOpResult> {
    if (this.busy) {
      const blocked: SourceOpResult = new SourceOpResult();
      blocked.message = '正在处理其他操作';
      return blocked;
    }
    this.busy = true;
    try {
      const nextActive: boolean = !script.active;
      const result: SourceOpResult = await SourceService.setActive(script, nextActive);
      if (result.ok) {
        script.active = nextActive;
        this.scripts = this.scripts.slice();
      } else {
        Logger.warn(SCOPE, `toggle failed: ${result.message}`);
      }
      return result;
    } finally {
      this.busy = false;
    }
  }

  async togglePlatform(script: SourceScript, platformId: string, enabled: boolean): Promise<SourceOpResult> {
    this.busy = true;
    try {
      const result: SourceOpResult = await SourceService.setPlatform(script.id, platformId, enabled);
      if (result.ok) {
        for (let i = 0; i < script.platforms.length; i++) {
          if (script.platforms[i].id === platformId) {
            script.platforms[i].enabled = enabled;
          }
        }
        this.scripts = this.scripts.slice();
      }
      return result;
    } finally {
      this.busy = false;
    }
  }

  async importUrl(url: string): Promise<SourceOpResult> {
    this.busy = true;
    try {
      const result: SourceOpResult = await SourceService.importUrl(url);
      if (result.ok) {
        await this.load();
      }
      return result;
    } finally {
      this.busy = false;
    }
  }

  async importContent(content: string): Promise<SourceOpResult> {
    this.busy = true;
    try {
      const result: SourceOpResult = await SourceService.importContent(content);
      if (result.ok) {
        await this.load();
      }
      return result;
    } finally {
      this.busy = false;
    }
  }
}

export const sourceStore: SourceStore = new SourceStore();
