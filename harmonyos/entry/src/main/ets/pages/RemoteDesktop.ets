/**
 * 远程桌面会话页面
 *
 * 显示远程桌面画面，处理输入事件
 */
import router from '@ohos.router';
import { image } from '@kit.ImageKit';
import nativeModule from 'libharmonydesk.so';

/// 视频帧数据结构
interface VideoFrame {
  width: number;
  height: number;
  data: ArrayBuffer;
  timestamp: number;
}

/// 会话参数
interface SessionParams {
  deskId: string;
  password: string;
}

@Entry
@Component
struct RemoteDesktop {
  @State deskId: string = '';
  @State password: string = '';
  @State isConnected: boolean = false;
  @State errorMessage: string = '';
  @State scale: number = 1.0;
  @State offsetX: number = 0;
  @State offsetY: number = 0;

  // 视频相关
  @State videoWidth: number = 1920;
  @State videoHeight: number = 1080;
  @State frameRate: number = 30;
  @State currentFrame: VideoFrame | null = null;
  @State pixelMap: image.PixelMap | null = null;

  // 性能统计
  @State frameCount: number = 0;
  @State latency: number = 0;
  @State actualFps: number = 0;

  // 控制栏显示状态
  @State showControls: boolean = false;
  private controlsTimer: number = -1;

  // 视频循环定时器
  private videoTimer: number = -1;
  private fpsTimer: number = -1;
  private frameTimestamps: number[] = [];

  // 触摸相关
  private lastTouchX: number = 0;
  private lastTouchY: number = 0;
  private isDragging: boolean = false;

  aboutToAppear() {
    // 获取传入的参数
    const params = router.getParams() as SessionParams;
    if (params) {
      this.deskId = params.deskId;
      this.password = params.password || '';
      this.connectToDesktop();
    }
  }

  aboutToDisappear() {
    // 清理所有定时器
    if (this.controlsTimer !== -1) {
      clearTimeout(this.controlsTimer);
    }
    if (this.videoTimer !== -1) {
      clearInterval(this.videoTimer);
    }
    if (this.fpsTimer !== -1) {
      clearInterval(this.fpsTimer);
    }

    // 释放 PixelMap
    if (this.pixelMap) {
      this.pixelMap.release();
      this.pixelMap = null;
    }
  }

  /**
   * 连接到远程桌面
   */
  async connectToDesktop() {
    try {
      const result = nativeModule.connect(this.deskId, this.password);

      if (result === 0) {
        this.isConnected = true;
        this.startVideoStream();
      } else {
        this.errorMessage = `连接失败: 错误码 ${result}`;
      }
    } catch (error) {
      this.errorMessage = `连接异常: ${error.message}`;
    }
  }

  /**
   * 启动视频流接收
   */
  startVideoStream() {
    console.info('启动视频流接收');

    // 启动 FPS 计算定时器
    this.fpsTimer = setInterval(() => {
      this.updateFps();
    }, 1000);

    // 启动视频帧获取定时器
    const interval = 1000 / this.frameRate;
    this.videoTimer = setInterval(() => {
      this.fetchVideoFrame();
    }, interval);
  }

  /**
   * 从 Rust 层获取视频帧
   */
  fetchVideoFrame() {
    if (!this.isConnected) return;

    try {
      const frame = nativeModule.getVideoFrame() as VideoFrame;

      if (frame && frame.data) {
        this.currentFrame = frame;
        this.frameCount++;

        // 转换为 PixelMap
        this.convertToPixelMap(frame);

        // 记录帧时间戳用于 FPS 计算
        const now = Date.now();
        this.frameTimestamps.push(now);

        // 保持最近 60 帧的时间戳
        if (this.frameTimestamps.length > 60) {
          this.frameTimestamps.shift();
        }
      }
    } catch (error) {
      console.error(`获取视频帧失败: ${error.message}`);
    }
  }

