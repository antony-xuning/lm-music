/**
 * 播客首页（覆盖层）：服务端订阅列表、添加 RSS 订阅、进入节目详情。
 */
import { Artwork } from '../components/Artwork';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { EmptyState } from '../components/EmptyState';
import { SectionHeader } from '../components/SectionHeader';
import { AppConstants } from '../common/Constants';
import { PodcastFeed } from '../model/ServerModels';
import { PodcastOpResult } from '../service/PodcastService';
import { layoutStore } from '../viewmodel/LayoutStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { podcastStore } from '../viewmodel/PodcastStore';
import { serverStore } from '../viewmodel/ServerStore';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct PodcastHomeView {
  @Param onOpenShow: (showId: string) => void = () => {
  };
  @Param onOpenManage: () => void = () => {
  };
  @Local showAdd: boolean = false;
  @Local rssUrl: string = '';
  @Local busy: boolean = false;
  @Local errorText: string = '';

  aboutToAppear(): void {
    podcastStore.loadFeeds();
  }

  private async submit(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const result: PodcastOpResult = await podcastStore.subscribe(this.rssUrl);
      if (result.ok) {
        this.rssUrl = '';
        this.showAdd = false;
        ConfirmDialog.toast(this.getUIContext(), result.message);
      } else {
        this.errorText = result.message;
      }
    } finally {
      this.busy = false;
    }
  }

  @Builder
  header() {
    Row({ space: 10 }) {
      Stack() {
        Image($r('app.media.ic_close'))
          .width(17)
          .height(17)
          .fillColor(themeStore.palette.text)
      }
      .width(34)
      .height(34)
      .borderRadius(17)
      .backgroundColor('#22FFFFFF')
      .onClick(() => {
        overlayStore.closePodcast();
      })

      Column({ space: 1 }) {
        Text('播客')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
        Text(`${podcastStore.feeds.length} 个订阅 · 来自你的音乐服务器`)
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Stack() {
        Image($r('app.media.ic_settings'))
          .width(16)
          .height(16)
          .fillColor(themeStore.palette.text)
      }
      .width(34)
      .height(34)
      .borderRadius(17)
      .backgroundColor('#22FFFFFF')
      .onClick(() => {
        this.onOpenManage();
      })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  addCard() {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Image($r('app.media.ic_plus'))
          .width(14)
          .height(14)
          .fillColor('#FFFFFF')
        Text(this.busy ? '订阅中…' : '添加 RSS 订阅')
          .fontSize(12.5)
          .fontColor('#FFFFFF')
      }
      .padding({ left: 14, right: 14, top: 9, bottom: 9 })
      .borderRadius(16)
      .backgroundColor(themeStore.palette.brand)
      .onClick(() => {
        this.showAdd = !this.showAdd;
      })

      if (this.showAdd) {
        Row({ space: 8 }) {
          TextInput({ text: this.rssUrl, placeholder: 'https://example.com/feed.xml' })
            .fontSize(12)
            .fontColor(themeStore.palette.text)
            .placeholderColor(themeStore.palette.sub)
            .layoutWeight(1)
            .height(38)
            .backgroundColor('#22FFFFFF')
            .borderRadius(12)
            .onChange((value: string) => {
              this.rssUrl = value;
            })
          Text('订阅')
            .fontSize(12)
            .fontColor('#FFFFFF')
            .padding({ left: 14, right: 14, top: 9, bottom: 9 })
            .borderRadius(12)
            .backgroundColor(themeStore.palette.brand)
            .onClick(() => {
              this.submit();
            })
        }
        .width('100%')
      }

      if (this.errorText.length > 0) {
        Text(this.errorText)
          .fontSize(10.5)
          .fontColor('#FFB44C')
          .width('100%')
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  feedCard(feed: PodcastFeed) {
    Row({ space: 10 }) {
      Artwork({
        seed: Math.abs(feed.title.length) % 12,
        artworkSize: 56,
        radius: 14,
        title: feed.title,
        showRing: true,
        showInitial: false,
        remoteUrl: feed.coverUrl
      })
      Column({ space: 3 }) {
        Text(feed.title)
          .fontSize(13.5)
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${feed.author.length > 0 ? feed.author + ' · ' : ''}${feed.episodeCount} 集`)
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
        if (feed.description.length > 0) {
          Text(feed.description)
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Image($r('app.media.ic_next'))
        .width(14)
        .height(14)
        .fillColor(themeStore.palette.sub)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .borderRadius(16)
    .backgroundColor(themeStore.palette.card)
    .onClick(() => {
      this.onOpenShow(feed.id);
    })
  }

  build() {
    Stack() {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor(themeStore.palette.bg)

      Scroll() {
        Column({ space: 14 }) {
          this.header()
          this.addCard()

          if (!serverStore.canRead) {
            EmptyState({
              title: '尚未连接柠檬音乐服务器',
              description: '连接服务器后可管理播客订阅',
              actionText: '去设置',
              textColor: themeStore.palette.text,
              subColor: themeStore.palette.sub,
              accent: themeStore.palette.brand,
              onAction: () => {
                overlayStore.closePodcast();
                overlayStore.setTab(3);
              }
            })
          } else if (podcastStore.feeds.length === 0) {
            EmptyState({
              title: podcastStore.loading ? '正在读取订阅' : '还没有订阅节目',
              description: podcastStore.errorText.length > 0 ? podcastStore.errorText : '点击「添加 RSS 订阅」输入节目地址',
              actionText: podcastStore.errorText.length > 0 ? '重试' : '',
              textColor: themeStore.palette.text,
              subColor: themeStore.palette.sub,
              accent: themeStore.palette.brand,
              onAction: () => {
                podcastStore.loadFeeds();
              }
            })
          } else {
            Column({ space: 8 }) {
              SectionHeader({
                title: '我的订阅',
                subtitle: '点开节目查看全部单集',
                textColor: themeStore.palette.text,
                subColor: themeStore.palette.sub
              })
              ForEach(podcastStore.feeds, (feed: PodcastFeed) => {
                this.feedCard(feed)
              }, (feed: PodcastFeed) => feed.id)
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
          }

          Text('播客内容由你订阅的 RSS 通过音乐服务器抓取提供。')
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
            .width('100%')
            .padding({ top: 6, bottom: 30 })
        }
        .width('100%')
        .padding({ left: layoutStore.gutter, right: layoutStore.gutter, top: 10, bottom: 40 })
        .constraintSize({ maxWidth: AppConstants.MAX_CONTENT_WIDTH })
        .alignItems(HorizontalAlign.Start)
      }
      .scrollBar(BarState.Off)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
  }
}
