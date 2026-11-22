# Implementation Plan: LMPlayer 柠檬音乐 · 服务器全功能接入

**Input**: Feature specification from `spec/lmplayer-harmony-port/spec.md`（v3，13 个用户故事 / 95 条功能需求）

**Note**: 本文件替代 v1「演示数据版」计划，作为本轮服务器接入的 Phase 3/4/5 唯一设计依据；既有 HarmonyOS 工程与 MVVM 分层保留，增量演进。

## Summary

在现有 `E:\lm-music\harmony` 工程（103 个 `.ets`，状态管理 V2，Navigation + Tabs + 播放器叠层）上，新增完整服务端接入层：HTTP 客户端、会话与自动重登、分页曲库同步与本地快照缓存、签名播放地址解析、带鉴权封面缓存、歌词获取、收藏/歌单双向写回，并把发现页、搜索、下载、播客、音源管理、标签编辑全部切到服务端真实接口；同时删除全部内置演示数据，未连接/离线时统一空态+重试。播放器继续使用单例 AVPlayer，视觉层保持沉浸光感。

本轮增量：① 原「发现」页签更名「首页」，首页提供「本地曲库 / 柠檬音乐服务器」模式切换；② 新增本地文件夹持久授权 + 递归扫描 + 标签/封面提取 + 增量索引；③ 底部导航重设计为华为音乐风整宽玻璃 Dock（高光、选中放大、标签渐现、封面主色轻染、上沿进度线）。

## Technical Context

**Language/Version**: ArkTS（HarmonyOS 26.0.0 / API 26）
**Primary Dependencies**: ArkUI、`@kit.NetworkKit`（http）、`@kit.MediaKit`（AVPlayer/AVMetadataExtractor）、`@kit.CoreFileKit`（fileIo/picker/fileShare）、`@kit.ArkData`（preferences）、`@kit.ArkUI`（uiMaterial/mediaquery）、`@kit.ImageKit` + `@kit.ArkGraphics2D`（封面解码与主色提取）、`@kit.BasicServicesKit`（BusinessError）、`@kit.PerformanceAnalysisKit`（hilog）
**State Management**: 状态管理 V2（`@ComponentV2` + `@Local/@Param/@Event/@Computed`；全局 Store 为模块级 `@ObservedV2` 单例 + `@Trace`）；不引入 V1 装饰器
**Storage**: preferences（设置/服务器配置/会话 Token+过期时间/搜索历史/首页模式）；`filesDir/data/server_<serverId>.json`（曲库快照/歌单/收藏/最近/同步元数据）；`filesDir/data/local_index.json`（本地文件夹授权 URI、扫描曲目、封面缓存键、最后扫描时间）；`cacheDir/covers/`（封面缓存）；`filesDir/imported/`（本地导入音频）
**Testing**: `devecocli build` + `devecocli check arkts` + 模拟器安装运行；接口层用真实服务器 smoke（health/login/tracks/play/cover/lyric/discover/search/download/podcast/source/tag-read）
**Target Platform**: HarmonyOS 26.0.0（API 26）；模拟器 Mate 80 Pro Max；服务端实测 `http://nas.sixfun.xyz:7983`
**Project Type**: mobile-app（单 entry 模块，Stage 模型，既有工程增量）
**Performance Goals**: 首屏 ≤5s；登录 ≤5s；500 首同步 ≤15s；起播 ≤2s；封面首载 ≤1.5s、缓存命中 ≤100ms；列表滚动 60fps；JSON 解析不阻塞 UI 线程
**Constraints**: 局域网 HTTP 明文；Token 30 天；密码不落盘；歌单含 689 条混合条目；标签写入破坏性；不执行 JS 音源脚本；媒体流需鉴权或签名
**Scale/Scope**: 13 个用户故事、95 条 FR；服务端当前 55 曲/54 专辑/45 歌手/1 歌单(689 条)/36 榜单/7 音源脚本；新增约 26 个 `.ets`，修改约 22 个

## Project Structure

### Documentation (this feature)

```text
E:\lm-music\spec\lmplayer-harmony-port\
├── spec.md      # v3 需求（13 US / 95 FR / 22 SC）
├── plan.md      # 本文件
└── tasks.md     # Phase 3 重新生成
```

### Source Code (repository root)

