/**
 * 本地音频元数据：AVMetadataExtractor 读取标题/歌手/专辑/时长/采样率与内嵌封面。
 * 每个文件独立创建并释放 extractor，提取失败不中断扫描（由调用方回退文件名）。
 */
import { media } from '@kit.MediaKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppContextHolder } from '../common/AppContextHolder';
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { LocalScanHelper, LocalTrack } from '../model/LocalScanModels';

const SCOPE: string = 'MediaTagService';

/** 单个文件的标签提取结果。 */
export class LocalTrackTags {
  title: string = '';
  artist: string = '';
  album: string = '';
  durationMs: number = 0;
  sampleRate: number = 0;
  bitDepth: number = 0;
  coverCacheKey: string = '';
  hasCover: boolean = false;
  readable: boolean = false;
}

export class MediaTagService {
  /**
   * 列表项 build 会反复调用 coverUriOf，命中缓存后避免每行都做 accessSync 同步磁盘探测。
   * key 为 coverCacheKey（含文件大小与 mtime），内容变化会产生新 key，不会命中旧 URI。
   */
  private static coverUriCache: Map<string, string> = new Map<string, string>();

  static coverDir(): string {
    return `${AppContextHolder.cacheDir}/${AppConstants.LOCAL_COVER_DIR}`;
  }

  static ensureCoverDir(): void {
    const dir: string = MediaTagService.coverDir();
    if (dir.length === 0) {
      return;
    }
    try {
      if (!fileIo.accessSync(dir)) {
        fileIo.mkdirSync(dir, true);
      }
    } catch (error) {
      Logger.warn(SCOPE, 'create local cover dir failed');
    }
  }

  static coverPathOf(cacheKey: string): string {
    if (cacheKey.length === 0) {
      return '';
    }
    return `${MediaTagService.coverDir()}/${cacheKey}.jpg`;
  }

  /** 本地曲目的封面 URI（供 UI 直接加载，无封面返回空串）。 */
  static coverUriOf(track: LocalTrack): string {
    if (!track.hasCover || track.coverCacheKey.length === 0) {
      return '';
    }
    const cached: string | undefined = MediaTagService.coverUriCache.get(track.coverCacheKey);
    if (cached !== undefined) {
      return cached;
    }
    const path: string = MediaTagService.coverPathOf(track.coverCacheKey);
    let uri: string = '';
    try {
      if (fileIo.accessSync(path)) {
        uri = `file://${path}`;
      }
    } catch (error) {
      uri = '';
    }
    MediaTagService.coverUriCache.set(track.coverCacheKey, uri);
    return uri;
  }

  static coverKeyFor(uri: string, sizeBytes: number, mtime: number): string {
    return `${LocalScanHelper.stableId(uri)}_${Math.round(sizeBytes)}_${Math.round(mtime)}`;
  }

