/**
 * 路由桥：让叠层面板（半模态）也能触发 Navigation 路由跳转。
 * 由 Index 在启动时注册处理函数。
 */
type RouteHandler = (name: string, param: Object | null) => void;

class RouteBridgeImpl {
  private handler: RouteHandler | null = null;

  register(handler: RouteHandler | null): void {
    this.handler = handler;
  }

  open(name: string, param: Object | null): boolean {
    if (this.handler === null) {
      return false;
    }
    this.handler(name, param);
    return true;
  }
}

export const routeBridge: RouteBridgeImpl = new RouteBridgeImpl();