工程根：`E:\lm-music\harmony\`；新增文件标 `[NEW]`，修改文件标 `[MOD]`，删除标 `[DEL]`。

```text
E:\lm-music\harmony\entry\src\main\
├── module.json5                                   [MOD] 增加 INTERNET 与 FILE_ACCESS_PERSIST 权限
├── ets\
│   ├── common\
│   │   ├── Constants.ets                          [MOD] 服务端/超时/缓存键/删除演示常量
│   │   ├── ServerEndpoints.ets                    [NEW] 路径常量、URL 构造、查询编码、音质映射
│   │   ├── Palette.ets                            （不变）
│   │   ├── Logger.ets                             [MOD] 敏感字段脱敏
│   │   ├── Utils.ets                              [MOD] 哈希/并发限制/重试退避/防抖
│   │   └── Breakpoints.ets                        （不变）
│   ├── model\
│   │   ├── MediaModels.ets                        [MOD] Song/PlayableItem 增加服务器与在线字段
│   │   ├── ServerModels.ets                       [NEW] 会话/曲库/歌单/同步/下载/播客/音源/标签
│   │   ├── LocalScanModels.ets                    [NEW] 本地文件夹/扫描状态/本地曲目/首页模式
│   │   ├── SettingsModels.ets                     [MOD] ServerConfig 增加过期/状态/名称
│   │   ├── DownloadModels.ets                     [MOD] 服务端任务状态映射
│   │   ├── PodcastModels.ets                      [MOD] 服务端 Feed/Episode
│   │   ├── LyricModels.ets                        （不变）
│   │   └── UiModels.ets                           [MOD] 发现/搜索结果/路由参数
│   ├── data\
│   │   ├── ServerSchemas.ets                      [NEW] 所有服务端 DTO Raw + 逐字段校验
│   │   ├── ServerCache.ets                        [NEW] 按服务器命名空间的快照读写
│   │   ├── LocalIndexStore.ets                    [NEW] 本地文件夹授权/曲目索引/扫描元数据持久化
│   │   ├── Schemas.ets                            [MOD] 本地曲库/播放器 DTO 增字段
│   │   ├── JsonStore.ets                          （不变）
│   │   ├── PreferencesRepo.ets                    [MOD] 会话过期/搜索历史等键
│   │   ├── SeedService.ets                        [DEL] 演示播种
│   │   ├── DemoCatalogMedia.ets                   [DEL] 演示媒体目录
│   │   └── DemoCatalogPodcast.ets                 [DEL] 演示播客目录
│   ├── service\
│   │   ├── HttpClient.ets                         [NEW] http 封装（超时/状态/JSON/二进制/错误映射）
│   │   ├── ServerApi.ets                          [NEW] 全部接口：auth/library/user-data/play/tag/discover/search/download/podcast/source
│   │   ├── ServerManager.ets                      [NEW] 激活服务器、登录/登出/会话校验/401 重登/请求守卫
│   │   ├── ServerSync.ets                         [NEW] 分页同步、DTO→模型、原子写快照、同步进度
│   │   ├── PlayUrlResolver.ets                    [NEW] /api/play/url 签名地址解析 + TTL 缓存 + 回退
│   │   ├── CoverService.ets                       [NEW] 带鉴权/外链封面下载到 cacheDir + 并发控制
│   │   ├── LyricService.ets                       [NEW] tag/read → play/lyric → 快照歌词
│   │   ├── DiscoverService.ets                    [NEW] 榜单/新歌/新碟/推荐（按音源 5 分钟缓存）
│   │   ├── ServerDownloadService.ets              [NEW] 任务动作与轮询
│   │   ├── PodcastService.ets                     [NEW] 订阅/单集/刷新/取消
│   │   ├── SourceService.ets                      [NEW] 脚本列表/启停/导入/平台开关
│   │   ├── TagService.ets                         [NEW] read/match/apply/write
│   │   ├── LocalScanService.ets                   [NEW] 文件夹选择/持久授权/递归扫描/增量 diff/取消
│   │   ├── MediaTagService.ets                    [NEW] AVMetadataExtractor 读标签与内嵌封面
│   │   ├── ColorService.ets                       [NEW] 封面解码 + effectKit 主色提取与缓存
│   │   ├── AvSessionService.ets                   [NEW] AVSession 元数据/状态/控制/歌词/封面
│   │   ├── BackgroundPlaybackService.ets          [NEW] audioPlayback 长时任务启停
│   │   ├── PlayerService.ets                      [MOD] 支持带 header 媒体源与 URL 重设
│   │   ├── ImportService.ets                      （不变）
│   │   ├── LyricParser.ets                        （不变）
│   │   ├── SearchService.ets                      [MOD] 本地+服务端曲库预过滤
│   │   ├── DownloadSimulator.ets                  [DEL] 演示下载模拟
│   │   └── Formatters.ets                         [MOD] mm:ss、qualitys、文件大小
│   ├── viewmodel\
│   │   ├── ServerStore.ets                        [NEW] 连接状态/延迟/用户/错误/登录动作
│   │   ├── SyncStore.ets                          [NEW] 同步阶段/进度/最后同步/错误
│   │   ├── DiscoverStore.ets                      [MOD] 重写为真实数据 + 分区块状态
│   │   ├── LibraryStore.ets                       [MOD] 服务端快照 + 本地扫描曲目 + 收藏/歌单写回
│   │   ├── LocalScanStore.ets                     [NEW] 文件夹列表/扫描进度/本地曲目/首页模式
│   │   ├── ScrollChromeStore.ets                  [NEW] 滚动偏移/折叠态/搜索收起/页签重置
│   │   ├── PlayerTransitionStore.ets              [NEW] 播放器 progress/目标矩形/动画状态
│   │   ├── DownloadStore.ets                      [MOD] 服务端任务 + 轮询 + 动作
│   │   ├── PodcastStore.ets                       [MOD] 服务端订阅/单集/进度
│   │   ├── SourceStore.ets                        [NEW] 脚本列表/健康/动作
│   │   ├── TagStore.ets                           [NEW] 标签读取/匹配/写入状态
│   │   ├── SearchStore.ets                        [MOD] 在线范围/结果/历史
│   │   ├── PlayerStore.ets                        [MOD] 播放前解析地址、歌词/封面加载、播客进度
│   │   ├── SettingsStore.ets                      [MOD] 去演示、服务器 CRUD/激活/Token
│   │   ├── ThemeStore.ets                         （不变）
│   │   ├── LayoutStore.ets                        （不变）
│   │   ├── OverlayStore.ets                       [MOD] 搜索/播放器/标签浮层状态
│   │   └── LibraryViewState.ets                   （不变）
│   ├── components\
│   │   ├── Artwork.ets                            [MOD] 远程封面（缓存文件）优先，失败回退渐变
│   │   ├── SongRow.ets                            [MOD] 来源徽章/在线标记/更多动作
│   │   ├── EmptyState.ets                         [MOD] 支持动作按钮（去设置/重试）
│   │   ├── AppSelect.ets                          （不变）
│   │   ├── AppSlider.ets / AppToggle.ets          （不变）
│   │   ├── AddToPlaylistSheet.ets                 [MOD] 服务端写回与错误回滚
│   │   ├── StorageDetailSheet.ets                 [MOD] 仅本地曲目
│   │   ├── ConfirmDialog.ets                      （不变）
│   │   ├── SheetShell.ets                         （不变）
│   │   ├── ServerStatusCard.ets                   [NEW] 在线状态/延迟/最后同步/数量
│   │   ├── DownloadTaskRow.ets                    [NEW] 服务端任务行与进度
│   │   ├── BottomDock.ets                          [MOD] 合并播放行+页签行的整块玻璃 Dock（高光/选中放大/进度线/极淡主色）
│   │   ├── HomeHeader.ets                         [MOD] 首页标题+双下拉+可收起搜索框/搜索图标
│   │   ├── CollapsedBar.ets                       [NEW] 上滑折叠态：首页圆钮+紧凑播放器+播控
│   │   ├── HomeModeSwitch.ets                     [NEW] 本地曲库 / 柠檬音乐服务器分段切换
│   │   └── SectionHeader.ets / GlassCard.ets / Badge.ets / MiniPlayer.ets [MOD 独立模糊玻璃胶囊] / ImmersiveHeader.ets （基本不变）
│   ├── player\
│   │   ├── FullscreenPlayer.ets                   [MOD] 接收 progress，驱动缩放/位移/圆角/透明度
│   │   ├── CoverPanel.ets                         [MOD] 远程封面、音质徽章
│   │   ├── LyricsPanel.ets                        （不变）
│   │   ├── LyricAdjustSheet.ets                   （不变）
│   │   ├── QueueSheet.ets                         （不变）
│   │   └── PlayerMoreSheet.ets                    [MOD] 标签编辑入口/下载入口
│   ├── views\
│   │   ├── DiscoverView.ets                       [MOD] 仅保留内容区，删除标题/音源 Chip（迁入 HomeHeader）
│   │   ├── HomeView.ets                           [MOD] 使用 HomeHeader + 本地/服务器内容
│   │   ├── LocalHomeView.ets                      [NEW] 本地扫描结果/最近添加/文件夹管理/扫描状态
│   │   ├── LibraryView.ets                        [MOD] 服务端状态/真实数量/最近添加
│   │   ├── DownloadView.ets                       [MOD] 服务端任务看板
│   │   ├── SearchView.ets                         [MOD] 在线范围/分页/收藏/加入歌单
│   │   ├── PodcastHomeView.ets                    [MOD] 服务端订阅/添加 RSS
│   │   ├── SettingsView.ets                       （不变）
│   │   ├── SettingsSections.ets                   [MOD] 服务器状态与同步入口
│   │   ├── SettingsAccountSection.ets             [MOD] 真实登录表单/测试/登出
│   │   ├── SourceManageView.ets                   [NEW] 音源脚本管理
│   │   └── TagEditorView.ets                      [NEW] 标签读取/匹配/写入
│   └── pages\
│       ├── Index.ets                              [MOD] 启动引导/空态路由/新增路由
│       ├── LibraryDetailPage.ets                  [MOD] 服务端数据/写回/下载/标签入口
│       ├── DiscoverCollectionPage.ets             [NEW] 榜单/新碟/推荐歌单曲目页
│       ├── PodcastShowPage.ets                    [MOD] 服务端单集
│       ├── PodcastSearchPage.ets                  [DEL] 改为添加 RSS 弹窗
│       ├── PodcastManagePage.ets                  [MOD] 服务端订阅管理
│       ├── SourceManagePage.ets                   [NEW] 音源管理路由页
│       └── TagEditorPage.ets                      [NEW] 标签编辑路由页
└── resources\
    ├── base\profile\router_map.json               [MOD] 新增路由
    ├── base\profile\main_pages.json               （不变）
    ├── base\element\string.json                   [MOD] 新模块文案
    ├── base\media\*.svg                           [MOD] 追加 server/source/tag/download 图标
    └── rawfile\music\*.wav                        [DEL] 演示音频
```

**Structure Decision**: 沿用现有工程与 MVVM 分层，不迁移、不重构。新增能力按职责放入既有 `service/`（网络与系统能力）、`viewmodel/`（状态与编排）、`data/`（DTO/缓存）、`model/`（领域模型）、`views/`/`pages/`（界面），符合现有 `pages→views→components` 与 `viewmodel→service→data` 的单向依赖。文件数从 74 增至约 118（服务端 9 类能力域 + 本地扫描 3 个服务 + 首页 3 个视图 + 底栏 2 个组件）；继续保持单文件 ≤800 行，模型按域合并（`ServerModels.ets`、`LocalScanModels.ets` 各承载多类实体），避免"一概念一文件"。

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| 文件数增至约 90（模板建议 6–12） | 接入 9 类服务端能力（认证/曲库/播放/发现/搜索/下载/播客/音源/标签），且需保留既有 UI 与播放器 | 合并为少量巨型文件会突破 800 行与 ArkTS 编译可维护性，也无法分模块验收 |
| 新增独立 `HttpClient` + `ServerApi` 两层 | 需要统一错误映射、401 重登、超时、JSON/二进制、签名地址 | 各 Service 直接调 http 会重复实现鉴权、超时与错误处理，且日志易泄露 Token |
| 服务端快照 JSON 与本地曲库 JSON 分离 | 多服务器命名空间、切换服务器不串数据、离线可读 | 共用 `library.json` 会在切换服务器时污染缓存，且无法区分来源 |
| 播放前异步解析签名地址 | 媒体流需鉴权，AVPlayer 直接播放会 401；签名地址已验证可免头播放 | 给 AVPlayer 加 header 也可行，但签名接口同时处理在线来源与音质，覆盖面更广；保留 header 回退 |
| 标签写入单独路由页 + 二次确认 | 破坏性操作，需展示只读信息与匹配候选 | 放在详情页内联弹窗容易误触，且无法容纳匹配列表 |

## Research & Decisions

### R1. 服务端协议与实测结果

- **Decision**: 以 Android 端 `LemonMusicProtocol.kt` 为协议基准，所有路径、字段、信封与错误处理与其对齐；服务端为 `http://nas.sixfun.xyz:7983`。
- **Rationale**: 该协议已在 Android 端长期使用；实测 13 组接口全部返回预期结构（详见 R2–R14 的实测值）。
- **Alternatives considered**: 以服务端仓库文档为准（无法访问，且与客户端实际用法可能不一致）；自行推测 REST 规范（风险高）。
- **约束**: 响应信封存在 `data[]`、`data.list[]`、`list[]`、裸数组四种形式，解析器必须全部兼容；数值字段可能为字符串（`play_count`、`total`、`count`）。

### R2. HTTP 客户端

- **Decision**: 新增 `HttpClient`，基于 `@ohos.net.http` 的 `createHttp().request`，统一返回 `{ status, bodyText, bytes }`；每次请求新建 `HttpRequest` 并 `destroy()`，统一设置 15s 连接/30s 读取（长任务 60s），`expectDataType: STRING` 或 `ARRAY_BUFFER`。
- **Rationale**: 官方推荐接口；明文 HTTP 无需额外配置（官方 FAQ 明确支持）；统一封装才能做 Token 注入、401 处理与错误映射。
- **Alternatives considered**: `rcp`（能力更全但本项目无需会话/多路复用）；`@system.fetch`（已停止维护）。
- **约束**: 响应体上限按需设置；不得在日志中输出 Authorization 或完整 URL 查询串（含 ticket）。

