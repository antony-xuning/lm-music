/**
 * 资料库二级页的辅助面板：多选操作条与歌单命名弹窗。
 */
import { Formatters } from '../service/Formatters';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct LibrarySelectionBar {
  @Param selectedCount: number = 0;
  @Param selectedBytes: number = 0;
  @Param playlistMode: boolean = false;
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @Param accent: string = '#FA2D48';
  @Param blurStyle: BlurStyle = BlurStyle.Regular;
  @Event onSelectAll: () => void = () => {
  };
  @Event onInvert: () => void = () => {
  };
  @Event onAddToPlaylist: () => void = () => {
  };
  @Event onRemove: () => void = () => {
  };

  build() {
    Row({ space: 8 }) {
      Column({ space: 1 }) {
        Text(`已选 ${this.selectedCount} 首`)
          .fontSize(11.5)
          .fontColor(this.textColor)
        Text(Formatters.bytes(this.selectedBytes))
          .fontSize(9.5)
          .fontColor(this.subColor)
      }
      .alignItems(HorizontalAlign.Start)

      Blank()

      Text('全选')
        .fontSize(10.5)
        .fontColor(this.textColor)
        .onClick(() => {
          this.onSelectAll();
        })
      Text('反选')
        .fontSize(10.5)
        .fontColor(this.textColor)
        .onClick(() => {
          this.onInvert();
        })
      Text('加入歌单')
        .fontSize(10.5)
        .fontColor('#FFFFFF')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(12)
        .backgroundColor(this.accent)
        .onClick(() => {
          this.onAddToPlaylist();
        })
      Text(this.playlistMode ? '移除' : '删除')
        .fontSize(10.5)
        .fontColor('#FFFFFF')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .borderRadius(12)
        .backgroundColor('#8A2B36')
        .onClick(() => {
          this.onRemove();
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 12 })
    .borderRadius(18)
    .backgroundColor('#E61C1C20')
    .backgroundBlurStyle(this.blurStyle)
  }
}

@ComponentV2
export struct LibraryNameDialog {
  @Param dialogTitle: string = '新建歌单';
  @Param nameValue: string = '';
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @Param accent: string = '#FA2D48';
  @Param cardColor: string = '#1C1C20';
  @Param blurStyle: BlurStyle = BlurStyle.Regular;
  @Event onNameChange: (value: string) => void = () => {
  };
  @Event onCancel: () => void = () => {
  };
  @Event onConfirm: () => void = () => {
  };

  build() {
    Column({ space: 12 }) {
      Text(this.dialogTitle)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.textColor)

      TextInput({ text: this.nameValue, placeholder: '歌单名称' })
        .fontSize(13)
        .fontColor(this.textColor)
        .placeholderColor(this.subColor)
        .backgroundColor(themeStore.palette.controlBg)
        .borderRadius(12)
        .height(40)
        .onChange((value: string) => {
          this.onNameChange(value);
        })

      Row({ space: 10 }) {
        Text('取消')
          .fontSize(12)
          .fontColor(this.subColor)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 9, bottom: 9 })
          .borderRadius(12)
          .backgroundColor(themeStore.palette.controlBg)
          .onClick(() => {
            this.onCancel();
          })
        Text('确定')
          .fontSize(12)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
          .padding({ top: 9, bottom: 9 })
          .borderRadius(12)
          .backgroundColor(this.accent)
          .onClick(() => {
            this.onConfirm();
          })
      }
      .width('100%')
    }
    .width('82%')
    .padding(18)
    .borderRadius(20)
    .backgroundColor(this.cardColor)
    .backgroundBlurStyle(this.blurStyle)
    .shadow({ radius: 30, color: '#88000000' })
  }
}
