/**
 * 设置页：账号音源 / 播放 / 下载存储 / 外观 / 关于 五个分类。
 */
import { layoutStore } from '../viewmodel/LayoutStore';
import { ThemeHelper } from '../model/SettingsModels';
import { settingsStore } from '../viewmodel/SettingsStore';
import { AppConstants, DockMetrics } from '../common/Constants';
import { themeStore } from '../viewmodel/ThemeStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { scrollChrome } from '../viewmodel/ScrollChromeStore';
import { SettingsAccountSection } from './SettingsAccountSection';
import {
  SettingsAboutSection,
  SettingsAppearanceSection,
  SettingsDownloadSection,
  SettingsPlaybackSection
} from './SettingsSections';

const CATEGORIES: string[] = ['账号音源', '播放', '下载存储', '外观', '关于'];

@ComponentV2
export struct SettingsView {
  @Param onOpenRoute: (route: string) => void = () => {
  };
  @Local category: number = 2;
  private scroller: Scroller = new Scroller();

  @Builder
  categoryChip(label: string, index: number) {
    Text(label)
      .fontSize(11.5)
      .fontColor(this.category === index ? '#FFFFFF' : themeStore.palette.sub)
      .padding({ left: 13, right: 13, top: 7, bottom: 7 })
      .borderRadius(15)
      .backgroundColor(this.category === index ? themeStore.palette.brand : '#1F1F26')
      .onClick(() => {
        this.category = index;
      })
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 14 }) {
        Row({ space: 10 }) {
          Column({ space: 2 }) {
            Text('设置')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(themeStore.palette.text)
            Text('偏好会自动保存，重启后保持')
              .fontSize(11)
              .fontColor(themeStore.palette.sub)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(ThemeHelper.label(settingsStore.prefs.themeMode))
            .fontSize(10)
            .fontColor(themeStore.palette.sub)

          Stack() {
            Image($r('app.media.ic_search'))
              .width(16)
              .height(16)
              .fillColor(themeStore.palette.text)
          }
          .width(32)
          .height(32)
          .borderRadius(16)
          .backgroundColor(themeStore.palette.controlBg)
          .margin({ left: 8 })
          .onClick(() => {
            overlayStore.openSearch();
          })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Scroll() {
          Row({ space: 8 }) {
            ForEach(CATEGORIES, (label: string, index: number) => {
              this.categoryChip(label, index)
            }, (label: string) => label)
          }
          .padding({ right: 8 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')

        if (this.category === 0) {
          SettingsAccountSection()
        } else if (this.category === 1) {
          SettingsPlaybackSection()
        } else if (this.category === 2) {
          SettingsDownloadSection()
        } else if (this.category === 3) {
          SettingsAppearanceSection()
        } else {
          SettingsAboutSection()
        }

        if (this.category === 0 || this.category === 4) {
        Column({ space: 2 }) {
          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text('音源脚本管理')
                .fontSize(13)
                .fontColor(themeStore.palette.text)
              Text('查看脚本、启停平台与导入新音源')
                .fontSize(10)
                .fontColor(themeStore.palette.sub)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Image($r('app.media.ic_next'))
              .width(14)
              .height(14)
              .fillColor(themeStore.palette.sub)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .onClick(() => {
            this.onOpenRoute(AppConstants.ROUTE_SOURCE_MANAGE);
          })

          Divider()
            .color(themeStore.palette.softDivider)
            .margin({ left: 14, right: 14 })

          Row({ space: 8 }) {
            Column({ space: 2 }) {
              Text('播客订阅')
                .fontSize(13)
                .fontColor(themeStore.palette.text)
              Text('管理 RSS 订阅与单集播放')
                .fontSize(10)
                .fontColor(themeStore.palette.sub)
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Image($r('app.media.ic_next'))
              .width(14)
              .height(14)
              .fillColor(themeStore.palette.sub)
          }
          .width('100%')
          .padding({ left: 14, right: 14, top: 12, bottom: 12 })
          .onClick(() => {
            overlayStore.openPodcast();
          })
        }
        .width('100%')
        .borderRadius(16)
        .backgroundColor(themeStore.palette.card)
        }

        Column({ space: 4 }) {
          Text('柠檬音乐 · 服务器版')
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
          Text('在线内容由你自建的柠檬音乐服务端提供')
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ top: 10, bottom: 24 })
      }
      .width('100%')
      .padding({ left: layoutStore.gutter, right: layoutStore.gutter, top: 8, bottom: DockMetrics.contentBottomInset(playerStore.current !== null, scrollChrome.collapsed) })
      .constraintSize({ maxWidth: AppConstants.MAX_CONTENT_WIDTH })
      .alignItems(HorizontalAlign.Start)
      .animation({ duration: 220, curve: Curve.EaseOut })
    }
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .width('100%')
    .height('100%')
    .onDidScroll((delta: number, state: ScrollState) => {
      scrollChrome.reportFromScroller(this.scroller, delta);
    })
  }
}

