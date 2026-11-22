import { common } from '@kit.AbilityKit';

/**
 * 全局 Ability 上下文持有者。
 * 非 UI 层（服务、持久化）不直接调用 getContext(this)，统一从这里取上下文，
 * 避免在非组件类中使用只能用于组件的 API。
 */
class ContextHolder {
  private abilityContext: common.UIAbilityContext | null = null;
  private filesDirPath: string = '';
  private cacheDirPath: string = '';

  init(context: common.UIAbilityContext): void {
    this.abilityContext = context;
    this.filesDirPath = context.filesDir;
    this.cacheDirPath = context.cacheDir;
  }

  get context(): common.UIAbilityContext | null {
    return this.abilityContext;
  }

  get filesDir(): string {
    return this.filesDirPath;
  }

  get cacheDir(): string {
    return this.cacheDirPath;
  }

  get ready(): boolean {
    return this.abilityContext !== null;
  }
}

export const AppContextHolder: ContextHolder = new ContextHolder();
