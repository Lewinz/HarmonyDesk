/**
 * 主页面 - 远程桌面连接
 */
import router from '@ohos.router';
import nativeModule from 'libharmonydesk.so';

@Entry
@Component
struct Index {
  @State deskId: string = '';
  @State password: string = '';
  @State isConnected: boolean = false;
  @State errorMessage: string = '';
  @State connectionStatus: string = '未连接';

  /**
   * 连接到远程桌面
   */
  async connectToRemoteDesk() {
    if (!this.deskId) {
      this.errorMessage = '请输入远程桌面 ID';
      return;
    }

    try {
      this.connectionStatus = '正在连接...';
      this.errorMessage = '';

      // 调用 Rust 原生模块
      const result = nativeModule.connect(this.deskId, this.password);

      if (result === 0) {
        this.isConnected = true;
        this.connectionStatus = '已连接';

        // 跳转到远程桌面页面
        router.pushUrl({
          url: 'pages/RemoteDesktop',
          params: {
            deskId: this.deskId,
            password: this.password
          }
        });
      } else {
        this.errorMessage = `连接失败: 错误码 ${result}`;
        this.connectionStatus = '连接失败';
      }
    } catch (error) {
      this.errorMessage = `连接异常: ${error.message}`;
      this.connectionStatus = '连接异常';
    }
  }

  /**
   * 断开连接
   */
  disconnect() {
    try {
      nativeModule.disconnect();
      this.isConnected = false;
      this.connectionStatus = '未连接';
      this.errorMessage = '';
    } catch (error) {
      this.errorMessage = `断开连接失败: ${error.message}`;
    }
  }

  build() {
    Column() {
      // 标题栏
      Text('HarmonyDesk')
        .fontSize(28)
        .fontWeight(FontWeight.Bold)
        .margin({ top: 40, bottom: 20 })

      // 连接状态
      Text(this.connectionStatus)
        .fontSize(16)
        .fontColor(this.isConnected ? '#4CAF50' : '#FF9800')
        .margin({ bottom: 30 })

      // 远程桌面 ID 输入
      Column({ space: 10 }) {
        Text('远程桌面 ID')
          .fontSize(14)
          .fontColor('#666')

        TextInput({ placeholder: '请输入远程桌面 ID' })
          .height(48)
          .enabled(!this.isConnected)
          .onChange((value: string) => {
            this.deskId = value;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 15 })

      // 密码输入
      Column({ space: 10 }) {
        Text('密码')
          .fontSize(14)
          .fontColor('#666')

        TextInput({ placeholder: '请输入密码（可选）' })
          .height(48)
          .type(InputType.Password)
          .enabled(!this.isConnected)
          .onChange((value: string) => {
            this.password = value;
          })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .margin({ bottom: 20 })

      // 错误提示
      if (this.errorMessage) {
        Text(this.errorMessage)
          .fontSize(14)
          .fontColor('#F44336')
          .margin({ bottom: 15 })
      }

      // 连接/断开按钮
      Button(this.isConnected ? '断开连接' : '连接')
        .width('100%')
        .height(48)
        .fontSize(16)
        .backgroundColor(this.isConnected ? '#F44336' : '#2196F3')
        .onClick(() => {
          if (this.isConnected) {
            this.disconnect();
          } else {
            this.connectToRemoteDesk();
          }
        })

      // 功能按钮（连接后可用）
      if (this.isConnected) {
        Column({ space: 10 }) {
          Button('打开文件传输')
            .width('100%')
            .height(44)
            .backgroundColor('#4CAF50')
            .onClick(() => {
              // TODO: 实现文件传输
            })

          Button('打开会话设置')
            .width('100%')
            .height(44)
            .backgroundColor('#9C27B0')
            .onClick(() => {
              // TODO: 打开设置
            })
        }
        .margin({ top: 20 })
        .width('100%')
      }

      Blank()

      // 底部信息
      Text('基于 RustDesk 协议的鸿蒙远程桌面控制端')
        .fontSize(12)
        .fontColor('#999')
        .margin({ bottom: 20 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 24, right: 24 })
    .backgroundColor('#F5F5F5')
  }
}
