/**
 * 滚动折叠状态：主页面滚动 → 底栏折叠（页签栏 + 完整播放器隐藏）
 * → 显示紧凑胶囊；下滑或回顶恢复。搜索框与折叠态同步收起。
 *
 * 阈值：上滑累计 120vp 折叠，下滑累计 40vp 展开（迟滞防抖）；
 * 上报节流 50ms，避免每帧写状态。
 */
export enum ChromeDirection {
  IDLE = 'idle',
  UP = 'up',
  DOWN = 'down'
}

@ObservedV2
export class ScrollChromeStore {
  @Trace collapsed: boolean = false;
  @Trace searchCollapsed: boolean = false;
  @Trace direction: ChromeDirection = ChromeDirection.IDLE;
  @Trace activeTab: number = 0;
  /** 回顶信号序号：首页列表订阅后滚动到顶部。 */
  @Trace homeTopRequest: number = 0;

  private lastOffset: number = 0;
  private lastReportAt: number = 0;
  private pendingMovement: number = 0;
  private upAccum: number = 0;
  private downAccum: number = 0;
  private hasBaseline: boolean = false;
  private suppressUntil: number = 0;
  private homeTopHandler: (() => void) | null = null;
  private homeTopToken: number = 0;
  private pendingHomeTop: boolean = false;

  /**
   * 主列表滚动回调：offset 为当前偏移（vp），delta 为本帧位移。
   * 用偏移差判定方向（不依赖不同组件对 delta 符号的实现差异）。
   */
  report(offset: number, delta: number): void {
    const safeOffset: number = Math.max(0, offset);
    const now: number = Date.now();

    // 首次上报只建立基线（例如切换页签后该页仍停留在原滚动位置）。
    if (!this.hasBaseline) {
      this.hasBaseline = true;
      this.lastOffset = safeOffset;
      this.pendingMovement = 0;
      this.lastReportAt = now;
      if (safeOffset <= 2) {
        this.setCollapsed(false);
      }
      return;
    }

    this.pendingMovement += safeOffset - this.lastOffset;
    this.lastOffset = safeOffset;

    // 回顶立即展开（不等节流，避免停在顶部仍保持折叠）。
    if (safeOffset <= 2) {
      this.pendingMovement = 0;
      this.upAccum = 0;
      this.downAccum = 0;
      this.setCollapsed(false);
      return;
    }

    // 折叠/展开会改变内容底部留白，可能引起一次偏移夹取；短暂忽略避免抖动。
    if (now < this.suppressUntil) {
      this.pendingMovement = 0;
      this.lastReportAt = now;
      return;
    }

    if (now - this.lastReportAt < 50) {
      return;
    }
    this.lastReportAt = now;

    const step: number = this.pendingMovement;
    this.pendingMovement = 0;
    if (step > 0.5) {
      this.direction = ChromeDirection.UP;
      this.upAccum += step;
      this.downAccum = 0;
      if (!this.collapsed && this.upAccum >= 120) {
        this.upAccum = 0;
        this.setCollapsed(true);
      }
    } else if (step < -0.5) {
      this.direction = ChromeDirection.DOWN;
      this.downAccum += -step;
      this.upAccum = 0;
      if (this.collapsed && this.downAccum >= 40) {
        this.downAccum = 0;
        this.setCollapsed(false);
      }
    }
  }

  /** 切换主页面：折叠状态重置为展开，各页面滚动互不影响。 */
  reset(tabIndex: number): void {
    this.activeTab = tabIndex;
    this.lastOffset = 0;
    this.lastReportAt = 0;
    this.pendingMovement = 0;
    this.upAccum = 0;
    this.downAccum = 0;
    this.hasBaseline = false;
    this.suppressUntil = 0;
    this.direction = ChromeDirection.IDLE;
    this.setCollapsed(false);
  }

  /** 请求首页列表回顶（折叠胶囊的首页圆钮）。 */
  requestHomeTop(): void {
    this.homeTopRequest = this.homeTopRequest + 1;
    this.pendingHomeTop = true;
    const handler: (() => void) | null = this.homeTopHandler;
    if (handler !== null) {
      this.pendingHomeTop = false;
      handler();
    }
  }

  /** 首页列表挂载时注册回顶处理器，返回注销令牌。 */
  setHomeTopHandler(handler: () => void): number {
    this.homeTopToken = this.homeTopToken + 1;
    this.homeTopHandler = handler;
    return this.homeTopToken;
  }

  clearHomeTopHandler(token: number): void {
    if (token === this.homeTopToken) {
      this.homeTopHandler = null;
    }
  }

  /** 首页列表挂载后消费挂起中的回顶请求（避免 Scroller 未绑定）。 */
  consumePendingHomeTop(): boolean {
    if (!this.pendingHomeTop) {
      return false;
    }
    this.pendingHomeTop = false;
    return true;
  }

  private setCollapsed(value: boolean): void {
    if (this.collapsed === value) {
      return;
    }
    this.collapsed = value;
    this.searchCollapsed = value;
    this.suppressUntil = Date.now() + 300;
  }
}

export const scrollChrome: ScrollChromeStore = new ScrollChromeStore();
