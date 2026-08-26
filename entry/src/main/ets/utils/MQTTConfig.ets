/**
 * MQTT 连接配置 & 单例实例
 * ——导入此文件即自动建立 MQTT 连接
 */
import { MQTTClient, MQTTOptionsType } from './MQTTClient';

const MQTTOption: MQTTOptionsType = {
  url: 'mqtt://your-broker-host:1883',
  clientId: '/your/client/id',
  userName: 'your-username',
  password: 'your-password',
  pubTopicName: '/your/pub/topic',      // 下发控制指令
  subTopicName: '/your/water/topic',    // 订阅水质数据
  gubTopicName: '/your/gps/topic',      // 订阅 GPS 数据
  qos: 0
};

/** 全局唯一 MQTT 客户端实例 */
export const MQTTInstance: MQTTClient = MQTTClient.getInstance(MQTTOption);