### R3. 会话与自动重登

- **Decision**: `ServerManager` 持有激活服务器与内存 Token；登录返回 `token + expiresAt`（实测 30 天），持久化到 `ServerConfig.token/tokenExpiresAt`；密码仅保存在内存 `sessionPassword`，冷启动后不恢复。请求统一走 `withAuth`：401 时若内存有密码则重登一次并重放，否则清除会话、标记 `SESSION_EXPIRED` 并提示重新登录。
- **Rationale**: 满足"重启免登录"与"密码不落盘"的安全要求；30 天有效期足以覆盖日常使用。
- **Alternatives considered**: 持久化密码自动重登（安全风险）；每次启动重新登录（体验差）；HUKS 加密存储密码（增加密钥管理复杂度，本期不需要）。
- **约束**: 重登必须串行且只重试一次，避免 401 风暴；Token 变更后所有缓存请求使用新 Token。

### R4. 凭据与日志安全

- **Decision**: `Logger` 增加 `redact()`；禁止记录密码、Token、`ticket` 参数、完整 Authorization；错误提示只显示状态码与业务错误字段。
- **Rationale**: 规格 FR-007 与安全红线。
- **Alternatives considered**: 仅靠人工避免（不可靠）。
- **约束**: 崩溃上报/Toast/UI 均不得回显凭据。

### R5. 曲库同步与快照

- **Decision**: `ServerSync` 依次拉取 tracks（分页 200）、albums（分页 500）、artists（分页 500）、user-data、playlists（user-data 优先，`/api/library/playlists` 回退），全部成功后一次性写入 `data/server_<serverId>.json`；任一页失败则整体失败并保留旧快照。
- **Rationale**: 避免残缺列表覆盖缓存（规格 FR-014）；按服务器命名空间隔离（FR-020）。
- **Alternatives considered**: 逐页增量写（中途失败会留下半份数据）；数据库存储（增加 DAO/SQL 样板，收益低）。
- **约束**: 分页终止条件：本页数量 < pageSize、无新增 filePath、累计 ≥ total、页数上限 5000；解析时按 filePath 去重。

### R6. 曲目身份与混合歌单

- **Decision**: 服务器文件曲目 id = `lemon_<md5(filePath)>`；在线来源条目 id = `lemon_online_<platform>_<songId|songmid|hash|copyrightId>`；`Song` 增加 `filePath/trackId/platform/platformSongId/onlineIds/coverUrl/qualitys/mtime/hasPicture` 等字段；歌单条目同时保存 `trackKey` 与 `snapshotJson` 以支持写回。
- **Rationale**: 实测歌单 689 条中绝大多数为 `wy:`/`kw:` 在线键，且 3 条无快照；必须保留原始 key 才能正确写回（FR-034）。
- **Alternatives considered**: 只展示本地文件（歌单几乎为空）；统一转成服务器文件（在线条目无法映射）。
- **约束**: 无快照的条目仍需展示可读占位（标题从 key 推导或"未知曲目"），播放失败给出提示。

### R7. 播放地址解析

- **Decision**: `PlayUrlResolver.resolve(item, quality)` 优先 `POST /api/play/url`：本地传 `{source:'local', filePath, trackId, quality, type}`，在线传 `{source, songId/songmid/hash/copyrightId, quality, type}`；返回相对地址补全 base；成功地址按 `serverId|key|quality` 缓存 10 分钟（实测带 `ticket` 可免 Authorization 播放）。失败回退 `/api/play/local?path=` + 带 Authorization 的 `MediaSource`。
- **Rationale**: 实测签名地址 206 可直接给 AVPlayer；在线 `wy` 曲目也返回代理地址 206；避免媒体层鉴权复杂性。
- **Alternatives considered**: 全部带 header 播放（AVPlayer 需 `createMediaSourceWithUrl`，可行但增加状态机复杂度）；本地缓存音频（违背"在线播放"）。
- **约束**: 签名失败不得静默播放未鉴权 URL；缓存命中需校验有效期；音质映射 `standard→128k, high→320k, lossless→flac, hires→flac24bit`。

### R8. 封面缓存

- **Decision**: `CoverService.coverUri(song)`：服务器文件 → `GET /api/tag/cover?path=<enc>&v=<mtime>`（带 Bearer）；在线 → `picUrl/img`（无鉴权）；下载字节写入 `cacheDir/covers/<md5(key)>.<ext>`，成功返回 `file://` 路径；失败返回空串由 `Artwork` 回退渐变。并发限制 4，命中检查文件存在与 mtime。
- **Rationale**: 实测 `Image` 无法附加 Authorization；`/api/tag/cover` 无 Token 返回 401；缓存可满足 SC-004。
- **Alternatives considered**: 使用 `Image` 直接加载 URL（401）；把 Token 拼进 URL（服务端不支持且泄露）。
- **约束**: 缓存上限约 200MB / 500 张，超出按 LRU 清理；外链 HTTP 图片允许明文。

### R9. 歌词

- **Decision**: 服务器文件优先 `POST /api/tag/read`（filePath/path）读 `data.lyric`；为空或失败则 `POST /api/play/lyric`（filePath/trackId/name/singer/album/interval）；在线条目优先快照 `lyric`，否则 `POST /api/play/lyric`（source + 平台 ID）；兼容 `lxlyric/lyric/ylyric/tlyric/rlyric`。
- **Rationale**: 实测 `tag/read` 返回 1251 字符带时间戳；在线 `play/lyric` 返回 849 字符。
- **Alternatives considered**: 仅用 `play/lyric`（服务器本地文件可能无匹配）；仅用 `tag/read`（在线条目不支持）。
- **约束**: 结果按曲目缓存于内存（LRU 50）；无歌词展示空态，不阻断播放。

### R10. 收藏与歌单写回

- **Decision**: 所有写操作经 `ServerManager.writeLock` 串行；收藏：GET user-data → 基于 `favorites` 数组保留未知条目 → 插入/删除目标快照 → PUT `{favorites}`；歌单：读取 `data.playlists` 或 `/api/library/playlists` → 修改 `trackKeys`/`trackSnapshots` → PUT `{playlists}`。读取失败立即中止并提示。
- **Rationale**: 规格 FR-031–FR-036；Android 端已采用同样的"整表读改写 + 锁"策略。
- **Alternatives considered**: 逐条增量接口（服务端未提供）；盲目写入（会清空用户收藏）。
- **约束**: 写回成功后更新本地快照；失败回滚 UI 状态；不得并发读改写。

### R11. 发现页

- **Decision**: `DiscoverService` 并行（或顺序）拉取 toplists/new-songs/new-albums/recommend，按音源缓存 5 分钟；榜单详情走 `/api/discover/toplist`；新碟走 `/api/album`；推荐歌单走 `/api/playlist?url=<id>`。每个区块独立 `loading/error/data`。
- **Rationale**: 实测 36 榜单；推荐接口 limit 固定返回 10；单区块失败不应拖垮整页。
- **Alternatives considered**: 一次性聚合接口（服务端未提供）；无缓存（切换音源频繁请求）。
- **约束**: 记住音源选择；离线时展示缓存并标注过期。

### R12. 搜索

- **Decision**: 搜索页保留本地/服务器曲库即时过滤；在线结果通过 `/api/search`、`/api/search/album`、`/api/search/playlist` 拉取，300ms 防抖 + 分页。结果可直接播放/收藏/加入歌单。
- **Rationale**: 规格 US9；实测三接口均可用。
- **Alternatives considered**: 仅本地过滤（无法获取新内容）；仅在线（离线不可用）。
- **约束**: 历史 ≤10 条；请求需带序号，丢弃过期响应。

### R13. 服务器下载任务

- **Decision**: `DownloadStore` 拉取 `/api/download/list` 并映射状态；动作走 `/api/download/add`、`/{id}/pause|resume|retry`、`/{id}/dismiss`、`/clear-completed`（以服务端实际路由为准，先按 Android 端调用方式实现）；有活动任务时每 3s 轮询，页面不可见时停止。
- **Rationale**: 规格 US10；实测列表可用。
- **Alternatives considered**: 本地模拟（不符合真实服务器）；WebSocket（服务端未提供）。
- **约束**: 轮询需去重与页面生命周期绑定；删除任务不删除音频文件；完成任务后触发同步。

### R14. 播客

- **Decision**: `PodcastService` 实现 GET/POST/DELETE `/api/podcasts`、GET `/api/podcasts/{id}/episodes?page&limit`、POST `/refresh`；单集音频直接交给 AVPlayer；进度存本地 `podcasts.json`。
- **Rationale**: 服务端当前 0 订阅，需用户提供 RSS；接口实测正常。
- **Alternatives considered**: 内置播客目录（已删除演示数据）；跳过播客（用户要求全量）。
- **约束**: RSS 抓取可能耗时 60s，使用长超时；失败提示可读原因。

