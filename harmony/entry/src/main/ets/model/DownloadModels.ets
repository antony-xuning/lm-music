/**
 * 下载任务模型与存储看板。
 */
export enum DownloadStatus {
  WAITING = 'waiting',
  DOWNLOADING = 'downloading',
  PAUSED = 'paused',
  COMPLETED = 'completed',
  FAILED = 'failed'
}

@ObservedV2
export class DownloadTask {
  id: string = '';
  songId: string = '';
  @Trace title: string = '';
  @Trace artist: string = '';
  coverSeed: number = 0;
  quality: string = 'FLAC';
  @Trace status: DownloadStatus = DownloadStatus.WAITING;
  @Trace progress: number = 0;
  @Trace bytesDone: number = 0;
  bytesTotal: number = 0;
  @Trace speedKbps: number = 0;
  @Trace completedAt: number = 0;
  localPath: string = '';

  static create(id: string, songId: string, title: string, artist: string, seed: number, quality: string,
    bytesTotal: number, status: DownloadStatus, progress: number): DownloadTask {
    const task: DownloadTask = new DownloadTask();
    task.id = id;
    task.songId = songId;
    task.title = title;
    task.artist = artist;
    task.coverSeed = seed;
    task.quality = quality;
    task.status = status;
    task.progress = progress;
    task.bytesTotal = bytesTotal;
    task.bytesDone = Math.floor(bytesTotal * progress / 100);
    task.localPath = `sandbox:downloads/${songId}.flac`;
    return task;
  }

  get active(): boolean {
    return this.status === DownloadStatus.DOWNLOADING || this.status === DownloadStatus.WAITING;
  }
}

export class StorageSummary {
  downloadedCount: number = 0;
  usedBytes: number = 0;
  totalBytes: number = 0;

  get freeBytes(): number {
    return Math.max(this.totalBytes - this.usedBytes, 0);
  }
}

export class DownloadStatusHelper {
  static label(status: DownloadStatus): string {
    if (status === DownloadStatus.WAITING) {
      return '等待中';
    }
    if (status === DownloadStatus.DOWNLOADING) {
      return '下载中';
    }
    if (status === DownloadStatus.PAUSED) {
      return '已暂停';
    }
    if (status === DownloadStatus.COMPLETED) {
      return '已完成';
    }
    return '下载失败';
  }
}
