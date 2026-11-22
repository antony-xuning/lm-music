/**
 * 音源管理路由页。
 */
import { SourceManageView } from '../views/SourceManageView';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct SourceManagePage {
  build() {
    NavDestination() {
      Column() {
        SourceManageView()
      }
      .width('100%')
      .height('100%')
      .backgroundColor(themeStore.palette.bg)
    }
    .title('音源脚本管理')
    .mode(NavDestinationMode.STANDARD)
    .backgroundColor(themeStore.palette.bg)
  }
}

@Builder
export function SourceManageBuilder() {
  SourceManagePage()
}
