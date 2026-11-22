/**
 * LRC 歌词解析：逐行时间戳、偏移应用、当前行计算。
 */
import { LyricDoc, LyricLine } from '../model/LyricModels';

export class LyricParser {
  static parse(lrc: string): LyricDoc {
    const doc: LyricDoc = new LyricDoc();
    if (lrc === null || lrc === undefined || lrc.trim().length === 0) {
      return LyricDoc.empty();
    }
    const rawLines: string[] = lrc.split('\n');
    const lines: LyricLine[] = [];
    for (let i = 0; i < rawLines.length; i++) {
      const raw: string = rawLines[i].trim();
      if (raw.length === 0) {
        continue;
      }
      const timeMs: number = LyricParser.parseFirstTimestamp(raw);
      if (timeMs < 0) {
        continue;
      }
      const text: string = LyricParser.stripTimestamps(raw);
      if (text.length === 0) {
        continue;
      }
      lines.push(new LyricLine(timeMs, text));
    }
    if (lines.length === 0) {
      return LyricDoc.empty();
    }
    lines.sort((a: LyricLine, b: LyricLine) => a.timeMs - b.timeMs);
    doc.lines = lines;
    doc.isSynced = true;
    doc.source = lrc;
    return doc;
  }

  static parseFirstTimestamp(line: string): number {
    if (line.length < 5) {
      return -1;
    }
    const open: number = line.indexOf('[');
    const close: number = line.indexOf(']');
    if (open < 0 || close <= open) {
      return -1;
    }
    const inside: string = line.substring(open + 1, close);
    const parts: string[] = inside.split(':');
    if (parts.length < 2) {
      return -1;
    }
    const minutes: number = parseInt(parts[0], 10);
    const secondPart: string = parts[1];
    const dot: number = secondPart.indexOf('.');
    const secondsText: string = dot >= 0 ? secondPart.substring(0, dot) : secondPart;
    const seconds: number = parseInt(secondsText, 10);
    if (Number.isNaN(minutes) || Number.isNaN(seconds)) {
      return -1;
    }
    let millis: number = 0;
    if (dot >= 0) {
      let fraction: string = secondPart.substring(dot + 1);
      if (fraction.length === 1) {
        fraction = `${fraction}00`;
      } else if (fraction.length === 2) {
        fraction = `${fraction}0`;
      }
      millis = parseInt(fraction, 10);
      if (Number.isNaN(millis)) {
        millis = 0;
      }
    }
    return minutes * 60000 + seconds * 1000 + millis;
  }

  static stripTimestamps(line: string): string {
    let result: string = line;
    let guard: number = 0;
    while (result.startsWith('[') && guard < 6) {
      const close: number = result.indexOf(']');
      if (close < 0) {
        break;
      }
      result = result.substring(close + 1).trim();
      guard++;
    }
    return result;
  }

  static activeIndex(doc: LyricDoc, positionMs: number, offsetMs: number = 0): number {
    if (doc.lines.length === 0) {
      return -1;
    }
    const effective: number = positionMs + offsetMs;
    let index: number = -1;
    for (let i = 0; i < doc.lines.length; i++) {
      if (doc.lines[i].timeMs <= effective) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  static applyOffset(doc: LyricDoc, offsetMs: number): LyricDoc {
    const next: LyricDoc = new LyricDoc();
    next.isSynced = doc.isSynced;
    next.source = doc.source;
    next.offsetMs = offsetMs;
    const lines: LyricLine[] = [];
    for (let i = 0; i < doc.lines.length; i++) {
      lines.push(new LyricLine(doc.lines[i].timeMs, doc.lines[i].text));
    }
    next.lines = lines;
    return next;
  }
}