### R15. 音源脚本管理

- **Decision**: `SourceService` 拉取 `/api/source/list`，展示脚本与平台能力/健康；支持 activate/deactivate/import-url/import/platform 状态；不在本机执行 JS。
- **Rationale**: 规格 US12；实测 7 个脚本，含平台级健康与失败原因。
- **Alternatives considered**: 本地执行脚本（安全与兼容风险高，且服务端已执行）。
- **约束**: 启停/导入需二次确认（影响全局播放）；导入内容限制大小。

### R16. 标签编辑

- **Decision**: `TagService` 提供 read/match/match-apply/write；标签页只对服务器本地文件开放；写入前展示"将修改服务器文件"并二次确认；在线条目只读。
- **Rationale**: 规格 US13/FR-094–098；实测 read 可用。
- **Alternatives considered**: 自动批量写入（风险过高）；不做（用户要求全量）。
- **约束**: 写入请求体只包含用户确认的字段；失败不得重试写入，避免重复修改。

### R17. 移除演示数据

- **Decision**: 删除 `DemoCatalogMedia/DemoCatalogPodcast/SeedService/DownloadSimulator` 与 `rawfile/music/*.wav`；`LibraryStore/SettingsStore/DiscoverStore/PodcastStore/DownloadStore` 去除所有 Demo 引用；首次启动不再播种；旧 `library.json/player.json/downloads.json/podcasts.json` 做一次迁移清理（去除 demo 来源条目）。
- **Rationale**: 规格 FR-040；用户明确要求删除演示数据。
- **Alternatives considered**: 保留但隐藏（仍有代码与包体负担，且可能误显示）。
- **约束**: 迁移需幂等；不得删除用户本地导入曲目与设置。

### R18. 导航与页面状态

- **Decision**: 新增路由 `DiscoverCollection`（榜单/新碟/推荐歌单）、`SourceManage`、`TagEditor`；播客搜索改为添加 RSS 弹窗（删除独立搜索页）；`Index` 启动时先初始化设置/会话，再决定显示主界面或空态。
- **Rationale**: 复用现有 Navigation + 路由表；避免多套入口。
- **Alternatives considered**: 全部用叠层（返回栈复杂）；新增多个 @Entry（违反单入口）。
- **约束**: 路由参数必须经 Raw 模型校验；返回后列表状态保持。

### R19. 状态管理

- **Decision**: 继续 V2；服务端 Store 均用 `@ObservedV2 + @Trace`；异步请求结果写回 Store 前做"服务器/请求序号"校验，防止切换服务器后旧响应覆盖新状态。
- **Rationale**: 既有工程已全面 V2；避免响应竞态。
- **Alternatives considered**: 引入第三方状态库（无必要）。
- **约束**: 不在 `build()` 中发起请求；使用 `aboutToAppear`/初始化入口。

### R20. 性能与包体

- **Decision**: 列表使用稳定 key + `cachedCount`；JSON 解析在异步任务中完成；快照写入使用临时文件+重命名；封面并发 4；移除 3.2MB 演示音频。
- **Rationale**: 689 条歌单与 200 条分页 JSON 可能造成主线程卡顿。
- **Alternatives considered**: 全量一次性解析（内存峰值高）。
- **约束**: 单次响应 >2MB 时提示并可重试；避免在 UI 线程做 Base64/大字符串操作。

### R21. 错误分类与提示

- **Decision**: 统一错误码：`OFFLINE`、`TIMEOUT`、`UNAUTHORIZED`、`FORBIDDEN`、`NOT_FOUND`、`SERVER_ERROR`、`BAD_RESPONSE`（HTML/非 JSON）、`UNSUPPORTED`（404 接口）。每类提供中文可操作提示与重试入口。
- **Rationale**: 规格 SC-011/SC-022；避免"未知错误"。
- **Alternatives considered**: 直接展示 HTTP 码（用户不可理解）。
- **约束**: 401 只触发一次重登；`BAD_RESPONSE` 不得当作登录成功。

### R22. 验证策略

- **Decision**: Phase 5 采用 build-only + 真实接口 smoke：构建、安装、启动；通过 PowerShell 对 `nas.sixfun.xyz:7983` 逐接口验证（health/login/tracks/play/cover/lyric/discover/search/download/podcast/source/tag-read），不执行写操作（收藏/歌单/标签写入仅在用户手动确认时验证）。
- **Rationale**: 构建阶段可自动验证读链路；写链路破坏性，交给用户或受控测试。
- **Alternatives considered**: 自动写测试（可能污染用户数据）。
- **约束**: 不在仓库/文档中保存凭据；验证输出需脱敏。

### R23. 首页模式架构

- **Decision**: `HomeView` 作为 Tabs 首屏容器，顶部使用 `HomeHeader`（标题+搜索+音源下拉+模式下拉，模式最右）切换 `LOCAL | SERVER`；本地模式渲染 `LocalHomeView`，服务器模式渲染 `DiscoverView` 内容区。模式存 preferences（`lm_home_mode`）：无服务器强制 LOCAL；有服务器且无历史默认 SERVER；否则读取上次值。音源仅服务器模式显示，存 `discoverStore.source`。
- **Rationale**: 复用现有发现页实现，避免搬迁榜单逻辑；模式状态集中，切页不重建播放器。
- **Alternatives considered**: 两个独立页签（违反"发现改为首页"）；把本地曲库并入资料库（首页失去本地入口）。
- **约束**: 服务器未登录时服务器模式展示"去登录"，不阻塞本地模式。

### R24. 本地文件夹授权与扫描

- **Decision**: `LocalScanService.pickFolder()` 用 `picker.DocumentViewPicker`（`DocumentSelectMode.FOLDER`）选择目录，立即 `fileShare.persistPermission([{uri, READ_MODE}])`；启动时对已保存目录调用 `activatePermission`。扫描使用 `fs.listFile` 递归（URI 优先，失败回退目录路径），并发受限，支持取消。
- **Rationale**: 官方推荐的持久访问方式；无需受限媒体库权限，避免上架风险。
- **Alternatives considered**: 系统媒体库 `READ_MEDIA`（受限，普通应用难申请）；每次选择文件（无法"扫描"）；复制全部音频到沙箱（占用双倍空间）。
- **约束**: 权限失效/目录不存在时标记失效并提示重新授权；声明 `ohos.permission.FILE_ACCESS_PERSIST`。

### R25. 音频标签与封面提取

- **Decision**: `MediaTagService` 用 `media.createAVMetadataExtractor()` + `fdSrc`（`fs.openSync(uri, READ_ONLY)`）读取 `fetchMetadata()` 与 `fetchAlbumCover()`；标签缺失回退文件名解析（`歌手 - 标题`），封面缺失回退程序化封面；封面写入 `cacheDir/local_covers/`。
- **Rationale**: 系统原生能力，支持 MP3/FLAC/M4A 等；避免自带解析器。
- **Alternatives considered**: 自行解析 ID3/FLAC（工作量大、易错）；只显示文件名（体验差）。
- **约束**: 提取失败不得中断扫描；每个文件的 extractor 用完 `release()`；封面解码限制尺寸（≤512px）避免内存峰值。

### R26. 增量扫描与去重

- **Decision**: 以 `uri + size + mtime` 为稳定键；扫描开始时加载旧索引，结束时做三向 diff：新增、更新（元数据/mtime 变化）、删除（索引有但磁盘无）。扫描结果先在内存构建，完成后一次性原子写入索引。
- **Rationale**: 满足 FR-109；避免扫描中途崩溃留下半份索引。
- **Alternatives considered**: 每次全量替换（丢失最近播放/收藏关联）；逐文件写盘（IO 放大）。
- **约束**: 同一文件被多个文件夹包含时按 URI 去重；扫描进度回调限频 200ms。

### R27. 本地索引持久化

- **Decision**: `LocalIndexStore` 读写 `filesDir/data/local_index.json`：folders[]（uri/name/addedAt/lastScanAt/fileCount/invalid）、tracks[]（id/uri/title/artist/album/durationMs/format/sizeBytes/mtime/sampleRate/bitDepth/coverCacheKey/folderUri）、lastScanAt。与服务器快照、播放队列分离。
- **Rationale**: 本地与服务器数据独立迁移；冷启动可立即展示上次结果。
- **Alternatives considered**: 复用服务器快照（切换服务器会污染）；关系型数据库（样板多）。
- **约束**: schemaVersion + 原子写；损坏回退为空并提示重新扫描。

### R28. 华为风底部 Dock

- **Decision**: 保留 `Tabs` + `barFloatingStyle`（官方沉浸材质）用于页签栏（64 高）；`BottomDock` 仅渲染 4 个页签格（高光/选中放大/标签渐现/进度线）。迷你播放器为独立模糊玻璃胶囊，详见 R36；上滑折叠详见 R37。移除品牌红染色，仅封面主色 4%–6%。
- **Rationale**: 复用官方材质通道（自定义容器设置 `systemMaterial` 不生效）；同时满足华为/QQ 的视觉特征。
- **Alternatives considered**: 完全自定义 Dock（失去沉浸材质）；仅调色（达不到"重设计"要求）。
- **约束**: 材质开启时不再设置 `barBackgroundColor`/`barBackgroundBlurStyle`；染色层放在 tabBar 内容内部且不遮挡文字。

