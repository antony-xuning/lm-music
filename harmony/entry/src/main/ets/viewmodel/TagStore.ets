/**
 * 标签编辑 Store：标签信息、匹配候选、编辑状态与写入结果。
 */
import { TagCandidate, TagInfo } from '../model/ServerModels';
import { TagMatchResult, TagOpResult, TagReadResult, TagService } from '../service/TagService';
import { serverStore } from './ServerStore';

@ObservedV2
export class TagStore {
  @Trace info: TagInfo = new TagInfo();
  @Trace candidates: TagCandidate[] = [];
  @Trace loading: boolean = false;
  @Trace matching: boolean = false;
  @Trace busy: boolean = false;
  @Trace errorText: string = '';
  @Trace matchError: string = '';
  @Trace dirty: boolean = false;
  @Trace filePath: string = '';

  async load(filePath: string): Promise<void> {
    this.filePath = filePath;
    this.loading = true;
    this.errorText = '';
    this.candidates = [];
    this.dirty = false;
    try {
      const result: TagReadResult = await TagService.read(filePath);
      if (result.ok) {
        this.info = result.info;
      } else {
        this.errorText = result.error;
      }
    } finally {
      this.loading = false;
    }
  }

  async match(source: string): Promise<void> {
    if (this.matching) {
      return;
    }
    this.matching = true;
    this.matchError = '';
    try {
      const result: TagMatchResult = await TagService.match(this.info, source);
      if (result.ok) {
        this.candidates = result.candidates;
        if (this.candidates.length === 0) {
          this.matchError = '没有找到匹配候选';
        }
      } else {
        this.matchError = result.error;
      }
    } finally {
      this.matching = false;
    }
  }

  async applyCandidate(candidate: TagCandidate): Promise<void> {
    this.busy = true;
    try {
      const result: TagReadResult = await TagService.applyCandidate(this.info, candidate);
      if (result.ok) {
        this.info = result.info;
        this.dirty = true;
        this.errorText = '';
      } else {
        this.errorText = result.error;
      }
    } finally {
      this.busy = false;
    }
  }

  async write(): Promise<TagOpResult> {
    this.busy = true;
    try {
      const result: TagOpResult = await TagService.write(this.info);
      if (result.ok) {
        this.dirty = false;
      }
      return result;
    } finally {
      this.busy = false;
    }
  }

  setTitle(value: string): void {
    this.info.title = value;
    this.dirty = true;
  }

  setArtist(value: string): void {
    this.info.artist = value;
    this.dirty = true;
  }

  setAlbum(value: string): void {
    this.info.album = value;
    this.dirty = true;
  }

  setYear(value: string): void {
    const parsed: number = Number.parseInt(value, 10);
    this.info.year = Number.isNaN(parsed) ? 0 : parsed;
    this.dirty = true;
  }

  setTrack(value: string): void {
    const parsed: number = Number.parseInt(value, 10);
    this.info.track = Number.isNaN(parsed) ? 0 : parsed;
    this.dirty = true;
  }

  setGenre(value: string): void {
    this.info.genre = value;
    this.dirty = true;
  }

  get writable(): boolean {
    return serverStore.canRead && this.filePath.length > 0 && this.errorText.length === 0;
  }
}

export const tagStore: TagStore = new TagStore();
