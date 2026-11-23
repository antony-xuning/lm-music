/**
 * 播客节目详情：节目信息、单集分页、播放、刷新与取消订阅。
 */
import { Artwork } from '../components/Artwork';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { EmptyState } from '../components/EmptyState';
import { Formatters } from '../service/Formatters';
import { PodcastOpResult } from '../service/PodcastService';
import { PodcastEpisode, PodcastFeed } from '../model/ServerModels';
import { PodcastShowParam } from '../model/UiModels';
import { layoutStore } from '../viewmodel/LayoutStore';
import { podcastStore } from '../viewmodel/PodcastStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { ImmersiveGlass } from '../common/ImmersiveGlass';

@ComponentV2
export struct PodcastShowPage {
  @Local param: PodcastShowParam = new PodcastShowParam();
  @Local feedId: string = '';

  private feed(): PodcastFeed {
    const found: PodcastFeed | null = podcastStore.findFeed(this.feedId);
    return found !== null ? found : new PodcastFeed();
  }

  private async refresh(): Promise<void> {
    const result: PodcastOpResult = await podcastStore.refreshFeed(this.feedId);
    ConfirmDialog.toast(this.getUIContext(), result.message);
  }

  private confirmUnsubscribe(): void {
    ConfirmDialog.confirm(this.getUIContext(), '取消订阅',
      `确定取消订阅「${this.feed().title}」？`, '取消订阅').then((ok: boolean) => {
      if (ok) {
        podcastStore.unsubscribe(this.feedId).then((result: PodcastOpResult) => {
          ConfirmDialog.toast(this.getUIContext(), result.message);
          if (result.ok) {
            const stack: NavPathStack | null = this.navStack;
            if (stack !== null) {
              stack.pop();
            }
          }
        });
      }
    });
  }

  private playEpisode(episode: PodcastEpisode): void {
    podcastStore.playEpisode(this.feed(), episode);
  }

  @Builder
  infoCard() {
    Column({ space: 10 }) {
      Row({ space: 12 }) {
        Artwork({
          seed: Math.abs(this.feed().title.length) % 12,
          artworkSize: 84,
          radius: 18,
          title: this.feed().title,
          showRing: true,
          showInitial: false,
          remoteUrl: this.feed().coverUrl
        })
        Column({ space: 4 }) {
          Text(this.feed().title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(themeStore.palette.text)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${this.feed().author.length > 0 ? this.feed().author + ' · ' : ''}${podcastStore.currentEpisodes.length} 集`)
            .fontSize(10.5)
            .fontColor(themeStore.palette.sub)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')

      if (this.feed().description.length > 0) {
        Text(this.feed().description)
          .fontSize(10.5)
          .fontColor(themeStore.palette.sub)
          .maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }

      Row({ space: 8 }) {
        Text('刷新节目')
          .fontSize(11)
          .fontColor(themeStore.palette.text)
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .borderRadius(14)
          .backgroundColor('#22FFFFFF')
          .onClick(() => {
            this.refresh();
          })

        Text('取消订阅')
          .fontSize(11)
          .fontColor('#FFFFFF')
          .padding({ left: 12, right: 12, top: 7, bottom: 7 })
          .borderRadius(14)
          .backgroundColor('#8A2B36')
          .onClick(() => {
            this.confirmUnsubscribe();
          })

        Blank()
      }
      .width('100%')
    }
    .width('100%')
    .padding(14)
    .borderRadius(20)
    .backgroundColor(themeStore.palette.card)
  }

  @Builder
  episodeRow(episode: PodcastEpisode, index: number) {
    Column({ space: 4 }) {
      Text(episode.title)
        .fontSize(13)
        .fontColor(themeStore.palette.text)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Row({ space: 8 }) {
        Text(Formatters.date(episode.publishedAt))
          .fontSize(9.5)
          .fontColor(themeStore.palette.sub)
        Text(Formatters.duration(episode.durationMs))
          .fontSize(9.5)
          .fontColor(themeStore.palette.sub)
        Blank()
        if (podcastStore.progressOf(episode.id) > 0) {
          Text(`上次听到 ${Formatters.duration(podcastStore.progressOf(episode.id))}`)
            .fontSize(9.5)
            .fontColor(themeStore.palette.brand)
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
    .onClick(() => {
      this.playEpisode(episode);
    })
  }

  private navStackValue(): NavPathStack | null {
    return this.navStack;
  }

  @Local navStack: NavPathStack | null = null;

  build() {
    NavDestination() {
      Column({ space: 10 }) {
        this.infoCard()

        if (podcastStore.episodesLoading && podcastStore.currentEpisodes.length === 0) {
          EmptyState({ loading: true, title: '正在加载单集' })
            .layoutWeight(1)
        } else if (podcastStore.episodesError.length > 0 && podcastStore.currentEpisodes.length === 0) {
          EmptyState({
            title: '读取单集失败',
            description: podcastStore.episodesError,
            actionText: '重试',
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand,
            onAction: () => {
              podcastStore.loadEpisodes(this.feedId, true);
            }
          })
            .layoutWeight(1)
        } else if (podcastStore.currentEpisodes.length === 0) {
          EmptyState({
            title: '这个节目还没有单集',
            description: '可以点击刷新节目让服务器重新抓取 RSS',
            actionText: '刷新节目',
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand,
            onAction: () => {
              this.refresh();
            }
          })
            .layoutWeight(1)
        } else {
          List() {
            ForEach(podcastStore.currentEpisodes, (episode: PodcastEpisode, index: number) => {
              ListItem() {
                this.episodeRow(episode, index)
              }
            }, (episode: PodcastEpisode) => episode.id)
            ListItem() {
              Column({ space: 4 }) {
                if (podcastStore.hasMoreEpisodes) {
                  Text(podcastStore.episodesLoading ? '加载中…' : '加载更多单集')
                    .fontSize(11.5)
                    .fontColor(themeStore.palette.brand)
                    .width('100%')
                    .textAlign(TextAlign.Center)
                    .padding({ top: 12, bottom: 16 })
                    .onClick(() => {
                      podcastStore.loadEpisodes(this.feedId, false);
                    })
                }
              }
              .width('100%')
            }
          }
          .width('100%')
          .layoutWeight(1)
          .divider({ strokeWidth: 0.5, color: '#14FFFFFF' })
          .scrollBar(BarState.Off)
          .cachedCount(6)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: layoutStore.gutter, right: layoutStore.gutter, top: 8 })
      .linearGradient({ angle: ImmersiveGlass.ANGLE, colors: ImmersiveGlass.backdrop() })
    }
    .title(this.feed().title.length > 0 ? this.feed().title : '播客节目')
    .mode(NavDestinationMode.STANDARD)
    .backgroundColor(themeStore.palette.bg)
    .systemMaterial(ImmersiveGlass.title())
    .onReady((ctx: NavDestinationContext) => {
      this.navStack = ctx.pathStack;
      if (ctx.pathInfo.param !== undefined) {
        const param = ctx.pathInfo.param as PodcastShowParam;
        if (param !== null && param !== undefined) {
          this.param = param;
        }
      }
      this.feedId = this.param.showId;
      podcastStore.loadEpisodes(this.feedId, true);
      if (podcastStore.feeds.length === 0) {
        podcastStore.loadFeeds();
      }
    })
  }
}

@Builder
export function PodcastShowBuilder() {
  PodcastShowPage()
}
