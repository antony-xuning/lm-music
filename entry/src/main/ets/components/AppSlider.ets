/**
 * 滑块封装：沉浸光感由应用级开启自动生效，这里统一配色与回调语义。
 */
@ComponentV2
export struct AppSlider {
  @Param sliderValue: number = 0;
  @Param minValue: number = 0;
  @Param maxValue: number = 100;
  @Param stepValue: number = 1;
  @Param accent: string = '#FA2D48';
  @Param trackColor: string = '#33FFFFFF';
  @Param sliderEnabled: boolean = true;
  @Event onValueChange: (value: number) => void = () => {
  };
  @Event onValueFinish: (value: number) => void = () => {
  };

  build() {
    Slider({
      value: this.sliderValue,
      min: this.minValue,
      max: this.maxValue,
      step: this.stepValue,
      style: SliderStyle.OutSet
    })
      .blockColor(this.accent)
      .selectedColor(this.accent)
      .trackColor(this.trackColor)
      .trackThickness(3)
      .enabled(this.sliderEnabled)
      .width('100%')
      .onChange((value: number, mode: SliderChangeMode) => {
        this.onValueChange(value);
        if (mode === SliderChangeMode.End || mode === SliderChangeMode.Click) {
          this.onValueFinish(value);
        }
      })
  }
}
