/**
 * 播客订阅管理：查看全部订阅、刷新、取消订阅。
 */
import { Artwork } from '../components/Artwork';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { EmptyState } from '../components/EmptyState';
import { PodcastOpResult } from '../service/PodcastService';
import { PodcastFeed } from '../model/ServerModels';
import { PodcastShowParam } from '../model/UiModels';
import { AppConstants } from '../common/Constants';
import { layoutStore } from '../viewmodel/LayoutStore';
import { podcastStore } from '../viewmodel/PodcastStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { ImmersiveGlass } from '../common/ImmersiveGlass';

@ComponentV2
export struct PodcastManagePage {
  @Local navStack: NavPathStack = new NavPathStack();

  aboutToAppear(): void {
    podcastStore.loadFeeds();
  }

  private confirmUnsubscribe(feed: PodcastFeed): void {
    ConfirmDialog.confirm(this.getUIContext(), '取消订阅', `确定取消订阅「${feed.title}」？`, '取消订阅')
      .then((ok: boolean) => {
        if (ok) {
          podcastStore.unsubscribe(feed.id).then((result: PodcastOpResult) => {
            ConfirmDialog.toast(this.getUIContext(), result.message);
          });
        }
      });
  }

  private refresh(feed: PodcastFeed): void {
    podcastStore.refreshFeed(feed.id).then((result: PodcastOpResult) => {
      ConfirmDialog.toast(this.getUIContext(), result.message);
    });
  }

  @Builder
  feedRow(feed: PodcastFeed) {
    Row({ space: 10 }) {
      Artwork({
        seed: Math.abs(feed.title.length) % 12,
        artworkSize: 44,
        radius: 12,
        title: feed.title,
        showRing: false,
        showInitial: false,
        remoteUrl: feed.coverUrl
      })
      Column({ space: 2 }) {
        Text(feed.title)
          .fontSize(13)
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${feed.author.length > 0 ? feed.author + ' · ' : ''}${feed.episodeCount} 集`)
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Text('刷新')
        .fontSize(10.5)
        .fontColor(themeStore.palette.text)
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .borderRadius(10)
        .backgroundColor('#22FFFFFF')
        .onClick(() => {
          this.refresh(feed);
        })

      Text('取消')
        .fontSize(10.5)
        .fontColor('#FFFFFF')
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .borderRadius(10)
        .backgroundColor('#8A2B36')
        .onClick(() => {
          this.confirmUnsubscribe(feed);
        })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      this.navStack.pushPathByName(AppConstants.ROUTE_PODCAST_SHOW, PodcastShowParam.create(feed.id));
    })
  }

  build() {
    NavDestination() {
      Column({ space: 10 }) {
        if (podcastStore.feeds.length === 0) {
          EmptyState({
            title: podcastStore.loading ? '正在读取订阅' : '还没有订阅节目',
            description: podcastStore.errorText.length > 0 ? podcastStore.errorText : '在播客页添加 RSS 订阅',
            actionText: podcastStore.errorText.length > 0 ? '重试' : '',
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand,
            onAction: () => {
              podcastStore.loadFeeds();
            }
          })
            .layoutWeight(1)
        } else {
          List() {
            ForEach(podcastStore.feeds, (feed: PodcastFeed) => {
              ListItem() {
                this.feedRow(feed)
              }
            }, (feed: PodcastFeed) => feed.id)
          }
          .width('100%')
          .layoutWeight(1)
          .divider({ strokeWidth: 0.5, color: '#14FFFFFF' })
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: layoutStore.gutter, right: layoutStore.gutter, top: 8 })
      .linearGradient({ angle: ImmersiveGlass.ANGLE, colors: ImmersiveGlass.backdrop() })
    }
    .title('订阅管理')
    .mode(NavDestinationMode.STANDARD)
    .backgroundColor(themeStore.palette.bg)
    .systemMaterial(ImmersiveGlass.title())
    .onReady((ctx: NavDestinationContext) => {
      this.navStack = ctx.pathStack;
    })
  }
}

@Builder
export function PodcastManageBuilder() {
  PodcastManagePage()
}