### R29. 封面主色提取

- **Decision**: `ColorService` 用 `image.createImageSource(coverPath).createPixelMap()` 解码 64×64 缩略图，`effectKit.createColorPicker(pixelMap).getMainColorSync()` 取主色；结果按封面键缓存；亮度不足时提升明度用于浅色主题，过亮时压暗用于深色主题；取色失败回退品牌红。
- **Rationale**: effectKit 为系统推荐取色方案；小图解码成本低。
- **Alternatives considered**: 手工计算平均色（不准、需遍历像素）；K-means（过重）。
- **约束**: 取色异步进行，失败不阻塞 Dock 渲染；每条曲目只取一次并缓存。

### R30. 布局与安全区

- **Decision**: `DockMetrics`：`TAB_BAR_HEIGHT=64`、`PLAYER_HEIGHT=60`、`GAP=8`、`BOTTOM_MARGIN=8`、`COLLAPSED_HEIGHT=56`。内容底部 padding：默认态 = 64+8+60+8（有播放）或 64+8（无播放）；折叠态 = 56+8+安全区。播放器/搜索/播客叠层打开时隐藏底栏与留白。
- **Rationale**: 满足 FR-147/150/159，双层悬浮与折叠态各自独立计算。
- **Alternatives considered**: 合并 124 Dock（与参考图不符）；固定留白（折叠后空洞）。
- **约束**: 状态切换用 `animateTo` ≤250ms；横屏/平板同一公式；折叠屏重新计算。

### R36. 双层悬浮底栏（默认态）

- **Decision**: `BottomDock` 仅渲染 4 个页签格，继续使用 Tabs `barFloatingStyle` 的系统材质（64 高、8 边距）。`MiniPlayer` 恢复为独立胶囊，悬浮在页签栏上方 8vp，使用 `backgroundBlurStyle(Thick)` + 半透明主题底色 + 1px 高光 + 5% 封面主色；提供封面/标题/歌手/播放/下一首/队列。无播放时仅隐藏 MiniPlayer，页签栏保持。
- **Rationale**: 系统材质仅能作用于 Tabs 背板，独立播放器用模糊玻璃达到参考图的通透感；符合图 1 的双层结构。
- **Alternatives considered**: 合并成一块 Dock（已否决）；给 MiniPlayer 设 `systemMaterial`（无效）。
- **约束**: MiniPlayer 不设置大面积品牌红；内容底部留白按 R30 公式；点击非按钮区域打开全屏播放器。

### R37. 上滑折叠态与紧凑胶囊

- **Decision**: 新增 `ScrollChromeStore`（`collapsed`、`searchCollapsed`、`lastOffset`、`direction`、`activeTab`）。滚动阈值 120vp 折叠、回退 40vp 或回顶展开（迟滞防抖）。折叠时 `Tabs.barHeight=0` 隐藏页签栏与 MiniPlayer，根级渲染 `CollapsedBar`：首页圆钮 + 封面 + 标题/歌手 + 播放/暂停 + 下一首 + 队列。首页圆钮 → tab 0 + 回顶 + 展开；胶囊其余区域 → 打开播放器。
- **Rationale**: 满足 FR-153–156；参考图 2 的紧凑形态。
- **Alternatives considered**: 仅隐藏页签栏（仍占空间）；悬浮球（不符合参考）。
- **约束**: 切换主页面重置展开；折叠态不显示空播放器；手势区留 8vp。

### R38. 顶部搜索收起

- **Decision**: `HomeHeader` 展开态：第一行标题+两个下拉，第二行整宽搜索框；折叠态：隐藏搜索框，第一行右侧（标题后）显示圆形搜索图标。`searchCollapsed` 与 `collapsed` 同步。
- **Rationale**: 满足 FR-157；参考图 2 的搜索图标形态。
- **Alternatives considered**: 搜索框常驻（占高度）；仅收起底栏（与参考不符）。
- **约束**: 图标点击打开搜索叠层；动画 ≤250ms；小屏不挤压下拉。

### R39. 滚动事件接入

- **Decision**: 各主页面（Home 的 Discover/Local、Library、Download、Settings）的 `Scroll`/`List` 增加 `onScroll`（或 `onDidScroll`）回调，将 `yOffset` 与方向上报 `ScrollChromeStore.report(offset, delta)`；`Index` 根据 `collapsed` 切换 `barHeight` 与浮层。页面切 tab 时 `reset()`。
- **Rationale**: 统一阈值与迟滞，避免每个页面各写一套。
- **Alternatives considered**: 每个页面自管折叠（不一致）；监听全局手势（与列表冲突）。
- **约束**: 上报节流 ≥50ms；嵌套滚动只取主列表；回顶时强制展开。

### R40. 完全通透玻璃（去遮罩）

- **Decision**: 删除 `BottomDock`、`MiniPlayer`、`CollapsedBar` 中所有不透明/半透明底色层与封面主色遮罩；迷你播放器与折叠胶囊仅使用 `backgroundBlurStyle(BlurStyle.Thin)` + 1px 高光描边 + 文字阴影保证可读；页签栏继续使用 Tabs `barFloatingStyle` 系统材质，单元格不再绘制底色。无播放/无封面时同样无底色。
- **Rationale**: 满足 FR-125/148 与用户"更通透"的要求；系统材质本身已提供玻璃层，叠加底色是遮罩来源。
- **Alternatives considered**: 保留 5% 专辑色（仍有遮罩感）；保留深色底（不通透）。
- **约束**: 浅色/深色文字对比度通过文字色与轻阴影保证；不改变材质透明度；不动 Tabs 的 `barBackgroundColor/BlurStyle`。

### R41. 播放器收缩/展开过渡

- **Decision**: 新增 `PlayerTransitionStore`（`progress 0..1`、`targetRect`、`sourceRect`、`animating`、`collapsedAtOpen`）。`Index` 计算目标矩形：默认态 mini player（width=dockBarWidth, height=60, bottom=miniPlayerBottomOffset）；折叠态 collapsed bar（height=56, bottom=old）。打开：先渲染 `FullscreenPlayer(progress=0)`，`animateTo(300ms)` 到 1；关闭：animate 到 0 后隐藏，再显示 mini/collapsed。`FullscreenPlayer` 接收 `progress`，用 lerp 驱动 `scale`、`translateY`、`cornerRadius`、`opacity`；内容随容器缩放。动画期间 `OverlayStore.transitioning=true` 阻断底层点击；浮层先关闭。
- **Rationale**: 满足 FR-161–172；单一 progress 保证打开/关闭互逆、可中断。
- **Alternatives considered**: geometryTransition（跨 if 分支行为不稳定）；两套播放器淡入淡出（重复/闪白）。
- **约束**: 目标矩形在旋转/分屏后重算；无当前曲目直接切换；低算力/减少动效降级 150ms 淡入淡出；关闭动画结束前不显示 mini player。

### R31. AVSession 系统实况窗

- **Decision**: 新增 `AvSessionService`：首次播放时 `createAVSession(context,'lm_player','audio')`；设置 `AVMetadata`（assetId/title/artist/album/duration/mediaImage/lyric/singleLyricText）与 `AVPlaybackState`（state/position/speed/loopMode/isFavorite/activeItemId）；注册 play/pause/stop/playNext/playPrevious/seek/fastForward/rewind/toggleFavorite/setLoopMode；最后 `activate()`。切歌/状态/进度/歌词/封面变化时增量更新，节流 1s。
- **Rationale**: 音乐类实况窗由 AVSession 自动接入系统播控中心/状态栏/锁屏；`lyric` 字段可直接展示 LRC。
- **Alternatives considered**: Live View Kit 自定义模板（音乐不在开放场景）；应用内胶囊（非系统实况窗，用户已否决）。
- **约束**: mediaImage 用 PixelMap（≤512）或本地路径；lyric ≤40960 字节；AVSession 对象全局单例，后台期间不释放；失败仅降级。

### R32. 后台播放长时任务

- **Decision**: 新增 `BackgroundPlaybackService`：首次播放 `backgroundTaskManager.startBackgroundRunning(context, ['audioPlayback'], wantAgent)`；队列空/停止/退出时 `stopBackgroundRunning`。`module.json5` 增加 `ohos.permission.KEEP_BACKGROUND_RUNNING` 与 `abilities[0].backgroundModes: ["audioPlayback"]`，权限带 reason/usedScene。
- **Rationale**: 官方后台播放要求；与 AVSession 生命周期一致。
- **Alternatives considered**: 仅 AVSession 不申请长时任务（切后台会被挂起）；常驻后台任务（耗电且不合规）。
- **约束**: 启动/停止需幂等；失败不阻塞播放；与 AVSession 同步启停。

### R33. ~~合并播放行与页签行的 Dock~~（已被 R36 取代）

- **Decision**: 原方案将播放行与页签合并为一块 124 高 Dock；按最新参考图改为**双层悬浮**，详见 R36。`BottomDock` 仅保留页签行，`MiniPlayer` 恢复为独立胶囊。
- **Rationale**: 参考图 1/图 2 明确为「独立播放器 + 独立页签栏」；合并态不再采用。
- **约束**: 删除 Index 中的 124 合并高度逻辑与 DockPlayerRow 合并布局。

