/**
 * 资料库二级页的列表状态（排序 / 关键词）跨页面保持：
 * 页面被重新 push 时从该单例恢复，避免返回后筛选条件丢失。
 */
export class LibraryViewState {
  private static sortMap: Record<string, number> = {};
  private static keywordMap: Record<string, string> = {};

  static sortOf(key: string): number {
    const value: number | undefined = LibraryViewState.sortMap[key];
    return typeof value === 'number' ? value : 0;
  }

  static keywordOf(key: string): string {
    const value: string | undefined = LibraryViewState.keywordMap[key];
    return typeof value === 'string' ? value : '';
  }

  static setSort(key: string, index: number): void {
    LibraryViewState.sortMap[key] = index;
  }

  static setKeyword(key: string, keyword: string): void {
    LibraryViewState.keywordMap[key] = keyword;
  }
}
