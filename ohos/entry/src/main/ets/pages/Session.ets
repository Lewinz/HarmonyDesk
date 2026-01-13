import router from '@ohos.router';
import { image } from '@kit.ImageKit';
import { getNativeModule, initHarmonyDesk, type VideoFrame } from '../native/HarmonyDeskNative';

@Entry
@Component
struct Session {
  @State viewOnly: boolean = false;
  @State hdQuality: boolean = true;
  @State showToolbar: boolean = false;
  @State deskId: string = '';
  @State password: string = '';
  @State isConnected: boolean = false;
  @State connectionStatus: string = '未连接';
  @State errorMessage: string = '';
  @State pixelMap: image.PixelMap | null = null;
  @State frameRate: number = 20;
  @State showMenu: boolean = false;
  @State deviceName: string = '';
  @State ballX: number = 300;
  @State ballY: number = 500;
  @State ballOffsetX: number = 0;
  @State ballOffsetY: number = 0;
  @State isDragging: boolean = false;
  @State isHalfHidden: boolean = true;

  private videoTimer: number = -1;
  private screenWidth: number = 360;
  private screenHeight: number = 780;
  private ballSize: number = 48;

  async aboutToAppear() {
    await initHarmonyDesk();

    const params = router.getParams() as Record<string, string>;
    this.deskId = params.id || '';
    this.password = params.password || '';
    this.deviceName = params.name || '';
    this.viewOnly = params.viewOnly === '1';

    // 初始化悬浮球位置（右下角，半隐藏）
    this.ballX = this.screenWidth - this.ballSize;
    this.ballY = this.screenHeight - this.ballSize - 100;
    this.isHalfHidden = true;

    if (this.deskId) {
      this.connect();
    }
  }