### R34. 去红与主色轻染

- **Decision**: 删除 Dock 的品牌红染色层；底色使用应用主题深/浅玻璃（`#8C101014` / `#B3FFFFFF`），封面主色仅以 0.04–0.06 alpha 叠一层；无封面时不叠色。进度线仍用品牌红渐变。
- **Rationale**: 满足 FR-125；解决用户反馈的"红色遮罩"。
- **Alternatives considered**: 保留 10% 品牌红（仍显遮罩）；完全无色（缺少专辑氛围）。
- **约束**: 染色层必须在文字下方；不改变材质透明度；浅色主题需校验对比度。

### R35. 首页顶部双下拉

- **Decision**: 新增 `HomeHeader`：左侧标题「首页」+ 搜索按钮；右侧 `AppSelect`（音源）与 `AppSelect`（模式），模式在最右。音源仅服务器模式显示；模式项在无服务器时禁用服务器项并给出"去设置"。`HomeView` 使用 HomeHeader，`DiscoverView` 删除自身标题/音源 Chip 行，仅保留内容区。
- **Rationale**: 满足 FR-141–146；两个高频切换项集中到第一行，节省垂直空间。
- **Alternatives considered**: 保留分段控件 + Chip（占两行、重复）；把模式放左侧（用户指定最右）。
- **约束**: 小屏下下拉宽度自适应（min 88vp/max 140vp），标题可省略副标题；下拉使用沉浸光感；不换行。

### Setup & Validation Guidelines

1. 先改 `module.json5` 增加 INTERNET、FILE_ACCESS_PERSIST、KEEP_BACKGROUND_RUNNING 与 `backgroundModes:["audioPlayback"]`，确认 `devecocli build` 通过。
2. 按 `common → model → data → service → viewmodel → components → views/pages` 顺序实现，每层构建一次。
3. 网络层先用真实服务器 smoke 验证 `health/login/tracks`，再接 UI。
4. 本地扫描先用 1 个含 3 首音频的文件夹验证「选择 → 持久授权 → 扫描 → 元数据/封面 → 重启读取」，再接首页。
5. 底栏先验证「独立播放器胶囊 + 页签栏」双层布局与完全去底色，再验证上滑折叠/下滑恢复与搜索收起。
6. 播放器过渡先验证默认态/mini 矩形落点，再验证折叠态胶囊落点与中断。
6. AVSession 先验证 `createAVSession → setAVMetadata → setAVPlaybackState → activate`，再验证系统播控命令回传与后台 30 秒播放。
7. 首页下拉先验证服务器模式两个下拉、再验证本地模式隐藏音源。
8. 播放链路先用 1 首服务器 FLAC、1 首在线 `wy` 曲目、1 首本地 FLAC 验证，再接列表。
5. 删除演示数据后必须全量构建，确认无残留引用（`rg DemoCatalog|SeedService|rawfile:music` 为空）。
6. UI 验收顺序：登录 → 同步 → 资料库 → 播放 → 发现 → 搜索 → 下载 → 播客 → 音源 → 标签。
7. 破坏性写操作（收藏/歌单/标签）只在用户确认后执行，验证前先备份服务器数据。

### Risks & Mitigations

| 风险 | 影响 | 缓解 |
|---|---|---|
| 模拟器无法访问 `nas.sixfun.xyz:7983` | 无法联调 | 先用 hdc/浏览器确认网络；必要时用局域网 IP；保留演示以外的空态验证 |
| 689 条歌单 JSON 过大导致卡顿 | 首屏卡顿/OOM | 分页解析、异步、限制快照大小、Lazy 列表 |
| 401 重登风暴 | 被服务端限流 | 单次重试 + 串行 + 退避 |
| 签名地址过期 | 播放中断 | TTL 缓存 + 播放前校验 + 失败重解析 |
| 封面缓存无上限 | 占用存储 | LRU 200MB/500 张 |
| 写回覆盖用户数据 | 数据丢失 | 读失败中止 + 串行锁 + 二次确认 |
| 标签写入破坏文件 | 数据损坏 | 仅手动确认 + 不自动重试 + 在线曲目禁写 |
| 服务端音源降级（tx/mg/qs） | 部分功能不可用 | 平台健康展示 + 单区块失败隔离 |
| 旧演示数据残留 | 误导 | 迁移清理 + 构建期 grep 校验 |
| HTTP 明文被系统限制 | 无法连接 | 官方支持明文；如失败改用 HTTPS 7983 |
| 文件夹 URI 无法直接 `listFile` | 本地扫描失败 | 优先 URI；失败回退 `fileUri` 解析路径；再失败改为多选文件导入并提示 |
| `FILE_ACCESS_PERSIST` 权限不可用/被拒 | 冷启动无法读取 | `canIUse` 校验；失败标记目录 invalid 并引导重新选择；不影响服务器功能 |
| 大曲库扫描耗时/内存峰值 | 卡顿/OOM | 分批并发（≤3）、逐文件释放 extractor、索引最后一次写入、进度限频 |
| 元数据提取失败率高 | 曲目信息缺失 | 回退文件名解析 + 程序化封面；不中断扫描 |
| Dock 材质与主色染色冲突 | 材质被遮挡/发灰 | 染色层低不透明度（8%–12%）置于材质之上；不设置 barBackgroundColor |
| 取色开销/颜色不可读 | 底栏文字对比度差 | 小图解码 + 结果缓存 + 明度校正；失败回退品牌红 |
| Dock 高度变化导致内容遮挡 | 最后一项不可见 | `DockMetrics` 动态高度 + 全页面底部 padding 公式 + animateTo |
| AVSession 创建失败/设备不支持 | 无系统实况窗 | 降级为应用内播放，记录日志，不阻塞 |
| 后台长时任务权限被拒 | 切后台暂停 | 声明权限 + backgroundModes；失败提示并保持前台播放 |
| 系统播控歌词超限/格式错 | 歌词不显示 | 截断 40KB + 仅传 LRC + 失败不设置 |
| 封面解码 PixelMap 失败 | 播控无封面 | 省略 mediaImage 或使用占位，不影响元数据 |
| barHeight 动态切换抖动 | 底栏跳动 | 单一状态源 + 200ms 动画 + 内部百分比布局 |
| 首页下拉在小屏换行/挤压 | 标题被遮挡 | 固定最小/最大宽度 + 标题省略 + 横屏单独阈值 |
| 滚动折叠抖动/频繁切换 | 底栏闪烁 | 120/40 迟滞 + 50ms 节流 + 回顶强制展开 |
| 隐藏页签栏导致内容跳动 | 阅读位置突变 | 动画同步底部留白；折叠胶囊固定高度 |
| 折叠胶囊与系统手势冲突 | 无法返回桌面 | 底部留 8vp + 胶囊不覆盖手势区 |
| 搜索框收起挤压下拉 | 标题错位 | 折叠态用图标替换整行；下拉宽度不变 |
| 完全去底色导致文字不可读 | 底栏文字看不清 | 文字色跟随主题 + 轻阴影 + 高光描边；浅色主题单独校验 |
| 播放器缩放导致内容变形/模糊 | 过渡观感差 | 以容器 scale+translate 为主，内容随缩放；封面单独保持比例；300ms 内完成 |
| 目标矩形在旋转后失效 | 落点偏移 | 每次打开/关闭实时计算；监听 display 变化 |
| 过渡中重复播放器/闪烁 | 白屏或双影 | mini/collapsed 在关闭结束才显示；单一 progress 驱动 |
| 过渡中可点击底层 | 误触 | `transitioning` 阻断列表/底栏点击，结束恢复 |

## Data Model

### 服务端核心模型（`model/ServerModels.ets`）

| 模型 | 关键字段 |
|---|---|
| ServerSession | token、expiresAt、userId、username、displayName、role、lastVerifiedAt |
| ConnectionStatus | state（idle/connecting/online/offline/authExpired/error）、latencyMs、errorCode、errorMessage、lastConnectedAt |
| ServerTrack | id、filePath、trackId、title、artist、album、albumArtist、durationMs、format、bitRate、sizeBytes、sampleRate、bitDepth、mtime、hasPicture、hasLyrics、qualitys、coverUrl、onlineRef? |
| OnlineRef | platform、songId、songmid、hash、copyrightId、musicId、rid、picUrl、lyric、qualitys |
| ServerAlbum | id、name、artist、year、count、coverPath、coverUrl、source |
| ServerArtist | id、name、count、coverPath、coverUrl |
| ServerPlaylist | id、name、coverUrl、coverMode、playlistType、trackKeys[]、trackSnapshots、updatedAt、isFavorites |
| PlaylistEntry | key、songId、platform、name、singer、album、localPath、picUrl、lyric、durationMs、qualitys |
| ServerUserData | favorites[]、playlists[]、favoriteAlbums[]、favoriteArtists[]、recentPlays[]、playStats、revision |
| SyncState | phase（idle/connecting/tracks/albums/artists/playlists/userdata/writing/done/error）、fetched、total、error、lastSuccessAt |
| ServerDownloadTask | id、name、singer、album、source、platform、songId、quality、status、progress、filePath、error、createdAt、updatedAt |
| PodcastFeed | id、title、author、coverUrl、description、episodeCount、subscribedAt |
| PodcastEpisode | id、feedId、title、audioUrl、durationMs、publishedAt、description |
| SourceScript | id、name、author、version、homepage、active、platforms[]、health、probe |
| SourcePlatform | id、label、qualitys[]、actions[]、enabled、level、okRatio、avgMs、lastError |
| TagInfo | filePath、title、artist、album、year、track、genre、hasPicture、hasLyric、lyric |
| TagCandidate | source、title、artist、album、coverUrl、matchScore |
| CoverRef | key（路径或外链）、cachePath、mtime、updatedAt |

