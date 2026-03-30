/**
 * GPS 数据帧解析器
 *
 * ★ 协议约定（与 MCU 固件保持一致，可按实际修改偏移量）：
 *   帧总长度 ≥ 40 字节（复用水质数据帧）
 *   Byte 28-31 : 纬度 × 1 000 000  (int32, 小端)  —— 36.880000 → 36880000
 *   Byte 32-35 : 经度 × 1 000 000  (int32, 小端)  —— 100.150000 → 100150000
 *   Byte 36    : 定位状态  0=无信号  1=GPS  2=DGPS
 *   Byte 37    : 可见卫星数
 *   Byte 38-39 : 速度 × 100 (uint16, 小端, km/h)  —— 5.23 km/h → 523
 */
import { GPSData } from '../common/Types';

// ===== 帧内偏移（根据 MCU 固件协议调整） =====
const GPS_LAT_OFFSET = 28;
const GPS_LNG_OFFSET = 32;
const GPS_FIX_OFFSET = 36;
const GPS_SAT_OFFSET = 37;
const GPS_SPD_OFFSET = 38;
const MIN_GPS_FRAME_LEN = 40;

/**
 * 从 HEX 字符串（空格分隔）中提取 GPS 信息
 * @param hexString  例 "AA 00 0A 00 ..."
 * @returns GPSData | null
 */
export function parseGPSData(hexString: string): GPSData | null {
  const cleaned = hexString.trim().toUpperCase();
  if (!cleaned) return null;

  const tokens = cleaned.split(/\s+/);
  if (tokens.length < MIN_GPS_FRAME_LEN) {
    // 帧长度不够，不含 GPS 字段
    return null;
  }

  const buf = new Uint8Array(tokens.length);
  for (let i = 0; i < tokens.length; i++) {
    if (!/^[0-9A-F]{2}$/.test(tokens[i])) return null;
    buf[i] = parseInt(tokens[i], 16);
  }

  const view = new DataView(buf.buffer);

  try {
    const rawLat = view.getInt32(GPS_LAT_OFFSET, true);
    const rawLng = view.getInt32(GPS_LNG_OFFSET, true);
    const fixStatus = buf[GPS_FIX_OFFSET];
    const satellites = buf[GPS_SAT_OFFSET];
    const rawSpeed = view.getUint16(GPS_SPD_OFFSET, true);

    const latitude  = rawLat / 1_000_000;
    const longitude = rawLng / 1_000_000;
    const speed     = rawSpeed / 100;

    // 简单有效性校验
    const isValid = fixStatus > 0
      && latitude >= -90 && latitude <= 90
      && longitude >= -180 && longitude <= 180
      && !(latitude === 0 && longitude === 0);

    return { latitude, longitude, fixStatus, satellites, speed, isValid };
  } catch (e) {
    console.error('parseGPSData error:', e);
    return null;
  }
}