  /**
   * 读取一个音频文件的标签与内嵌封面。
   * @param uri 首选用户文件 URI
   * @param fallbackPath URI 不可直接打开时的沙箱/公共绝对路径
   */
  static async read(uri: string, fallbackPath: string, cacheKey: string): Promise<LocalTrackTags> {
    const tags: LocalTrackTags = new LocalTrackTags();
    let file: fileIo.File | null = null;
    let extractor: media.AVMetadataExtractor | null = null;
    try {
      file = MediaTagService.openFile(uri, fallbackPath);
      if (file === null) {
        return tags;
      }
      const size: number = fileIo.statSync(file.fd).size;
      if (size <= 0) {
        return tags;
      }
      extractor = await media.createAVMetadataExtractor();
      const descriptor: media.AVFileDescriptor = { fd: file.fd, offset: 0, length: size };
      extractor.fdSrc = descriptor;
      const metadata: media.AVMetadata = await extractor.fetchMetadata();
      MediaTagService.applyMetadata(tags, metadata);
      tags.readable = true;
      if (cacheKey.length > 0) {
        const coverKey: string = await MediaTagService.extractCover(extractor, cacheKey);
        if (coverKey.length > 0) {
          tags.coverCacheKey = coverKey;
          tags.hasCover = true;
        }
      }
      return tags;
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `read tags failed: ${err.code}`);
      return tags;
    } finally {
      if (extractor !== null) {
        try {
          await extractor.release();
        } catch (error) {
          Logger.warn(SCOPE, 'release extractor failed');
        }
      }
      if (file !== null) {
        try {
          fileIo.closeSync(file);
        } catch (error) {
          Logger.warn(SCOPE, 'close fd failed');
        }
      }
    }
  }

  private static openFile(uri: string, fallbackPath: string): fileIo.File | null {
    const candidates: string[] = [];
    if (uri.length > 0) {
      candidates.push(uri);
    }
    if (fallbackPath.length > 0 && fallbackPath !== uri) {
      candidates.push(fallbackPath);
    }
    for (let i = 0; i < candidates.length; i++) {
      try {
        return fileIo.openSync(candidates[i], fileIo.OpenMode.READ_ONLY);
      } catch (error) {
        Logger.warn(SCOPE, 'open candidate failed');
      }
    }
    return null;
  }

  private static applyMetadata(tags: LocalTrackTags, metadata: media.AVMetadata): void {
    tags.title = typeof metadata.title === 'string' ? metadata.title.trim() : '';
    tags.artist = typeof metadata.artist === 'string' ? metadata.artist.trim() : '';
    tags.album = typeof metadata.album === 'string' ? metadata.album.trim() : '';
    if (tags.artist.length === 0 && typeof metadata.albumArtist === 'string') {
      tags.artist = metadata.albumArtist.trim();
    }
    tags.durationMs = MediaTagService.numberOf(metadata.duration);
    tags.sampleRate = MediaTagService.numberOf(metadata.sampleRate);
    tags.bitDepth = MediaTagService.bitDepthOf(metadata);
  }

  private static numberOf(raw: string | undefined): number {
    if (typeof raw !== 'string' || raw.length === 0) {
      return 0;
    }
    const value: number = Number(raw);
    return Number.isNaN(value) ? 0 : Math.round(value);
  }

  /** AVMetadata 未直接暴露位深，优先读取 customInfo，缺失时返回 0。 */
  private static bitDepthOf(metadata: media.AVMetadata): number {
    const info: Record<string, string> | undefined = metadata.customInfo;
    if (info !== undefined) {
      const keys: string[] = ['bits_per_sample', 'bitsPerSample', 'bitDepth', 'bit_depth'];
      for (let i = 0; i < keys.length; i++) {
        const raw: string = info[keys[i]];
        if (typeof raw === 'string' && raw.length > 0) {
          const value: number = Number(raw);
          if (!Number.isNaN(value) && value > 0) {
            return Math.round(value);
          }
        }
      }
    }
    return 0;
  }

  /** 内嵌封面 -> cacheDir/local_covers/<key>.jpg，返回缓存键（失败返回空串）。 */
  private static async extractCover(extractor: media.AVMetadataExtractor, cacheKey: string): Promise<string> {
    let pixelMap: image.PixelMap | null = null;
    let packer: image.ImagePacker | null = null;
    let file: fileIo.File | null = null;
    try {
      pixelMap = await extractor.fetchAlbumCover();
      if (pixelMap === null || pixelMap === undefined) {
        return '';
      }
      MediaTagService.ensureCoverDir();
      const path: string = MediaTagService.coverPathOf(cacheKey);
      if (path.length === 0) {
        return '';
      }
      MediaTagService.shrink(pixelMap);
      file = fileIo.openSync(path, fileIo.OpenMode.READ_WRITE | fileIo.OpenMode.CREATE
        | fileIo.OpenMode.TRUNC);
      packer = image.createImagePacker();
      const options: image.PackingOption = {
        format: 'image/jpeg',
        quality: AppConstants.LOCAL_COVER_QUALITY
      };
      await packer.packToFile(pixelMap, file.fd, options);
      return cacheKey;
    } catch (error) {
      const err = error as BusinessError;
      Logger.warn(SCOPE, `extract cover failed: ${err.code}`);
      return '';
    } finally {
      if (packer !== null) {
        try {
          await packer.release();
        } catch (error) {
          Logger.warn(SCOPE, 'release packer failed');
        }
      }
      if (pixelMap !== null) {
        try {
          pixelMap.release();
        } catch (error) {
          Logger.warn(SCOPE, 'release pixel map failed');
        }
      }
      if (file !== null) {
        try {
          fileIo.closeSync(file);
        } catch (error) {
          Logger.warn(SCOPE, 'close cover fd failed');
        }
      }
    }
  }

  /** 封面过大时按比例缩到 512px 以内，避免内存峰值。 */
  private static shrink(pixelMap: image.PixelMap): void {
    try {
      const info: image.ImageInfo = pixelMap.getImageInfoSync();
      const width: number = info.size.width;
      const height: number = info.size.height;
      const maxEdge: number = Math.max(width, height);
      if (maxEdge <= AppConstants.LOCAL_COVER_MAX_EDGE || maxEdge <= 0) {
        return;
      }
      const scale: number = AppConstants.LOCAL_COVER_MAX_EDGE / maxEdge;
      pixelMap.scaleSync(scale, scale);
    } catch (error) {
      Logger.warn(SCOPE, 'shrink cover failed');
    }
  }
}

