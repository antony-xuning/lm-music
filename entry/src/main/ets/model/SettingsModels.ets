/**
 * 设置项模型：主题、缩放、音质、下载目标、服务器配置。
 */
export enum ThemeMode {
  SYSTEM = 'system',
  DARK = 'dark',
  LIGHT = 'light'
}

export enum QualityLevel {
  STANDARD = 'standard',
  HIGH = 'high',
  LOSSLESS = 'lossless',
  HIRES = 'hires'
}

export enum DownloadTarget {
  LOCAL = 'local',
  SERVER = 'server',
  BOTH = 'both'
}

export enum BottomBarAnim {
  TAP = 'tap',
  SWIPE = 'swipe'
}

export enum OnlineSource {
  KUWO = 'kuwo',
  NETEASE = 'netease',
  QQ = 'qq',
  KUGOU = 'kugou',
  MIGU = 'migu'
}

@ObservedV2
export class Preferences {
  @Trace themeMode: ThemeMode = ThemeMode.SYSTEM;
  @Trace uiScale: number = 1.0;
  @Trace blurAlpha: number = 0.6;
  @Trace bottomBarAnim: BottomBarAnim = BottomBarAnim.TAP;
  @Trace autoPlay: boolean = true;
  @Trace autoFallbackLocal: boolean = true;
  @Trace autoLaunch: boolean = false;
  @Trace defaultQuality: QualityLevel = QualityLevel.LOSSLESS;
  @Trace downloadTarget: DownloadTarget = DownloadTarget.LOCAL;
  @Trace embedCover: boolean = true;
  @Trace embedLyric: boolean = true;
  @Trace saveLrc: boolean = false;
  @Trace onlineSource: OnlineSource = OnlineSource.KUWO;
  @Trace showRecentlyPlayed: boolean = true;
  @Trace showRecentlyAdded: boolean = true;
  @Trace showAlbums: boolean = true;
  @Trace showArtists: boolean = true;
  @Trace showFavorites: boolean = true;
}

@ObservedV2
export class ServerConfig {
  id: string = '';
  @Trace name: string = '';
  @Trace type: string = 'lemon';
  @Trace url: string = '';
  @Trace username: string = '';
  @Trace token: string = '';
  @Trace tokenExpiresAt: number = 0;
  @Trace displayName: string = '';
  @Trace statusState: string = 'idle';
  @Trace lastConnectedAt: number = 0;
  @Trace lastSyncAt: number = 0;
  @Trace trackCount: number = 0;
  @Trace syncMode: string = 'twoWay';
  @Trace isActive: boolean = false;

  get hasSession(): boolean {
    return this.token.length > 0 && (this.tokenExpiresAt <= 0 || this.tokenExpiresAt > Date.now());
  }
}

export class QualityHelper {
  static label(quality: QualityLevel): string {
    if (quality === QualityLevel.STANDARD) {
      return '标准音质 128kbps';
    }
    if (quality === QualityLevel.HIGH) {
      return '高品质 320kbps';
    }
    if (quality === QualityLevel.LOSSLESS) {
      return '无损 FLAC';
    }
    return 'Hi-Res 高解析母带';
  }

  static shortLabel(quality: QualityLevel): string {
    if (quality === QualityLevel.STANDARD) {
      return '标准';
    }
    if (quality === QualityLevel.HIGH) {
      return '高品质';
    }
    if (quality === QualityLevel.LOSSLESS) {
      return '无损';
    }
    return 'Hi-Res';
  }

  static all(): QualityLevel[] {
    return [QualityLevel.STANDARD, QualityLevel.HIGH, QualityLevel.LOSSLESS, QualityLevel.HIRES];
  }
}

export class DownloadTargetHelper {
  static label(target: DownloadTarget): string {
    if (target === DownloadTarget.LOCAL) {
      return '仅本机（离线可用）';
    }
    if (target === DownloadTarget.SERVER) {
      return '仅音乐服务器';
    }
    return '本机与服务器双端';
  }
}

export class SourceHelper {
  static label(source: OnlineSource): string {
    if (source === OnlineSource.NETEASE) {
      return '网易云音乐';
    }
    if (source === OnlineSource.QQ) {
      return 'QQ 音乐';
    }
    if (source === OnlineSource.KUGOU) {
      return '酷狗音乐';
    }
    if (source === OnlineSource.MIGU) {
      return '咪咕音乐';
    }
    return '酷我音乐';
  }

  static shortLabel(source: OnlineSource): string {
    if (source === OnlineSource.NETEASE) {
      return '网易云';
    }
    if (source === OnlineSource.QQ) {
      return 'QQ';
    }
    if (source === OnlineSource.KUGOU) {
      return '酷狗';
    }
    if (source === OnlineSource.MIGU) {
      return '咪咕';
    }
    return '酷我';
  }

  static all(): OnlineSource[] {
    return [OnlineSource.KUWO, OnlineSource.NETEASE, OnlineSource.QQ, OnlineSource.KUGOU, OnlineSource.MIGU];
  }
}

export class ThemeHelper {
  static label(mode: ThemeMode): string {
    if (mode === ThemeMode.DARK) {
      return '纯黑深色';
    }
    if (mode === ThemeMode.LIGHT) {
      return '纯白浅色';
    }
    return '跟随系统';
  }
}

export class BottomBarAnimHelper {
  static label(mode: BottomBarAnim): string {
    return mode === BottomBarAnim.SWIPE ? '滑动切换' : '点击切换';
  }
}
