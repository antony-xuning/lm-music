/**
 * 下拉选择封装：按钮与下拉菜单的沉浸光感由应用级开启自动生效。
 */
import { SelectOptionItem } from '../model/UiModels';

@ComponentV2
export struct AppSelect {
  @Param options: SelectOptionItem[] = [];
  @Param selectedIndex: number = 0;
  @Param textColor: string = '#F5F5F7';
  @Param subColor: string = '#A1A1A8';
  @Param accent: string = '#FA2D48';
  @Param selectWidth: number = 150;
  @Event onSelect: (index: number) => void = () => {
  };

  private buildOptions(): SelectOption[] {
    const result: SelectOption[] = [];
    for (let i = 0; i < this.options.length; i++) {
      const option: SelectOption = { value: this.options[i].label };
      result.push(option);
    }
    return result;
  }

  build() {
    Select(this.buildOptions())
      .selected(this.selectedIndex)
      .value(this.options.length > 0 && this.selectedIndex >= 0
        && this.selectedIndex < this.options.length ? this.options[this.selectedIndex].label : '')
      .font({ size: 13, weight: FontWeight.Medium })
      .fontColor(this.textColor)
      .selectedOptionFontColor(this.accent)
      .optionFontColor(this.textColor)
      .optionBgColor('#1C1C20')
      .width(this.selectWidth)
      .onSelect((index: number) => {
        this.onSelect(index);
      })
  }
}
