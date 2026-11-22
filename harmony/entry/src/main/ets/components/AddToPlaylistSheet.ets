/**
 * 加入歌单面板：选择已有歌单或新建歌单，并通过 LibraryStore 写回服务器。
 */
import { SheetShell } from './SheetShell';
import { Artwork } from './Artwork';
import { Playlist } from '../model/MediaModels';
import { libraryStore } from '../viewmodel/LibraryStore';
import { WriteOutcome } from '../viewmodel/LibraryModels';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct AddToPlaylistSheet {
  @Param songIds: string[] = [];
  @Local showCreate: boolean = false;
  @Local newName: string = '';
  @Local busy: boolean = false;
  @Local errorText: string = '';
  @Event onClose: () => void = () => {
  };
  @Event onDone: (message: string) => void = () => {
  };

  private playlists(): Playlist[] {
    return libraryStore.userPlaylists;
  }

  private async addTo(playlist: Playlist): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const outcome: WriteOutcome = await libraryStore.addToPlaylist(playlist.id, this.songIds);
      if (outcome.ok) {
        this.onDone(outcome.message);
      } else {
        this.errorText = outcome.message;
      }
    } finally {
      this.busy = false;
    }
  }

  private async createAndAdd(): Promise<void> {
    const name: string = this.newName.trim();
    if (name.length === 0) {
      this.errorText = '歌单名称不能为空';
      return;
    }
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.errorText = '';
    try {
      const created: WriteOutcome = await libraryStore.createPlaylist(name);
      if (!created.ok) {
        this.errorText = created.message;
        return;
      }
      this.newName = '';
      this.showCreate = false;
      const added: WriteOutcome = await libraryStore.addToPlaylist(created.playlistId, this.songIds);
      if (added.ok) {
        this.onDone(added.message);
      } else {
        this.onDone(`已新建「${name}」，但加入曲目失败：${added.message}`);
      }
    } finally {
      this.busy = false;
    }
  }

  @Builder
  playlistRow(playlist: Playlist) {
    Row({ space: 10 }) {
      Artwork({
        seed: playlist.coverSeed,
        artworkSize: 40,
        radius: 10,
        title: playlist.name,
        showRing: true,
        showInitial: false
      })
      Column({ space: 2 }) {
        Text(playlist.name)
          .fontSize(13)
          .fontColor(themeStore.palette.text)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${playlist.entries.length} 首`)
          .fontSize(10)
          .fontColor(themeStore.palette.sub)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($r('app.media.ic_plus'))
        .width(15)
        .height(15)
        .fillColor(themeStore.palette.brand)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .onClick(() => {
      this.addTo(playlist);
    })
  }

  build() {
    SheetShell({
      sheetTitle: '加入歌单',
      sheetSubtitle: `已选择 ${this.songIds.length} 首`,
      panelColor: themeStore.palette.card,
      textColor: themeStore.palette.text,
      subColor: themeStore.palette.sub,
      onClose: () => {
        this.onClose();
      }
    }) {
      Column({ space: 10 }) {
        Row({ space: 6 }) {
          Image($r('app.media.ic_plus'))
            .width(13)
            .height(13)
            .fillColor('#FFFFFF')
          Text(this.busy ? '处理中…' : '新建歌单')
            .fontSize(11.5)
            .fontColor('#FFFFFF')
        }
        .padding({ left: 12, right: 12, top: 7, bottom: 7 })
        .borderRadius(14)
        .backgroundColor(themeStore.palette.brand)
        .onClick(() => {
          this.showCreate = !this.showCreate;
        })

        if (this.showCreate) {
          Row({ space: 8 }) {
            TextInput({ text: this.newName, placeholder: '输入歌单名称' })
              .fontSize(12)
              .fontColor(themeStore.palette.text)
              .placeholderColor(themeStore.palette.sub)
              .layoutWeight(1)
              .height(38)
              .backgroundColor('#22FFFFFF')
              .borderRadius(12)
              .onChange((value: string) => {
                this.newName = value;
              })
            Text('创建')
              .fontSize(11.5)
              .fontColor('#FFFFFF')
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .borderRadius(12)
              .backgroundColor(themeStore.palette.brand)
              .onClick(() => {
                this.createAndAdd();
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

        if (this.playlists().length === 0) {
          Text('服务器上还没有自建歌单，先新建一个吧')
            .fontSize(12)
            .fontColor(themeStore.palette.sub)
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 30, bottom: 30 })
        } else {
          List() {
            ForEach(this.playlists(), (playlist: Playlist) => {
              ListItem() {
                this.playlistRow(playlist)
              }
            }, (playlist: Playlist) => playlist.id)
          }
          .width('100%')
          .constraintSize({ maxHeight: 320 })
          .divider({ strokeWidth: 0.5, color: '#1AFFFFFF' })
          .scrollBar(BarState.Off)
        }
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
    }
  }
}
