/**
 * 曲库 Store：服务器快照（曲目/专辑/歌手/歌单/收藏/最近）+ 本地导入曲目。
 * 收藏与歌单采用「读取整表 → 本地修改 → 整表写回」策略，读取失败立即中止。
 */
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { Debouncer, Utils } from '../common/Utils';
import { JsonStore } from '../data/JsonStore';
import { ServerCache, ServerSnapshot } from '../data/ServerCache';
import { LibraryDoc, SchemaCodec, SongRaw } from '../data/Schemas';
import { ServerSchemas, UserDataParsed, trackKeyOf } from '../data/ServerSchemas';
import { Album, Artist, MediaSource, Playlist, Song } from '../model/MediaModels';
import { ApiErrorHelper, PlaylistEntry } from '../model/ServerModels';
import { ObjectResult, TextResult, serverApi } from '../service/ServerApi';
import { serverManager } from '../service/ServerManager';
import { serverContext } from '../service/ServerContext';
import { playerStore } from './PlayerStore';
import {
  FavoriteEntry,
  FavoriteToggle,
  findPlaylistRaw,
  parseObjectArray,
  PlaylistCreateBody,
  PlaylistRawForPatch,
  removeFavorite,
  songFromEntry,
  songTrackKey,
  favoriteKeyOf,
  serverStoreReady,
  trackSnapshotOf,
  entryFromJson,
  WriteOutcome
} from './LibraryModels';
const SCOPE: string = 'LibraryStore';
@ObservedV2
export class LibraryStore {
  @Trace serverSongs: Song[] = [];
  @Trace localSongs: Song[] = [];
  /** 本地扫描（文件夹授权）曲目，LOCAL 来源，播放使用用户文件 URI。 */
  @Trace scannedSongs: Song[] = [];
  @Trace albums: Album[] = [];
  @Trace artists: Artist[] = [];
  @Trace playlists: Playlist[] = [];
  @Trace favoriteFlags: string[] = [];
  @Trace recentIds: string[] = [];
  @Trace syncedAt: number = 0;
  @Trace ready: boolean = false;
  @Trace importing: boolean = false;
  @Trace lastImportMessage: string = '';
  @Trace writing: boolean = false;
  private started: boolean = false;
  private saver: Debouncer = new Debouncer(320);
  private favoritesJson: string = '[]';
  private playlistsJson: string = '[]';
  private recentJson: string[] = [];
  private favoriteKeys: Set<string> = new Set<string>();
  private favoriteFlagSet: Set<string> = new Set<string>();
  /** id → Song 索引：播放器动画每帧都会查当前曲目，避免全表线性扫描。 */
  private songIndex: Map<string, Song> = new Map<string, Song>();
  private songIndexDirty: boolean = true;
  private allSongsCache: Song[] = [];
  private allSongsDirty: boolean = true;
  @Trace recentSongsCache: Song[] = [];
  init(): void {
    if (this.started) {
      return;
    }
    this.started = true;
    this.loadLocal();
    this.loadSnapshot();
    this.ready = true;
    playerStore.addTrackListener((item) => {
      if (item.songId.length > 0) {
        this.markPlayed(item.songId);
      }
    });
  }
  // ---------- 本地曲目 ----------
  private loadLocal(): void {
    const text: string | null = JsonStore.readText(AppConstants.FILE_LIBRARY);
    if (text === null || text.length === 0) {
      return;
    }
    try {
      const doc: LibraryDoc = JSON.parse(text) as LibraryDoc;
      const raws: SongRaw[] = Array.isArray(doc.localSongs) ? doc.localSongs : [];
      const local: Song[] = [];
      for (let i = 0; i < raws.length; i++) {
        const song: Song = SchemaCodec.fromSongRaw(raws[i]);
        if (song.id.length > 0 && song.audioRef.length > 0) {
          song.source = MediaSource.LOCAL;
          local.push(song);
        }
      }
      this.localSongs = local;
      this.invalidateSongIndex();
    } catch (error) {
      Logger.warn(SCOPE, 'library.json unreadable');
    }
  }
  private persistLocal(): void {
    const raws: SongRaw[] = [];
    for (let i = 0; i < this.localSongs.length; i++) {
      raws.push(SchemaCodec.toSongRaw(this.localSongs[i]));
    }
    const doc: LibraryDoc = {
      schemaVersion: AppConstants.SCHEMA_VERSION,
      localSongs: raws,
      favoriteIds: [],
      recentIds: []
    };
    JsonStore.writeText(AppConstants.FILE_LIBRARY, JSON.stringify(doc));
  }
  // ---------- 服务器快照 ----------
  /** 清空当前服务器的内存与缓存数据（保留本地导入曲目）。 */
  clearServerData(): void {
    this.serverSongs = [];
    this.albums = [];
    this.artists = [];
    this.playlists = [];
    this.favoriteFlags = [];
    this.recentIds = [];
    this.recentSongsCache = [];
    this.invalidateSongIndex();
    this.favoritesJson = '[]';
    this.playlistsJson = '[]';
    this.recentJson = [];
    this.favoriteKeys = new Set<string>();
    this.favoriteFlagSet = new Set<string>();
    this.syncedAt = 0;
    const serverId: string = serverContext.serverId;
    if (serverId.length > 0) {
      ServerCache.remove(serverId);
    }
  }
  loadSnapshot(): void {
    const serverId: string = serverContext.serverId;
    if (serverId.length === 0) {
      this.serverSongs = [];
      this.albums = [];
      this.artists = [];
      this.playlists = [];
      this.invalidateSongIndex();
      return;
    }
    const snapshot: ServerSnapshot | null = ServerCache.read(serverId);
    if (snapshot !== null) {
      this.applySnapshot(snapshot);
    }
  }
  applySnapshot(snapshot: ServerSnapshot): void {
    this.serverSongs = snapshot.songs;
    this.invalidateSongIndex();
    this.albums = snapshot.albums;
    this.artists = snapshot.artists;
    this.syncedAt = snapshot.syncedAt;
    this.favoritesJson = snapshot.favoritesJson.length > 0 ? snapshot.favoritesJson : '[]';
    this.playlistsJson = snapshot.playlistsJson.length > 0 ? snapshot.playlistsJson : '[]';
    const recent: Object[] = parseObjectArray(snapshot.recentJson);
    this.recentJson = [];
    for (let i = 0; i < recent.length; i++) {
      this.recentJson.push(JSON.stringify(recent[i]));
    }
    this.rebuildFavoriteKeys();
    this.applyFavoriteFlags();
    if (snapshot.playlists.length > 0) {
      this.playlists = snapshot.playlists;
    } else {
      this.rebuildPlaylists();
    }
    this.rebuildRecent();
  }
  private persistSnapshot(): void {
    const serverId: string = serverContext.serverId;
    if (serverId.length === 0) {
      return;
    }
    const snapshot: ServerSnapshot = new ServerSnapshot();
    snapshot.serverId = serverId;
    snapshot.syncedAt = this.syncedAt;
    snapshot.songs = this.serverSongs;
    snapshot.albums = this.albums;
    snapshot.artists = this.artists;
    snapshot.playlists = this.playlists;
    snapshot.favoritesJson = this.favoritesJson;
    snapshot.playlistsJson = '';
    const recent: string[] = [];
    for (let i = 0; i < this.recentJson.length; i++) {
      recent.push(this.recentJson[i]);
    }
    snapshot.recentJson = `[${recent.join(',')}]`;
    ServerCache.write(snapshot);
  }
  private rebuildPlaylists(): void {
    const raws: Object[] = parseObjectArray(this.playlistsJson);
    const list: Playlist[] = [];
    for (let i = 0; i < raws.length; i++) {
      list.push(ServerSchemas.playlistFrom(raws[i], serverContext.serverId));
    }
    this.playlists = list;
  }
  private rebuildRecent(): void {
    const songs: Song[] = [];
    const ids: string[] = [];
    for (let i = 0; i < this.recentJson.length; i++) {
      const entry: PlaylistEntry | null = entryFromJson(this.recentJson[i]);
      if (entry === null) {
        continue;
      }
      const song: Song | null = this.resolveEntrySong(entry);
      if (song !== null) {
        songs.push(song);
        ids.push(song.id);
      }
    }
    this.recentSongsCache = songs;
    this.invalidateSongIndex();
    this.recentIds = ids;
  }
  // ---------- 查询 ----------
  get allSongs(): Song[] {
    if (this.allSongsDirty) {
      this.allSongsCache = this.serverSongs.concat(this.localSongs, this.scannedSongs);
      this.allSongsDirty = false;
    }
    return this.allSongsCache;
  }
  get songCount(): number {
    return this.serverSongs.length + this.localSongs.length + this.scannedSongs.length;
  }
  get favoriteSongs(): Song[] {
    const result: Song[] = [];
    const all: Song[] = this.allSongs;
    for (let i = 0; i < all.length; i++) {
      if (this.favoriteFlagSet.has(all[i].id)) {
        result.push(all[i]);
      }
    }
    return result;
  }
  get recentSongs(): Song[] {
    return this.recentSongsCache;
  }
  get downloadedSongs(): Song[] {
    return this.serverSongs;
  }
  get userPlaylists(): Playlist[] {
    const result: Playlist[] = [];
    for (let i = 0; i < this.playlists.length; i++) {
      if (!this.playlists[i].isFavorites && !this.playlists[i].readOnly) {
        result.push(this.playlists[i]);
      }
    }
    return result;
  }
  private invalidateSongIndex(): void {
    this.songIndexDirty = true;
    this.allSongsDirty = true;
  }

