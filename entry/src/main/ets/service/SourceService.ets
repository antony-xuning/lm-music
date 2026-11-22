/**
 * 音源脚本服务：列表、启用/停用、按 URL / 内容导入、单平台开关。
 * 不在本机执行脚本，脚本由服务端运行。
 */
import { SourceScript } from '../model/ServerModels';
import { ServerSchemasAux } from '../data/ServerSchemasAux';
import { ListResult, ObjectResult } from './ServerApi';
import { ServerApiCatalog } from './ServerApiCatalog';

export class SourceListResult {
  ok: boolean = false;
  error: string = '';
  items: SourceScript[] = [];
}

export class SourceOpResult {
  ok: boolean = false;
  message: string = '';
  unsupported: boolean = false;
}

class ScriptRefBody {
  id: string = '';
  name: string = '';
  scriptId: string = '';
  active: boolean = true;

  constructor(script: SourceScript, active: boolean) {
    this.id = script.id;
    this.scriptId = script.id;
    this.name = script.name;
    this.active = active;
  }
}

class ImportUrlBody {
  url: string = '';

  constructor(url: string) {
    this.url = url;
  }
}

class ImportContentBody {
  content: string = '';
  name: string = '';

  constructor(content: string) {
    this.content = content;
  }
}

class PlatformToggleBody {
  platform: string = '';
  enabled: boolean = true;

  constructor(platform: string, enabled: boolean) {
    this.platform = platform;
    this.enabled = enabled;
  }
}

export class SourceService {
  static async list(): Promise<SourceListResult> {
    const result: SourceListResult = new SourceListResult();
    const response: ListResult = await ServerApiCatalog.sources();
    if (!response.ok) {
      result.error = response.message;
      return result;
    }
    for (let i = 0; i < response.items.length; i++) {
      const script: SourceScript = ServerSchemasAux.sourceScriptFrom(response.items[i]);
      if (script.id.length === 0) {
        script.id = `src_${i}`;
      }
      result.items.push(script);
    }
    result.ok = true;
    return result;
  }

  static async setActive(script: SourceScript, active: boolean): Promise<SourceOpResult> {
    const body: string = JSON.stringify(new ScriptRefBody(script, active));
    const response: ObjectResult = active
      ? await ServerApiCatalog.activateSource(body)
      : await ServerApiCatalog.deactivateSource(body);
    return toOpResult(response, active ? '已启用脚本' : '已停用脚本');
  }

  static async importUrl(url: string): Promise<SourceOpResult> {
    const response: ObjectResult = await ServerApiCatalog.importSourceUrl(JSON.stringify(new ImportUrlBody(url)));
    return toOpResult(response, '脚本已导入');
  }

  static async importContent(content: string): Promise<SourceOpResult> {
    const response: ObjectResult = await ServerApiCatalog.importSource(JSON.stringify(new ImportContentBody(content)));
    return toOpResult(response, '脚本已导入');
  }

  static async setPlatform(scriptId: string, platform: string, enabled: boolean): Promise<SourceOpResult> {
    const body: string = JSON.stringify(new PlatformToggleBody(platform, enabled));
    const response: ObjectResult = await ServerApiCatalog.sourcePlatform(scriptId, body);
    return toOpResult(response, enabled ? '已启用平台' : '已停用平台');
  }
}

function toOpResult(response: ObjectResult, successMessage: string): SourceOpResult {
  const result: SourceOpResult = new SourceOpResult();
  if (response.ok) {
    result.ok = true;
    result.message = successMessage;
    return result;
  }
  result.unsupported = response.status === 404 || response.status === 405;
  result.message = result.unsupported ? '服务器不支持该操作' : response.message;
  return result;
}
