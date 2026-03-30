/**
 * 水质数据帧解析
 */
import { MeasureDataInterface } from '../common/Types';

/** 数据帧总字节长度 */
const DATA_FRAME_LEN: number = 64;

/** 参数在帧中的字节偏移量 */
const TEMP_OFFSET = 10;
const PH_OFFSET   = 12;
const ORP_OFFSET  = 16;
const TDS_OFFSET  = 20;
const TURB_OFFSET = 24;

/**
 * 将 HEX 字符串（空格分隔）解析为水质参数
 * @param hexString 例 "AA 00 0A 00 ..."
 * @returns 解析结果，失败返回 null
 */
export function parseWaterData(hexString: string): MeasureDataInterface | null {
  const cleanedHex = hexString.trim().toUpperCase();
  if (!cleanedHex) {
    console.error('输入数据为空');
    return null;
  }

  const bytes = cleanedHex.split(/\s+/);
  if (bytes.length < DATA_FRAME_LEN) {
    console.error(`数据长度不足: 需要${DATA_FRAME_LEN}字节，实际${bytes.length}字节`);
    return null;
  }

  const byteArray = new Uint8Array(DATA_FRAME_LEN);
  for (let i = 0; i < DATA_FRAME_LEN; i++) {
    const hexByte = bytes[i];
    if (!/^[0-9A-F]{2}$/.test(hexByte)) {
      console.error(`无效的HEX字节: ${hexByte}，位置: ${i}`);
      return null;
    }
    byteArray[i] = parseInt(hexByte, 16);
  }

  const view = new DataView(byteArray.buffer);

  try {
    const rawTemp = view.getUint16(TEMP_OFFSET, true);
    const rawPh   = view.getUint32(PH_OFFSET, true);
    const rawOrp  = view.getUint32(ORP_OFFSET, true);
    const rawTds  = view.getUint32(TDS_OFFSET, true);
    const rawTurb = view.getUint32(TURB_OFFSET, true);

    return {
      tempVal: parseFloat(((rawTemp / 10) * 0.625).toFixed(1)),
      phVal:   parseFloat((rawPh / 100).toFixed(2)),
      orpVal:  parseFloat((rawOrp / 100).toFixed(2)),
      tdsVal:  parseFloat((rawTds / 100).toFixed(2)),
      turbVal: parseFloat((rawTurb / 100).toFixed(2))
    };
  } catch (error) {
    console.error('解析二进制数据时出错:', error);
    return null;
  }
}