  private rebuildSongIndex(): void {
    const map: Map<string, Song> = new Map<string, Song>();
    const groups: Song[][] = [this.serverSongs, this.localSongs, this.scannedSongs, this.recentSongsCache];
    for (let g = 0; g < groups.length; g++) {
      const songs: Song[] = groups[g];
      for (let i = 0; i < songs.length; i++) {
        const song: Song = songs[i];
        if (song.id.length > 0 && !map.has(song.id)) {
          map.set(song.id, song);
        }
      }
    }
    this.songIndex = map;
    this.songIndexDirty = false;
  }

  findSong(id: string): Song | null {
    if (this.songIndexDirty) {
      this.rebuildSongIndex();
    }
    const song: Song | undefined = this.songIndex.get(id);
    return song !== undefined ? song : null;
  }
  findSongs(ids: string[]): Song[] {
    const result: Song[] = [];
    for (let i = 0; i < ids.length; i++) {
      const song: Song | null = this.findSong(ids[i]);
      if (song !== null) {
        result.push(song);
      }
    }
    return result;
  }
  findPlaylist(id: string): Playlist | null {
    for (let i = 0; i < this.playlists.length; i++) {
      if (this.playlists[i].id === id) {
        return this.playlists[i];
      }
    }
    return null;
  }
  albumSongs(albumId: string): Song[] {
    const result: Song[] = [];
    const all: Song[] = this.allSongs;
    for (let i = 0; i < all.length; i++) {
      if (all[i].albumId === albumId) {
        result.push(all[i]);
      }
    }
    return result;
  }
  artistSongs(artistId: string, artistName: string): Song[] {
    const result: Song[] = [];
    const all: Song[] = this.allSongs;
    for (let i = 0; i < all.length; i++) {
      if (all[i].artistId === artistId || all[i].artist === artistName) {
        result.push(all[i]);
      }
    }
    return result;
  }
  playlistSongs(playlistId: string): Song[] {
    const playlist: Playlist | null = this.findPlaylist(playlistId);
    if (playlist === null) {
      return [];
    }
    const result: Song[] = [];
    for (let i = 0; i < playlist.entries.length; i++) {
      const song: Song | null = this.resolveEntrySong(playlist.entries[i]);
      if (song !== null) {
        result.push(song);
      }
    }
    return result;
  }
  private resolveEntrySong(entry: PlaylistEntry): Song | null {
    if (entry.localPath.length > 0) {
      for (let i = 0; i < this.serverSongs.length; i++) {
        if (this.serverSongs[i].filePath === entry.localPath) {
          return this.serverSongs[i];
        }
      }
      for (let i = 0; i < this.localSongs.length; i++) {
        if (this.localSongs[i].localPath === entry.localPath) {
          return this.localSongs[i];
        }
      }
      for (let i = 0; i < this.scannedSongs.length; i++) {
        if (this.scannedSongs[i].filePath === entry.localPath) {
          return this.scannedSongs[i];
        }
      }
    }
    if (entry.platform.length > 0 && entry.songId.length > 0) {
      const key: string = `${entry.platform}:${entry.songId}`;
      for (let i = 0; i < this.serverSongs.length; i++) {
        if (this.serverSongs[i].trackKey === key) {
          return this.serverSongs[i];
        }
      }
    }
    return songFromEntry(entry, serverContext.serverId);
  }
  countBySource(source: MediaSource): number {
    let count: number = 0;
    const all: Song[] = this.allSongs;
    for (let i = 0; i < all.length; i++) {
      if (all[i].source === source) {
        count++;
      }
    }
    return count;
  }
  // ---------- 收藏 ----------
  private rebuildFavoriteKeys(): void {
    const keys: Set<string> = new Set<string>();
    const raws: Object[] = parseObjectArray(this.favoritesJson);
    for (let i = 0; i < raws.length; i++) {
      const key: string = favoriteKeyOf(raws[i]);
      if (key.length > 0) {
        keys.add(key);
        if (key.startsWith('local:')) {
          keys.add(key.substring('local:'.length));
        }
      }
    }
    this.favoriteKeys = keys;
  }
  private songKey(song: Song): string {
    if (song.source === MediaSource.SERVER_FILE) {
      return song.filePath;
    }
    if (song.source === MediaSource.ONLINE) {
      return `${song.platform}:${song.platformSongId}`;
    }
    return song.localPath.length > 0 ? song.localPath : song.id;
  }
  isFavorite(songId: string): boolean {
    // 先读取 @Trace 的 favoriteFlags，确保界面能感知收藏变化。
    const flagged: boolean = this.favoriteFlagSet.has(songId);
    const song: Song | null = this.findSong(songId);
    if (song === null) {
      return flagged;
    }
    return this.favoriteKeys.has(this.songKey(song)) || flagged;
  }
  private applyFavoriteFlags(): void {
    const flags: string[] = [];
    const all: Song[] = this.allSongs;
    for (let i = 0; i < all.length; i++) {
      const matched: boolean = this.favoriteKeys.has(this.songKey(all[i]));
      all[i].isFavorite = matched;
      if (matched) {
        flags.push(all[i].id);
      }
    }
    this.favoriteFlags = flags;
    this.favoriteFlagSet = new Set<string>(flags);
  }
  /** 收藏切换：乐观更新 → 读取整表 → 修改 → 整表写回；读取失败回滚。 */
  async toggleFavorite(songId: string): Promise<FavoriteToggle> {
    const song: Song | null = this.findSong(songId);
    if (song === null) {
      const missing: FavoriteToggle = new FavoriteToggle();
      missing.message = '找不到该曲目';
      return missing;
    }
    return this.toggleFavoriteFor(song);
  }
  /** 直接对曲目对象切换收藏（在线搜索结果不在曲库中时同样可用）。 */
  async toggleFavoriteFor(song: Song): Promise<FavoriteToggle> {
    const outcome: FavoriteToggle = new FavoriteToggle();
    if (!serverStoreReady()) {
      outcome.message = '尚未连接服务器，无法同步收藏';
      return outcome;
    }
    const wasFavorite: boolean = this.favoriteKeys.has(this.songKey(song));
    this.applyFavoriteLocal(song, !wasFavorite);
    let failure: string = '';
    let newJson: string = '';
    let finalFavorite: boolean = !wasFavorite;
    await serverManager.exclusive(async () => {
      const read: TextResult = await serverApi.userDataText();
      if (!read.ok) {
        failure = '读取服务器收藏失败，已取消本次修改';
        return;
      }
      const parsed: UserDataParsed = ServerSchemas.parseUserData(ServerSchemas.parseRoot(read.text));
      const entries: Object[] = parsed.favorites.slice();
      if (wasFavorite) {
        finalFavorite = false;
        removeFavorite(entries, song);
      } else {
        finalFavorite = true;
        entries.unshift(FavoriteEntry.fromSong(song));
      }
      newJson = JSON.stringify(entries);
      const body: string = `{"favorites":${newJson}}`;
      const write: ObjectResult = await serverApi.saveUserData(body);
      if (!write.ok) {
        failure = ApiErrorHelper.message(write.code);
        finalFavorite = wasFavorite;
        return;
      }
    });
    if (failure.length > 0) {
      this.applyFavoriteLocal(song, wasFavorite);
      outcome.ok = false;
      outcome.favorite = wasFavorite;
      outcome.message = failure;
      return outcome;
    }
    this.favoritesJson = newJson;
    this.rebuildFavoriteKeys();
    this.applyFavoriteFlags();
    this.persistSnapshot();
    outcome.ok = true;
    outcome.favorite = finalFavorite;
    outcome.message = finalFavorite ? '已加入我喜欢' : '已取消喜欢';
    return outcome;
  }
  private applyFavoriteLocal(song: Song, favorite: boolean): void {
    song.isFavorite = favorite;
    const flags: string[] = this.favoriteFlags.slice();
    const index: number = flags.indexOf(song.id);
    if (favorite && index < 0) {
      flags.push(song.id);
    } else if (!favorite && index >= 0) {
      flags.splice(index, 1);
    }
    this.favoriteFlags = flags;
    this.favoriteFlagSet = new Set<string>(flags);
  }
  // ---------- 歌单写回 ----------
  private async readPlaylistsRaw(): Promise<Object[] | null> {
    const read: TextResult = await serverApi.userDataText();
    if (read.ok) {
      const parsed: UserDataParsed = ServerSchemas.parseUserData(ServerSchemas.parseRoot(read.text));
      return parsed.playlists;
    }
    const fallback: TextResult = await serverApi.playlistsText();
    if (fallback.ok) {
      return ServerSchemas.listOf(ServerSchemas.parseRoot(fallback.text));
    }
    return null;
  }
  private async writePlaylists(entries: Object[]): Promise<WriteOutcome> {
    const outcome: WriteOutcome = new WriteOutcome();
    const body: string = `{"playlists":${JSON.stringify(entries)}}`;
    const write: ObjectResult = await serverApi.savePlaylists(body);
    if (!write.ok) {
      outcome.message = ApiErrorHelper.message(write.code);
      return outcome;
    }
    this.playlistsJson = JSON.stringify(entries);
    this.rebuildPlaylists();
    this.persistSnapshot();
    outcome.ok = true;
    return outcome;
  }
  async createPlaylist(name: string): Promise<WriteOutcome> {
    const outcome: WriteOutcome = new WriteOutcome();
    const trimmed: string = name.trim();
    if (trimmed.length === 0) {
      outcome.message = '歌单名称不能为空';
      return outcome;
    }
    if (!serverStoreReady()) {
      outcome.message = '尚未连接服务器';
      return outcome;
    }
    await serverManager.exclusive(async () => {
      const entries: Object[] | null = await this.readPlaylistsRaw();
      if (entries === null) {
        outcome.message = '读取服务器歌单失败，已取消本次修改';
        return;
      }
      const created: PlaylistCreateBody = new PlaylistCreateBody(trimmed, Date.now());
      entries.push(created);
      const result: WriteOutcome = await this.writePlaylists(entries);
      outcome.ok = result.ok;
      outcome.message = result.ok ? `已新建「${trimmed}」` : result.message;
      outcome.playlistId = result.ok ? `pl_${Utils.stableId(`${serverContext.serverId}|${trimmed}`)}` : '';
    });
    return outcome;
  }
  async renamePlaylist(playlistId: string, name: string): Promise<WriteOutcome> {
    const outcome: WriteOutcome = new WriteOutcome();
    const playlist: Playlist | null = this.findPlaylist(playlistId);
    if (playlist === null) {
      outcome.message = '歌单不存在';
      return outcome;
    }
    const newName: string = name.trim();
    if (newName.length === 0) {
      outcome.message = '歌单名称不能为空';
      return outcome;
    }
    const oldName: string = playlist.name;
    await serverManager.exclusive(async () => {
      const entries: Object[] | null = await this.readPlaylistsRaw();
      if (entries === null) {
        outcome.message = '读取服务器歌单失败，已取消本次修改';
        return;
      }
      const target: PlaylistRawForPatch | null = findPlaylistRaw(entries, oldName);
      if (target === null) {
        outcome.message = '服务器上找不到该歌单';
        return;
      }
      target.name = newName;
      const result: WriteOutcome = await this.writePlaylists(entries);
      outcome.ok = result.ok;
      outcome.message = result.ok ? '已重命名歌单' : result.message;
    });
    return outcome;
  }
  async deletePlaylist(playlistId: string): Promise<WriteOutcome> {
    const outcome: WriteOutcome = new WriteOutcome();
    const playlist: Playlist | null = this.findPlaylist(playlistId);
    if (playlist === null) {
      outcome.message = '歌单不存在';
      return outcome;
    }
    const targetName: string = playlist.name;
    await serverManager.exclusive(async () => {
      const entries: Object[] | null = await this.readPlaylistsRaw();
      if (entries === null) {
        outcome.message = '读取服务器歌单失败，已取消本次修改';
        return;
      }
      const kept: Object[] = [];
      for (let i = 0; i < entries.length; i++) {
        const raw: PlaylistRawForPatch = entries[i] as PlaylistRawForPatch;
        if (raw.name !== targetName) {
          kept.push(entries[i]);
        }
      }
      const result: WriteOutcome = await this.writePlaylists(kept);
      outcome.ok = result.ok;
      outcome.message = result.ok ? '已删除歌单' : result.message;
    });
    return outcome;
  }
  async addToPlaylist(playlistId: string, songIds: string[]): Promise<WriteOutcome> {
    return this.addSongsToPlaylist(playlistId, this.findSongs(songIds));
  }
  /** 直接以曲目对象加入歌单（支持在线搜索结果）。 */
  async addSongsToPlaylist(playlistId: string, songs: Song[]): Promise<WriteOutcome> {
    const outcome: WriteOutcome = new WriteOutcome();
    const playlist: Playlist | null = this.findPlaylist(playlistId);
    if (playlist === null) {
      outcome.message = '歌单不存在';
      return outcome;
    }
    const targetName: string = playlist.name;
    await serverManager.exclusive(async () => {
      const entries: Object[] | null = await this.readPlaylistsRaw();
      if (entries === null) {
        outcome.message = '读取服务器歌单失败，已取消本次修改';
        return;
      }
      const target: PlaylistRawForPatch | null = findPlaylistRaw(entries, targetName);
      if (target === null) {
        outcome.message = '服务器上找不到该歌单';
        return;
      }
      const keys: Object[] = Array.isArray(target.trackKeys) ? target.trackKeys.slice() : [];
      const snapshots: Record<string, Object> = target.trackSnapshots !== undefined
        ? target.trackSnapshots as Record<string, Object> : {};
      const existing: Set<string> = new Set<string>();
      for (let i = 0; i < keys.length; i++) {
        const key: string = trackKeyOf(keys[i]);
        if (key.length > 0) {
          existing.add(key);
        }
      }
      let added: number = 0;
      for (let i = 0; i < songs.length; i++) {
        const entryKey: string = songTrackKey(songs[i]);
        if (entryKey.length === 0 || existing.has(entryKey)) {
          continue;
        }
        keys.push(entryKey);
        snapshots[entryKey] = trackSnapshotOf(songs[i]);
        existing.add(entryKey);
        added++;
      }
      if (added === 0) {
        outcome.message = `「${targetName}」中已包含所选曲目`;
        return;
      }
      target.trackKeys = keys;
      target.trackSnapshots = snapshots;
      const result: WriteOutcome = await this.writePlaylists(entries);
      outcome.ok = result.ok;
      outcome.message = result.ok ? `已加入「${targetName}」` : result.message;
    });
    return outcome;
  }
  async removeFromPlaylist(playlistId: string, songIds: string[]): Promise<WriteOutcome> {
    const outcome: WriteOutcome = new WriteOutcome();
    const playlist: Playlist | null = this.findPlaylist(playlistId);
    if (playlist === null) {
      outcome.message = '歌单不存在';
      return outcome;
    }
    const targetName: string = playlist.name;
    const songs: Song[] = this.findSongs(songIds);
    await serverManager.exclusive(async () => {
      const entries: Object[] | null = await this.readPlaylistsRaw();
      if (entries === null) {
        outcome.message = '读取服务器歌单失败，已取消本次修改';
        return;
      }
      const target: PlaylistRawForPatch | null = findPlaylistRaw(entries, targetName);
      if (target === null) {
        outcome.message = '服务器上找不到该歌单';
        return;
      }
      const removeKeys: Set<string> = new Set<string>();
      for (let i = 0; i < songs.length; i++) {
        removeKeys.add(songTrackKey(songs[i]));
      }
      const keys: Object[] = Array.isArray(target.trackKeys) ? target.trackKeys : [];
      const kept: Object[] = [];
      for (let i = 0; i < keys.length; i++) {
        const key: string = trackKeyOf(keys[i]);
        if (!removeKeys.has(key)) {
          kept.push(keys[i]);
        }
      }
      target.trackKeys = kept;
      const result: WriteOutcome = await this.writePlaylists(entries);
      outcome.ok = result.ok;
      outcome.message = result.ok ? '已从歌单移除' : result.message;
    });
    return outcome;
  }
  // ---------- 本地导入 / 删除 / 最近播放 ----------
  /** 合并本地扫描曲目（LOCAL）：按 audioRef 去重，并跳过与已导入文件重复的条目。 */
  setScannedSongs(songs: Song[]): void {
    const existingKeys: Set<string> = new Set<string>();
    for (let i = 0; i < this.localSongs.length; i++) {
      existingKeys.add(this.localSongs[i].audioRef);
    }
    for (let i = 0; i < this.scannedSongs.length; i++) {
      existingKeys.add(this.scannedSongs[i].audioRef);
    }
    const next: Song[] = [];
    for (let i = 0; i < songs.length; i++) {
      const song: Song = songs[i];
      if (song.audioRef.length === 0 || existingKeys.has(song.audioRef)) {
        continue;
      }
      if (this.duplicatesImported(song)) {
        continue;
      }
      existingKeys.add(song.audioRef);
      next.push(song);
    }
    this.scannedSongs = next;
    this.invalidateSongIndex();
    this.applyFavoriteFlags();
  }
  private duplicatesImported(candidate: Song): boolean {
    for (let i = 0; i < this.localSongs.length; i++) {
      const imported: Song = this.localSongs[i];
      if (imported.sizeBytes > 0 && imported.sizeBytes === candidate.sizeBytes
        && imported.title === candidate.title) {
        return true;
      }
    }
    return false;
  }
  addImportedSongs(imported: Song[], skipped: number, message: string): void {
    if (imported.length === 0) {
      this.lastImportMessage = message;
      return;
    }
    const next: Song[] = this.localSongs.slice();
    for (let i = 0; i < imported.length; i++) {
      let duplicated: boolean = false;
      for (let k = 0; k < next.length; k++) {
        if (next[k].audioRef === imported[i].audioRef) {
          duplicated = true;
          break;
        }
      }
      if (!duplicated) {
        next.push(imported[i]);
      }
    }
    this.localSongs = next;
    this.invalidateSongIndex();
    this.lastImportMessage = skipped > 0 ? `${message}（跳过 ${skipped} 个不支持的文件）` : message;
    this.saver.run(() => {
      this.persistLocal();
    });
  }
  removeLocalSongs(ids: string[]): number {
    const remaining: Song[] = [];
    const removedSongs: Song[] = [];
    for (let i = 0; i < this.localSongs.length; i++) {
      if (ids.indexOf(this.localSongs[i].id) >= 0 && this.localSongs[i].source === MediaSource.LOCAL) {
        removedSongs.push(this.localSongs[i]);
      } else {
        remaining.push(this.localSongs[i]);
      }
    }
    this.localSongs = remaining;
    this.invalidateSongIndex();
    // 扫描曲目只移除索引记录，绝不删除用户目录中的原文件。
    const keptScanned: Song[] = [];
    for (let i = 0; i < this.scannedSongs.length; i++) {
      if (ids.indexOf(this.scannedSongs[i].id) >= 0) {
        removedSongs.push(this.scannedSongs[i]);
      } else {
        keptScanned.push(this.scannedSongs[i]);
      }
    }
    this.scannedSongs = keptScanned;
    this.invalidateSongIndex();
    this.persistLocal();
    this.applyFavoriteFlags();
    return removedSongs.length;
  }
  markPlayed(songId: string): void {
    const song: Song | null = this.findSong(songId);
    if (song === null) {
      return;
    }
    song.lastPlayedAt = Date.now();
    song.playCount = song.playCount + 1;
    const entry: PlaylistEntry = new PlaylistEntry();
    entry.key = songTrackKey(song);
    entry.songId = song.platformSongId;
    entry.platform = song.platform;
    entry.localPath = song.source === MediaSource.SERVER_FILE ? song.filePath : song.localPath;
    entry.name = song.title;
    entry.singer = song.artist;
    entry.album = song.album;
    entry.durationMs = song.durationMs;
    const json: string = JSON.stringify(entry);
    const next: string[] = [json];
    for (let i = 0; i < this.recentJson.length && next.length < AppConstants.MAX_RECENT; i++) {
      if (this.recentJson[i] !== json) {
        next.push(this.recentJson[i]);
      }
    }
    this.recentJson = next;
    this.rebuildRecent();
    this.saver.run(() => {
      this.persistSnapshot();
    });
  }
}
export const libraryStore: LibraryStore = new LibraryStore();