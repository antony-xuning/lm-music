/**
 * 本地音频导入：系统 AudioViewPicker 选择 → 校验扩展名 → 复制到沙箱 → 生成 Song。
 */
import { picker } from '@kit.CoreFileKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { Utils } from '../common/Utils';
import { MediaSource, Song } from '../model/MediaModels';

const SCOPE: string = 'ImportService';
const AUDIO_EXTENSIONS: string[] = ['mp3', 'flac', 'wav', 'm4a', 'aac', 'ogg', 'ape'];

export class ImportResult {
  songs: Song[] = [];
  skipped: number = 0;
  message: string = '';
  cancelled: boolean = false;
}

export class ImportService {
  static importDir(): string {
    return `${AppContextHolder.filesDir}/${AppConstants.IMPORT_DIR}`;
  }

  private static ensureDir(): void {
    const dir: string = ImportService.importDir();
    try {
      if (dir.length > 0 && !fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
    } catch (error) {
      Logger.error(SCOPE, 'create import dir failed');
    }
  }

  static async pickAndImport(): Promise<ImportResult> {
    const result: ImportResult = new ImportResult();
    const context: common.UIAbilityContext | null = AppContextHolder.context;
    if (context === null) {
      result.message = '应用上下文未就绪';
      return result;
    }
    ImportService.ensureDir();
    let uris: string[] = [];
    try {
      const audioPicker: picker.AudioViewPicker = new picker.AudioViewPicker(context);
      const options: picker.AudioSelectOptions = new picker.AudioSelectOptions();
      options.maxSelectNumber = 10;
      uris = await audioPicker.select(options);
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `picker failed: ${err.code}`);
      result.message = '无法打开文件选择器';
      return result;
    }
    if (uris.length === 0) {
      result.cancelled = true;
      result.message = '未选择音频文件';
      return result;
    }
    for (let i = 0; i < uris.length; i++) {
      const song: Song | null = ImportService.copyOne(uris[i]);
      if (song === null) {
        result.skipped = result.skipped + 1;
      } else {
        result.songs.push(song);
      }
    }
    if (result.songs.length === 0) {
      result.message = '未导入任何文件，请选择常见音频格式';
    } else {
      result.message = `已导入 ${result.songs.length} 首本地音乐`;
    }
    return result;
  }

  private static copyOne(uri: string): Song | null {
    const fileName: string = ImportService.extractName(uri);
    const extension: string = ImportService.extractExtension(fileName);
    if (AUDIO_EXTENSIONS.indexOf(extension) < 0) {
      Logger.warn(SCOPE, `unsupported extension: ${extension}`);
      return null;
    }
    const storedName: string = ImportService.uniqueName(fileName);
    const destPath: string = `${ImportService.importDir()}/${storedName}`;
    let sizeBytes: number = 0;
    try {
      const source = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      try {
        fileIo.copyFileSync(source.fd, destPath);
      } finally {
        fileIo.closeSync(source);
      }
      const stat = fileIo.statSync(destPath);
      sizeBytes = stat.size;
    } catch (error) {
      const err = error as BusinessError;
      Logger.error(SCOPE, `copy failed: ${err.code}`);
      try {
        if (fileIo.accessSync(destPath)) {
          fileIo.unlinkSync(destPath);
        }
      } catch (cleanupError) {
        Logger.warn(SCOPE, 'cleanup failed');
      }
      return null;
    }

    const title: string = ImportService.stripExtension(fileName);
    const song: Song = new Song();
    song.id = `local_${Utils.hashString(storedName)}`;
    song.title = title;
    song.artist = '本地导入';
    song.album = '本地音乐';
    song.artistId = 'local_artist';
    song.albumId = 'local_album';
    song.durationMs = 0;
    song.audioRef = `${AppConstants.SANDBOX_PREFIX}${AppConstants.IMPORT_DIR}/${storedName}`;
    song.source = MediaSource.LOCAL;
    song.coverSeed = Utils.hashString(title) % 12;
    song.format = extension.toUpperCase();
    song.bitRate = 320;
    song.sizeBytes = sizeBytes;
    song.addedAt = Date.now();
    song.localPath = destPath;
    song.lyricText = '';
    return song;
  }

  private static extractName(uri: string): string {
    const index: number = uri.lastIndexOf('/');
    const raw: string = index >= 0 ? uri.substring(index + 1) : uri;
    const decoded: string = decodeURIComponent(raw);
    return decoded.length > 0 ? decoded : `imported_${Date.now()}`;
  }

  private static extractExtension(fileName: string): string {
    const dot: number = fileName.lastIndexOf('.');
    if (dot < 0 || dot === fileName.length - 1) {
      return '';
    }
    return fileName.substring(dot + 1).toLowerCase();
  }

  private static stripExtension(fileName: string): string {
    const dot: number = fileName.lastIndexOf('.');
    return dot > 0 ? fileName.substring(0, dot) : fileName;
  }

  private static uniqueName(fileName: string): string {
    let candidate: string = fileName.replace(/[\\/:*?"<>|]/g, '_');
    let counter: number = 1;
    while (ImportService.exists(`${ImportService.importDir()}/${candidate}`)) {
      const dot: number = fileName.lastIndexOf('.');
      const base: string = dot > 0 ? fileName.substring(0, dot) : fileName;
      const ext: string = dot > 0 ? fileName.substring(dot) : '';
      candidate = `${base}_${counter}${ext}`;
      counter++;
    }
    return candidate;
  }

  private static exists(path: string): boolean {
    try {
      return fileIo.accessSync(path);
    } catch (error) {
      return false;
    }
  }
}
