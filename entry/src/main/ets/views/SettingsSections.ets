/**
 * 设置分区（下载存储 / 播放 / 外观 / 关于）。
 */
import { AppConstants } from '../common/Constants';
import { AppSelect } from '../components/AppSelect';
import { AppSlider } from '../components/AppSlider';
import { AppToggle } from '../components/AppToggle';
import { ConfirmDialog } from '../components/ConfirmDialog';
import { SettingGroup, SettingRow } from '../components/SettingRow';
import { BottomBarAnim, DownloadTarget, DownloadTargetHelper, QualityHelper, QualityLevel,
  ThemeHelper, ThemeMode } from '../model/SettingsModels';
import { SelectOptionItem } from '../model/UiModels';
import { ImportService, ImportResult } from '../service/ImportService';
import { Formatters } from '../service/Formatters';
import { downloadStore } from '../viewmodel/DownloadStore';
import { libraryStore } from '../viewmodel/LibraryStore';
import { settingsStore } from '../viewmodel/SettingsStore';
import { themeStore } from '../viewmodel/ThemeStore';

function qualityOptions(): SelectOptionItem[] {
  const levels: QualityLevel[] = QualityHelper.all();
  const result: SelectOptionItem[] = [];
  for (let i = 0; i < levels.length; i++) {
    result.push(new SelectOptionItem(levels[i], QualityHelper.shortLabel(levels[i])));
  }
  return result;
}

function qualityIndex(): number {
  const levels: QualityLevel[] = QualityHelper.all();
  for (let i = 0; i < levels.length; i++) {
    if (levels[i] === settingsStore.prefs.defaultQuality) {
      return i;
    }
  }
  return 0;
}

@ComponentV2
export struct SettingsDownloadSection {
  private targetOptions(): SelectOptionItem[] {
    const list: DownloadTarget[] = [DownloadTarget.LOCAL, DownloadTarget.SERVER, DownloadTarget.BOTH];
    const result: SelectOptionItem[] = [];
    for (let i = 0; i < list.length; i++) {
      result.push(new SelectOptionItem(list[i], DownloadTargetHelper.label(list[i])));
    }
    return result;
  }

  private targetIndex(): number {
    const list: DownloadTarget[] = [DownloadTarget.LOCAL, DownloadTarget.SERVER, DownloadTarget.BOTH];
    for (let i = 0; i < list.length; i++) {
      if (list[i] === settingsStore.prefs.downloadTarget) {
        return i;
      }
    }
    return 0;
  }

  private async importNow(): Promise<void> {
    const result: ImportResult = await ImportService.pickAndImport();
    if (result.cancelled) {
      return;
    }
    libraryStore.addImportedSongs(result.songs, result.skipped, result.message);
    ConfirmDialog.toast(this.getUIContext(), result.message);
  }

