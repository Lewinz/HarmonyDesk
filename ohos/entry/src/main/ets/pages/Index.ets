import router from '@ohos.router';
import type common from '@ohos.app.ability.common';
import { DeviceItem, DeviceGroup, RecentSession, RustDeskStore } from '../services/RustDeskStore';
import { getNativeModule, initHarmonyDesk } from '../native/HarmonyDeskNative';

@Entry
@Component
struct Index {
  @State activeTab: number = 0;
  @State devices: DeviceItem[] = [];
  @State sessions: RecentSession[] = [];
  @State quickId: string = '';
  @State quickPassword: string = '';
  @State relayEnabled: boolean = true;
  @State directEnabled: boolean = true;
  @State relayHost: string = 'relay.rustdesk.org';
  @State apiHost: string = 'https://rustdesk.com/api';
  @State apiKey: string = '123456';
  @State clipboardSync: boolean = true;
  @State fileTransfer: boolean = true;
  @State loadError: string = '';
  @State editingDevice: DeviceItem | null = null;
  @State showEditDialog: boolean = false;
  @State editDeviceName: string = '';
  @State expandedDeviceId: string = '';

  private store: RustDeskStore = new RustDeskStore();
  private storeReady: boolean = false;

  async aboutToAppear() {
    try {
      await initHarmonyDesk();
    } catch (error) {
      this.loadError = `初始化失败: ${error}`;
    }
    await this.loadData();
  }

  build() {
    Stack() {
      Column() {
        this.header()
        if (this.loadError) {
          Text(this.loadError)
            .fontSize(12)
            .fontColor($r('app.color.status_offline'))
            .padding({ bottom: 6 })
        }
        Tabs({ index: this.activeTab }) {
          TabContent() {
            this.devicesTab()
          }
          .tabBar('设备')
          TabContent() {
            this.settingsTab()
          }
          .tabBar('设置')
        }
        .barPosition(BarPosition.End)
        .onChange((index: number) => {
          this.activeTab = index;
        })
        .layoutWeight(1)
      }
      .padding({ left: 4, right: 4, top: 0 })
      .height('100%')
      .width('100%')

      // 编辑设备对话框
      if (this.showEditDialog) {
        Column({ space: 0 }) {
          Column()
            .width('100%')
            .height('100%')
            .backgroundColor('rgba(0, 0, 0, 0.5)')
            .onClick(() => {
              this.cancelDeviceEdit();
            })

          Column({ space: 16 }) {
            Text('编辑设备')
              .fontSize(18)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))

            Column({ space: 8 }) {
              Text('设备 ID')
                .fontSize(12)
                .fontColor($r('app.color.text_muted'))
              Text(this.editingDevice?.id ?? '')
                .fontSize(14)
                .fontColor($r('app.color.text_secondary'))
                .padding(12)
                .borderRadius(10)
                .backgroundColor($r('app.color.input_background'))
                .width('100%')
            }

            this.inputField('设备名称', this.editDeviceName, (value: string) => {
              this.editDeviceName = value;
            })

            Row({ space: 8 }) {
              Button('删除设备')
                .type(ButtonType.Capsule)
                .height(40)
                .borderRadius(12)
                .fontColor($r('app.color.status_offline'))
                .backgroundColor('#F5F5F5')
                .onClick(() => {
                  if (this.editingDevice) {
                    this.deleteDevice(this.editingDevice);
                  }
                  this.cancelDeviceEdit();
                })
              Button('取消')
                .type(ButtonType.Capsule)
                .height(40)
                .borderRadius(12)
                .fontColor($r('app.color.text_primary'))
                .backgroundColor('#F5F5F5')
                .onClick(() => {
                  this.cancelDeviceEdit();
                })
              Button('保存')
                .type(ButtonType.Capsule)
                .height(40)
                .borderRadius(12)
                .fontColor($r('app.color.text_on_accent'))
                .backgroundColor($r('app.color.accent'))
                .onClick(() => {
                  this.saveDeviceEdit();
                })
            }
          }
          .padding(20)
          .borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
          .margin({ left: 40, right: 40 })
        }
        .width('100%')
        .height('100%')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .backgroundColor($r('app.color.app_background_top'))
    .height('100%')
    .width('100%')
  }