### 本地扫描模型（`model/LocalScanModels.ets`）

| 模型 | 关键字段 |
|---|---|
| HomeMode | `local` / `server` |
| LocalFolder | uri、displayName、addedAt、lastScanAt、fileCount、invalid、error |
| LocalTrack | id（uri 哈希）、uri、folderUri、title、artist、album、durationMs、format、sizeBytes、mtime、sampleRate、bitDepth、coverCacheKey、hasCover |
| LocalScanState | phase（idle/scanning/diffing/done/cancelled/error）、currentFile、scanned、discovered、added、updated、removed、errors[]、startedAt、finishedAt |
| LocalIndexDoc | schemaVersion、folders[]、tracks[]、lastScanAt |
| AvSessionState | sessionId、active、assetId、playbackState、position、loopMode、isFavorite、backgroundTaskId、lastSyncAt |
| HomeHeaderState | mode（local/server）、source（kw/wy/tx/kg/mg）、dropdownOpen、searchCollapsed |
| ScrollChromeState | collapsed、lastOffset、direction、activeTab、threshold、searchCollapsed |

### 既有模型扩展（`model/MediaModels.ets`）

- `MediaSource`: `LOCAL | SERVER_FILE | ONLINE | PODCAST`（移除 `DEMO`）。
- `Song` 新增：`filePath`、`trackId`、`platform`、`platformSongId`、`coverUrl`、`onlineIdsJson`、`qualitys`、`mtime`、`hasPicture`、`hasLyric`、`isOnline`、`trackKey`。
- `PlayableItem` 新增：`mediaSource`、`filePath`、`trackId`、`platform`、`platformSongId`、`coverUrl`、`playbackUrl`（解析后）、`lyricText`、`serverId`。
- `Playlist` 新增：`serverId`、`remoteSnapshotJson`、`isFavorites`、`readOnly`。

### 持久化布局

| 位置 | 内容 | 说明 |
|---|---|---|
| preferences `lm_servers` | ServerConfig[]（含 token/expiresAt/lastSyncAt） | 不存密码 |
| preferences `lm_settings` | Preferences | 增加 `onlineSource` 默认 kw；移除演示相关 |
| preferences `lm_search_history` | string[] ≤10 | 搜索历史 |
| preferences `lm_home_mode` | `local` / `server` | 首页模式记忆 |
| `filesDir/data/local_index.json` | schemaVersion、folders[]、tracks[]、lastScanAt | 本地扫描索引 |
| `cacheDir/local_covers/` | 本地内嵌封面缩略图 | 按文件键缓存 |
| `filesDir/data/server_<id>.json` | schemaVersion、serverId、tracks[]、albums[]、artists[]、playlists[]、userData、syncedAt、revision | 原子写；切换服务器按 id 读取 |
| `filesDir/data/local_library.json` | 本地导入曲目、本地歌单 | 与服务器快照分离 |
| `filesDir/data/player.json` | 队列（含播放来源/解析地址）、模式、进度 | 队列持久化 |
| `filesDir/data/downloads_cache.json` | 服务端任务最后快照 | 离线展示 |
| `filesDir/data/podcasts_progress.json` | 单集进度、订阅缓存 | 离线展示 |
| `cacheDir/covers/` | 封面缓存文件 | LRU 上限 |
| `filesDir/imported/` | 本地音频 | 保留 |

### 状态迁移

- 连接：`idle → connecting → online | offline | authExpired`；`authExpired → connecting`（重新登录）。
- 同步：`idle → tracks → albums → artists → playlists → userdata → writing → done | error`；`error` 保留旧快照。
- 播放：`idle → resolving → loading → playing ↔ paused → completed`；`resolving` 失败 → `error`（可重试）。
- 下载：`waiting → downloading → completed | failed`；`downloading ↔ paused`；`failed → waiting`（重试）；`dismiss` 移除。
- 写回：`reading → applying → writing → done | aborted`；`reading` 失败直接 `aborted`（0 写入）。
- 本地扫描：`idle → scanning → diffing → done | cancelled | error`；`error` 保留旧索引。
- 首页模式：`local ↔ server`；无服务器时 `server → local` 强制回退。
- 底栏：`idle ↔ playing ↔ paused`（进度线亮度随状态变化）。

## Contracts & Interfaces

### 配置契约

- `module.json5`：`requestPermissions: [{ name: "ohos.permission.INTERNET" }, { name: "ohos.permission.FILE_ACCESS_PERSIST" }]`；保留 `ohos.arkui.UIMaterial.state=enable`。
- 基础地址：允许 `http://` / `https://`，自动去除尾部 `/`；拒绝空、无协议、含空格；拼接规则 `base + path`（path 以 `/api/` 开头）。
- 超时：普通 15s 连接 / 30s 读；登录 20s；RSS 60s；封面 30s。

### HTTP 契约（`service/HttpClient.ets`）

- `requestText(method, url, headers, body?, timeoutMs?) → HttpResponse { status, text }`
- `requestBytes(getUrl, headers, timeoutMs?) → HttpResponseBytes { status, bytes }`
- `getJson<T>`（由调用方传入 Raw 解析函数）：要求 `Content-Type` 含 `json` 或 body 以 `{`/`[` 开头，否则 `BAD_RESPONSE`
- 错误映射：网络失败→`OFFLINE`，超时→`TIMEOUT`，401→`UNAUTHORIZED`，403→`FORBIDDEN`，404→`NOT_FOUND`，5xx→`SERVER_ERROR`，HTML→`BAD_RESPONSE`
- 禁止记录 URL 中的 `ticket` 与 Authorization

### 服务端接口契约（`service/ServerApi.ets`）

| 方法 | 请求 | 返回 |
|---|---|---|
| `health()` | GET `/api/health` | `{ ok, uptime, ... }` |
| `login(username,password,remember)` | POST `/api/auth/login` | `{ ok, token, expiresAt, user }` |
| `me()` | GET `/api/auth/me` | `{ user, token }` |
| `tracks(page,limit)` | GET `/api/library/tracks?page&limit` | `{ data[], total, page, limit }` |
| `albums(page,limit)` | GET `/api/library/albums` | `{ data[], total }` |
| `artists(page,limit)` | GET `/api/library/artists` | `{ data[], total }` |
| `userData()` | GET `/api/library/user-data` | `{ ok, data, unchanged, revision }` |
| `playlists()` | GET `/api/library/playlists` | `{ ok, data[] }` |
| `saveUserData(favorites)` | PUT `/api/library/user-data` | `{ ok }` |
| `savePlaylists(playlists)` | PUT `/api/library/playlists` | `{ ok }` |
| `playUrl(payload)` | POST `/api/play/url` | `{ ok, url, local, smooth, format }` |
| `tagRead(filePath)` | POST `/api/tag/read` | `{ data: { lyric, ... } }` |
| `tagMatch(...)` | POST `/api/tag/match` | `{ data[] }` |
| `tagMatchApply(match,source)` | POST `/api/tag/match-apply` | tag object |
| `tagWrite(filePath,meta)` | POST `/api/tag/write` | `{ ok }` |
| `lyric(payload)` | POST `/api/play/lyric` | `{ lyric, lxlyric, ylyric, tlyric, rlyric }` |
| `discoverToplists(source)` | GET `/api/discover/toplists?source` | `{ data: { list[] } }` |
| `discoverToplist(source,id,limit)` | GET `/api/discover/toplist` | `{ data: { list[] } }` |
| `newSongs(source,limit)` | GET `/api/discover/new-songs` | `{ data[] }` |
| `newAlbums(source,limit)` | GET `/api/discover/new-albums` | `{ data[] }` |
| `recommendPlaylists(source,page,limit)` | GET `/api/playlist/recommend` | `{ data[] }` |
| `playlistDetail(source,id)` | GET `/api/playlist?source&url` | `{ data: { list[] } }` |
| `albumDetail(source,id)` | GET `/api/album?source&id` | `{ data: { list[] } }` |
| `searchSongs(keyword,source,page,limit)` | GET `/api/search` | `{ data: { list[], total } }` |
| `searchAlbums(keyword,source,page,limit)` | GET `/api/search/album` | `{ data[] }` |
| `searchPlaylists(keyword,source,page,limit)` | GET `/api/search/playlist` | `{ data[] }` |
| `downloadList()` | GET `/api/download/list` | task[] |
| `downloadAdd(task)` | POST `/api/download/add` | `{ ok }` |
| `downloadAction(id,action)` | POST `/api/download/{id}/{pause|resume|retry}` | `{ ok }` |
| `downloadDismiss(id)` | POST/DELETE `/api/download/{id}/dismiss` | `{ ok }` |
| `downloadClearCompleted()` | POST `/api/download/clear-completed` | `{ ok }` |
| `podcasts()` | GET `/api/podcasts` | `{ data: feed[] }` |
| `podcastEpisodes(id,page,limit)` | GET `/api/podcasts/{id}/episodes` | `{ data: episode[] }` |
| `subscribePodcast(url)` | POST `/api/podcasts` | `{ data: feed }` |
| `refreshPodcast(id)` | POST `/api/podcasts/{id}/refresh` | `{ ok }` |
| `unsubscribePodcast(id)` | DELETE `/api/podcasts/{id}` | `{ ok }` |
| `sources()` | GET `/api/source/list` | script[] |
| `activateSource(id)` / `deactivateSource(id)` | POST `/api/source/activate|deactivate` | `{ ok }` |
| `importSourceUrl(url)` | POST `/api/source/import-url` | `{ ok }` |
| `importSource(content)` | POST `/api/source/import` | `{ ok }` |
| `sourcePlatformStatus(id,platform,enabled)` | POST `/api/source/{id}/platform` | `{ ok }` |

