/**
 * 服务器编辑浮层：添加 / 编辑柠檬音乐服务器（参考稿样式）。
 * 品牌「固定类型」卡 + 浮动标签输入组 + 端口独立字段 + 密码可见切换 + 三按钮操作区。
 * 密码只在本次输入中进入内存，不写入任何持久化内容。
 */
import { ServerEndpoints } from '../common/ServerEndpoints';
import { ServerConfig } from '../model/SettingsModels';
import { LoginOutcome } from '../service/ServerManager';
import { libraryStore } from '../viewmodel/LibraryStore';
import { overlayStore } from '../viewmodel/OverlayStore';
import { serverStore } from '../viewmodel/ServerStore';
import { settingsStore } from '../viewmodel/SettingsStore';
import { syncStore } from '../viewmodel/SyncStore';
import { themeStore } from '../viewmodel/ThemeStore';

@ComponentV2
export struct ServerEditSheet {
  @Local editId: string = '';
  @Local formName: string = '';
  @Local formAddr: string = '';
  @Local formPort: string = '';
  @Local formUser: string = '';
  @Local formPassword: string = '';
  @Local showPassword: boolean = false;
  @Local testing: boolean = false;
  @Local message: string = '';
  @Local messageOk: boolean = false;

  aboutToAppear(): void {
    this.editId = overlayStore.serverEditId;
    this.message = '';
    this.messageOk = false;
    this.showPassword = false;
    this.formPassword = '';
    if (this.editId.length > 0) {
      const server: ServerConfig | null = settingsStore.findServer(this.editId);
      if (server !== null) {
        this.formName = server.name;
        this.splitUrl(server.url);
        this.formUser = server.username;
      }
    } else {
      this.formName = '';
      this.formAddr = '';
      this.formPort = '';
      this.formUser = '';
    }
  }

  /** 把已保存的完整地址拆为「地址（含协议）」与「端口」两个字段。 */
  private splitUrl(url: string): void {
    const base: string = url.trim();
    const schemeIdx: number = base.indexOf('://');
    if (schemeIdx < 0) {
      this.formAddr = base;
      return;
    }
    const schemeEnd: number = schemeIdx + 3;
    const pathIdx: number = base.indexOf('/', schemeEnd);
    const host: string = pathIdx >= 0 ? base.substring(0, pathIdx) : base;
    const colon: number = host.lastIndexOf(':');
    if (colon > schemeEnd) {
      const portPart: string = host.substring(colon + 1);
      if (/^[0-9]+$/.test(portPart)) {
        this.formPort = portPart;
        this.formAddr = host.substring(0, colon);
        return;
      }
    }
    this.formAddr = host;
  }

  /** 由地址与端口组合出完整 Base URL；裸地址缺省补 7983，带协议地址端口留空即原样使用。 */
  private composeBase(): string {
    let addr: string = this.formAddr.trim();
    if (addr.length === 0) {
      return '';
    }
    const lower: string = addr.toLowerCase();
    const hasScheme: boolean = lower.startsWith('http://') || lower.startsWith('https://');
    if (!hasScheme) {
      addr = 'http://' + addr;
    }
    addr = ServerEndpoints.normalizeBase(addr);
    let port: string = this.formPort.trim();
    if (port.length === 0) {
      if (!hasScheme) {
        port = '7983';
      } else {
        return addr;
      }
    }
    const schemeEnd: number = addr.indexOf('://') + 3;
    const pathIdx: number = addr.indexOf('/', schemeEnd);
    const host: string = pathIdx >= 0 ? addr.substring(0, pathIdx) : addr;
    const path: string = pathIdx >= 0 ? addr.substring(pathIdx) : '';
    const colon: number = host.lastIndexOf(':');
    let bare: string = host;
    if (colon > schemeEnd && /^[0-9]+$/.test(host.substring(colon + 1))) {
      bare = host.substring(0, colon);
    }
    return bare + ':' + port + path;
  }

  /** needPassword：测试连接必须带密码；仅保存时编辑已有服务器可不填。 */
  private validate(needPassword: boolean): string {
    const addr: string = this.formAddr.trim();
    if (addr.length === 0) {
      return '请填写服务器地址';
    }
    if (addr.indexOf(' ') >= 0) {
      return '服务器地址不能包含空格';
    }
    const port: string = this.formPort.trim();
    if (port.length > 0) {
      if (!/^[0-9]+$/.test(port)) {
        return '端口必须为数字';
      }
      const value: number = parseInt(port);
      if (isNaN(value) || value < 1 || value > 65535) {
        return '端口范围为 1 - 65535';
      }
    }
    if (this.formUser.trim().length === 0) {
      return '请填写用户名';
    }
    if (needPassword && this.formPassword.length === 0) {
      return '请填写登录密码';
    }
    return '';
  }

