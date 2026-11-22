/**
 * 统一格式化：时长、字节、日期、数量、音质徽章。
 */
export class Formatters {
  static duration(ms: number): string {
    if (ms <= 0 || Number.isNaN(ms)) {
      return '0:00';
    }
    const totalSeconds: number = Math.floor(ms / 1000);
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    return `${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  static clock(ms: number): string {
    if (ms <= 0) {
      return '00:00';
    }
    const totalSeconds: number = Math.floor(ms / 1000);
    const minutes: number = Math.floor(totalSeconds / 60);
    const seconds: number = totalSeconds % 60;
    return `${minutes < 10 ? '0' : ''}${minutes}:${seconds < 10 ? '0' : ''}${seconds}`;
  }

  static bytes(value: number): string {
    if (value <= 0) {
      return '0 B';
    }
    if (value < 1024) {
      return `${Math.round(value)} B`;
    }
    const kb: number = value / 1024;
    if (kb < 1024) {
      return `${kb.toFixed(1)} KB`;
    }
    const mb: number = kb / 1024;
    if (mb < 1024) {
      return `${mb.toFixed(1)} MB`;
    }
    return `${(mb / 1024).toFixed(2)} GB`;
  }

  static date(timestamp: number): string {
    if (timestamp <= 0) {
      return '—';
    }
    const date: Date = new Date(timestamp);
    const month: number = date.getMonth() + 1;
    const day: number = date.getDate();
    return `${date.getFullYear()}-${month < 10 ? '0' : ''}${month}-${day < 10 ? '0' : ''}${day}`;
  }

  static relativeDate(timestamp: number): string {
    if (timestamp <= 0) {
      return '—';
    }
    const diff: number = Date.now() - timestamp;
    const day: number = 86400000;
    if (diff < 3600000) {
      return '刚刚';
    }
    if (diff < day) {
      return `${Math.floor(diff / 3600000)} 小时前`;
    }
    if (diff < day * 30) {
      return `${Math.floor(diff / day)} 天前`;
    }
    return Formatters.date(timestamp);
  }

  static count(value: number): string {
    return `${value} 首`;
  }

  static bitRate(bitRate: number): string {
    return bitRate >= 1000 ? `${bitRate} kbps` : `${bitRate} kbps`;
  }

  static qualityBadge(format: string, bitRate: number): string {
    return `${format} · ${Formatters.bitRate(bitRate)}`;
  }

  static speed(kbps: number): string {
    if (kbps <= 0) {
      return '—';
    }
    return kbps >= 1024 ? `${(kbps / 1024).toFixed(1)} MB/s` : `${Math.round(kbps)} KB/s`;
  }

  static percent(value: number): string {
    return `${Math.round(value)}%`;
  }
}