  @Builder
  header() {
    Row() {
      Column({ space: 2 }) {
        Text('HarmonyDesk')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('远程桌面控制')
          .fontSize(13)
          .fontColor($r('app.color.text_secondary'))
      }
      .layoutWeight(1)
    }
    .alignItems(VerticalAlign.Center)
    .padding({ bottom: 12 })
  }

  @Builder
  devicesTab() {
    Scroll() {
      Column({ space: 12 }) {
        // 连接设备
        Column({ space: 10 }) {
          Text('连接设备')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          this.inputField('设备 ID', this.quickId, (value: string) => {
            this.quickId = value;
          })
          this.inputField('密码（可选）', this.quickPassword, (value: string) => {
            this.quickPassword = value;
          }, InputType.Password)
          Button('连接')
            .width('100%')
            .type(ButtonType.Capsule)
            .height(44)
            .borderRadius(22)
            .fontColor($r('app.color.text_on_accent'))
            .backgroundColor($r('app.color.accent'))
            .onClick(() => {
              this.openSession();
            })
        }
        .padding(14)
        .borderRadius(16)
        .backgroundColor($r('app.color.card_background'))

        // 设备列表
        Row() {
          Text('设备列表')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
            .layoutWeight(1)
        }
        .alignItems(VerticalAlign.Center)

        if (this.devices.length === 0) {
          Column({ space: 8 }) {
            Text('暂无设备')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
            Text('可以手动输入 ID 连接，连接后自动保存到列表')
              .fontSize(12)
              .fontColor($r('app.color.text_muted'))
              .textAlign(TextAlign.Center)
          }
          .padding(40)
          .borderRadius(16)
          .backgroundColor($r('app.color.card_background'))
        } else {
          Column({ space: 10 }) {
            ForEach(this.devices, (device: DeviceItem) => {
              Column({ space: 12 }) {
                Row({ space: 12 }) {
                  Column({ space: 4 }) {
                    Text(device.name)
                      .fontSize(16)
                      .fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary'))
                    Text(device.id)
                      .fontSize(12)
                      .fontColor($r('app.color.text_secondary'))
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)
                  Text(this.getStatusText(device.status))
                    .fontSize(11)
                    .fontColor(this.statusColor(device.status))
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .borderRadius(8)
                    .backgroundColor($r('app.color.chip_background'))
                }
                Row({ space: 8 }) {
                  Button('连接')
                    .type(ButtonType.Capsule)
                    .fontSize(13)
                    .height(36)
                    .borderRadius(18)
                    .fontColor($r('app.color.text_on_accent'))
                    .backgroundColor($r('app.color.accent'))
                    .onClick(() => {
                      this.openDeviceSession(device);
                    })
                  Button('设置')
                    .type(ButtonType.Capsule)
                    .fontSize(13)
                    .height(36)
                    .borderRadius(18)
                    .fontColor($r('app.color.text_primary'))
                    .backgroundColor('#F5F5F5')
                    .onClick(() => {
                      if (this.expandedDeviceId === device.id) {
                        this.expandedDeviceId = '';
                      } else {
                        this.expandedDeviceId = device.id;
                      }
                    })
                }
                if (this.expandedDeviceId === device.id) {
                  Column({ space: 8 }) {
                    this.deviceActionBtn('文件传输', () => {})
                    this.deviceActionBtn('端口转发', () => {})
                    this.deviceActionBtn('重命名', () => {
                      this.editingDevice = device;
                      this.editDeviceName = device.name;
                      this.showEditDialog = true;
                    })
                    this.deviceActionBtn('删除设备', () => {
                      this.deleteDevice(device);
                    }, true)
                  }
                  .padding({ top: 8 })
                  .width('100%')
                }
              }
              .padding(14)
              .borderRadius(16)
              .backgroundColor($r('app.color.card_background'))
            }, (device: DeviceItem) => device.id)
          }
        }
      }
      .width('100%')
      .padding({ bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  settingsTab() {
    Scroll() {
      Column({ space: 12 }) {
        // 网络设置
        Column({ space: 10 }) {
          Text('网络设置')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          this.toggleRow('使用中继服务器', this.relayEnabled, (value: boolean) => {
            this.relayEnabled = value;
            this.saveRelayConfig();
          })
          this.toggleRow('允许直连', this.directEnabled, (value: boolean) => {
            this.directEnabled = value;
            this.saveRelayConfig();
          })
        }
        .padding(14)
        .borderRadius(16)
        .backgroundColor($r('app.color.card_background'))

        // 功能设置
        Column({ space: 10 }) {
          Text('功能设置')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          this.toggleRow('剪贴板同步', this.clipboardSync, (value: boolean) => {
            this.clipboardSync = value;
            this.saveSettings();
          })
          this.toggleRow('文件传输', this.fileTransfer, (value: boolean) => {
            this.fileTransfer = value;
            this.saveSettings();
          })
        }
        .padding(14)
        .borderRadius(16)
        .backgroundColor($r('app.color.card_background'))

        // 服务器设置
        Column({ space: 10 }) {
          Text('服务器设置')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          this.inputField('中继服务器', this.relayHost, (value: string) => {
            this.relayHost = value;
            this.saveRelayConfig();
          })
          this.inputField('API 服务器', this.apiHost, (value: string) => {
            this.apiHost = value;
            this.saveRelayConfig();
          })
          this.inputField('密钥', this.apiKey, (value: string) => {
            this.apiKey = value;
            this.saveRelayConfig();
          }, InputType.Password)
          Button('保存配置')
            .width('100%')
            .type(ButtonType.Capsule)
            .height(44)
            .borderRadius(22)
            .fontColor($r('app.color.text_on_accent'))
            .backgroundColor($r('app.color.accent'))
            .onClick(() => {
              this.saveRelayConfig();
            })
        }
        .padding(14)
        .borderRadius(16)
        .backgroundColor($r('app.color.card_background'))
      }
      .width('100%')
      .padding({ bottom: 16 })
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  inputField(label: string, value: string, onChange: (value: string) => void, type: InputType = InputType.Normal) {
    Column({ space: 6 }) {
      Text(label)
        .fontSize(12)
        .fontColor($r('app.color.text_muted'))
      TextInput({ text: value, placeholder: `请输入${label}` })
        .type(type)
        .onChange(onChange)
        .height(44)
        .padding({ left: 12, right: 12 })
        .borderRadius(12)
        .backgroundColor('#FFFFFF')
        .border({ width: 1, color: '#E0E0E0' })
    }
  }

  @Builder
  deviceActionBtn(label: string, action: () => void, isDanger: boolean = false) {
    Button(label)
      .type(ButtonType.Normal)
      .fontSize(13)
      .height(40)
      .width('100%')
      .borderRadius(12)
      .fontColor(isDanger ? $r('app.color.status_offline') : $r('app.color.text_primary'))
      .backgroundColor('#F5F5F5')
      .onClick(action)
  }

  @Builder
  toggleRow(label: string, value: boolean, onChange: (value: boolean) => void) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor($r('app.color.text_primary'))
        .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: value })
        .onChange(onChange)
    }
    .alignItems(VerticalAlign.Center)
  }

  private async loadData(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      await this.store.init(context);
      const devices = await this.store.loadDevices();
      const relay = await this.store.loadRelay();
      this.devices = devices;
      this.relayEnabled = relay.relayEnabled;
      this.directEnabled = relay.directEnabled;
      this.relayHost = relay.relayHost;
      this.apiHost = relay.apiHost;
      this.apiKey = relay.key;
      this.storeReady = true;
      this.applyNativeConfig();
      this.loadError = '';
    } catch (error) {
      this.loadError = `加载数据失败: ${error.message ?? error}`;
    }
  }

  private async saveSettings(): Promise<void> {
    if (!this.storeReady) {
      return;
    }
    await this.store.savePolicy({
      autoAccept: false,
      clipboardSync: this.clipboardSync,
      fileTransfer: this.fileTransfer,
      viewOnlyDefault: false
    });
  }

  private async saveRelayConfig(): Promise<void> {
    if (!this.storeReady) {
      return;
    }
    await this.store.saveRelay({
      relayEnabled: this.relayEnabled,
      directEnabled: this.directEnabled,
      selfHostEnabled: false,
      relayHost: this.relayHost,
      apiHost: this.apiHost,
      key: this.apiKey
    });
    await this.applyNativeConfig();
  }

  private async applyNativeConfig(): Promise<void> {
    try {
      const native = await getNativeModule();
      if (!native) {
        return;
      }
      const idServer = this.apiHost.trim();
      const relayServer = this.relayEnabled ? this.relayHost.trim() : '';
      const forceRelay = !this.directEnabled;
      const key = this.apiKey.trim();
      native.setServerConfig(idServer, relayServer, forceRelay, key);
    } catch (error) {
      console.error('[Index] 配置应用失败:', error);
    }
  }

  private statusColor(status: string): ResourceColor {
    if (status === 'Online') {
      return $r('app.color.status_online');
    }
    if (status === 'Sleeping') {
      return $r('app.color.status_idle');
    }
    return $r('app.color.status_offline');
  }

  private getStatusText(status: string): string {
    switch (status) {
      case 'Online': return '在线';
      case 'Sleeping': return '休眠';
      case 'Offline': return '离线';
      default: return status;
    }
  }

  private async saveDeviceToList(id: string, name: string): Promise<void> {
    const existing = this.devices.find(d => d.id === id);
    if (existing) {
      return;
    }
    const newDevice: DeviceItem = {
      id,
      name: name || id,
      status: 'Unknown',
      lastSeen: '刚刚',
      tags: []
    };
    this.devices.unshift(newDevice);
    if (this.storeReady) {
      await this.store.saveDevices(this.devices);
    }
  }

  private openSession(): void {
    console.info('[Index] openSession called, quickId:', this.quickId);
    
    if (!this.quickId || this.quickId.trim().length === 0) {
      this.loadError = '请输入设备 ID';
      console.warn('[Index] quickId is empty');
      return;
    }
    
    // 保存到列表
    this.saveDeviceToList(this.quickId, this.quickId);

    interface SessionParams {
      id: string;
      name: string;
      status: string;
      password: string;
      viewOnly: string;
    }
    
    const params: SessionParams = {
      id: this.quickId.trim(),
      name: this.quickId.trim(),
      status: 'Unknown',
      password: this.quickPassword || '',
      viewOnly: '0'
    };
    
    console.info('[Index] Pushing to Session with params:', JSON.stringify(params));
    
    router.pushUrl({
      url: 'pages/Session',
      params: params
    }).catch((error: Error) => {
      console.error('[Index] pushUrl failed:', error);
      this.loadError = `跳转失败: ${error.message || String(error)}`;
    });
  }

  private openDeviceSession(device: DeviceItem): void {
    interface SessionParams {
      id: string;
      name: string;
      status: string;
      password: string;
      viewOnly: string;
    }
    
    const params: SessionParams = {
      id: device.id,
      name: device.name,
      status: device.status,
      password: '',
      viewOnly: '0'
    };
    
    router.pushUrl({
      url: 'pages/Session',
      params: params
    }).catch((error: Error) => {
      console.error('[Index] pushUrl failed:', error);
      this.loadError = `跳转失败: ${error.message || String(error)}`;
    });
  }

  private async saveDeviceEdit(): Promise<void> {
    if (!this.editingDevice) {
      return;
    }
    const device = this.devices.find(d => d.id === this.editingDevice!.id);
    if (device) {
      device.name = this.editDeviceName.trim() || device.id;
      if (this.storeReady) {
        await this.store.saveDevices(this.devices);
      }
    }
    this.showEditDialog = false;
    this.editingDevice = null;
    this.editDeviceName = '';
  }

  private cancelDeviceEdit(): void {
    this.showEditDialog = false;
    this.editingDevice = null;
    this.editDeviceName = '';
  }

  private async deleteDevice(device: DeviceItem): Promise<void> {
    this.devices = this.devices.filter(d => d.id !== device.id);
    if (this.storeReady) {
      await this.store.saveDevices(this.devices);
    }
  }
}
