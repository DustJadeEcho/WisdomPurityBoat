/**
 * 公共类型定义
 */

/** 页面导航回调 */
export type NavigationFunc = (page: number) => void;

/** 水质状态结果（状态文字 + 显示颜色） */
export interface StatusResult {
  status: string;
  color: number;
}

/** 解析后的水质测量数据 */
export interface MeasureDataInterface {
  tempVal: number;
  phVal: number;
  orpVal: number;
  tdsVal: number;
  turbVal: number;
}

/** ===== 新增：GPS 定位数据 ===== */
export interface GPSData {
  latitude: number;       // 纬度（°）
  longitude: number;      // 经度（°）
  fixStatus: number;      // 0=无信号  1=GPS  2=DGPS
  satellites: number;     // 可见卫星数
  speed: number;          // 速度 km/h
  isValid: boolean;       // 坐标是否有效
}