  private buildConfig(): ServerConfig {
    const server: ServerConfig = new ServerConfig();
    server.id = this.editId.length > 0 ? this.editId : settingsStore.newServerId();
    server.name = this.formName.trim().length > 0 ? this.formName.trim() : '柠檬音乐服务器';
    server.url = ServerEndpoints.normalizeBase(this.composeBase());
    server.username = this.formUser.trim();
    server.type = 'lemon';
    server.syncMode = 'twoWay';
    server.isActive = false;
    const existing: ServerConfig | null = this.editId.length > 0 ? settingsStore.findServer(this.editId) : null;
    if (existing !== null) {
      server.token = existing.token;
      server.tokenExpiresAt = existing.tokenExpiresAt;
      server.isActive = existing.isActive;
    }
    return server;
  }

  /** 测试连接：校验 → 登录（成功即持久化令牌并激活）→ 刷新曲库与同步 → 关闭浮层。 */
  private async test(): Promise<void> {
    if (this.testing) {
      return;
    }
    const error: string = this.validate(true);
    if (error.length > 0) {
      this.message = error;
      this.messageOk = false;
      return;
    }
    this.testing = true;
    this.message = '正在连接…';
    this.messageOk = false;
    try {
      const server: ServerConfig = this.buildConfig();
      const outcome: LoginOutcome = await serverStore.testAndLogin(server, this.formPassword);
      this.formPassword = '';
      if (outcome.ok) {
        libraryStore.clearServerData();
        libraryStore.loadSnapshot();
        syncStore.syncNow(true);
        overlayStore.closeSheet();
      } else {
        this.message = outcome.message;
      }
    } finally {
      this.testing = false;
    }
  }

  /** 仅保存：不登录，编辑模式保留已有令牌。 */
  private save(): void {
    const error: string = this.validate(false);
    if (error.length > 0) {
      this.message = error;
      this.messageOk = false;
      return;
    }
    settingsStore.saveServer(this.buildConfig());
    overlayStore.closeSheet();
  }

  @Builder
  fieldLabel(label: string) {
    Text(label)
      .fontSize(11)
      .fontColor(themeStore.palette.sub)
      .margin({ bottom: 7 })
  }

