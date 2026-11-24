/**
 * 服务器下载任务行：封面 / 标题 / 状态 / 进度 / 速度 / 错误 / 操作按钮。
 */
import { ServerDownloadTask } from '../model/ServerModels';
import { Formatters } from '../service/Formatters';
import { themeStore } from '../viewmodel/ThemeStore';
import { Artwork } from './Artwork';
import { BadgeView } from './Badge';

@ComponentV2
export struct DownloadTaskRow {
  @Param task: ServerDownloadTask = new ServerDownloadTask();
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @Param accent: string = '#FA2D48';
  @Event onPause: (task: ServerDownloadTask) => void = () => {
  };
  @Event onResume: (task: ServerDownloadTask) => void = () => {
  };
  @Event onRetry: (task: ServerDownloadTask) => void = () => {
  };
  @Event onDismiss: (task: ServerDownloadTask) => void = () => {
  };
  @Event onShowDetail: (task: ServerDownloadTask) => void = () => {
  };

  private statusLabel(): string {
    if (this.task.status === 'downloading') {
      return '下载中';
    }
    if (this.task.status === 'paused') {
      return '已暂停';
    }
    if (this.task.status === 'completed') {
      return '已完成';
    }
    if (this.task.status === 'failed') {
      return '失败';
    }
    return '等待中';
  }

  private statusTone(): string {
    if (this.task.status === 'completed') {
      return 'success';
    }
    if (this.task.status === 'failed') {
      return 'warn';
    }
    return this.task.status === 'downloading' ? 'brand' : 'glass';
  }

  private showProgress(): boolean {
    return this.task.status === 'downloading' || this.task.status === 'paused' || this.task.status === 'waiting';
  }

  private subtitle(): string {
    const values: string[] = [];
    if (this.task.singer.length > 0) {
      values.push(this.task.singer);
    }
    if (this.task.quality.length > 0) {
      values.push(this.task.quality);
    }
    if (this.task.bytesTotal > 0) {
      values.push(Formatters.bytes(this.task.bytesTotal));
    }
    if (this.task.speed > 0 && this.task.status === 'downloading') {
      values.push(Formatters.speed(this.task.speed));
    }
    return values.join(' · ');
  }

  @Builder
  actionButton(label: string, filled: boolean, action: () => void) {
    Text(label)
      .fontSize(10)
      .fontColor(filled ? '#FFFFFF' : this.textColor)
      .padding({ left: 9, right: 9, top: 5, bottom: 5 })
      .borderRadius(10)
      .backgroundColor(filled ? this.accent : themeStore.palette.controlBg)
      .stateStyles({
        pressed: { .scale({ x: 0.9, y: 0.9 }) },
        normal: { .scale({ x: 1, y: 1 }) }
      })
      .animation({ duration: 120, curve: Curve.EaseOut })
      .onClick(() => {
        action();
      })
  }

  build() {
    Row({ space: 10 }) {
      Artwork({ seed: this.task.name.length % 12, artworkSize: 42, radius: 10, title: this.task.name })

      Column({ space: 5 }) {
        Row({ space: 6 }) {
          Text(this.task.name)
            .fontSize(13)
            .fontColor(this.textColor)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          BadgeView({ text: this.statusLabel(), tone: this.statusTone() })
        }
        .width('100%')

        Text(this.subtitle())
          .fontSize(10)
          .fontColor(this.subColor)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })

        if (this.showProgress()) {
          Row() {
            Row()
              .height(4)
              .width(`${Math.max(this.task.progress, 2)}%`)
              .borderRadius(2)
              .backgroundColor(this.task.status === 'paused' ? '#8A8A93' : this.accent)
          }
          .width('100%')
          .height(4)
          .borderRadius(2)
          .backgroundColor(themeStore.palette.controlBg)
        }

        if (this.task.status === 'failed' && this.task.error.length > 0) {
          Text(this.task.error)
            .fontSize(9.5)
            .fontColor('#FFB44C')
            .maxLines(2)
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (this.task.status === 'downloading') {
        this.actionButton('暂停', false, () => {
          this.onPause(this.task);
        })
      } else if (this.task.status === 'paused') {
        this.actionButton('继续', true, () => {
          this.onResume(this.task);
        })
      } else if (this.task.status === 'failed') {
        this.actionButton('重试', true, () => {
          this.onRetry(this.task);
        })
      } else {
        this.actionButton('删除', false, () => {
          this.onDismiss(this.task);
        })
      }

      Image($r('app.media.ic_more'))
        .width(16)
        .height(16)
        .fillColor(this.subColor)
        .stateStyles({
          pressed: { .scale({ x: 0.82, y: 0.82 }).opacity(0.6) },
          normal: { .scale({ x: 1, y: 1 }).opacity(1) }
        })
        .animation({ duration: 120, curve: Curve.EaseOut })
        .onClick(() => {
          this.onShowDetail(this.task);
        })
    }
    .width('100%')
    .padding({ top: 8, bottom: 8, left: 2, right: 2 })
    .alignItems(VerticalAlign.Center)
    .stateStyles({
      pressed: { .scale({ x: 0.98, y: 0.98 }) },
      normal: { .scale({ x: 1, y: 1 }) }
    })
    .animation({ duration: 130, curve: Curve.EaseOut })
    .onClick(() => {
      this.onShowDetail(this.task);
    })
  }
}
