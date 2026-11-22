/**
 * 断点与列数映射：sm < 600vp ≤ md ≤ 840vp < lg。
 */
export enum SizeClass {
  SM = 'sm',
  MD = 'md',
  LG = 'lg'
}

export class Breakpoints {
  static readonly SM_MAX: number = 600;
  static readonly MD_MAX: number = 840;

  static sizeClass(widthVp: number): SizeClass {
    if (widthVp < Breakpoints.SM_MAX) {
      return SizeClass.SM;
    }
    if (widthVp <= Breakpoints.MD_MAX) {
      return SizeClass.MD;
    }
    return SizeClass.LG;
  }

  static isLandscape(widthVp: number, heightVp: number): boolean {
    return widthVp > heightVp;
  }

  /** 卡片网格列数：手机 2 列、中屏 3 列、大屏 4 列。 */
  static gridColumns(sizeClass: SizeClass): number {
    if (sizeClass === SizeClass.LG) {
      return 4;
    }
    if (sizeClass === SizeClass.MD) {
      return 3;
    }
    return 2;
  }

  /** 播放器是否使用左右分栏。 */
  static useWidePlayer(sizeClass: SizeClass, landscape: boolean): boolean {
    return sizeClass === SizeClass.LG || landscape;
  }

  /** 内容最大宽度，避免平板卡片被过度拉伸。 */
  static contentWidth(sizeClass: SizeClass): string {
    if (sizeClass === SizeClass.LG) {
      return '92%';
    }
    if (sizeClass === SizeClass.MD) {
      return '96%';
    }
    return '100%';
  }

  static horizontalGutter(sizeClass: SizeClass): number {
    if (sizeClass === SizeClass.LG) {
      return 32;
    }
    if (sizeClass === SizeClass.MD) {
      return 24;
    }
    return 16;
  }
}
