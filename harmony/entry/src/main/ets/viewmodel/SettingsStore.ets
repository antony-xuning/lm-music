/**
 * 设置 Store：偏好读写、服务器配置管理（含 Token 与过期时间），修改后立即持久化。
 */
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { Debouncer } from '../common/Utils';
import { preferencesRepo } from '../data/PreferencesRepo';
import { PreferencesRaw, ServerRaw } from '../data/Schemas';
import {
  BottomBarAnim,
  DownloadTarget,
  OnlineSource,
  Preferences,
  QualityLevel,
  ServerConfig,
  ThemeMode
} from '../model/SettingsModels';

const SCOPE: string = 'SettingsStore';

@ObservedV2
export class SettingsStore {
  @Trace prefs: Preferences = new Preferences();
  @Trace servers: ServerConfig[] = [];
  @Trace ready: boolean = false;

  private started: boolean = false;
  private persistDebouncer: Debouncer = new Debouncer(120);

  async init(): Promise<void> {
    if (this.started) {
      return;
    }
    this.started = true;
    await this.loadSettings();
    await this.loadServers();
    this.ready = true;
  }

  private async loadSettings(): Promise<void> {
    const text: string = await preferencesRepo.getString(AppConstants.PREF_KEY_SETTINGS, '');
    if (text.length === 0) {
      return;
    }
    try {
      const raw = JSON.parse(text) as PreferencesRaw;
      this.applyRaw(raw);
    } catch (error) {
      Logger.warn(SCOPE, 'settings parse failed, using defaults');
    }
  }

  private applyRaw(raw: PreferencesRaw): void {
    const prefs: Preferences = new Preferences();
    if (typeof raw.uiScale === 'number') {
      prefs.uiScale = raw.uiScale;
    }
    if (typeof raw.blurAlpha === 'number') {
      prefs.blurAlpha = raw.blurAlpha;
    }
    if (typeof raw.autoPlay === 'boolean') {
      prefs.autoPlay = raw.autoPlay;
    }
    if (typeof raw.autoFallbackLocal === 'boolean') {
      prefs.autoFallbackLocal = raw.autoFallbackLocal;
    }
    if (typeof raw.autoLaunch === 'boolean') {
      prefs.autoLaunch = raw.autoLaunch;
    }
    if (typeof raw.embedCover === 'boolean') {
      prefs.embedCover = raw.embedCover;
    }
    if (typeof raw.embedLyric === 'boolean') {
      prefs.embedLyric = raw.embedLyric;
    }
    if (typeof raw.saveLrc === 'boolean') {
      prefs.saveLrc = raw.saveLrc;
    }
    if (typeof raw.showRecentlyPlayed === 'boolean') {
      prefs.showRecentlyPlayed = raw.showRecentlyPlayed;
    }
    if (typeof raw.showRecentlyAdded === 'boolean') {
      prefs.showRecentlyAdded = raw.showRecentlyAdded;
    }
    if (typeof raw.showAlbums === 'boolean') {
      prefs.showAlbums = raw.showAlbums;
    }
    if (typeof raw.showArtists === 'boolean') {
      prefs.showArtists = raw.showArtists;
    }
    if (typeof raw.showFavorites === 'boolean') {
      prefs.showFavorites = raw.showFavorites;
    }
    prefs.themeMode = parseTheme(raw.themeMode);
    prefs.bottomBarAnim = parseBottomAnim(raw.bottomBarAnim);
    prefs.defaultQuality = parseQuality(raw.defaultQuality);
    prefs.downloadTarget = parseTarget(raw.downloadTarget);
    prefs.onlineSource = parseSource(raw.onlineSource);
    this.prefs = prefs;
  }

