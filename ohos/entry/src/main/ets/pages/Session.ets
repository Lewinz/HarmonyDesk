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
  @State connectionStep: string = '';
  @State connectionLogs: string[] = [];
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
    console.info('[Session] aboutToAppear called');
    
    try {
      await initHarmonyDesk();
      console.info('[Session] initHarmonyDesk completed');
    } catch (error) {
      console.error('[Session] initHarmonyDesk failed:', error);
    }

    // 获取路由参数 - 尝试多种方式
    let params: Record<string, Object> | null = null;
    
    try {
      params = router.getParams() as Record<string, Object> | null;
      console.info('[Session] router.getParams() result:', params ? JSON.stringify(params) : 'null');
    } catch (error) {
      console.error('[Session] router.getParams() error:', error);
    }
    
    // 如果 getParams 返回 null，尝试延迟获取
    if (!params) {
      console.warn('[Session] Params is null, waiting 100ms and retry...');
      await new Promise<void>((resolve) => {
        setTimeout(() => resolve(), 100);
      });
      try {
        params = router.getParams() as Record<string, Object> | null;
        console.info('[Session] Retry getParams() result:', params ? JSON.stringify(params) : 'null');
      } catch (error) {
        console.error('[Session] Retry getParams() error:', error);
      }
    }
    
    if (params) {
      // 安全地获取参数值
      this.deskId = String(params.id || params['id'] || '').trim();
      this.password = String(params.password || params['password'] || '').trim();
      this.deviceName = String(params.name || params['name'] || '').trim();
      this.viewOnly = String(params.viewOnly || params['viewOnly'] || '0') === '1' || params.viewOnly === true;
      
      console.info('[Session] Parsed params - deskId:', this.deskId, 'password:', this.password ? '***' : '(empty)', 'name:', this.deviceName);
    } else {
      console.warn('[Session] No params received from router');
      this.errorMessage = '缺少设备 ID 参数';
      this.connectionStatus = '参数错误';
    }

    // 初始化悬浮球位置（右下角，半隐藏）
    const hideOffset = this.ballSize * 0.4;
    this.ballX = this.screenWidth - this.ballSize + hideOffset;
    this.ballY = this.screenHeight - this.ballSize - 100;
    this.isHalfHidden = true;

    // 如果有设备 ID，开始连接
    if (this.deskId && this.deskId.trim().length > 0) {
      console.info('[Session] Starting connection to:', this.deskId);
      // 延迟一下确保UI更新
      await new Promise<void>((resolve) => {
        setTimeout(() => resolve(), 200);
      });
      this.connect();
    } else {
      console.warn('[Session] No deskId provided, cannot connect. Current deskId:', this.deskId);
      this.errorMessage = '设备 ID 为空，无法连接';
      this.connectionStatus = '参数错误';
    }
    
    console.info('[Session] aboutToAppear completed');
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
          Scroll() {
            Column({ space: 16 }) {
              // 连接状态图标
              if (this.connectionStatus === '正在连接...') {
                Column({ space: 8 }) {
                  Text('⏳')
                    .fontSize(48)
                  Text(this.connectionStep || '正在连接...')
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                }
              } else if (this.connectionStatus === '连接失败' || this.connectionStatus === '连接错误' || this.connectionStatus === '参数错误') {
                Column({ space: 8 }) {
                  Text('❌')
                    .fontSize(48)
                  Text(this.connectionStatus)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.status_offline'))
                }
              } else {
                Column({ space: 8 }) {
                  Text('🖥️')
                    .fontSize(48)
                  Text(this.connectionStatus === '未连接' ? '准备连接' : this.connectionStatus)
                    .fontSize(16)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))
                }
              }

              // 设备信息
              Column({ space: 8 }) {
                Text(`设备 ID: ${this.deskId || '(空)'}`)
                  .fontSize(14)
                  .fontColor(this.deskId ? $r('app.color.text_secondary') : $r('app.color.status_offline'))
                if (this.deviceName) {
                  Text(`设备名称: ${this.deviceName}`)
                    .fontSize(14)
                    .fontColor($r('app.color.text_secondary'))
                }
                // 调试信息
                Text(`连接状态: ${this.connectionStatus}`)
                  .fontSize(12)
                  .fontColor($r('app.color.text_muted'))
                  .margin({ top: 4 })
              }
              .padding(16)
              .borderRadius(12)
              .backgroundColor($r('app.color.card_background'))
              .width('100%')

              // 连接日志
              if (this.connectionLogs.length > 0) {
                Column({ space: 8 }) {
                  Text('连接日志')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary'))

                  Column({ space: 4 }) {
                    ForEach(this.connectionLogs, (log: string, index: number) => {
                      Text(log)
                        .fontSize(12)
                        .fontColor(log.includes('✓') ? $r('app.color.status_online') :
                                   log.includes('✗') ? $r('app.color.status_offline') :
                                   $r('app.color.text_secondary'))
                        .width('100%')
                    }, (log: string, index: number) => `${index}_${log}`)
                  }
                  .width('100%')
                  .padding(12)
                  .borderRadius(8)
                  .backgroundColor('#F5F5F5')
                }
                .padding(16)
                .borderRadius(12)
                .backgroundColor($r('app.color.card_background'))
                .width('100%')
              }

              // 错误信息
              if (this.errorMessage) {
                Column({ space: 8 }) {
                  Text('错误信息')
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.status_offline'))
                  Text(this.errorMessage)
                    .fontSize(13)
                    .fontColor($r('app.color.text_secondary'))
                }
                .padding(16)
                .borderRadius(12)
                .backgroundColor('#FFF3F3')
                .width('100%')
              }

              // 重试按钮
              if (this.connectionStatus === '连接失败' || this.connectionStatus === '连接错误') {
                Button('重新连接')
                  .width('100%')
                  .type(ButtonType.Capsule)
                  .height(44)
                  .borderRadius(22)
                  .fontColor($r('app.color.text_on_accent'))
                  .backgroundColor($r('app.color.accent'))
                  .onClick(() => {
                    this.connect();
                  })
              }

              // 返回按钮
              Button('返回')
                .width('100%')
                .type(ButtonType.Capsule)
                .height(44)
                .borderRadius(22)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor($r('app.color.card_background'))
                .onClick(() => {
                  router.back();
                })
            }
            .padding({ left: 16, right: 16, top: 20, bottom: 20 })
          }
          .width('100%')
          .height('100%')
          .backgroundColor($r('app.color.app_background_top'))
        }
      }
      .width('100%')
      .height('100%')
      .onAreaChange((area: Area) => {
        this.screenWidth = Number(area.width) as number;
        this.screenHeight = Number(area.height) as number;
        // 更新悬浮球位置到右下角（半隐藏）
        if (!this.isDragging && !this.showMenu && this.isHalfHidden) {
          const hideOffset = this.ballSize * 0.4;
          this.ballX = this.screenWidth - this.ballSize + hideOffset;
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
            // 悬浮球按钮 - 完美的圆形设计
            Column() {
              // 悬浮球图标
              Text('⚙️')
                .fontSize(24)
                .fontColor(Color.White)
            }
            .width(this.ballSize)
            .height(this.ballSize)
            .borderRadius(this.ballSize / 2)
            .backgroundColor($r('app.color.accent'))
            .position({ x: this.ballX, y: this.ballY })
            .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.4)', offsetY: 4 })
            .animation({ duration: 200, curve: Curve.EaseOut })
            .gesture(
              // 组合手势：可以直接拖拽，短按点击
              GestureGroup(GestureMode.Exclusive,
                // 拖动手势 - 直接拖拽，不需要长按
                PanGesture({ direction: PanDirection.All })
                  .onActionStart((event: GestureEvent) => {
                    // 记录起始偏移
                    this.ballOffsetX = event.fingerList[0].localX - this.ballX;
                    this.ballOffsetY = event.fingerList[0].localY - this.ballY;
                    this.isDragging = true;
                    this.isHalfHidden = false;
                  })
                  .onActionUpdate((event: GestureEvent) => {
                    const x = event.fingerList[0].localX;
                    const y = event.fingerList[0].localY;
                    this.ballX = x - this.ballOffsetX;
                    this.ballY = y - this.ballOffsetY;
                    this.constrainBallPosition();
                  })
                  .onActionEnd(() => {
                    this.isDragging = false;
                    this.snapToEdge();
                  }),
                // 点击手势 - 快速点击打开菜单
                TapGesture()
                  .onAction(() => {
                    this.showMenu = true;
                    this.isHalfHidden = false;
                  })
              )
            )
            // 拖拽时的视觉反馈
            .scale({ x: this.isDragging ? 1.15 : 1, y: this.isDragging ? 1.15 : 1 })
            .opacity(this.isHalfHidden ? 0.6 : 1)
          } else {
            // 菜单面板 - 显示在悬浮球附近
            Column({ space: 12 }) {
              // 功能按钮列表
              Column({ space: 8 }) {
                this.menuButton('⌨️ 键盘', () => {
                  // 键盘功能
                })
                this.menuButton(this.viewOnly ? '👁️ 只读' : '✏️ 控制', () => {
                  this.viewOnly = !this.viewOnly;
                })
                this.menuButton(this.hdQuality ? '🎨 高清' : '🎨 标清', () => {
                  this.hdQuality = !this.hdQuality;
                })
                this.menuButton('🔒 锁屏', () => {
                  // 锁屏功能
                })
                this.menuButton('⌨️ Ctrl+Alt+Del', () => {
                  // 发送快捷键
                })
                this.menuButton('🔌 断开连接', () => {
                  this.disconnect();
                  router.back();
                }, true)
              }
              .padding(12)
              .borderRadius(16)
              .backgroundColor($r('app.color.card_background'))
              .shadow({ radius: 16, color: 'rgba(0, 0, 0, 0.25)', offsetY: 4 })
              .width(140)

              // 关闭菜单按钮
              Column() {
                Text('✕')
                  .fontSize(20)
                  .fontColor($r('app.color.text_secondary'))
                  .fontWeight(FontWeight.Medium)
              }
              .width(44)
              .height(44)
              .borderRadius(22)
              .backgroundColor($r('app.color.card_background'))
              .justifyContent(FlexAlign.Center)
              .shadow({ radius: 8, color: 'rgba(0, 0, 0, 0.15)' })
              .onClick(() => {
                this.showMenu = false;
                this.snapToEdge();
              })
            }
            .position({
              x: this.ballX > this.screenWidth / 2 ? this.ballX - 150 : this.ballX + this.ballSize + 10,
              y: Math.max(0, Math.min(this.ballY, this.screenHeight - 400))
            })
            .animation({ duration: 250, curve: Curve.FastOutSlowIn })
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
    Column() {
      Text(label)
        .fontSize(14)
        .fontColor(isDanger ? '#E53935' : $r('app.color.text_primary'))
        .fontWeight(FontWeight.Medium)
    }
    .width('100%')
    .height(44)
    .borderRadius(10)
    .backgroundColor(isDanger ? '#FFEBEE' : $r('app.color.input_background'))
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
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
    const hideOffset = this.ballSize * 0.4; // 半隐藏偏移量

    // 判断应该吸附到哪边
    if (this.ballX + this.ballSize / 2 < threshold) {
      // 靠左边缘
      this.ballX = -hideOffset;
    } else {
      // 靠右边缘
      this.ballX = this.screenWidth - this.ballSize + hideOffset;
    }

    this.isHalfHidden = true;

    // 上下边界 - 不做半隐藏
    if (this.ballY < 0) {
      this.ballY = 0;
    }
    if (this.ballY > this.screenHeight - this.ballSize) {
      this.ballY = this.screenHeight - this.ballSize;
    }
  }

  private addLog(message: string): void {
    const timestamp = new Date().toLocaleTimeString('zh-CN', { hour12: false });
    this.connectionLogs.push(`[${timestamp}] ${message}`);
    console.log(`[Session] ${message}`);
  }

  private async connect(): Promise<void> {
    // 先检查设备 ID
    if (!this.deskId || this.deskId.trim().length === 0) {
      this.errorMessage = '缺少设备 ID';
      this.connectionStatus = '参数错误';
      console.error('[Session] Cannot connect: deskId is empty');
      return;
    }

    // 重置状态
    this.connectionLogs = [];
    this.connectionStep = '';
    this.errorMessage = '';

    try {
      this.addLog(`开始连接到: ${this.deskId}`);
      // 立即更新状态，确保UI能看到
      this.connectionStatus = '正在连接...';
      this.connectionStep = '初始化原生模块';
      
      // 强制触发UI更新
      await new Promise<void>((resolve) => {
        setTimeout(() => resolve(), 10);
      });

      // 确保UI状态更新先被处理
      await new Promise<void>((resolve) => {
        setTimeout(() => resolve(), 50);
      });

      const native = await getNativeModule();
      if (!native) {
        throw new Error('原生模块不可用');
      }

      this.addLog('原生模块已就绪');
      this.connectionStep = '正在连接到远程桌面';
      
      // 再次确保UI更新
      await new Promise<void>((resolve) => {
        setTimeout(() => resolve(), 50);
      });

      // 调用原生连接方法（在后台执行，避免阻塞UI）
      this.addLog('调用原生连接接口...');
      
      // 使用 Promise 包装同步调用，避免阻塞UI线程
      const result = await new Promise<number>((resolve) => {
        // 使用 setTimeout 将同步调用移到下一个事件循环，让UI有时间更新
        setTimeout(() => {
          try {
            const connectResult = native.connect(this.deskId, this.password ?? '');
            resolve(connectResult);
          } catch (error) {
            console.error('[Session] Connect error:', error);
            resolve(-1);
          }
        }, 100);
      });

      this.addLog(`连接返回结果: ${result}`);

      if (result === 0) {
        this.isConnected = true;
        this.connectionStatus = '已连接';
        this.connectionStep = '连接成功';
        this.addLog('✓ 连接成功');
        this.addLog('启动视频流...');
        this.startVideoStream();
      } else {
        this.isConnected = false;
        this.connectionStatus = '连接失败';
        this.connectionStep = '连接失败';
        this.errorMessage = `连接失败 (错误码: ${result})`;
        this.addLog(`✗ 连接失败，错误码: ${result}`);
        this.addLog('请检查：');
        this.addLog('1. 设备 ID 是否正确');
        this.addLog('2. 远程设备是否在线');
        this.addLog('3. 网络连接是否正常');
        this.addLog('4. 密码是否正确（如果需要）');
      }
    } catch (error) {
      this.isConnected = false;
      this.connectionStatus = '连接错误';
      this.connectionStep = '发生错误';
      const errorMsg = error instanceof Error ? error.message : String(error);
      this.errorMessage = `连接错误: ${errorMsg}`;
      this.addLog(`✗ 连接异常: ${errorMsg}`);
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
