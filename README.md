<div align="center">

# 🍋 柠檬音乐 · HarmonyOS 版

**LMPlayer for HarmonyOS** —— 面向 HarmonyOS 手机与平板的高保真音乐播放器客户端

<p>
  <img src="https://img.shields.io/badge/Platform-HarmonyOS%20NEXT%20(API%2026)-%2300B4FF?logo=harmonyos" alt="Platform" />
  <img src="https://img.shields.io/badge/Language-ArkTS%20%7C%20ArkUI-purple" alt="Language" />
  <img src="https://img.shields.io/badge/Build-hvigor-brightgreen" alt="hvigor" />
  <img src="https://img.shields.io/badge/Bundle-com.lm.player.harmony-blue" alt="Bundle" />
  <img src="https://img.shields.io/badge/Version-1.0.0-orange" alt="Version" />
  <img src="https://img.shields.io/badge/License-MIT-orange" alt="License" />
</p>

</div>

---

## 📖 项目简介

**柠檬音乐 HarmonyOS 版** 是 [LMPlayer](https://github.com/zyhub/LMplayer) 音乐客户端的 HarmonyOS 原生移植版本，使用 ArkTS + ArkUI 声明式框架从零构建，适配 HarmonyOS NEXT（API 26）手机与平板设备。

本应用是一个**纯客户端**：不内置任何音乐、榜单、歌单或播客内容。所有云端曲库、在线检索、榜单推荐、播客 RSS、封面与歌词，均来自使用者**自建的柠檬音乐服务端**；本地曲库来自使用者自行导入的音频文件。应用只负责播放与展示，并确保你对自己访问的内容拥有合法使用权。

> 🍋 **配套服务端**：[lemon-muisc](https://github.com/jia070310/lemon-muisc) —— 面向飞牛 NAS / Linux 的轻量级音乐后端，提供多用户、私有曲库缓存、在线全网检索与音源集中托管能力。

---

## ✨ 核心特性

### ☁️ 云端曲库与账号
- 连接自建柠檬音乐服务端，支持登录鉴权（Bearer Token）、会话自动续期与过期重登
- 曲库浏览：歌曲 / 专辑 / 艺人 / 歌单，支持分页拉取与本地缓存
- 云端用户数据同步：收藏、最近播放、歌单双向同步
- 服务器连接状态实时检测与健康检查

### 🌐 在线音源与检索（由服务端提供）
- 聚合五大音源：**酷我、网易云、QQ 音乐、酷狗、咪咕**
- 全网歌曲 / 专辑 / 歌单搜索，音源脚本启停与平台开关管理
- 播放链接智能解析与容灾换链，区分标准（128K）/ 高品（320K）/ FLAC / Hi-Res 音质
- Wi-Fi 与移动网络下可分别设置试听音质偏好

### 🎵 本地曲库与播放
- 本地音频高速扫描，支持 `mp3 / flac / wav / m4a / aac / ogg / opus / ape`
- 本地封面提取与缩略图缓存，标签读取 / 智能匹配 / 写回
- 沉浸式全屏播放器：超大封面铺底、全屏滚动歌词、歌词字号与时间微调
- 播放队列、列表循环 / 单曲 / 顺序 / 随机、播放偏好记忆
- 基于 `AVSession` 的系统播控与实况窗，支持后台音频播放（`audioPlayback`）

### 📥 下载与标签管理
- 服务端 / 本地双通道下载，下载任务与进度管理
- 下载完成自动写入音频标签与高清封面，并生成同名 `.lrc` 歌词文件
- 已下载内容的批量管理、清理与存储占用统计

### 🎧 播客与音源管理
- RSS 播客订阅、单集列表与播放进度记忆（由服务端抓取）
- 音源脚本查看、导入（URL / 内容）、启停与平台绑定

### 🎨 界面与体验
- 玻璃拟态（Glass）悬浮页签与迷你播放器胶囊，支持上滑折叠
- 深浅主题、界面缩放、底栏动画与模糊强度可调
- 响应式布局，手机 / 平板 / 横竖屏自适应
- 四页签导航：首页 · 资料库 · 下载 · 设置

---

## 🏗 技术架构

| 层面 | 技术选型 |
| :--- | :--- |
| 开发语言 | ArkTS |
| UI 框架 | ArkUI 声明式（`@ComponentV2` / `@ObservedV2` / `@Local` / `@Param`） |
| 导航结构 | `Navigation(STACK)` + `Tabs` + 覆盖层插槽 |
| 构建系统 | hvigor（HarmonyOS 官方构建工具） |
| 编译 / 目标 SDK | HarmonyOS API 26（compileSdk / targetSdk / compatibleSdk 均为 26.0.0） |
| 网络 | `@kit.NetworkKit` HTTP 请求，Bearer Token 鉴权，统一 API 封装 |
| 播放 | `@kit.MediaKit` + `@kit.AVSessionKit`，后台音频播放 |
| 本地存储 | Preferences + 沙箱 JSON 文件（曲库 / 播放器 / 下载 / 播客 / 本地索引） |
| 图片 | 沙箱封面缓存 + 并发控制 |
| 设备类型 | phone、tablet |

---

## 📁 目录结构

```
lm-music/
├── README.md                       # 本说明文件
├── LICENSE                         # MIT 许可证
└── harmony/                        # HarmonyOS 工程根目录
    ├── AppScope/                   # 应用全局配置与资源（名称/图标）
    ├── entry/                      # 唯一 entry 模块
    │   └── src/main/
    │       ├── module.json5        # 模块配置、权限、Ability
    │       ├── resources/          # 图标、字符串、颜色等资源
    │       └── ets/
    │           ├── entryability/   # 应用入口 Ability
    │           ├── pages/          # @Entry 页面与二级页面
    │           ├── views/          # 页面视图（首页/资料库/下载/设置等）
    │           ├── components/     # 通用 UI 组件（Dock/封面/歌单/弹层等）
    │           ├── player/         # 全屏播放器、歌词、队列面板
    │           ├── service/        # 网络 API、播放、扫描、标签、同步、播客服务
    │           ├── viewmodel/      # 全局状态仓库（Store）
    │           ├── model/          # 数据模型定义
    │           ├── data/           # 本地持久化与缓存
    │           └── common/         # 常量、调色板、工具、服务端接口定义
    ├── hvigor/                     # hvigor 配置
    ├── build-profile.json5         # 工程构建配置（含签名配置，见下文）
    └── oh-package.json5            # 工程级依赖声明
```

> 应用只有一个 `@Entry` 页面（`pages/Index.ets`），内部以 `Navigation + Tabs + 覆盖层` 组织全部界面。

---

## 🚀 快速开始

### 环境要求
- **DevEco Studio**：支持 HarmonyOS NEXT / API 26 的版本（建议 5.0 及以上）
- **HarmonyOS SDK**：API 26（可通过 DevEco Studio 的 SDK Manager 安装）
- **Node.js**：DevEco Studio 自带或本地安装（hvigor 依赖）
- 一台 HarmonyOS NEXT 真机或模拟器

### 获取代码
```bash
git clone https://github.com/antony-xuning/lm-music.git
cd lm-music/harmony
```

### 配置签名
本仓库的 `build-profile.json5` **不包含任何真实签名凭据**，仅保留结构占位。首次构建前请在 DevEco Studio 中配置签名：

1. 打开 `File > Project Structure > Project > Signing Configs`
2. 勾选 **Automatically generate signature**（自动签名）
3. 使用你的华为开发者账号登录并完成自动签名
4. DevEco Studio 会将本机签名信息写回 `build-profile.json5`（该文件已被 `.gitignore` 的本地规则排除提交，请勿将个人凭据提交到仓库）

### 构建与运行
1. 用 DevEco Studio 打开 `harmony/` 目录
2. 等待依赖同步（hvigor / oh_modules）完成
3. 选择 `entry` 模块与 `default` 产物，连接真机或启动模拟器
4. 点击运行（ ▶ ）安装应用

> ⚠️ 应用首次启动需要配置服务端地址。请在 **设置 → 账号音源** 中填写你自建的柠檬音乐服务端地址（形如 `http://192.168.1.10:7983`）、用户名与密码。应用不会内置任何默认服务器或凭据。

### 所需权限
`module.json5` 中已声明：
- `ohos.permission.INTERNET` —— 访问服务端
- `ohos.permission.FILE_ACCESS_PERSIST` —— 本地音频与封面访问
- `ohos.permission.KEEP_BACKGROUND_RUNNING` —— 后台音频播放（配合 `audioPlayback` 后台模式）

---

## 🔌 服务端接口约定

客户端通过如下 API 前缀与服务端通信（`common/ServerEndpoints.ets` 集中定义）：

| 类别 | 接口示例 |
| :--- | :--- |
| 鉴权 | `/api/health`、`/api/auth/login`、`/api/auth/me` |
| 曲库 | `/api/library/tracks`、`/albums`、`/artists`、`/playlists`、`/user-data` |
| 播放 | `/api/play/url`、`/play/local`、`/play/lyric` |
| 标签 | `/api/tag/read`、`/match`、`/match-apply`、`/write`、`/cover` |
| 发现 | `/api/discover/toplists`、`/new-songs`、`/playlist/recommend`、`/album` |
| 搜索 | `/api/search`、`/search/album`、`/search/playlist` |
| 下载 | `/api/download/list`、`/add`、`/clear-completed` |
| 播客 | `/api/podcasts` 及相关子路径 |
| 音源 | `/api/source/list`、`/activate`、`/import-url`、`/import` |

服务端实现请参考 [lemon-muisc](https://github.com/jia070310/lemon-muisc)。

---

## ⚠️ 免责声明

1. **纯客户端工具**：本项目不内置、不制作、不存储、不分发任何音频、歌词、封面等版权内容。应用展示的在线内容均来自使用者自建的服务端或公开网络接口。
2. **内容合法性**：请仅连接你自己拥有合法使用权的服务端与内容。通过本应用检索或缓存的任何音频资源，仅供个人技术研究、播放测试与学习交流使用，体验后请及时清理缓存与离线文件。
3. **第三方名称**：界面中出现的音乐平台名称仅用于说明音源类型，不代表与相关平台存在任何官方合作、授权或商业关联。
4. **按“现状”提供**：本项目不附带任何明示或暗示担保，因使用、连接不受信任服务端或网络异常导致的任何损失，由使用者自行承担。
5. **非商业用途**：本项目为业余技术探索作品，禁止用于任何商业运营、分发或侵犯他人知识产权的用途。请尊重版权，支持正版音乐。

---

## 📄 许可证

本项目采用 [MIT License](LICENSE) 开源。

原始 Android 版 [LMPlayer](https://github.com/zyhub/LMplayer) Copyright © 2026 Zhou (zyhub)，HarmonyOS 移植版在其基础上重新实现。

---

## 🔗 相关项目

- [LMPlayer（Android 原版）](https://github.com/zyhub/LMplayer)
- [lemon-muisc（配套服务端）](https://github.com/jia070310/lemon-muisc)