  /**
   * 将视频帧数据转换为 PixelMap
   */
  async convertToPixelMap(frame: VideoFrame) {
    try {
      // 创建 ImageInfo
      const imageInfo: image.ImageInfo = {
        size: { width: frame.width, height: frame.height },
        pixelFormat: image.PixelMapFormat.RGBA_8888,
      };

      // 创建 PixelMap
      const opts: image.InitializationOptions = {
        size: imageInfo.size,
        pixelFormat: imageInfo.pixelFormat,
        editable: true,
      };

      const pixelMap = await image.createPixelMap(frame.data, opts);

      // 释放旧的 PixelMap
      if (this.pixelMap) {
        this.pixelMap.release();
      }

      this.pixelMap = pixelMap;
    } catch (error) {
      console.error(`转换 PixelMap 失败: ${error.message}`);
    }
  }

  /**
   * 更新 FPS 统计
   */
  updateFps() {
    if (this.frameTimestamps.length < 2) {
      this.actualFps = 0;
      return;
    }

    const now = this.frameTimestamps[this.frameTimestamps.length - 1];
    const oneSecondAgo = now - 1000;

    // 计算最近 1 秒内的帧数
    let framesInLastSecond = 0;
    for (let i = this.frameTimestamps.length - 1; i >= 0; i--) {
      if (this.frameTimestamps[i] >= oneSecondAgo) {
        framesInLastSecond++;
      } else {
        break;
      }
    }

    this.actualFps = framesInLastSecond;
  }

  /**
   * 断开连接并返回
   */
  disconnectAndGoBack() {
    nativeModule.disconnect();
    this.isConnected = false;
    router.back();
  }

  /**
   * 发送键盘事件
   */
  sendKeyEvent(keyCode: number, pressed: boolean) {
    if (!this.isConnected) return;

    try {
      nativeModule.sendKeyEvent(keyCode, pressed);
    } catch (error) {
      console.error(`发送键盘事件失败: ${error.message}`);
    }
  }

  /**
   * 发送鼠标事件
   */
  sendMouseEvent(x: number, y: number, button: number, pressed: boolean) {
    if (!this.isConnected) return;

    try {
      if (button !== undefined) {
        nativeModule.sendMouseClick(button, pressed);
      } else {
        nativeModule.sendMouseMove(x, y);
      }
    } catch (error) {
      console.error(`发送鼠标事件失败: ${error.message}`);
    }
  }

  /**
   * 处理触摸事件
   */
  handleTouch(event: TouchEvent) {
    if (!this.isConnected) return;

    const touch = event.touches[0];
    const x = Math.floor(touch.screenX / this.scale);
    const y = Math.floor(touch.screenY / this.scale);

    switch (event.type) {
      case TouchType.Down:
        this.isDragging = true;
        this.lastTouchX = x;
        this.lastTouchY = y;
        this.sendMouseEvent(x, y, 1, true);  // 左键按下
        break;

      case TouchType.Move:
        if (this.isDragging) {
          this.sendMouseEvent(x, y, undefined, undefined);  // 鼠标移动
          this.lastTouchX = x;
          this.lastTouchY = y;
        }
        break;

      case TouchType.Up:
      case TouchType.Cancel:
        this.isDragging = false;
        this.sendMouseEvent(x, y, 1, false);  // 左键释放
        break;
    }
  }

  /**
   * 切换控制栏显示
   */
  toggleControls() {
    this.showControls = !this.showControls;

    // 自动隐藏控制栏
    if (this.showControls) {
      if (this.controlsTimer !== -1) {
        clearTimeout(this.controlsTimer);
      }
      this.controlsTimer = setTimeout(() => {
        this.showControls = false;
      }, 3000);
    }
  }

  /**
   * 调整缩放
   */
  adjustScale(delta: number) {
    this.scale = Math.max(0.5, Math.min(3.0, this.scale + delta));
  }

  /**
   * 重置视图
   */
  resetView() {
    this.scale = 1.0;
    this.offsetX = 0;
    this.offsetY = 0;
  }

