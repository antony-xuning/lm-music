/**
 * 旧版本数据迁移：清理已下线的内置样例曲目与旧下载/播客数据（幂等，只执行一次）。
 */
import { fileIo } from '@kit.CoreFileKit';
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { preferencesRepo } from './PreferencesRepo';
import { JsonStore } from './JsonStore';

const SCOPE: string = 'LegacyMigration';
const FLAG_KEY: string = 'lm_legacy_migrated_v2';

interface LegacySongRaw {
  id?: string;
  source?: string;
  audioRef?: string;
  localPath?: string;
}

interface LegacyLibraryDoc {
  localSongs?: LegacySongRaw[];
}

interface LegacyEpisodeProgress {
  episodeId?: string;
  progressMs?: number;
  updatedAt?: number;
}

interface LegacyPodcastsDoc {
  progress?: LegacyEpisodeProgress[];
}

interface ProgressDoc {
  schemaVersion?: number;
  subscriptions?: Object[];
  progress?: LegacyEpisodeProgress[];
}

export class LegacyMigration {
  static async runOnce(): Promise<void> {
    const flag: string = await preferencesRepo.getString(FLAG_KEY, '');
    if (flag === 'done') {
      return;
    }
    try {
      LegacyMigration.cleanLibrary();
      LegacyMigration.migratePodcasts();
      LegacyMigration.removeFile('downloads.json');
      LegacyMigration.removeFile('seed.json');
    } catch (error) {
      Logger.warn(SCOPE, 'migration failed');
    }
    await preferencesRepo.putString(FLAG_KEY, 'done');
  }

  private static cleanLibrary(): void {
    const text: string | null = JsonStore.readText(AppConstants.FILE_LIBRARY);
    if (text === null || text.length === 0) {
      return;
    }
    try {
      const doc: LegacyLibraryDoc = JSON.parse(text) as LegacyLibraryDoc;
      const raws: LegacySongRaw[] = Array.isArray(doc.localSongs) ? doc.localSongs : [];
      const kept: LegacySongRaw[] = [];
      for (let i = 0; i < raws.length; i++) {
        const raw: LegacySongRaw = raws[i];
        const audioRef: string = typeof raw.audioRef === 'string' ? raw.audioRef : '';
        const source: string = typeof raw.source === 'string' ? raw.source : '';
        const isDemo: boolean = source === 'demo' || audioRef.startsWith('rawfile:');
        if (!isDemo) {
          kept.push(raw);
        }
      }
      doc.localSongs = kept;
      JsonStore.writeText(AppConstants.FILE_LIBRARY, JSON.stringify(doc));
    } catch (error) {
      Logger.warn(SCOPE, 'library migration skipped');
    }
  }

  private static migratePodcasts(): void {
    const oldText: string | null = JsonStore.readText('podcasts.json');
    if (oldText === null || oldText.length === 0) {
      return;
    }
    const progress: LegacyEpisodeProgress[] = [];
    try {
      const doc: LegacyPodcastsDoc = JSON.parse(oldText) as LegacyPodcastsDoc;
      const raws: LegacyEpisodeProgress[] = Array.isArray(doc.progress) ? doc.progress : [];
      for (let i = 0; i < raws.length; i++) {
        const raw: LegacyEpisodeProgress = raws[i];
        const id: string = typeof raw.episodeId === 'string' ? raw.episodeId : '';
        if (id.length === 0 || id.indexOf('demo') >= 0) {
          continue;
        }
        progress.push(raw);
      }
    } catch (error) {
      Logger.warn(SCOPE, 'podcast migration skipped');
    }
    const next: ProgressDoc = {
      schemaVersion: AppConstants.SCHEMA_VERSION,
      subscriptions: [],
      progress: progress
    };
    JsonStore.writeText(AppConstants.FILE_PODCASTS, JSON.stringify(next));
    LegacyMigration.removeFile('podcasts.json');
  }

  private static removeFile(name: string): void {
    try {
      const path: string = JsonStore.filePath(name);
      if (fileIo.accessSync(path)) {
        fileIo.unlinkSync(path);
      }
    } catch (error) {
      Logger.warn(SCOPE, `remove ${name} failed`);
    }
  }
}