  async aboutToDisappear() {
    if (this.videoTimer !== -1) {
      clearInterval(this.videoTimer);
      this.videoTimer = -1;
    }
    if (this.pixelMap) {
      this.pixelMap.release();
      this.pixelMap = null;
    }
    await this.disconnect();
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      // 全屏远程画面
      Column() {
        if (this.pixelMap) {
          Image(this.pixelMap)
            .objectFit(ImageFit.Cover)
            .width('100%')
            .height('100%')
        } else {
          Column({ space: 12 }) {
            if (this.connectionStatus === '连接中...') {
              Text('正在连接...')
                .fontSize(16)
                .fontColor($r('app.color.text_primary'))
            }
            if (this.errorMessage) {
              Text(this.errorMessage)
                .fontSize(14)
                .fontColor($r('app.color.status_offline'))
            }
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .backgroundColor($r('app.color.app_background_top'))
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange((area: Area) => {
        this.screenWidth = Number(area.width) as number;
        this.screenHeight = Number(area.height) as number;
        // 更新悬浮球位置到右下角
        if (!this.isDragging && !this.showMenu) {
          this.ballX = this.screenWidth - this.ballSize;
          this.ballY = this.screenHeight - this.ballSize - 100;
        }
      })

      // 顶部状态栏（连接后显示）
      if (this.isConnected && this.showToolbar) {
        Row({ space: 12 }) {
          Button()
            .type(ButtonType.Circle)
            .width(36)
            .height(36)
            .backgroundColor($r('app.color.card_background'))
            .onClick(() => {
              router.back();
            })
          .stateEffect(true)

          Column({ space: 2 }) {
            Text(this.deviceName || this.deskId)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            Text('已连接')
              .fontSize(12)
              .fontColor($r('app.color.status_online'))
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Button('断开')
            .type(ButtonType.Capsule)
            .fontSize(13)
            .height(32)
            .fontColor($r('app.color.text_on_accent'))
            .backgroundColor($r('app.color.accent'))
            .onClick(() => {
              this.disconnect();
              router.back();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor($r('app.color.card_background'))
        .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.1)' })
      }

      // 悬浮球
      if (this.isConnected) {
        Stack() {
          if (!this.showMenu) {
            // 悬浮球按钮
            Button()
              .type(ButtonType.Circle)
              .width(this.ballSize)
              .height(this.ballSize)
              .backgroundColor($r('app.color.accent'))
              .position({ x: this.ballX, y: this.ballY })
              .translate({
                x: this.isHalfHidden ? (this.ballX >= this.screenWidth - this.ballSize ? -10 : 10) : 0,
                y: this.isHalfHidden ? (this.ballY >= this.screenHeight - this.ballSize ? -10 : 10) : 0
              })
              .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.3)' })
              .gesture(
                // 组合手势：优先识别长按，没有长按才识别点击
                LongPressGesture({ repeat: false, duration: 200 })
                  .onAction(() => {
                    this.isDragging = true;
                    this.isHalfHidden = false;
                  })
              )
              .gesture(
                // 拖动手势
                PanGesture({ direction: PanDirection.All })
                  .onActionUpdate((event: GestureEvent) => {
                    if (this.isDragging) {
                      const x = event.fingerList[0].localX;
                      const y = event.fingerList[0].localY;
                      this.ballX = x - this.ballSize / 2;
                      this.ballY = y - this.ballSize / 2;
                      this.constrainBallPosition();
                    }
                  })
                  .onActionEnd(() => {
                    this.isDragging = false;
                    this.snapToEdge();
                  })
              )
              .onClick(() => {
                if (!this.isDragging) {
                  this.showMenu = true;
                  this.isHalfHidden = false;
                }
              })
          } else {
            // 菜单面板
            Column({ space: 12 }) {
              Row({ space: 8 }) {
                Button()
                  .type(ButtonType.Circle)
                  .width(40)
                  .height(40)
                  .backgroundColor($r('app.color.card_background'))
                  .onClick(() => {
                    this.showToolbar = !this.showToolbar;
                  })
                  .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.2)' })
              }

              Column({ space: 8 }) {
                // 功能按钮
                this.menuButton('键盘', () => {
                  // 键盘功能
                })
                this.menuButton('只读', () => {
                  this.viewOnly = !this.viewOnly;
                })
                this.menuButton('画质', () => {
                  this.hdQuality = !this.hdQuality;
                })
                this.menuButton('锁屏', () => {
                  // 锁屏功能
                })
                this.menuButton('Ctrl+Alt+Del', () => {
                  // 发送快捷键
                })
                this.menuButton('断开', () => {
                  this.disconnect();
                  router.back();
                }, true)
              }
              .padding(12)
              .borderRadius(16)
              .backgroundColor($r('app.color.card_background'))
              .shadow({ radius: 12, color: 'rgba(0, 0, 0, 0.2)' })

              // 关闭菜单按钮
              Button()
                .type(ButtonType.Circle)
                .width(40)
                .height(40)
                .backgroundColor($r('app.color.card_background'))
                .onClick(() => {
                  this.showMenu = false;
                  this.snapToEdge();
                })
                .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.2)' })
            }
          }
        }
        .width('100%')
        .height('100%')
      }

      // 连接提示（未连接时显示）
      if (!this.isConnected) {
        Column({ space: 12 }) {
          Text('正在连接...')
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
          if (this.errorMessage) {
            Text(this.errorMessage)
              .fontSize(14)
              .fontColor($r('app.color.status_offline'))
            Button('返回')
              .type(ButtonType.Capsule)
              .onClick(() => {
                router.back();
              })
          }
        }
        .padding(20)
        .borderRadius(16)
        .backgroundColor($r('app.color.card_background'))
        .margin({ bottom: 100 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.app_background_top'))
  }

  @Builder
  menuButton(label: string, action: () => void, isDanger: boolean = false) {
    Button(label)
      .type(ButtonType.Normal)
      .fontSize(13)
      .height(40)
      .width('100%')
      .fontColor(isDanger ? $r('app.color.status_offline') : $r('app.color.text_primary'))
      .backgroundColor($r('app.color.input_background'))
      .onClick(action)
  }

  // 限制悬浮球在屏幕范围内
  private constrainBallPosition(): void {
    const margin = 0;
    if (this.ballX < margin) {
      this.ballX = margin;
    }
    if (this.ballX > this.screenWidth - this.ballSize - margin) {
      this.ballX = this.screenWidth - this.ballSize - margin;
    }
    if (this.ballY < margin) {
      this.ballY = margin;
    }
    if (this.ballY > this.screenHeight - this.ballSize - margin) {
      this.ballY = this.screenHeight - this.ballSize - margin;
    }
  }

  // 吸附到边缘并半隐藏
  private snapToEdge(): void {
    const threshold = this.screenWidth / 2;

    if (this.ballX + this.ballSize / 2 < threshold) {
      // 靠左边缘
      this.ballX = 0;
    } else {
      // 靠右边缘
      this.ballX = this.screenWidth - this.ballSize;
    }

    this.isHalfHidden = true;

    // 上下边界
    if (this.ballY < 0) {
      this.ballY = 0;
    }
    if (this.ballY > this.screenHeight - this.ballSize) {
      this.ballY = this.screenHeight - this.ballSize;
    }
  }

  private async connect(): Promise<void> {
    if (!this.deskId) {
      this.errorMessage = '缺少设备 ID';
      return;
    }
    try {
      const native = await getNativeModule();
      if (!native) {
        throw new Error('原生模块不可用');
      }

      this.connectionStatus = '连接中...';
      this.errorMessage = '';
      const result = native.connect(this.deskId, this.password ?? '');
      if (result === 0) {
        this.isConnected = true;
        this.connectionStatus = '已连接';
        this.startVideoStream();
      } else {
        this.isConnected = false;
        this.connectionStatus = '连接失败';
        this.errorMessage = `连接失败 (错误码: ${result})`;
      }
    } catch (error) {
      this.isConnected = false;
      this.connectionStatus = '连接错误';
      this.errorMessage = `连接错误: ${error}`;
    }
  }

  private async disconnect(): Promise<void> {
    try {
      if (this.videoTimer !== -1) {
        clearInterval(this.videoTimer);
        this.videoTimer = -1;
      }
      if (this.isConnected) {
        const native = await getNativeModule();
        if (native) {
          native.disconnect();
        }
      }
      this.isConnected = false;
      this.connectionStatus = '未连接';
      this.errorMessage = '';
    } catch (error) {
      this.errorMessage = `断开连接错误: ${error}`;
    }
  }

  private startVideoStream(): void {
    if (this.videoTimer !== -1) {
      clearInterval(this.videoTimer);
    }
    const interval = Math.max(50, 1000 / this.frameRate);
    this.videoTimer = setInterval(async () => {
      await this.fetchVideoFrame();
    }, interval);
  }

  private async fetchVideoFrame(): Promise<void> {
    if (!this.isConnected) {
      return;
    }
    try {
      const native = await getNativeModule();
      if (!native) {
        return;
      }
      const frame = native.getVideoFrame();
      if (frame && frame.data) {
        await this.convertToPixelMap(frame);
      }
    } catch (error) {
      this.errorMessage = `画面获取失败: ${error}`;
    }
  }

  private async convertToPixelMap(frame: VideoFrame) {
    try {
      const imageInfo: image.ImageInfo = {
        size: { width: frame.width, height: frame.height },
        pixelFormat: image.PixelMapFormat.RGBA_8888,
        alphaType: image.AlphaType.OPAQUE,
        density: 0,
        stride: 0,
        mimeType: '',
        isHdr: false
      };
      const opts: image.InitializationOptions = {
        size: imageInfo.size,
        pixelFormat: imageInfo.pixelFormat,
        editable: true,
      };
      const next = await image.createPixelMap(frame.data, opts);
      if (this.pixelMap) {
        this.pixelMap.release();
      }
      this.pixelMap = next;
    } catch (error) {
      this.errorMessage = `解码失败: ${error.message ?? error}`;
    }
  }
}
