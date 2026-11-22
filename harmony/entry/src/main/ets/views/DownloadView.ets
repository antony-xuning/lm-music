/**
 * 下载页：服务器下载任务看板（状态分组、进度、暂停/继续/重试/删除、清空已完成）。
 */
import { ConfirmDialog } from '../components/ConfirmDialog';
import { DownloadTaskRow } from '../components/DownloadTaskRow';
import { EmptyState } from '../components/EmptyState';
import { SectionHeader } from '../components/SectionHeader';
import { AppConstants, DockMetrics } from '../common/Constants';
import { ServerDownloadTask } from '../model/ServerModels';
import { Formatters } from '../service/Formatters';
import { DownloadOpResult } from '../service/ServerDownloadService';
import { downloadStore } from '../viewmodel/DownloadStore';
import { layoutStore } from '../viewmodel/LayoutStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { playerStore } from '../viewmodel/PlayerStore';
import { serverStore } from '../viewmodel/ServerStore';
import { themeStore } from '../viewmodel/ThemeStore';
import { scrollChrome } from '../viewmodel/ScrollChromeStore';

@ComponentV2
export struct DownloadView {
  @Local showDetail: boolean = false;
  @Local detailTask: ServerDownloadTask = new ServerDownloadTask();
  private scroller: Scroller = new Scroller();

  aboutToAppear(): void {
    downloadStore.setPageVisible(true);
  }

  aboutToDisappear(): void {
    downloadStore.setPageVisible(false);
  }

  private async runAction(promise: Promise<DownloadOpResult>): Promise<void> {
    const result: DownloadOpResult = await promise;
    ConfirmDialog.toast(this.getUIContext(), result.message);
    if (downloadStore.completedNotice.length > 0) {
      ConfirmDialog.toast(this.getUIContext(), downloadStore.completedNotice);
      downloadStore.completedNotice = '';
    }
  }

  private confirmDismiss(task: ServerDownloadTask): void {
    ConfirmDialog.confirm(this.getUIContext(), '删除任务',
      `将从服务器移除「${task.name}」的下载任务记录（不删除音频文件）。`, '删除').then((ok: boolean) => {
      if (ok) {
        this.runAction(downloadStore.dismiss(task.id));
      }
    });
  }

  private confirmClearCompleted(): void {
    ConfirmDialog.confirm(this.getUIContext(), '清空已完成',
      '将从服务器移除所有已完成任务记录（不删除音频文件）。', '清空').then((ok: boolean) => {
      if (ok) {
        this.runAction(downloadStore.clearCompleted());
      }
    });
  }

  @Builder
  dashboard() {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text(`${downloadStore.activeCount}`)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.brand)
        Text('进行中任务')
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .borderRadius(16)
      .backgroundColor(themeStore.palette.card)

      Column({ space: 3 }) {
        Text(`${downloadStore.completedCount}`)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
        Text('已完成')
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .borderRadius(16)
      .backgroundColor(themeStore.palette.card)

      Column({ space: 3 }) {
        Text(`${downloadStore.tasks.length}`)
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
        Text('任务总数')
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding(12)
      .borderRadius(16)
      .backgroundColor(themeStore.palette.card)
    }
    .width('100%')
  }

