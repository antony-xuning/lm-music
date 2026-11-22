/**
 * 首页容器：顶部 HomeHeader（标题 + 搜索 + 音源/模式双下拉），
 * 下方按模式渲染服务器内容（DiscoverView）或本地扫描结果（LocalHomeView）。
 * 无服务器时强制本地模式；有服务器时恢复上次选择（无历史默认服务器）。
 */
import { AppConstants } from '../common/Constants';
import { HomeHeader } from '../components/HomeHeader';
import { HomeMode } from '../model/LocalScanModels';
import { OnlineSource } from '../model/SettingsModels';
import { DiscoverCollectionParam } from '../model/UiModels';
import { discoverStore } from '../viewmodel/DiscoverStore';
import { layoutStore } from '../viewmodel/LayoutStore';
import { localScanStore } from '../viewmodel/LocalScanStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { serverStore } from '../viewmodel/ServerStore';
import { settingsStore } from '../viewmodel/SettingsStore';
import { scrollChrome } from '../viewmodel/ScrollChromeStore';
import { DiscoverView } from './DiscoverView';
import { LocalHomeView } from './LocalHomeView';

/** 服务端音源代码 → 偏好设置中的在线音源枚举。 */
function toOnlineSource(code: string): OnlineSource {
  if (code === 'wy') {
    return OnlineSource.NETEASE;
  }
  if (code === 'tx') {
    return OnlineSource.QQ;
  }
  if (code === 'kg') {
    return OnlineSource.KUGOU;
  }
  if (code === 'mg') {
    return OnlineSource.MIGU;
  }
  return OnlineSource.KUWO;
}

@ComponentV2
export struct HomeView {
  @Param onOpenCollection: (param: DiscoverCollectionParam) => void = () => {
  };

  private serverAvailable(): boolean {
    return serverStore.configured;
  }

  private effectiveMode(): HomeMode {
    return this.serverAvailable() ? localScanStore.homeMode : HomeMode.LOCAL;
  }

  private selectMode(mode: HomeMode): void {
    if (mode !== localScanStore.homeMode) {
      // 首页内容切换（本地/服务器）时恢复展开态，避免沿用上一列表的折叠状态。
      scrollChrome.reset(0);
    }
    localScanStore.setMode(mode);
    if (mode === HomeMode.SERVER) {
      discoverStore.reloadIfStale();
    }
  }

  private selectSource(code: string): void {
    discoverStore.setSource(code);
    settingsStore.setOnlineSource(toOnlineSource(code));
    // 切换音源后按 5 分钟缓存策略重新加载（命中缓存则直接复用）。
    discoverStore.load(false);
  }

  private openSettings(): void {
    overlayStore.setTab(3);
  }

  build() {
    Column() {
      Column() {
        HomeHeader({
          mode: this.effectiveMode(),
          source: discoverStore.source,
          serverAvailable: this.serverAvailable(),
          searchCollapsed: scrollChrome.searchCollapsed,
          onModeChange: (mode: HomeMode) => {
            this.selectMode(mode);
          },
          onSourceChange: (code: string) => {
            this.selectSource(code);
          },
          onSearch: () => {
            overlayStore.openSearch();
          },
          onNeedServer: () => {
            this.openSettings();
          }
        })
      }
      .width('100%')
      .padding({ left: layoutStore.gutter, right: layoutStore.gutter, top: 6, bottom: 6 })

      if (this.effectiveMode() === HomeMode.SERVER) {
        DiscoverView({
          onOpenCollection: (param: DiscoverCollectionParam) => {
            this.onOpenCollection(param);
          }
        })
          .layoutWeight(1)
      } else {
        LocalHomeView()
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .constraintSize({ maxWidth: AppConstants.MAX_CONTENT_WIDTH })
  }
}
