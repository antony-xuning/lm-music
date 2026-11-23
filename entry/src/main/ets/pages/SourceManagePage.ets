/**
 * 音源管理路由页。
 */
import { SourceManageView } from '../views/SourceManageView';
import { themeStore } from '../viewmodel/ThemeStore';
import { ImmersiveGlass } from '../common/ImmersiveGlass';

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
      .linearGradient({ angle: ImmersiveGlass.ANGLE, colors: ImmersiveGlass.backdrop() })
    }
    .title('音源脚本管理')
    .mode(NavDestinationMode.STANDARD)
    .backgroundColor(themeStore.palette.bg)
    .systemMaterial(ImmersiveGlass.title())
  }
}

@Builder
export function SourceManageBuilder() {
  SourceManagePage()
}