  private async loadServers(): Promise<void> {
    const text: string = await preferencesRepo.getString(AppConstants.PREF_KEY_SERVERS, '');
    if (text.length === 0) {
      this.servers = [];
      return;
    }
    try {
      const raws = JSON.parse(text) as ServerRaw[];
      if (!Array.isArray(raws)) {
        this.servers = [];
        return;
      }
      const list: ServerConfig[] = [];
      for (let i = 0; i < raws.length; i++) {
        const raw: ServerRaw = raws[i];
        const server: ServerConfig = new ServerConfig();
        server.id = typeof raw.id === 'string' ? raw.id : `srv_${i}`;
        server.name = typeof raw.name === 'string' ? raw.name : '未命名服务器';
        server.type = typeof raw.type === 'string' ? raw.type : 'lemon';
        server.url = typeof raw.url === 'string' ? raw.url : '';
        server.username = typeof raw.username === 'string' ? raw.username : '';
        server.token = typeof raw.token === 'string' ? raw.token : '';
        server.tokenExpiresAt = typeof raw.tokenExpiresAt === 'number' ? raw.tokenExpiresAt : 0;
        server.displayName = typeof raw.displayName === 'string' ? raw.displayName : '';
        server.statusState = typeof raw.statusState === 'string' ? raw.statusState : 'idle';
        server.lastConnectedAt = typeof raw.lastConnectedAt === 'number' ? raw.lastConnectedAt : 0;
        server.lastSyncAt = typeof raw.lastSyncAt === 'number' ? raw.lastSyncAt : 0;
        server.trackCount = typeof raw.trackCount === 'number' ? raw.trackCount : 0;
        server.syncMode = typeof raw.syncMode === 'string' ? raw.syncMode : 'twoWay';
        server.isActive = raw.isActive === true;
        list.push(server);
      }
      this.servers = list;
    } catch (error) {
      Logger.warn(SCOPE, 'servers parse failed');
      this.servers = [];
    }
  }

  update(mutator: (prefs: Preferences) => void): void {
    mutator(this.prefs);
    this.persistSettings();
  }

  setThemeMode(mode: ThemeMode): void {
    this.prefs.themeMode = mode;
    this.persistSettings();
  }

  setUiScale(scale: number): void {
    this.prefs.uiScale = scale;
    this.persistSettings();
  }

  setBlurAlpha(alpha: number): void {
    this.prefs.blurAlpha = alpha;
    this.persistSettings();
  }

  setBottomBarAnim(mode: BottomBarAnim): void {
    this.prefs.bottomBarAnim = mode;
    this.persistSettings();
  }

  setQuality(quality: QualityLevel): void {
    this.prefs.defaultQuality = quality;
    this.persistSettings();
  }

  setDownloadTarget(target: DownloadTarget): void {
    this.prefs.downloadTarget = target;
    this.persistSettings();
  }

  setOnlineSource(source: OnlineSource): void {
    this.prefs.onlineSource = source;
    this.persistSettings();
  }

  toggle(updater: () => void): void {
    updater();
    this.persistSettings();
  }

  private persistSettings(): void {
    this.persistDebouncer.run(() => {
      const prefs: Preferences = this.prefs;
      const raw: PreferencesRaw = {
        themeMode: prefs.themeMode,
        uiScale: prefs.uiScale,
        blurAlpha: prefs.blurAlpha,
        bottomBarAnim: prefs.bottomBarAnim,
        autoPlay: prefs.autoPlay,
        autoFallbackLocal: prefs.autoFallbackLocal,
        autoLaunch: prefs.autoLaunch,
        defaultQuality: prefs.defaultQuality,
        downloadTarget: prefs.downloadTarget,
        embedCover: prefs.embedCover,
        embedLyric: prefs.embedLyric,
        saveLrc: prefs.saveLrc,
        onlineSource: prefs.onlineSource,
        showRecentlyPlayed: prefs.showRecentlyPlayed,
        showRecentlyAdded: prefs.showRecentlyAdded,
        showAlbums: prefs.showAlbums,
        showArtists: prefs.showArtists,
        showFavorites: prefs.showFavorites
      };
      preferencesRepo.putString(AppConstants.PREF_KEY_SETTINGS, JSON.stringify(raw));
    });
  }

