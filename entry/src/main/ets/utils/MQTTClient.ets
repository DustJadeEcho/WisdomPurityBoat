import {
  MqttAsync,
  MqttClient,
  MqttMessage,
  MqttQos,
  MqttResponse,
  MqttSubscribeOptions,
} from '@ohos/mqtt';
import emitter from '@ohos.events.emitter';


// 事件id
const EVENTID = 1001
const GPS_EVENTID = 1002;          // ← 新增：GPS 专用事件 ID

interface MQTTOptionsType {
  url?: string
  clientId?: string
  userName?: string
  password?: string
  pubTopicName?: string
  subTopicName?: string
  qos?: MqttQos | undefined
}

class MQTTClient {
  private static instance: MQTTClient
  private mqttClient: MqttClient | null = null
  private url: string = ""
  // 以null结尾的字符串，指定客户端将连接到的服务器。它采取的形式protocol://host:port.protocol必须是tcp、ssl、ws或wss。对于主机，可以指定IP地址或主机名。例如，tcp://localhost:1883
  private userName: string = '' // 客户端用户名
  private password: string = '' // 客户端密码
  private clientId: string = '' // 客户端连接到服务器时传递给服务器的客户端标识符。它是一个以空结尾的UTF-8编码字符串
  private pubTopicName: string = '' //发布主题
  private subTopicName: string = '' //订阅主题
  private qos: MqttQos | undefined // 消息的服务质量设置 0 最多一次 1 至少一次 2 近一次

  constructor(mqttOptions: MQTTOptionsType) {
    mqttOptions.url && (this.url = mqttOptions.url)
    mqttOptions.userName && (this.userName = mqttOptions.userName)
    mqttOptions.password && (this.password = mqttOptions.password)
    mqttOptions.clientId && (this.clientId = mqttOptions.clientId)
    mqttOptions.pubTopicName && (this.pubTopicName = mqttOptions.pubTopicName)
    mqttOptions.subTopicName && (this.subTopicName = mqttOptions.subTopicName)
    mqttOptions.qos && (this.qos = mqttOptions.qos)
    this.init()
  }

  // 静态方法获取唯一实例
  public static getInstance(mqttOptions: MQTTOptionsType): MQTTClient {
    if (!MQTTClient.instance) {
      MQTTClient.instance = new MQTTClient(mqttOptions)
    }
    return MQTTClient.instance
  }

  // 初始化方法
  async init() {
    console.info(`MQTT Server URL: ${this.url}`)
    console.info(`UserName: ${this.userName}`)
    console.info(`Client ID: ${this.clientId}`)
    console.info(`Publish Topic: ${this.pubTopicName}`)
    console.info(`Subscribe Topic: ${this.subTopicName}`)
    this.createMqttClient() // 创建mqtt实例
    await this.connectMqtt() // 连接服务器
    await this.subscribe() // 订阅主题
    this.messageArrived() // 监听订阅主题
  }

  // 创建mqtt实例
  public createMqttClient() {
    this.mqttClient = MqttAsync.createMqtt({
      url: this.url,
      clientId: this.clientId,
      persistenceType: 1 // 客户端使用的持久性类型，0=默认值：使用默认（基于文件系统）持久性机制。1=在内存持久性中使用。2=使用特定于应用程序的持久性实现
    })
  }

  // 连接服务器
  public async connectMqtt() {
    if (!this.mqttClient) {
      return
    }
    await this.mqttClient.connect({
      userName: this.userName,
      password: this.password,
      connectTimeout: 30, // 设置连接超时时间，默认
      automaticReconnect: true, // 是否在连接丢失的情况下自动重新连接
      MQTTVersion: 0, // 设置要在连接上使用的MQTT版本， 0=默认值：从3.1.1开始，如果失败，则返回到3.1，3=仅尝试版本3.1，4=仅尝试3.1.1版本
      // sslOptions:{
      //   enableServerCertAuth: true, // 是否开启服务端证书认证，默认为false
      //    trustStore: fileDir + "/ca.crt" // CA证书的沙箱路径
      // }
    }).then((res: MqttResponse) => {
      console.info('MQTT服务器连接连接成功：' + JSON.stringify(res.message))
    }).catch((err: Error) => {
      console.error('MQTT服务器连接连接失败：' + JSON.stringify(err))
    })
  }



