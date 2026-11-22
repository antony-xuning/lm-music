/**
 * 播客节目与单集模型。
 */
@ObservedV2
export class PodcastShow {
  id: string = '';
  @Trace title: string = '';
  @Trace author: string = '';
  coverSeed: number = 0;
  @Trace description: string = '';
  category: string = '音乐';
  episodeIds: string[] = [];
  @Trace isSubscribed: boolean = false;

  get episodeCount(): number {
    return this.episodeIds.length;
  }
}

@ObservedV2
export class Episode {
  id: string = '';
  showId: string = '';
  @Trace title: string = '';
  @Trace durationMs: number = 0;
  @Trace publishedAt: number = 0;
  audioRef: string = '';
  @Trace progressMs: number = 0;

  get progressPercent(): number {
    if (this.durationMs <= 0) {
      return 0;
    }
    return Math.min(100, Math.round(this.progressMs * 100 / this.durationMs));
  }
}

export class PodcastSubscription {
  showId: string = '';
  subscribedAt: number = 0;
}

export class EpisodeProgress {
  episodeId: string = '';
  progressMs: number = 0;
  updatedAt: number = 0;
}
