/**
 * 播放启动辅助：把 Song 列表转成队列并交给 PlayerStore，供多个页面复用。
 */
import { PlayableItem, Song } from '../model/MediaModels';
import { playerStore } from '../viewmodel/PlayerStore';

export function toPlayableItems(songs: Song[]): PlayableItem[] {
  const items: PlayableItem[] = [];
  for (let i = 0; i < songs.length; i++) {
    items.push(PlayableItem.fromSong(songs[i]));
  }
  return items;
}

export function playVisualSong(songs: Song[], index: number): void {
  if (songs.length === 0) {
    return;
  }
  playerStore.loadQueue(toPlayableItems(songs), index, true);
}

export function playSongsShuffled(songs: Song[]): void {
  if (songs.length === 0) {
    return;
  }
  const shuffled: Song[] = songs.slice();
  for (let i = shuffled.length - 1; i > 0; i--) {
    const j: number = Math.floor(Math.random() * (i + 1));
    const temp: Song = shuffled[i];
    shuffled[i] = shuffled[j];
    shuffled[j] = temp;
  }
  playerStore.loadQueue(toPlayableItems(shuffled), 0, true);
}

export function queueSong(song: Song): void {
  playerStore.addToQueue([PlayableItem.fromSong(song)]);
}

export function queueSongs(songs: Song[]): void {
  playerStore.addToQueue(toPlayableItems(songs));
}