  build() {
    Stack() {
      // 远程桌面画面
      Column() {
        if (this.isConnected) {
          // 视频显示区域
          if (this.pixelMap) {
            // 使用 Image 显示 PixelMap
            Image(this.pixelMap)
              .width('100%')
              .height('100%')
              .objectFit(ImageFit.Contain)
              .scale({ x: this.scale, y: this.scale })
              .translate({ x: this.offsetX, y: this.offsetY })
              .border({ width: 1, color: '#333' })
              .onClick(() => {
                this.toggleControls();
              })
              .gesture(
                // 触摸手势
                TouchGesture()
                  .onAction((event: TouchEvent) => {
                    this.handleTouch(event);
                  })
              )
              .gesture(
                // 缩放手势
                PinchGesture({ fingers: 2 })
                  .onActionUpdate((event: GestureEvent) => {
                    if (event.scale) {
                      this.scale = Math.max(0.5, Math.min(3.0, event.scale));
                    }
                  })
              )
          } else {
            // 等待视频帧
            Column() {
              Text('等待视频流...')
                .fontSize(16)
                .fontColor('#666')
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
            .backgroundColor('#1a1a1a')
          }
        } else {
          // 连接中/失败
          Column() {
            Image($r('app.media.icon'))
              .width(120)
              .height(120)

            if (this.errorMessage) {
              Text(this.errorMessage)
                .fontSize(16)
                .fontColor('#F44336')
                .margin({ top: 20 })
            } else {
              Text('正在连接...')
                .fontSize(16)
                .fontColor('#666')
                .margin({ top: 20 })
            }

            Button('返回')
              .margin({ top: 20 })
              .onClick(() => {
                router.back();
              })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#1a1a1a')
        }
      }
      .width('100%')
      .height('100%')

      // 顶部状态栏
      if (this.showControls && this.isConnected) {
        Column() {
          Row() {
            // 返回按钮
            Button() {
              Image($r('sys.media.ohos_ic_public_arrow_left'))
                .width(24)
                .height(24)
                .fillColor(Color.White)
            }
            .type(ButtonType.Circle)
            .backgroundColor('#80000000')
            .width(40)
            .height(40)
            .onClick(() => {
              this.disconnectAndGoBack();
            })

            // 远程桌面 ID
            Text(this.deskId)
              .fontSize(16)
              .fontColor(Color.White)
              .margin({ left: 16 })

            Blank()

            // 性能统计
            Row() {
              Text(`${this.actualFps.toFixed(1)} FPS`)
                .fontSize(12)
                .fontColor(Color.White)

              if (this.frameCount > 0) {
                Text(`| Frames: ${this.frameCount}`)
                  .fontSize(12)
                  .fontColor(Color.White)
                  .margin({ left: 8 })
              }
            }
          }
          .width('100%')
          .padding(12)

          Blank()

          // 底部控制栏
          Row() {
            // 缩小
            Button() {
              Image($r('sys.media.ohos_ic_public_zoom_out'))
                .width(24)
                .height(24)
                .fillColor(Color.White)
            }
            .type(ButtonType.Circle)
            .backgroundColor('#80000000')
            .width(40)
            .height(40)
            .onClick(() => {
              this.adjustScale(-0.1);
            })

            // 放大
            Button() {
              Image($r('sys.media.ohos_ic_public_zoom_in'))
                .width(24)
                .height(24)
                .fillColor(Color.White)
            }
            .type(ButtonType.Circle)
            .backgroundColor('#80000000')
            .width(40)
            .height(40)
            .margin({ left: 12 })
            .onClick(() => {
              this.adjustScale(0.1);
            })

            // 重置
            Button() {
              Image($r('sys.media.ohos_ic_public_refresh'))
                .width(24)
                .height(24)
                .fillColor(Color.White)
            }
            .type(ButtonType.Circle)
            .backgroundColor('#80000000')
            .width(40)
            .height(40)
            .margin({ left: 12 })
            .onClick(() => {
              this.resetView();
            })

            Blank()

            // 断开连接
            Button('断开')
              .fontSize(14)
              .backgroundColor('#F44336')
              .onClick(() => {
                this.disconnectAndGoBack();
              })
          }
          .width('100%')
          .padding(12)
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#000')
  }
}