  build() {
    Column({ space: 16 }) {
      SettingGroup({
        groupTitle: '下载偏好',
        groupDesc: '默认音质与下载目标会应用到后续任务',
        cardColor: themeStore.palette.card,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      }) {
        SettingRow({
          rowTitle: '默认下载音质',
          rowDesc: QualityHelper.label(settingsStore.prefs.defaultQuality),
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          AppSelect({
            options: qualityOptions(),
            selectedIndex: qualityIndex(),
            textColor: themeStore.palette.text,
            accent: themeStore.palette.brand,
            selectWidth: 96,
            onSelect: (index: number) => {
              const levels: QualityLevel[] = QualityHelper.all();
              settingsStore.setQuality(levels[index]);
            }
          })
        }

        SettingRow({
          rowTitle: '下载目标',
          rowDesc: DownloadTargetHelper.label(settingsStore.prefs.downloadTarget),
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          AppSelect({
            options: this.targetOptions(),
            selectedIndex: this.targetIndex(),
            textColor: themeStore.palette.text,
            accent: themeStore.palette.brand,
            selectWidth: 104,
            onSelect: (index: number) => {
              const list: DownloadTarget[] = [DownloadTarget.LOCAL, DownloadTarget.SERVER, DownloadTarget.BOTH];
              settingsStore.setDownloadTarget(list[index]);
            }
          })
        }

        SettingRow({
          rowTitle: '内嵌高清封面',
          rowDesc: '下载时尝试写入专辑封面',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          AppToggle({
            isOn: settingsStore.prefs.embedCover,
            accent: themeStore.palette.brand,
            onToggle: (value: boolean) => {
              settingsStore.toggle(() => {
                settingsStore.prefs.embedCover = value;
              });
            }
          })
        }

        SettingRow({
          rowTitle: '内嵌歌词',
          rowDesc: '把逐行歌词写入音频文件',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          AppToggle({
            isOn: settingsStore.prefs.embedLyric,
            accent: themeStore.palette.brand,
            onToggle: (value: boolean) => {
              settingsStore.toggle(() => {
                settingsStore.prefs.embedLyric = value;
              });
            }
          })
        }

        SettingRow({
          rowTitle: '同时保存 .lrc 文件',
          rowDesc: '在歌曲同目录生成外挂歌词',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card,
          isLast: true
        }) {
          AppToggle({
            isOn: settingsStore.prefs.saveLrc,
            accent: themeStore.palette.brand,
            onToggle: (value: boolean) => {
              settingsStore.toggle(() => {
                settingsStore.prefs.saveLrc = value;
              });
            }
          })
        }
      }

      SettingGroup({
        groupTitle: '存储与路径',
        groupDesc: '导入的音频保存在应用沙箱，卸载应用会一并清除',
        cardColor: themeStore.palette.card,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      }) {
        SettingRow({
          rowTitle: '音乐存储位置',
          rowDesc: 'filesDir/imported（沙箱内）',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          Text(`${libraryStore.localSongs.length} 首本地`)
            .fontSize(10.5)
            .fontColor(themeStore.palette.sub)
        }

        SettingRow({
          rowTitle: '服务器下载',
          rowDesc: `已提交 ${downloadStore.tasks.length} 个任务`,
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          Text(`服务器完成 ${downloadStore.completedCount} 个`)
            .fontSize(10.5)
            .fontColor(themeStore.palette.sub)
        }

        SettingRow({
          rowTitle: '导入本地音乐',
          rowDesc: '通过系统文件选择器导入音频',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card,
          isLast: true
        }) {
          Text(libraryStore.importing ? '导入中…' : '选择文件')
            .fontSize(10.5)
            .fontColor('#FFFFFF')
            .padding({ left: 10, right: 10, top: 5, bottom: 5 })
            .borderRadius(10)
            .backgroundColor(themeStore.palette.brand)
            .onClick(() => {
              if (!libraryStore.importing) {
                libraryStore.importing = true;
                this.importNow().then(() => {
                  libraryStore.importing = false;
                }).catch(() => {
                  libraryStore.importing = false;
                });
              }
            })
        }
      }
    }
    .width('100%')
  }
}

@ComponentV2
export struct SettingsPlaybackSection {

  build() {
    Column({ space: 16 }) {
      SettingGroup({
        groupTitle: '播放行为',
        groupDesc: '影响播放器的启动与失败回退策略',
        cardColor: themeStore.palette.card,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      }) {
        SettingRow({
          rowTitle: '启动自动播放',
          rowDesc: '打开播放器时自动开始播放',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          AppToggle({
            isOn: settingsStore.prefs.autoPlay,
            accent: themeStore.palette.brand,
            onToggle: (value: boolean) => {
              settingsStore.toggle(() => {
                settingsStore.prefs.autoPlay = value;
              });
            }
          })
        }

        SettingRow({
          rowTitle: '在线失败回退本地',
          rowDesc: '在线音源不可用时尝试播放本地文件',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          AppToggle({
            isOn: settingsStore.prefs.autoFallbackLocal,
            accent: themeStore.palette.brand,
            onToggle: (value: boolean) => {
              settingsStore.toggle(() => {
                settingsStore.prefs.autoFallbackLocal = value;
              });
            }
          })
        }

        SettingRow({
          rowTitle: '开机自启',
          rowDesc: '系统自启由系统设置管理',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card,
          isLast: true
        }) {
          AppToggle({
            isOn: settingsStore.prefs.autoLaunch,
            accent: themeStore.palette.brand,
            onToggle: (value: boolean) => {
              settingsStore.toggle(() => {
                settingsStore.prefs.autoLaunch = value;
              });
            }
          })
        }
      }

      SettingGroup({
        groupTitle: '音频与缓存',
        groupDesc: '在线音频来自你的音乐服务器',
        cardColor: themeStore.palette.card,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      }) {
        SettingRow({
          rowTitle: '播放模式',
          rowDesc: '可在播放器中随时切换',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          Text('列表循环 / 单曲 / 顺序 / 随机')
            .fontSize(10)
            .fontColor(themeStore.palette.sub)
        }

        SettingRow({
          rowTitle: '音频输出',
          rowDesc: '跟随系统音量与输出设备',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          Text('系统默认')
            .fontSize(10)
            .fontColor(themeStore.palette.sub)
        }

        SettingRow({
          rowTitle: '重置播放队列',
          rowDesc: `当前队列 ${downloadStore.tasks.length >= 0 ? '' : ''}由播放器管理`,
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card,
          isLast: true
        }) {
          Text('清空')
            .fontSize(10.5)
            .fontColor(themeStore.palette.brand)
            .onClick(() => {
              ConfirmDialog.toast(this.getUIContext(), '可在播放器队列面板中清空队列');
            })
        }
      }
    }
    .width('100%')
  }
}

@ComponentV2
export struct SettingsAppearanceSection {
  @Local blurValue: number = 0.6;

  aboutToAppear(): void {
    this.blurValue = settingsStore.prefs.blurAlpha;
  }

  @Builder
  themeChip(mode: ThemeMode) {
    Text(ThemeHelper.label(mode))
      .fontSize(11)
      .fontColor(settingsStore.prefs.themeMode === mode ? '#FFFFFF' : themeStore.palette.text)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(14)
      .backgroundColor(settingsStore.prefs.themeMode === mode
        ? themeStore.palette.brand : themeStore.palette.controlBg)
      .onClick(() => {
        settingsStore.setThemeMode(mode);
        themeStore.setMode(mode);
      })
  }

  @Builder
  scaleChip(scale: number) {
    Text(`${Math.round(scale * 100)}%`)
      .fontSize(11)
      .fontColor(settingsStore.prefs.uiScale === scale ? '#FFFFFF' : themeStore.palette.text)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(14)
      .backgroundColor(settingsStore.prefs.uiScale === scale
        ? themeStore.palette.brand : themeStore.palette.controlBg)
      .onClick(() => {
        settingsStore.setUiScale(scale);
        themeStore.setScale(scale);
      })
  }

  @Builder
  animChip(mode: BottomBarAnim) {
    Text(mode === BottomBarAnim.TAP ? '点击切换' : '滑动切换')
      .fontSize(11)
      .fontColor(settingsStore.prefs.bottomBarAnim === mode ? '#FFFFFF' : themeStore.palette.text)
      .padding({ left: 12, right: 12, top: 7, bottom: 7 })
      .borderRadius(14)
      .backgroundColor(settingsStore.prefs.bottomBarAnim === mode
        ? themeStore.palette.brand : themeStore.palette.controlBg)
      .onClick(() => {
        settingsStore.setBottomBarAnim(mode);
      })
  }

  build() {
    Column({ space: 16 }) {
      SettingGroup({
        groupTitle: '主题',
        groupDesc: '深色为默认配色，浅色适配明亮环境',
        cardColor: themeStore.palette.card,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      }) {
        Column({ space: 10 }) {
          Row({ space: 8 }) {
            this.themeChip(ThemeMode.SYSTEM)
            this.themeChip(ThemeMode.DARK)
            this.themeChip(ThemeMode.LIGHT)
            Blank()
          }
          .width('100%')

          Row({ space: 8 }) {
            Text('界面缩放')
              .fontSize(11)
              .fontColor(themeStore.palette.sub)
            Blank()
          }
          .width('100%')

          Row({ space: 8 }) {
            this.scaleChip(0.9)
            this.scaleChip(1.0)
            this.scaleChip(1.1)
            this.scaleChip(1.2)
            Blank()
          }
          .width('100%')

          Row({ space: 8 }) {
            Text('底栏动画')
              .fontSize(11)
              .fontColor(themeStore.palette.sub)
            Blank()
          }
          .width('100%')

          Row({ space: 8 }) {
            this.animChip(BottomBarAnim.TAP)
            this.animChip(BottomBarAnim.SWIPE)
            Blank()
          }
          .width('100%')
        }
        .width('100%')
        .padding(14)
      }

      SettingGroup({
        groupTitle: '毛玻璃强度',
        groupDesc: '影响标题栏、迷你播放器与浮层的模糊程度',
        cardColor: themeStore.palette.card,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      }) {
        Column({ space: 6 }) {
          Row() {
            Text('当前强度')
              .fontSize(11)
              .fontColor(themeStore.palette.sub)
            Blank()
            Text(`${Math.round(this.blurValue * 100)}%`)
              .fontSize(11)
              .fontColor(themeStore.palette.brand)
          }
          .width('100%')

          AppSlider({
            sliderValue: this.blurValue,
            minValue: 0,
            maxValue: 1,
            stepValue: 0.05,
            accent: themeStore.palette.brand,
            onValueChange: (value: number) => {
              this.blurValue = value;
              settingsStore.setBlurAlpha(value);
              themeStore.setBlur(value);
            },
            onValueFinish: (value: number) => {
              this.blurValue = value;
              settingsStore.setBlurAlpha(value);
              themeStore.setBlur(value);
            }
          })
        }
        .width('100%')
        .padding(14)
      }

      SettingGroup({
        groupTitle: '资料库显示',
        groupDesc: '控制资料库首页展示哪些板块',
        cardColor: themeStore.palette.card,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      }) {
        SettingRow({
          rowTitle: '最近播放',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          AppToggle({
            isOn: settingsStore.prefs.showRecentlyPlayed,
            accent: themeStore.palette.brand,
            onToggle: (value: boolean) => {
              settingsStore.toggle(() => {
                settingsStore.prefs.showRecentlyPlayed = value;
              });
            }
          })
        }

        SettingRow({
          rowTitle: '最近添加',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          AppToggle({
            isOn: settingsStore.prefs.showRecentlyAdded,
            accent: themeStore.palette.brand,
            onToggle: (value: boolean) => {
              settingsStore.toggle(() => {
                settingsStore.prefs.showRecentlyAdded = value;
              });
            }
          })
        }

        SettingRow({
          rowTitle: '专辑',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          AppToggle({
            isOn: settingsStore.prefs.showAlbums,
            accent: themeStore.palette.brand,
            onToggle: (value: boolean) => {
              settingsStore.toggle(() => {
                settingsStore.prefs.showAlbums = value;
              });
            }
          })
        }

        SettingRow({
          rowTitle: '歌手',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card
        }) {
          AppToggle({
            isOn: settingsStore.prefs.showArtists,
            accent: themeStore.palette.brand,
            onToggle: (value: boolean) => {
              settingsStore.toggle(() => {
                settingsStore.prefs.showArtists = value;
              });
            }
          })
        }

        SettingRow({
          rowTitle: '我喜欢',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card,
          isLast: true
        }) {
          AppToggle({
            isOn: settingsStore.prefs.showFavorites,
            accent: themeStore.palette.brand,
            onToggle: (value: boolean) => {
              settingsStore.toggle(() => {
                settingsStore.prefs.showFavorites = value;
              });
            }
          })
        }
      }
    }
    .width('100%')
  }
}

@ComponentV2
export struct SettingsAboutSection {
  build() {
    Column({ space: 16 }) {
      Column({ space: 6 }) {
        Text(AppConstants.APP_NAME)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
        Text(`版本 ${AppConstants.APP_VERSION} · HarmonyOS 26`)
          .fontSize(11)
          .fontColor(themeStore.palette.sub)
        Text('连接你自建的柠檬音乐服务端，同步并播放服务器曲库')
          .fontSize(10.5)
          .fontColor(themeStore.palette.sub)
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding(16)
      .borderRadius(18)
      .backgroundColor(themeStore.palette.card)

      SettingGroup({
        groupTitle: '开源许可',
        cardColor: themeStore.palette.card,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      }) {
        Column({ space: 6 }) {
          Text('· HarmonyOS ArkUI / ArkTS 系统能力').fontSize(10.5).fontColor(themeStore.palette.sub)
          Text('· 曲库、封面与歌词由你的自建服务端提供').fontSize(10.5).fontColor(themeStore.palette.sub)
          Text('· 应用不内置任何歌曲、榜单或播客内容').fontSize(10.5).fontColor(themeStore.palette.sub)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(14)
      }

      SettingGroup({
        groupTitle: '免责声明',
        cardColor: themeStore.palette.card,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      }) {
        Column({ space: 6 }) {
          Text('本应用仅作为你自建音乐服务端的客户端。所有曲库、榜单、推荐、播客与下载任务均由你自己的服务器提供，应用不内置任何媒体内容；请确保你拥有对所访问内容的合法使用权。')
            .fontSize(10.5)
            .fontColor(themeStore.palette.sub)
          Text('用户导入的本地音频仅在应用沙箱内使用，可在系统设置中清除应用数据以删除。')
            .fontSize(10.5)
            .fontColor(themeStore.palette.sub)
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)
        .padding(14)
      }

      SettingGroup({
        groupTitle: '维护',
        cardColor: themeStore.palette.card,
        textColor: themeStore.palette.text,
        subColor: themeStore.palette.sub
      }) {
        SettingRow({
          rowTitle: '恢复默认设置',
          rowDesc: '将主题、缩放与所有开关恢复初始值',
          textColor: themeStore.palette.text,
          subColor: themeStore.palette.sub,
          rowColor: themeStore.palette.card,
          isLast: true
        }) {
          Text('恢复')
            .fontSize(10.5)
            .fontColor(themeStore.palette.brand)
            .onClick(() => {
              ConfirmDialog.confirm(this.getUIContext(), '恢复默认设置', '所有偏好将回到初始状态。', '恢复')
                .then((ok: boolean) => {
                  if (ok) {
                    settingsStore.resetAll();
                    themeStore.setMode(settingsStore.prefs.themeMode);
                    themeStore.setScale(settingsStore.prefs.uiScale);
                    themeStore.setBlur(settingsStore.prefs.blurAlpha);
                    ConfirmDialog.toast(this.getUIContext(), '已恢复默认设置');
                  }
                });
            })
        }
      }
    }
    .width('100%')
  }
}