  @Builder
  actionToolbar() {
    Row({ space: 8 }) {
      Text(downloadStore.loading ? '刷新中…' : '刷新')
        .fontSize(11)
        .fontColor(themeStore.palette.text)
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .borderRadius(14)
        .backgroundColor('#22FFFFFF')
        .onClick(() => {
          downloadStore.refresh();
        })

      Text('清空已完成')
        .fontSize(11)
        .fontColor(themeStore.palette.text)
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .borderRadius(14)
        .backgroundColor('#22FFFFFF')
        .onClick(() => {
          this.confirmClearCompleted();
        })

      Blank()

      if (downloadStore.polling) {
        Row({ space: 4 }) {
          Column()
            .width(6)
            .height(6)
            .borderRadius(3)
            .backgroundColor('#2ED3A6')
          Text('自动刷新')
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
        }
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  detailSheet() {
    Column({ space: 10 }) {
      Column()
        .width(36)
        .height(4)
        .borderRadius(2)
        .backgroundColor('#3A3A42')
        .margin({ top: 8, bottom: 6 })

      Text(this.detailTask.name)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(themeStore.palette.text)
        .maxLines(2)

      Row({ space: 8 }) {
        Text(this.detailTask.singer)
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
        Text(this.detailTask.quality)
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
      }

      Column({ space: 4 }) {
        Row() {
          Text('进度')
            .fontSize(11.5)
            .fontColor(themeStore.palette.sub)
          Blank()
          Text(`${Formatters.percent(this.detailTask.progress)} · ${Formatters.bytes(this.detailTask.bytesDone)} / ${Formatters.bytes(this.detailTask.bytesTotal)}`)
            .fontSize(11)
            .fontColor(themeStore.palette.text)
        }
        .width('100%')

        if (this.detailTask.error.length > 0) {
          Text(`错误：${this.detailTask.error}`)
            .fontSize(10.5)
            .fontColor('#FFB44C')
            .width('100%')
        }

        if (this.detailTask.filePath.length > 0) {
          Text(`服务器路径：${this.detailTask.filePath}`)
            .fontSize(10.5)
            .fontColor(themeStore.palette.sub)
            .width('100%')
            .maxLines(3)
        }
      }
      .width('100%')
      .padding(12)
      .borderRadius(14)
      .backgroundColor('#14FFFFFF')

      Text('下载目标为服务器曲库，不占用本机存储。')
        .fontSize(9.5)
        .fontColor(themeStore.palette.sub)
        .width('100%')

      Blank()
    }
    .width('100%')
    .padding({ left: 18, right: 18, bottom: 24 })
    .backgroundColor(themeStore.palette.card)
    .alignItems(HorizontalAlign.Start)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 14 }) {
        Row() {
          Column({ space: 2 }) {
            Text('下载')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor(themeStore.palette.text)
            Text(serverStore.canRead
              ? `${downloadStore.tasks.length} 个服务器任务 · ${downloadStore.activeCount} 个进行中`
              : '连接服务器后管理下载任务')
              .fontSize(11)
              .fontColor(themeStore.palette.sub)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        if (!serverStore.canRead) {
          EmptyState({
            title: '尚未连接柠檬音乐服务器',
            description: '连接服务器后可在此管理下载到服务器曲库的任务',
            actionText: '去设置',
            textColor: themeStore.palette.text,
            subColor: themeStore.palette.sub,
            accent: themeStore.palette.brand,
            onAction: () => {
              overlayStore.setTab(3);
            }
          })
        } else {
          this.dashboard()
          this.actionToolbar()

          if (downloadStore.errorText.length > 0) {
            Text(downloadStore.errorText)
              .fontSize(10.5)
              .fontColor('#FFB44C')
              .width('100%')
          }

          if (downloadStore.tasks.length === 0) {
            EmptyState({
              title: downloadStore.loading ? '正在读取任务' : '还没有下载任务',
              description: '在歌曲更多菜单里选择「下载到服务器」即可提交任务',
              textColor: themeStore.palette.text,
              subColor: themeStore.palette.sub,
              accent: themeStore.palette.brand
            })
          } else {
            ForEach(downloadStore.grouped, (label: string) => {
              if (downloadStore.tasksOf(label).length > 0) {
                Column({ space: 6 }) {
                  SectionHeader({
                    title: label,
                    subtitle: `${downloadStore.tasksOf(label).length} 个任务`,
                    titleSize: 15,
                    textColor: themeStore.palette.text,
                    subColor: themeStore.palette.sub
                  })
                  Column() {
                    ForEach(downloadStore.tasksOf(label), (task: ServerDownloadTask) => {
                      DownloadTaskRow({
                        task: task,
                        textColor: themeStore.palette.text,
                        subColor: themeStore.palette.sub,
                        accent: themeStore.palette.brand,
                        onPause: (item: ServerDownloadTask) => {
                          this.runAction(downloadStore.pause(item.id));
                        },
                        onResume: (item: ServerDownloadTask) => {
                          this.runAction(downloadStore.resume(item.id));
                        },
                        onRetry: (item: ServerDownloadTask) => {
                          this.runAction(downloadStore.retry(item.id));
                        },
                        onDismiss: (item: ServerDownloadTask) => {
                          this.confirmDismiss(item);
                        },
                        onShowDetail: (item: ServerDownloadTask) => {
                          this.detailTask = item;
                          this.showDetail = true;
                        }
                      })
                    }, (task: ServerDownloadTask) => task.id)
                  }
                  .width('100%')
                  .padding({ left: 8, right: 8 })
                  .borderRadius(16)
                  .backgroundColor(themeStore.palette.card)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Start)
              }
            }, (label: string) => label)
          }

          Text('服务器下载任务由你的音乐服务器执行；应用不保存音频到本机。')
            .fontSize(9.5)
            .fontColor(themeStore.palette.sub)
            .width('100%')
            .padding({ top: 6, bottom: DockMetrics.contentBottomInset(playerStore.current !== null, scrollChrome.collapsed) })
        }
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
      scrollChrome.report(this.scroller.currentOffset().yOffset, delta);
    })
    .bindSheet(this.showDetail, this.detailSheet(), {
      dragBar: false,
      showClose: false,
      backgroundColor: Color.Transparent,
      height: SheetSize.MEDIUM,
      onDisappear: () => {
        this.showDetail = false;
      }
    })
  }
}

