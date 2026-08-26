/**
 * 高原智清舟 —— 液态玻璃主题系统
 * 设计灵感：iOS 26 Liquid Glass + HarmonyOS 6 光效 + 大海/湖泊色彩
 */

// ============== 字体 ==============
/** 霞鹜文楷字体家族名（由 EntryAbility 注册） */
export const LXGW_FONT: string = 'LXGWWenKai';

// ============== 海洋色板 ==============
export class OceanPalette {
  // —— 主色调（深海 → 湖面 → 浅水）——
  static readonly ABYSS: string        = '#002244'; // 深渊蓝
  static readonly DEEP_OCEAN: string   = '#003B6F'; // 深海
  static readonly OCEAN: string        = '#0077B6'; // 海洋
  static readonly LAKE: string         = '#0096C7'; // 湖泊
  static readonly SHALLOW: string      = '#00B4D8'; // 浅水
  static readonly LAGOON: string       = '#48CAE4'; // 潟湖
  static readonly SKY: string          = '#90E0EF'; // 天空
  static readonly MIST: string         = '#CAF0F8'; // 雾气
  static readonly FOAM: string         = '#EAF6FB'; // 浪花
  static readonly SNOW: string         = '#F7FBFD'; // 雪

  // —— 玻璃面板色（带 alpha） ——
  static readonly GLASS_WHITE_STRONG: string = '#CCFFFFFF'; // 80%
  static readonly GLASS_WHITE: string        = '#99FFFFFF'; // 60%
  static readonly GLASS_WHITE_SOFT: string   = '#66FFFFFF'; // 40%
  static readonly GLASS_WHITE_LIGHT: string  = '#40FFFFFF'; // 25%
  static readonly GLASS_BORDER: string       = '#66FFFFFF'; // 边框高光
  static readonly GLASS_INNER: string        = '#33FFFFFF'; // 内侧高光

  // —— 强调色 ——
  static readonly ACCENT_CORAL: string  = '#FF7A8A'; // 珊瑚（警告/异常）
  static readonly ACCENT_GOLD: string   = '#FFD166'; // 金（提示）
  static readonly ACCENT_KELP: string   = '#3DDC97'; // 海草（正常）
  static readonly ACCENT_DANGER: string = '#EF476F'; // 危险

  // —— 文字色 ——
  static readonly TEXT_PRIMARY: string   = '#002244'; // 主文字（深海墨）
  static readonly TEXT_SECONDARY: string = '#3A5D7A'; // 次文字
  static readonly TEXT_MUTED: string     = '#708090'; // 淡文字
  static readonly TEXT_ON_GLASS: string  = '#0A2540'; // 玻璃上的字
  static readonly TEXT_WHITE: string     = '#FFFFFF';

  // —— 光效 ——
  static readonly HALO_CYAN: string  = '#4D48CAE4'; // 青色光晕
  static readonly HALO_BLUE: string  = '#4D0077B6'; // 蓝色光晕
  static readonly HALO_GOLD: string  = '#4DFFD166';
  static readonly HALO_CORAL: string = '#4DFF7A8A';
}

// ============== 渐变配置类型 ==============
/** .linearGradient() 参数对象结构 */
export interface GradientOption {
  angle?: number | string;
  direction?: GradientDirection;
  colors: Array<[ResourceColor, number]>;
  repeating?: boolean;
}

// ============== 渐变 ==============
export class OceanGradients {
  /** 页面背景渐变 —— 深海自上而下到浅湖 */
  static readonly PAGE_BG: GradientOption = {
    angle: 180,
    colors: [
      [OceanPalette.DEEP_OCEAN, 0.0],
      [OceanPalette.OCEAN,      0.3],
      [OceanPalette.LAKE,       0.6],
      [OceanPalette.LAGOON,     0.85],
      [OceanPalette.MIST,       1.0]
    ]
  };

  /** 顶部标题栏渐变 —— 深海微调光 */
  static readonly HEADER: GradientOption = {
    angle: 135,
    colors: [
      [OceanPalette.DEEP_OCEAN, 0.0],
      [OceanPalette.OCEAN,      0.6],
      [OceanPalette.LAKE,       1.0]
    ]
  };

  /** 按钮主色渐变 —— 清澈湖水 */
  static readonly BUTTON_PRIMARY: GradientOption = {
    angle: 135,
    colors: [
      [OceanPalette.OCEAN,   0.0],
      [OceanPalette.LAKE,    0.5],
      [OceanPalette.SHALLOW, 1.0]
    ]
  };

  /** 按钮强调色 —— 珊瑚暖光 */
  static readonly BUTTON_ACCENT: GradientOption = {
    angle: 135,
    colors: [
      [OceanPalette.ACCENT_CORAL, 0.0],
      [OceanPalette.ACCENT_GOLD,  1.0]
    ]
  };

  /** 按钮成功 —— 海草绿 */
  static readonly BUTTON_SUCCESS: GradientOption = {
    angle: 135,
    colors: [
      [OceanPalette.ACCENT_KELP, 0.0],
      [OceanPalette.LAGOON,      1.0]
    ]
  };

  /** 卡片高光 —— 玻璃质感 */
  static readonly GLASS_HIGHLIGHT: GradientOption = {
    angle: 160,
    colors: [
      [OceanPalette.GLASS_WHITE,       0.0],
      [OceanPalette.GLASS_WHITE_SOFT,  0.5],
      [OceanPalette.GLASS_WHITE_LIGHT, 1.0]
    ]
  };

  /** 底部导航栏玻璃 */
  static readonly TAB_BAR: GradientOption = {
    angle: 180,
    colors: [
      ['#66FFFFFF', 0.0],
      ['#99FFFFFF', 1.0]
    ]
  };

  /** 按钮禁用态灰色 */
  static readonly BUTTON_DISABLED: GradientOption = {
    angle: 135,
    colors: [
      ['#99708090', 0.0],
      ['#99A0B0C0', 1.0]
    ]
  };
}

// ============== 字号规范 ==============
export class OceanFont {
  static readonly TITLE: number    = 28;
  static readonly HEADING: number  = 22;
  static readonly SUBHEAD: number  = 18;
  static readonly BODY: number     = 16;
  static readonly CAPTION: number  = 14;
  static readonly MICRO: number    = 12;
}

// ============== 圆角规范 ==============
export class OceanRadius {
  static readonly CARD: number    = 20;
  static readonly BUTTON: number  = 16;
  static readonly CHIP: number    = 24;
  static readonly ICON: number    = 14;
}
