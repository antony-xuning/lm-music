/**
 * 列表封面：按曲目异步获取带鉴权的缓存封面，失败自动回退渐变。
 */
import { MediaSource, Song } from '../model/MediaModels';
import { coverService } from '../service/CoverService';
import { Artwork } from './Artwork';

@ComponentV2
export struct SongCover {
  @Param song: Song = new Song();
  @Param artworkSize: number = 44;
  @Param radius: number = 10;
  @Param cacheKey: string = '';
  @Param showRing: boolean = false;
  @Local uri: string = '';

  aboutToAppear(): void {
    this.load();
  }

  @Monitor('cacheKey')
  onKeyChange(): void {
    this.load();
  }

  private async load(): Promise<void> {
    if (this.song.source === MediaSource.LOCAL) {
      this.uri = '';
      return;
    }
    const key: string = this.cacheKey;
    const resolved: string = await coverService.uriForSong(this.song);
    if (key === this.cacheKey) {
      this.uri = resolved;
    }
  }

  build() {
    Artwork({
      seed: this.song.coverSeed,
      artworkSize: this.artworkSize,
      radius: this.radius,
      title: this.song.title,
      showRing: this.showRing,
      showInitial: false,
      remoteUrl: this.uri
    })
  }
}