  private async persistServers(): Promise<void> {
    const raws: ServerRaw[] = [];
    for (let i = 0; i < this.servers.length; i++) {
      const server: ServerConfig = this.servers[i];
      const raw: ServerRaw = {
        id: server.id,
        name: server.name,
        type: server.type,
        url: server.url,
        username: server.username,
        token: server.token,
        tokenExpiresAt: server.tokenExpiresAt,
        displayName: server.displayName,
        statusState: server.statusState,
        lastConnectedAt: server.lastConnectedAt,
        lastSyncAt: server.lastSyncAt,
        trackCount: server.trackCount,
        syncMode: server.syncMode,
        isActive: server.isActive
      };
      raws.push(raw);
    }
    await preferencesRepo.putString(AppConstants.PREF_KEY_SERVERS, JSON.stringify(raws));
  }

  get activeServer(): ServerConfig | null {
    for (let i = 0; i < this.servers.length; i++) {
      if (this.servers[i].isActive) {
        return this.servers[i];
      }
    }
    return this.servers.length > 0 ? this.servers[0] : null;
  }

  findServer(id: string): ServerConfig | null {
    for (let i = 0; i < this.servers.length; i++) {
      if (this.servers[i].id === id) {
        return this.servers[i];
      }
    }
    return null;
  }

  activateServer(id: string): void {
    for (let i = 0; i < this.servers.length; i++) {
      this.servers[i].isActive = this.servers[i].id === id;
    }
    this.persistServers();
  }

  saveServer(server: ServerConfig): void {
    const list: ServerConfig[] = this.servers.slice();
    for (let i = 0; i < list.length; i++) {
      if (list[i].id === server.id) {
        list[i] = server;
        this.servers = list;
        this.persistServers();
        return;
      }
    }
    list.push(server);
    if (list.length === 1) {
      list[0].isActive = true;
    }
    this.servers = list;
    this.persistServers();
  }

  removeServer(id: string): void {
    const list: ServerConfig[] = [];
    let removedActive: boolean = false;
    for (let i = 0; i < this.servers.length; i++) {
      if (this.servers[i].id === id) {
        removedActive = this.servers[i].isActive;
      } else {
        list.push(this.servers[i]);
      }
    }
    if (list.length > 0 && removedActive) {
      list[0].isActive = true;
    }
    this.servers = list;
    this.persistServers();
  }

  persistNow(): void {
    this.persistServers();
  }

  setSyncMeta(serverId: string, syncedAt: number, trackCount: number): void {
    const server: ServerConfig | null = this.findServer(serverId);
    if (server !== null) {
      server.lastSyncAt = syncedAt;
      server.trackCount = trackCount;
      this.persistServers();
    }
  }

  newServerId(): string {
    return `srv_${Date.now()}`;
  }

  resetAll(): void {
    this.prefs = new Preferences();
    this.persistSettings();
  }
}

function parseTheme(value: string | undefined): ThemeMode {
  if (value === 'dark') {
    return ThemeMode.DARK;
  }
  if (value === 'light') {
    return ThemeMode.LIGHT;
  }
  return ThemeMode.SYSTEM;
}

function parseBottomAnim(value: string | undefined): BottomBarAnim {
  return value === 'swipe' ? BottomBarAnim.SWIPE : BottomBarAnim.TAP;
}

function parseQuality(value: string | undefined): QualityLevel {
  if (value === 'standard') {
    return QualityLevel.STANDARD;
  }
  if (value === 'high') {
    return QualityLevel.HIGH;
  }
  if (value === 'hires') {
    return QualityLevel.HIRES;
  }
  return QualityLevel.LOSSLESS;
}

function parseTarget(value: string | undefined): DownloadTarget {
  if (value === 'server') {
    return DownloadTarget.SERVER;
  }
  if (value === 'both') {
    return DownloadTarget.BOTH;
  }
  return DownloadTarget.LOCAL;
}

function parseSource(value: string | undefined): OnlineSource {
  if (value === 'netease') {
    return OnlineSource.NETEASE;
  }
  if (value === 'qq') {
    return OnlineSource.QQ;
  }
  if (value === 'kugou') {
    return OnlineSource.KUGOU;
  }
  if (value === 'migu') {
    return OnlineSource.MIGU;
  }
  return OnlineSource.KUWO;
}

export const settingsStore: SettingsStore = new SettingsStore();
