/**
 * 本地扫描索引持久化：filesDir/data/local_index.json，原子写入，损坏时回退为空索引。
 */
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { JsonStore } from './JsonStore';
import { LocalIndexDoc, LocalScanCodec } from '../model/LocalScanModels';

const SCOPE: string = 'LocalIndexStore';

export class LocalIndexStore {
  static load(): LocalIndexDoc {
    const text: string | null = JsonStore.readText(AppConstants.FILE_LOCAL_INDEX);
    if (text === null || text.length === 0) {
      return new LocalIndexDoc();
    }
    const doc: LocalIndexDoc | null = LocalScanCodec.docFrom(text);
    if (doc === null) {
      Logger.warn(SCOPE, 'local_index.json unreadable, fallback to empty index');
      LocalIndexStore.clear();
      return new LocalIndexDoc();
    }
    return doc;
  }

  static save(doc: LocalIndexDoc): boolean {
    try {
      JsonStore.writeText(AppConstants.FILE_LOCAL_INDEX, LocalScanCodec.docToJson(doc));
      return true;
    } catch (error) {
      Logger.error(SCOPE, 'write local index failed');
      return false;
    }
  }

  static clear(): void {
    JsonStore.remove(AppConstants.FILE_LOCAL_INDEX);
  }
}
