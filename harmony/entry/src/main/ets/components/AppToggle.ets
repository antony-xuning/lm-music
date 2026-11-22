/**
 * 开关封装：统一配色与禁用态。
 */
@ComponentV2
export struct AppToggle {
  @Param isOn: boolean = false;
  @Param toggleEnabled: boolean = true;
  @Param accent: string = '#FA2D48';
  @Event onToggle: (value: boolean) => void = () => {
  };

  build() {
    Toggle({ type: ToggleType.Switch, isOn: this.isOn })
      .selectedColor(this.accent)
      .switchPointColor('#FFFFFF')
      .enabled(this.toggleEnabled)
      .opacity(this.toggleEnabled ? 1 : 0.45)
      .onChange((value: boolean) => {
        this.onToggle(value);
      })
  }
}
