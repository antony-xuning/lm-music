/**
 * 沙箱 JSON 存储：写入使用「临时文件 → 重命名」，避免半写文件；读取失败由调用方回退种子数据。
 */
import { fileIo } from '@kit.CoreFileKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { Logger } from '../common/Logger';

const SCOPE: string = 'JsonStore';

export class JsonStore {
  static dirPath(): string {
    return `${AppContextHolder.filesDir}/data`;
  }

  static ensureDir(): void {
    const dir: string = JsonStore.dirPath();
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
    } catch (error) {
      Logger.error(SCOPE, `ensureDir failed: ${JSON.stringify(error)}`);
    }
  }

  static filePath(name: string): string {
    return `${JsonStore.dirPath()}/${name}`;
  }

  static exists(name: string): boolean {
    try {
      return fileIo.accessSync(JsonStore.filePath(name));
    } catch (error) {
      return false;
    }
  }

  static readText(name: string): string | null {
    const path: string = JsonStore.filePath(name);
    try {
      if (!fileIo.accessSync(path)) {
        return null;
      }
      return fileIo.readTextSync(path);
    } catch (error) {
      Logger.warn(SCOPE, `read ${name} failed`);
      return null;
    }
  }

  static writeText(name: string, content: string): void {
    JsonStore.ensureDir();
    const path: string = JsonStore.filePath(name);
    const tempPath: string = `${path}.tmp`;
    try {
      if (fileIo.accessSync(tempPath)) {
        fileIo.unlinkSync(tempPath);
      }
      const file = fileIo.openSync(tempPath, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE
        | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(file.fd, content);
      } finally {
        fileIo.closeSync(file);
      }
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
      fileIo.renameSync(tempPath, path);
    } catch (error) {
      Logger.error(SCOPE, `write ${name} failed: ${JSON.stringify(error)}`);
    }
  }

  static remove(name: string): void {
    const path: string = JsonStore.filePath(name);
    try {
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (error) {
      Logger.warn(SCOPE, `remove ${name} failed`);
    }
  }
}
