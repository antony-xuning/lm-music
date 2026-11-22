/**
 * 播放器收缩/展开过渡 Store（US19 / FR-161–FR-172）。
 *
 * 单一 `progress`（0=迷你播放器/折叠胶囊矩形，1=全屏）驱动整段过渡：
 * Index 按窗口与底栏几何算目标矩形，FullscreenPlayer 用 progress lerp 出
 * 尺寸/位移/圆角/透明度，并由组件内的 @Local 补间值做 animateTo 插值；
 * 迷你播放器与折叠胶囊只在过渡结束后出现，避免双影。
 *
 * 中断：补间值从当前值续接到新目标，反向切换不跳变。
 * 降级：系统「减少动效」或算力不足时矩形退化为整屏，只做 150ms 淡入淡出。
 */
import { accessibility } from '@kit.AccessibilityKit';
import { Logger } from '../common/Logger';

const SCOPE: string = 'PlayerTransitionStore';

export enum PlayerTransitionPhase {
  IDLE = 'idle',
  OPENING = 'opening',
  CLOSING = 'closing'
}

/** 过渡终点矩形（vp，相对播放器所在层）：用户点开的迷你播放器/折叠胶囊位置。 */
@ObservedV2
export class PlayerTargetRect {
  @Trace left: number = 0;
  @Trace top: number = 0;
  @Trace width: number = 0;
  @Trace height: number = 0;
  @Trace screenWidth: number = 360;
  @Trace screenHeight: number = 780;

  update(left: number, top: number, width: number, height: number, screenWidth: number,
    screenHeight: number): void {
    this.left = left;
    this.top = top;
    this.width = width;
    this.height = height;
    this.screenWidth = screenWidth;
    this.screenHeight = screenHeight;
  }

  /** 退化到整屏（无曲目/降级动效时不做位移与缩放）。 */
  toFullScreen(): void {
    this.left = 0;
    this.top = 0;
    this.width = this.screenWidth;
    this.height = this.screenHeight;
  }
}

@ObservedV2
export class PlayerTransitionStore {
  @Trace visible: boolean = false;
  @Trace progress: number = 0;
  @Trace animating: boolean = false;
  @Trace phase: PlayerTransitionPhase = PlayerTransitionPhase.IDLE;
  @Trace collapsedAtOpen: boolean = false;
  @Trace reduceMotion: boolean = false;
  @Trace targetRect: PlayerTargetRect = new PlayerTargetRect();

  private hiddenListener: () => void = () => {
  };
  private mounted: boolean = false;
  private pendingOpen: boolean = false;
  private token: number = 0;

  /** 正常过渡时长（FR-161：280–320ms）。 */
  static readonly DURATION_MS: number = 300;
  /** 降级淡入淡出时长（FR-172）。 */
  static readonly FADE_MS: number = 150;

  /** 供 FullscreenPlayer 的隐式动画使用的时长。 */
  get animationDuration(): number {
    return this.reduceMotion ? PlayerTransitionStore.FADE_MS : PlayerTransitionStore.DURATION_MS;
  }

  /** 过渡收起完成（播放器节点卸载）时由 Index 同步叠加层状态。 */
  setHiddenListener(listener: () => void): void {
    this.hiddenListener = listener;
  }

  setReduceMotion(value: boolean): void {
    this.reduceMotion = value;
  }

  /** 读取系统「减少动效」开关；读取失败时保持完整动效。 */
  refreshReduceMotion(): void {
    try {
      this.reduceMotion = accessibility.isAnimationReduceEnabledSync();
    } catch (error) {
      Logger.warn(SCOPE, 'animation reduce state unavailable');
    }
  }

  /** FullscreenPlayer 挂载：首次打开时在这里启动放大动画（挂载帧才有 progress=0 的起点）。 */
  notifyMounted(): void {
    this.mounted = true;
    if (!this.pendingOpen) {
      return;
    }
    this.pendingOpen = false;
    const current: number = this.token;
    // 等挂载帧先按 progress=0 渲染一帧，再切到 1，隐式动画才有起点。
    setTimeout(() => {
      if (current !== this.token || this.phase !== PlayerTransitionPhase.OPENING) {
        return;
      }
      this.runOpen(current);
    }, 48);
  }

  notifyUnmounted(): void {
    this.mounted = false;
  }

  /** 打开：从目标矩形放大到全屏；无曲目/降级时直接整屏淡入。 */
  open(rect: PlayerTargetRect, collapsed: boolean, animate: boolean): void {
    this.applyTarget(rect, animate);
    this.collapsedAtOpen = collapsed;
    if (this.phase === PlayerTransitionPhase.OPENING) {
      // 已在放大中：保持目标矩形与进行中的动画，不重启（避免抖动）。
      this.visible = true;
      return;
    }
    this.token++;
    const current: number = this.token;
    if (!animate) {
      this.visible = true;
      this.progress = 1;
      this.animating = false;
      this.phase = PlayerTransitionPhase.IDLE;
      return;
    }
    // 关闭途中再次打开：从当前 progress 续接到 1，不回到 0（FR-166）。
    const resuming: boolean = this.visible && this.progress > 0.001;
    this.visible = true;
    if (!resuming) {
      this.progress = 0;
    }
    this.animating = true;
    this.phase = PlayerTransitionPhase.OPENING;
    if (this.mounted) {
      this.runOpen(current);
    } else {
      this.pendingOpen = true;
    }
  }

  /** 关闭：缩回目标矩形后卸载；无曲目/降级时直接收起。 */
  close(rect: PlayerTargetRect, collapsed: boolean, animate: boolean): void {
    if (!this.visible) {
      this.hiddenListener();
      return;
    }
    if (this.phase === PlayerTransitionPhase.CLOSING) {
      return;
    }
    this.applyTarget(rect, animate);
    this.collapsedAtOpen = collapsed;
    this.token++;
    const current: number = this.token;
    if (!animate) {
      this.completeClose();
      return;
    }
    this.animating = true;
    this.phase = PlayerTransitionPhase.CLOSING;
    this.progress = 0;
    setTimeout(() => {
      if (current !== this.token || this.phase !== PlayerTransitionPhase.CLOSING) {
        return;
      }
      this.completeClose();
    }, this.animationDuration + 40);
  }

  /** 归一化的过渡进度（0..1）。 */
  setProgress(value: number): void {
    this.progress = value < 0 ? 0 : (value > 1 ? 1 : value);
  }

  /** 是否处于过渡中（用于阻断底层点击，FR-170）。 */
  get transitioning(): boolean {
    return this.visible || this.animating;
  }

  private runOpen(current: number): void {
    this.progress = 1;
    setTimeout(() => {
      if (current !== this.token) {
        return;
      }
      if (this.progress >= 0.999) {
        this.animating = false;
        this.phase = PlayerTransitionPhase.IDLE;
      }
    }, this.animationDuration + 40);
  }

  /** 降级/无曲目时把目标矩形退化为整屏，只保留透明度淡入淡出。 */
  private applyTarget(rect: PlayerTargetRect, animate: boolean): void {
    this.targetRect.update(rect.left, rect.top, rect.width, rect.height, rect.screenWidth, rect.screenHeight);
    if (!animate || this.reduceMotion) {
      this.targetRect.toFullScreen();
    }
  }

  private completeClose(): void {
    this.progress = 0;
    this.visible = false;
    this.animating = false;
    this.phase = PlayerTransitionPhase.IDLE;
    this.pendingOpen = false;
    this.hiddenListener();
  }
}

export const playerTransition: PlayerTransitionStore = new PlayerTransitionStore();






