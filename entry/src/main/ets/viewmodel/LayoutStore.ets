/**
 * 布局 Store：监听宽高断点与横竖屏，向各页面提供列数与大屏形态。
 */
import { mediaquery, UIContext } from '@kit.ArkUI';
import { Breakpoints, SizeClass } from '../common/Breakpoints';
import { Logger } from '../common/Logger';

const SCOPE: string = 'LayoutStore';

@ObservedV2
export class LayoutStore {
  @Trace sizeClass: SizeClass = SizeClass.SM;
  @Trace landscape: boolean = false;
  @Trace attached: boolean = false;

  private listeners: mediaquery.MediaQueryListener[] = [];
  private listenerCallbacks: ((result: mediaquery.MediaQueryResult) => void)[] = [];
  private smMatches: boolean = true;
  private mdMatches: boolean = false;
  private lgMatches: boolean = false;

  attach(context: UIContext): void {
    if (this.attached) {
      return;
    }
    this.attached = true;
    try {
      this.register(context, '(width<600vp)', (matches: boolean) => {
        this.smMatches = matches;
        this.refresh();
      });
      this.register(context, '(600vp<=width<840vp)', (matches: boolean) => {
        this.mdMatches = matches;
        this.refresh();
      });
      this.register(context, '(width>=840vp)', (matches: boolean) => {
        this.lgMatches = matches;
        this.refresh();
      });
      const landscapeListener: mediaquery.MediaQueryListener =
        context.getMediaQuery().matchMediaSync('(orientation: landscape)');
      this.landscape = landscapeListener.matches;
      const landscapeCallback: (result: mediaquery.MediaQueryResult) => void =
        (result: mediaquery.MediaQueryResult): void => {
          this.landscape = result.matches;
        };
      landscapeListener.on('change', landscapeCallback);
      this.listeners.push(landscapeListener);
      this.listenerCallbacks.push(landscapeCallback);
      this.refresh();
    } catch (error) {
      Logger.warn(SCOPE, 'media query unavailable, fallback to phone layout');
    }
  }

  private register(context: UIContext, condition: string, apply: (matches: boolean) => void): void {
    const listener: mediaquery.MediaQueryListener = context.getMediaQuery().matchMediaSync(condition);
    apply(listener.matches);
    const callback: (result: mediaquery.MediaQueryResult) => void =
      (result: mediaquery.MediaQueryResult): void => {
        apply(result.matches);
      };
    listener.on('change', callback);
    this.listeners.push(listener);
    this.listenerCallbacks.push(callback);
  }

  /** 页面卸载时解绑所有媒体查询，避免 Ability 重建后重复监听。 */
  detach(): void {
    if (!this.attached) {
      return;
    }
    for (let i = 0; i < this.listeners.length; i++) {
      try {
        this.listeners[i].off('change', this.listenerCallbacks[i]);
      } catch (error) {
        Logger.warn(SCOPE, 'media query off failed');
      }
    }
    this.listeners = [];
    this.listenerCallbacks = [];
    this.attached = false;
  }

  private refresh(): void {
    if (this.lgMatches) {
      this.sizeClass = SizeClass.LG;
    } else if (this.mdMatches) {
      this.sizeClass = SizeClass.MD;
    } else {
      this.sizeClass = SizeClass.SM;
    }
  }

  get columns(): number {
    return Breakpoints.gridColumns(this.sizeClass);
  }

  get widePlayer(): boolean {
    return Breakpoints.useWidePlayer(this.sizeClass, this.landscape);
  }

  get gutter(): number {
    return Breakpoints.horizontalGutter(this.sizeClass);
  }

  get contentWidth(): string {
    return Breakpoints.contentWidth(this.sizeClass);
  }

  get isLargeScreen(): boolean {
    return this.sizeClass !== SizeClass.SM;
  }
}

export const layoutStore: LayoutStore = new LayoutStore();