  @Builder
  brandCard() {
    Row({ space: 10 }) {
      Column({ space: 3 }) {
        Text('柠檬音乐')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text('固定类型 · 仅支持柠檬音乐服务端')
          .fontSize(10.5)
          .fontColor('#CCFFFFFF')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Stack() {
        Image($r('app.media.ic_check'))
          .width(13)
          .height(13)
          .fillColor('#FA2D48')
      }
      .width(22)
      .height(22)
      .borderRadius(11)
      .backgroundColor(Color.White)
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 13, bottom: 13 })
    .borderRadius(14)
    .linearGradient({ angle: 120, colors: [[themeStore.palette.brand, 0], ['#D91B34', 1]] })
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text(this.editId.length > 0 ? '编辑柠檬音乐服务器' : '添加柠檬音乐服务器')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(themeStore.palette.text)
          .width('100%')

        this.brandCard()

        // 服务器名称
        Column() {
          this.fieldLabel('服务器名称（可选，如 客厅柠檬）')
          TextInput({ text: this.formName, placeholder: 'nas' })
            .fontSize(13)
            .fontColor(themeStore.palette.text)
            .placeholderColor(themeStore.palette.sub)
            .height(46)
            .backgroundColor(themeStore.palette.controlBg)
            .borderRadius(14)
            .border({ width: 1, color: themeStore.palette.softBorder })
            .onChange((value: string) => {
              this.formName = value;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 服务器地址
        Column() {
          this.fieldLabel('服务器地址（如 192.168.1.100 或 https://域名）')
          TextInput({ text: this.formAddr, placeholder: 'http://nas.sixfun.xyz' })
            .fontSize(13)
            .fontColor(themeStore.palette.text)
            .placeholderColor(themeStore.palette.sub)
            .height(46)
            .backgroundColor(themeStore.palette.controlBg)
            .borderRadius(14)
            .border({ width: 1, color: themeStore.palette.softBorder })
            .onChange((value: string) => {
              this.formAddr = value;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 端口
        Column() {
          this.fieldLabel('端口（默认 7983，反向代理域名可留空）')
          TextInput({ text: this.formPort, placeholder: '7983' })
            .fontSize(13)
            .fontColor(themeStore.palette.text)
            .placeholderColor(themeStore.palette.sub)
            .height(46)
            .backgroundColor(themeStore.palette.controlBg)
            .borderRadius(14)
            .border({ width: 1, color: themeStore.palette.softBorder })
            .onChange((value: string) => {
              this.formPort = value;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 用户名
        Column() {
          this.fieldLabel('用户名')
          TextInput({ text: this.formUser, placeholder: 'admin' })
            .fontSize(13)
            .fontColor(themeStore.palette.text)
            .placeholderColor(themeStore.palette.sub)
            .height(46)
            .backgroundColor(themeStore.palette.controlBg)
            .borderRadius(14)
            .border({ width: 1, color: themeStore.palette.softBorder })
            .onChange((value: string) => {
              this.formUser = value;
            })
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        // 登录密码
        Column() {
          this.fieldLabel('登录令牌 Token / 密码')
          Stack({ alignContent: Alignment.End }) {
            TextInput({ text: this.formPassword, placeholder: this.editId.length > 0 ? '留空则沿用已保存的登录状态' : '仅本次会话内存保存' })
              .type(this.showPassword ? InputType.Normal : InputType.Password)
              .fontSize(13)
              .fontColor(themeStore.palette.text)
              .placeholderColor(themeStore.palette.sub)
              .height(46)
              .backgroundColor(themeStore.palette.controlBg)
              .borderRadius(14)
              .border({ width: 1, color: themeStore.palette.softBorder })
              .padding({ right: 44 })
              .onChange((value: string) => {
                this.formPassword = value;
              })

            Image(this.showPassword ? $r('app.media.ic_eye_off') : $r('app.media.ic_eye'))
              .width(19)
              .height(19)
              .fillColor(themeStore.palette.sub)
              .margin({ right: 12 })
              .onClick(() => {
                this.showPassword = !this.showPassword;
              })
          }
          .width('100%')
        }
        .width('100%')
        .alignItems(HorizontalAlign.Start)

        if (this.message.length > 0) {
          Text(this.message)
            .fontSize(11)
            .fontColor(this.messageOk ? '#2ED3A6' : '#FFB44C')
            .width('100%')
        }

        // 操作区：测试连接 / 取消 / 保存
        Row({ space: 10 }) {
          Text(this.testing ? '连接中…' : '测试连接')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(themeStore.palette.text)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(46)
            .borderRadius(16)
            .backgroundColor(themeStore.palette.controlBg)
            .border({ width: 1, color: themeStore.palette.softBorder })
            .stateStyles({
              pressed: {
                .scale({ x: 0.96, y: 0.96 })
              },
              normal: {
                .scale({ x: 1, y: 1 })
              }
            })
            .animation({ duration: 130, curve: Curve.EaseOut })
            .onClick(() => {
              this.test();
            })

          Text('取消')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(themeStore.palette.text)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
            .height(46)
            .borderRadius(16)
            .backgroundColor(themeStore.palette.controlBg)
            .border({ width: 1, color: themeStore.palette.softBorder })
            .stateStyles({
              pressed: {
                .scale({ x: 0.96, y: 0.96 })
              },
              normal: {
                .scale({ x: 1, y: 1 })
              }
            })
            .animation({ duration: 130, curve: Curve.EaseOut })
            .onClick(() => {
              overlayStore.closeSheet();
            })

          Text('保存')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(Color.White)
            .textAlign(TextAlign.Center)
            .layoutWeight(1.2)
            .height(46)
            .borderRadius(16)
            .backgroundColor(themeStore.palette.brand)
            .stateStyles({
              pressed: {
                .scale({ x: 0.96, y: 0.96 })
              },
              normal: {
                .scale({ x: 1, y: 1 })
              }
            })
            .animation({ duration: 130, curve: Curve.EaseOut })
            .onClick(() => {
              this.save();
            })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 18, bottom: 26 })
      .backgroundColor(themeStore.palette.card)
    }
    .width('100%')
    .scrollable(ScrollDirection.Vertical)
    .edgeEffect(EdgeEffect.Spring)
    .align(Alignment.Top)
  }
}
