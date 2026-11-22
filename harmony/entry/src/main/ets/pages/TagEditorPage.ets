/**
 * 标签编辑路由页。
 */
import { TagEditorView } from '../views/TagEditorView';
import { TagEditorParam } from '../model/UiModels';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct TagEditorPage {
  @Local filePath: string = '';

  build() {
    NavDestination() {
      Column() {
        TagEditorView({ filePath: this.filePath })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(themeStore.palette.bg)
    }
    .title('标签编辑')
    .mode(NavDestinationMode.STANDARD)
    .backgroundColor(themeStore.palette.bg)
    .onReady((ctx: NavDestinationContext) => {
      if (ctx.pathInfo.param !== undefined) {
        const param = ctx.pathInfo.param as TagEditorParam;
        if (param !== null && param !== undefined) {
          this.filePath = param.filePath;
        }
      }
    })
  }
}

@Builder
export function TagEditorBuilder() {
  TagEditorPage()
}