  // 订阅主题
  public async subscribe() {
    if (!this.mqttClient) {
      return
    }
    let subscribeOption: MqttSubscribeOptions = {
      topic: this.subTopicName,
      qos: this.qos as MqttQos
    }
    await this.mqttClient.subscribe(subscribeOption).then((res: MqttResponse) => {
      console.info('MQTT订阅主题成功：', JSON.stringify(res.message))
    }).catch((err: Error) => {
      console.error('MQTT订阅主题失败：', JSON.stringify(err))
    })
    // 监听订阅主题
    this.messageArrived()
  }

  // 监听订阅主题
  public messageArrived() {
    if (!this.mqttClient) {
      return
    }
    // 监听主题发送消息
    this.mqttClient.messageArrived((err: Error, data: MqttMessage) => {
      if (err) {
        console.error('MQTT接收消息失败：', JSON.stringify(err))
      } else {
        // HarmonyOS 返回 payload 类型是 ArrayBuffer 或 Uint8Array
        const raw = new Uint8Array(data.payloadBinary); // 将 payloadBinary 转为字节数组
        // 示例：转换为十六进制字符串显示
        const hexStr = Array.from(raw).map(b => b.toString(16).padStart(2, '0')).join(' ');
        console.info('MQTT接收消息成功（HEX）：', hexStr);
        // ① 水质数据事件（MonitoringPage 监听）
        emitter.emit({
          eventId: EVENTID,
          priority: emitter.EventPriority.LOW
        }, {
          data: { content: hexStr }
        });

        // ② GPS 数据事件（MapPage 监听）        ← 新增
        emitter.emit({
          eventId: GPS_EVENTID,
          priority: emitter.EventPriority.LOW
        }, {
          data: { content: hexStr }
        });
      }
    });
  }

  private arrayBufferToBase64(buffer: ArrayBuffer): string {
    let binary = ''
    const bytes = new Uint8Array(buffer)
    for (let i = 0; i < bytes.byteLength; i++) {
      binary += String.fromCharCode(bytes[i])
    }
    return globalThis.btoa(binary)
  }
  /**
   * 发送消息
   * @param pic 订阅的主题
   * @param msg 消息内容
   * @param qo qos
   */
  public async pushMessage(hexString: string, pic: string = this.pubTopicName, qo: MqttQos = this.qos as MqttQos) {
    if (!this.mqttClient) {
      console.error('MQTT client not initialized');
      return;
    }

    await this.mqttClient.publish({
      topic: pic,
      qos: qo,
      payload: hexString
    }).then((data: MqttResponse) => {
      console.info(`MQTT消息发送成功到 ${pic}:`, JSON.stringify(data));
      // 调试信息：显示发送的十六进制数据
      console.debug('发送的十六进制数据:', hexString);
    }).catch((err: Error) => {
      console.error("MQTT消息发送失败：", JSON.stringify(err))
    });
  }
  // 添加格式化方法（如果类中不存在）
  private formatHexForLog(hex: string): string {
    // 移除所有空格和非十六进制字符
    const cleanHex = hex.replace(/[^0-9A-Fa-f]/g, '');

    // 每4个字符（2字节）加一个空格
    let result = '';
    for (let i = 0; i < cleanHex.length; i += 4) {
      if (i > 0) result += ' ';
      result += cleanHex.substring(i, i + 4);
    }
    return result;
  }

  // 销毁客户端实例
  public async destroy() {
    if (!this.mqttClient) {
      return
    }
    await this.mqttClient.destroy().then((data: boolean) => {
      if (data) {
        console.info('MQTT实例销毁成功')
        emitter.off(EVENTID)
      } else {
        console.error('MQTT实例销毁失败')
      }
    })

  }
}

export {
  MQTTClient, EVENTID, GPS_EVENTID, MQTTOptionsType
}