> 未在实测中确认的写接口（download action、source platform、tag match/write）按 Android 端既有调用方式实现，并在实现时做 404/405 兼容提示；不得因写接口失败影响读链路。

### AVSession / 后台播放契约

- **AvSessionService**：`ensureSession()`、`activate()`、`updateMetadata(item, coverPath, lyric)`、`updatePlayback(state, position, loopMode, favorite)`、`updateQueue(items, index)`、`destroy()`；事件回调注入：`onPlay/onPause/onStop/onNext/onPrev/onSeek/onFavorite/onLoopMode`。
- **BackgroundPlaybackService**：`start()`（audioPlayback + WantAgent，幂等）、`stop()`（幂等）；与 AVSession 同生命周期启停。
- **module.json5**：`ohos.permission.KEEP_BACKGROUND_RUNNING`（reason/usedScene）、`abilities[0].backgroundModes: ["audioPlayback"]`。
- **HomeHeader**：`@Param mode`、`@Param source`、`@Param serverAvailable`、`@Event onModeChange`、`@Event onSourceChange`、`@Event onSearch`；音源下拉仅服务器模式渲染；模式下拉在最右。

### 本地扫描契约（`service/LocalScanService.ets`）

- `pickFolder() → Promise<LocalFolder | null>`：拉起文件夹选择器 → `persistPermission` → 保存授权。
- `activateSavedFolders() → Promise<void>`：启动时对已保存 URI 调用 `activatePermission`，失败标记 invalid。
- `scanAll(onProgress) → Promise<ScanResult>`：遍历所有有效文件夹，递归收集音频，读取标签/封面，构建索引，执行 diff。
- `rescanFolder(folderUri, onProgress) → Promise<ScanResult>`：单目录增量扫描。
- `cancel() → void`：设置取消标记，扫描循环在安全点退出并保留上次索引。
- `removeFolder(folderUri) → Promise<void>`：`revokePermission` → 从索引移除曲目。
- `listAudioFiles(folderUri) → Promise<string[]>`：`fs.listFile` 递归（URI 优先，失败回退路径），过滤扩展名。
- **MediaTagService**：`readTags(uri) → LocalTrackTags`（title/artist/album/duration/sampleRate/bitDepth）、`extractCover(uri, cacheKey) → string`。
- **ColorService**：`dominantColor(coverUri) → string`（`#RRGGBB`），带内存缓存与主题明度校正。

### Store 契约

| Store | 状态 | 动作 |
|---|---|---|
| ServerStore | status、latency、user、activeServer、passwordInMemory | init、login、logout、testConnection、handleUnauthorized |
| SyncStore | phase、fetched、total、lastSuccessAt、error | syncNow、reset |
| LibraryStore | serverTracks、localTracks、albums、artists、playlists、favorites、recent、syncMeta | loadSnapshot、sync、toggleFavorite、createPlaylist、rename、delete、addTracks、removeTracks、importLocal |
| DiscoverStore | source、toplists、newSongs、newAlbums、recommend、blockStates | load(source)、refresh、loadToplistSongs、loadAlbum、loadPlaylist |
| SearchStore | keyword、scope、results、history、page、loading | search、loadMore、setScope、clearHistory |
| DownloadStore | tasks、polling、selected | refresh、add、pause、resume、retry、dismiss、clearCompleted |
| PodcastStore | feeds、episodes、currentFeed | loadFeeds、loadEpisodes、subscribe、refresh、unsubscribe、saveProgress |
| SourceStore | scripts、selected、health | load、activate、deactivate、importUrl、togglePlatform |
| TagStore | info、candidates、dirty、busy | load(filePath)、match、applyCandidate、write |
| LocalScanStore | folders、tracks、scanState、homeMode、lastScanAt | init、pickFolder、scanAll、rescan、removeFolder、cancel、setMode、visibleTracks、recentTracks |

### 路由契约（`router_map.json`）

| name | 页面 | 参数 |
|---|---|---|
| `LibraryDetail` | `pages/LibraryDetailPage.ets` | `{ kind: 'all'|'favorites'|'recent'|'downloaded'|'album'|'artist'|'playlist'|'local', id?, title }` |
| `DiscoverCollection` | `pages/DiscoverCollectionPage.ets` | `{ kind: 'toplist'|'album'|'playlist', id, source, title }` |
| `PodcastShow` | `pages/PodcastShowPage.ets` | `{ feedId, title }` |
| `PodcastManage` | `pages/PodcastManagePage.ets` | `{}` |
| `SourceManage` | `pages/SourceManagePage.ets` | `{}` |
| `TagEditor` | `pages/TagEditorPage.ets` | `{ songId, filePath }` |

### UI 契约

- **PlayerTransitionStore**：`progress`（0..1）、`visible`、`animating`、`targetRect`、`collapsedAtOpen`；`open(targetRect)`、`close(targetRect)`、`setProgress`；`OverlayStore.transitioning` 阻断底层点击。
- **FullscreenPlayer**：`@Param progress`；lerp 计算 `scale`（目标宽/屏宽、目标高/屏高）、`translateY`（目标底-屏底）、`radius`（28→16）、`opacity`；内容随容器缩放。
- **透明玻璃**：`BottomDock`/`MiniPlayer`/`CollapsedBar` 不绘制底色；仅 `backgroundBlurStyle(BlurStyle.Thin)` + 1px 高光 + 文字阴影；页签栏沿用 Tabs 系统材质。

- **ScrollChromeStore**：`report(offset, delta)`（节流 50ms）、`collapse()`、`expand()`、`reset(tabIndex)`；`collapsed`/`searchCollapsed` 为 `@Trace`；阈值 120/40 迟滞，回顶强制展开。
- **CollapsedBar**：`@Param visible`、`@Param hasPlayer`、`@Event onHome`、`@Event onOpenPlayer`、`@Event onTogglePlay`、`@Event onNext`、`@Event onQueue`；左侧首页圆钮，右侧播放器信息/播控；隐藏时 `translateY` 下移。
- **HomeHeader**：展开态第二行整宽搜索框；`searchCollapsed=true` 时隐藏搜索框并在第一行显示圆形搜索图标。

- 所有空态使用 `EmptyState`，支持 `actionText` 与 `onAction`（去设置/重试/添加订阅）。
- 所有在线列表项显示来源徽章（服务器/在线/本地/播客）与音质徽章。
- 详情页「更多」菜单按来源展示：服务器文件（收藏/加入歌单/下载到服务器/标签编辑）、在线（收藏/加入歌单/下载到服务器）、本地（收藏/加入歌单/删除本地文件）。
- 危险操作统一 `ConfirmDialog`（ULTRA_THICK 沉浸光感）。
- 同步/登录/下载操作期间按钮进入 loading 且防重复点击。
- **HomeView**：`@Param` 无；内部读取 `LocalScanStore.homeMode`；服务器模式渲染 `DiscoverView`（保留其回调），本地模式渲染 `LocalHomeView`；模式切换不重建播放器。
- **HomeModeSwitch**：`@Param mode`、`@Param serverAvailable`、`@Event onChange(mode)`；服务器不可用时禁用服务器段并提示去设置。
- **LocalHomeView**：展示扫描统计、扫描状态、文件夹列表、最近添加、全部本地曲目；动作：添加文件夹、重新扫描、取消、移除。
- **BottomDock**：由 `Tabs.tabBar` 调用；读取 `overlayStore.tabIndex`、`playerStore`（进度/封面主色）、`themeStore`；渲染高光、选中放大、标签渐现、进度线、主色染色；高度与底部边距来自 `DockMetrics`。

### 资源契约

- 新增 SVG：`ic_server.svg`、`ic_cloud_download.svg`、`ic_source.svg`、`ic_tag.svg`、`ic_refresh.svg`、`ic_link.svg`、`ic_warning.svg`。
- 删除 `rawfile/music/demo_*.wav`。
- 文案写入 `string.json`：未连接、离线、重试、登录失败、同步中、无结果、未订阅播客、音源不可用等。
