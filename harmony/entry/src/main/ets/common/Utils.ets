/**
 * 通用工具：数值裁剪、去重、稳定哈希、并发限制、退避重试与防抖。
 */
export class Utils {
  private static seqCounter: number = 0;

  static clamp(value: number, min: number, max: number): number {
    if (Number.isNaN(value)) {
      return min;
    }
    if (value < min) {
      return min;
    }
    if (value > max) {
      return max;
    }
    return value;
  }

  static pad2(value: number): string {
    const v: number = Math.floor(Math.abs(value));
    return v < 10 ? `0${v}` : `${v}`;
  }

  /** 生成 [0, max) 内不重复的 count 个随机索引。 */
  static uniqueIndices(count: number, max: number, exclude: number = -1): number[] {
    const limit: number = Math.min(count, Math.max(max, 0));
    const pool: number[] = [];
    for (let i = 0; i < max; i++) {
      if (i !== exclude) {
        pool.push(i);
      }
    }
    const result: number[] = [];
    for (let i = 0; i < limit && pool.length > 0; i++) {
      const index: number = Math.floor(Math.random() * pool.length);
      result.push(pool[index]);
      pool.splice(index, 1);
    }
    return result;
  }

  /** 取 [0, max) 内不等于 exclude 的随机值。 */
  static randomOther(max: number, exclude: number): number {
    if (max <= 1) {
      return 0;
    }
    let value: number = Math.floor(Math.random() * max);
    let guard: number = 0;
    while (value === exclude && guard < 12) {
      value = Math.floor(Math.random() * max);
      guard++;
    }
    return value;
  }

  static dedupe(items: string[]): string[] {
    const seen: Set<string> = new Set<string>();
    const result: string[] = [];
    for (let i = 0; i < items.length; i++) {
      const item: string = items[i];
      if (!seen.has(item)) {
        seen.add(item);
        result.push(item);
      }
    }
    return result;
  }

  /** 允许重复但保持顺序去重，同时把 head 放到最前。 */
  static promote(items: string[], head: string, limit: number): string[] {
    const merged: string[] = [head];
    for (let i = 0; i < items.length; i++) {
      if (items[i] !== head) {
        merged.push(items[i]);
      }
    }
    return Utils.dedupe(merged).slice(0, limit);
  }

  static hashString(text: string): number {
    let hash: number = 5381;
    for (let i = 0; i < text.length; i++) {
      hash = (hash * 33 + text.charCodeAt(i)) | 0;
    }
    return Math.abs(hash);
  }

  /** 稳定 32 位哈希（FNV-1a 变体），用于生成不依赖运行时随机的曲目标识。 */
  private static fnv1a(text: string, seed: number): number {
    let hash: number = seed;
    for (let i = 0; i < text.length; i++) {
      hash = hash ^ text.charCodeAt(i);
      hash = (hash * 16777619) | 0;
    }
    return hash >>> 0;
  }

  private static hex8(value: number): string {
    const text: string = (value >>> 0).toString(16);
    return text.length >= 8 ? text.substring(0, 8) : '00000000'.substring(0, 8 - text.length) + text;
  }

  /** 稳定标识：两路 FNV 组合成 16 位十六进制字符串（用于封面/曲目缓存键）。 */
  static stableId(text: string): string {
    const first: number = Utils.fnv1a(text, 0x811C9DC5);
    const second: number = Utils.fnv1a(text, 0x01000193);
    return `${Utils.hex8(first)}${Utils.hex8(second)}`;
  }

  /** 请求序号：用于丢弃过期响应。 */
  static nextSeq(): number {
    Utils.seqCounter = Utils.seqCounter + 1;
    return Utils.seqCounter;
  }

  static backoffDelay(attempt: number): number {
    const safe: number = Utils.clamp(attempt, 0, 5);
    return Math.min(400 * Math.pow(2, safe), 5000);
  }

  static safeText(value: string | null | undefined, fallback: string): string {
    if (value === null || value === undefined) {
      return fallback;
    }
    const trimmed: string = value.trim();
    return trimmed.length > 0 ? value : fallback;
  }

  static safeNumber(value: number | null | undefined, fallback: number): number {
    if (value === null || value === undefined || Number.isNaN(value)) {
      return fallback;
    }
    return value;
  }

  static shorten(text: string, max: number): string {
    if (text.length <= max) {
      return text;
    }
    return `${text.substring(0, Math.max(max - 1, 0))}…`;
  }

  static containsIgnoreCase(source: string, keyword: string): boolean {
    if (keyword.length === 0) {
      return true;
    }
    return source.toLowerCase().indexOf(keyword.toLowerCase()) >= 0;
  }

  static delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => {
        resolve();
      }, ms);
    });
  }
}

/** 并发限制器：最多同时执行 limit 个任务，其余排队。 */
export class Limiter {
  private limit: number;
  private active: number = 0;
  private waiting: (() => void)[] = [];

  constructor(limit: number) {
    this.limit = Math.max(1, limit);
  }

  async run(task: () => Promise<void>): Promise<void> {
    if (this.active >= this.limit) {
      await new Promise<void>((resolve) => {
        this.waiting.push(resolve);
      });
    }
    this.active = this.active + 1;
    try {
      await task();
    } finally {
      this.active = this.active - 1;
      const next: (() => void) | undefined = this.waiting.shift();
      if (next !== undefined) {
        next();
      }
    }
  }
}

/** 防抖执行器：合并高频调用，只有停止调用 delay 毫秒后才真正执行。 */
export class Debouncer {
  private timerId: number = -1;
  private delay: number;

  constructor(delay: number) {
    this.delay = delay;
  }

  run(action: () => void): void {
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
    }
    this.timerId = setTimeout(() => {
      this.timerId = -1;
      action();
    }, this.delay);
  }

  cancel(): void {
    if (this.timerId >= 0) {
      clearTimeout(this.timerId);
      this.timerId = -1;
    }
  }
}
