/**
 * 首页顶部：展开态第一行「首页」标题 + [音源下拉][模式下拉]（模式最右），
 * 第二行整宽搜索框；上滑折叠后隐藏第二行，标题右侧出现圆形搜索图标。
 * 本地模式隐藏音源下拉；无服务器时模式下拉的服务器项带「去设置」提示。
 */
import { ServerEndpoints } from '../common/ServerEndpoints';
import { HomeMode } from '../model/LocalScanModels';
import { SelectOptionItem } from '../model/UiModels';
import { layoutStore } from '../viewmodel/LayoutStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { AppSelect } from './AppSelect';

/** 下拉宽度约束：min 88vp / max 140vp（小屏取下限附近，横屏取上限）。 */
const SOURCE_SELECT_WIDTH: number = 92;
const SOURCE_SELECT_WIDTH_WIDE: number = 104;
const MODE_SELECT_WIDTH: number = 124;
const MODE_SELECT_WIDTH_WIDE: number = 140;

@ComponentV2
export struct HomeHeader {
  @Param mode: HomeMode = HomeMode.LOCAL;
  @Param source: string = 'kw';
  @Param serverAvailable: boolean = false;
  @Param searchCollapsed: boolean = false;
  @Event onModeChange: (mode: HomeMode) => void = () => {
  };
  @Event onSourceChange: (code: string) => void = () => {
  };
  @Event onSearch: () => void = () => {
  };
  @Event onNeedServer: () => void = () => {
  };

  private sourceWidth(): number {
    return layoutStore.landscape ? SOURCE_SELECT_WIDTH_WIDE : SOURCE_SELECT_WIDTH;
  }

  private modeWidth(): number {
    return layoutStore.landscape ? MODE_SELECT_WIDTH_WIDE : MODE_SELECT_WIDTH;
  }

  private modeOptions(): SelectOptionItem[] {
    const items: SelectOptionItem[] = [];
    items.push(new SelectOptionItem('local', '本地曲库'));
    items.push(new SelectOptionItem('server',
      this.serverAvailable ? '柠檬音乐服务器' : '柠檬音乐服务器 · 去设置'));
    return items;
  }

  private modeIndex(): number {
    return this.mode === HomeMode.SERVER && this.serverAvailable ? 1 : 0;
  }

  private sourceOptions(): SelectOptionItem[] {
    const codes: string[] = ServerEndpoints.allPlatforms();
    const items: SelectOptionItem[] = [];
    for (let i = 0; i < codes.length; i++) {
      items.push(new SelectOptionItem(codes[i], ServerEndpoints.platformLabel(codes[i])));
    }
    return items;
  }

  private sourceIndex(): number {
    const codes: string[] = ServerEndpoints.allPlatforms();
    for (let i = 0; i < codes.length; i++) {
      if (codes[i] === this.source) {
        return i;
      }
    }
    return 0;
  }

  private handleModeSelect(index: number): void {
    if (index === 0) {
      this.onModeChange(HomeMode.LOCAL);
      return;
    }
    if (!this.serverAvailable) {
      this.onNeedServer();
      return;
    }
    this.onModeChange(HomeMode.SERVER);
  }

  private handleSourceSelect(index: number): void {
    const codes: string[] = ServerEndpoints.allPlatforms();
    if (index < 0 || index >= codes.length) {
      return;
    }
    if (codes[index] !== this.source) {
      this.onSourceChange(codes[index]);
    }
  }

  @Builder
  searchButton() {
    Stack() {
      Image($r('app.media.ic_search'))
        .width(17)
        .height(17)
        .fillColor(themeStore.palette.text)
    }
    .width(32)
    .height(32)
    .borderRadius(16)
    .backgroundColor(themeStore.isDark ? '#22FFFFFF' : '#14000000')
    .onClick(() => {
      this.onSearch();
    })
    .transition(TransitionEffect.OPACITY.animation({ duration: 200 })
      .combine(TransitionEffect.scale({ x: 0.8, y: 0.8 })))
  }

  @Builder
  searchBar() {
    Row({ space: 8 }) {
      Image($r('app.media.ic_search'))
        .width(16)
        .height(16)
        .fillColor(themeStore.palette.sub)
      Text('搜索歌曲、专辑与歌单')
        .fontSize(12.5)
        .fontColor(themeStore.palette.sub)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
    }
    .width('100%')
    .height(36)
    .padding({ left: 14, right: 14 })
    .borderRadius(18)
    .backgroundColor(themeStore.isDark ? '#1FFFFFFF' : '#0F000000')
    .border({ width: 1, color: themeStore.isDark ? '#22FFFFFF' : '#14000000' })
    .onClick(() => {
      this.onSearch();
    })
    .transition(TransitionEffect.OPACITY.animation({ duration: 200 })
      .combine(TransitionEffect.translate({ y: -4 })))
  }

  build() {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        Row({ space: 6 }) {
          Text('首页')
            .fontSize(this.searchCollapsed ? 22 : 24)
            .fontWeight(FontWeight.Bold)
            .fontColor(themeStore.palette.text)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (this.searchCollapsed) {
            this.searchButton()
          }
        }
        .layoutWeight(1)
        .alignItems(VerticalAlign.Center)

        if (this.mode === HomeMode.SERVER) {
          AppSelect({
            options: this.sourceOptions(),
            selectedIndex: this.sourceIndex(),
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand,
            selectWidth: this.sourceWidth(),
            onSelect: (index: number) => {
              this.handleSourceSelect(index);
            }
          })
        }

        AppSelect({
          options: this.modeOptions(),
          selectedIndex: this.modeIndex(),
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          accent: themeStore.palette.brand,
          selectWidth: this.modeWidth(),
          onSelect: (index: number) => {
            this.handleModeSelect(index);
          }
        })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (!this.searchCollapsed) {
        this.searchBar()
      }

      if (!this.serverAvailable && !this.searchCollapsed) {
        Row({ space: 4 }) {
          Text('尚未添加服务器，服务器模式需先在设置中登录')
            .fontSize(10)
            .fontColor(themeStore.palette.sub)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text('去设置')
            .fontSize(10.5)
            .fontColor(themeStore.palette.brand)
            .onClick(() => {
              this.onNeedServer();
            })
        }
        .width('100%')
        .transition(TransitionEffect.OPACITY.animation({ duration: 200 }))
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
    .animation({ duration: 200, curve: Curve.EaseOut })
  }
}
