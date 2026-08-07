import { common } from '@kit.AbilityKit';
import {
  AccountStatus,
  AuditLog,
  IdentityRole,
  LoginMethod,
  RegisterRequest,
  UserAccount,
  VerificationPurpose
} from '../models/AccountModels';
import { AppNotification, ClaimRequest, ClaimStatus, ContentSnapshot, Post, PostComment, PostDraft, PostKind, PostStatus } from '../models/AppModels';
import { roleLabel } from '../services/AccountRules';
import { ContentRepository } from '../services/ContentRepository';
import { ImagePickerService } from '../services/ImagePickerService';
import { ContentApiRepository } from '../services/api/ContentApiRepository';
import { FileApiRepository } from '../services/api/FileApiRepository';
import { AppStore } from '../stores/AppStore';
import { AuthStore } from '../stores/AuthStore';

const COLOR_BACKGROUND: string = '#F5F5F7';
const COLOR_SURFACE: string = '#FFFFFF';
const COLOR_PRIMARY: string = '#007AFF';
const COLOR_TEXT: string = '#1D1D1F';
const COLOR_SECONDARY: string = '#86868B';
const COLOR_BORDER: string = '#E5E5EA';
const COLOR_SUCCESS: string = '#34C759';
const COLOR_WARNING: string = '#FF9500';
const COLOR_DANGER: string = '#FF3B30';

function placeholderAccount(): UserAccount {
  return { id: '', phone: '', email: '', passwordSalt: '', passwordDigest: '', nickname: '', realName: '',
    identityNumber: '', identityRole: IdentityRole.STUDENT, isAdmin: false, department: '', grade: '',
    campus: '主校区', contact: '', creditScore: 0, status: AccountStatus.NORMAL, createdAt: 0,
    activeToken: '', frozenReason: '', violations: [], auditLogs: [] };
}

function placeholderPost(): Post {
  return { id: '', ownerId: '', ownerName: '', kind: PostKind.LOST_NOTICE, status: PostStatus.ACTIVE,
    title: '', description: '', category: '', location: '', occurredAt: '', imageKey: '', likeCount: 0,
    commentCount: 0, isLiked: false, isFavorite: false, createdAt: 0 };
}

function postStatusLabel(status: PostStatus): string {
  if (status === PostStatus.ACTIVE) {
    return '待认领';
  }
  if (status === PostStatus.CLAIMING) {
    return '认领中';
  }
  if (status === PostStatus.RESOLVED) {
    return '已归还';
  }
  return '已关闭';
}

@Entry
@Component
struct Index {
  @State ready: boolean = false;
  @State revision: number = 0;
  @State route: string = 'tabs';
  @State selectedPostId: string = '';
  @State startupError: string = '';
  @State operationError: string = '';
  @State authStore: AuthStore = new AuthStore();
  @State appStore: AppStore = AppStore.createDemo('student-1');
  private contentRepository: ContentRepository = new ContentRepository();
  private contentApiRepository: ContentApiRepository = new ContentApiRepository();
  private contentSaveQueue: Promise<void> = Promise.resolve();
  private pathStack: NavPathStack = new NavPathStack();
  private readNotificationIds: string[] = [];

  aboutToAppear(): void {
    this.initializeApp();
  }

  private async initializeApp(): Promise<void> {
    this.ready = false;
    this.startupError = '';
    try {
      const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
      await this.authStore.initialize(context);
      await this.contentRepository.initialize(context);
      await this.loadCurrentAccountContent();
    } catch (error) {
      this.startupError = '应用数据初始化失败，请检查存储空间后重试';
    }
    this.ready = true;
    this.revision += 1;
  }

  private async loadCurrentAccountContent(): Promise<void> {
    const account: UserAccount | undefined = this.authStore.currentAccount;
    if (account === undefined) {
      this.appStore = AppStore.createDemo('student-1');
      return;
    }
    if (this.authStore.session?.deviceId === 'remote-api' && this.authStore.session.token.length > 0) {
      const posts = await this.contentApiRepository.listPosts(this.authStore.session.token);
      const notifications = await this.contentApiRepository.listNotifications(this.authStore.session.token);
      notifications.forEach((item: AppNotification) => {
        if (this.readNotificationIds.includes(item.id)) item.read = true;
      });
      const store = new AppStore(account.id, posts);
      store.notifications = notifications;
      this.appStore = store;
      return;
    }
    try {
      const posts = await this.contentApiRepository.listPublicPosts();
      this.appStore = new AppStore(account.id, posts);
      return;
    } catch (error) {
      // Keep the local demo fallback available when the API is not running.
    }
    const snapshot: ContentSnapshot | undefined = this.contentRepository.load(account.id);
    if (snapshot !== undefined) {
      this.appStore = AppStore.fromSnapshot(account.id, snapshot);
      return;
    }
    this.appStore = AppStore.createDemo(account.id, account.nickname);
    await this.contentRepository.save(account.id, this.appStore.toSnapshot());
  }

  private async refreshAfterAuth(): Promise<void> {
    try {
      await this.contentSaveQueue;
      this.readNotificationIds = [];
      await this.loadCurrentAccountContent();
      this.operationError = '';
    } catch (error) {
      this.operationError = '账号内容加载失败，请稍后重试';
    }
    this.route = 'tabs';
    this.revision += 1;
  }

  private refreshContent(): void {
    this.readNotificationIds = this.appStore.notifications
      .filter((item: AppNotification) => item.read).map((item: AppNotification) => item.id);
    if (this.authStore.session?.deviceId === 'remote-api') {
      this.loadCurrentAccountContent().then(() => {
        this.operationError = '';
        this.revision += 1;
      }).catch(() => {
        this.operationError = '内容同步失败，请稍后重试';
        this.revision += 1;
      });
      return;
    }
    this.persistContent();
  }

  private async markNotificationsRead(): Promise<void> {
    if (!this.appStore.markAllNotificationsRead()) return;
    const session = this.authStore.session;
    if (session?.deviceId === 'remote-api' && session.token.length > 0) {
      const notificationIds: string[] = this.appStore.notifications.map((item: AppNotification) => item.id);
      try {
        await this.contentApiRepository.markNotificationsRead(session.token, notificationIds);
      } catch (error) {
        // Keep the in-memory read state as a fallback until the next successful sync.
      }
    }
    this.refreshContent();
  }

  private async saveSnapshot(accountId: string, snapshot: ContentSnapshot): Promise<void> {
    try {
      await this.contentRepository.save(accountId, snapshot);
      this.operationError = '';
    } catch (error) {
      this.operationError = '内容保存失败，本次修改可能无法在重启后保留';
    }
    this.revision += 1;
  }

  private persistContent(): void {
    const account: UserAccount | undefined = this.authStore.currentAccount;
    if (account === undefined) {
      return;
    }
    const snapshot: ContentSnapshot = this.appStore.toSnapshot();
    this.revision += 1;
    this.contentSaveQueue = this.contentSaveQueue.then(() => this.saveSnapshot(account.id, snapshot));
  }

  build() {
    Navigation(this.pathStack) {
      Stack({ alignContent: Alignment.Top }) {
        if (!this.ready) {
          LoadingPage()
        } else if (this.startupError.length > 0) {
          StartupErrorPage({ message: this.startupError, onRetry: () => this.initializeApp() })
        } else if (this.authStore.currentAccount === undefined) {
          AuthPage({ store: this.authStore, revision: this.revision,
            onChanged: () => this.refreshAfterAuth() })
        } else if (this.authStore.currentAccount.isAdmin) {
          AdminDashboard({ store: this.authStore, contentStore: this.appStore, account: this.authStore.currentAccount,
            revision: this.revision, accessToken: this.authStore.session?.token ?? '', apiRepository: this.contentApiRepository,
            onChanged: () => this.revision += 1,
            onLogout: () => {
              this.authStore.logout().then(() => this.refreshAfterAuth()).catch(() => {
                this.operationError = '退出状态保存失败，请稍后重试';
                this.refreshAfterAuth();
              });
            } })
        } else if (this.route === 'detail') {
          PostDetailPage({ store: this.appStore, account: this.authStore.currentAccount,
            postId: this.selectedPostId, revision: this.revision,
            accessToken: this.authStore.session?.token ?? '', apiRepository: this.contentApiRepository,
            onBack: () => { this.route = 'tabs'; }, onChanged: () => this.refreshContent() })
        } else if (this.route === 'profile-edit') {
          EditProfilePage({ store: this.authStore, account: this.authStore.currentAccount,
            revision: this.revision, onBack: () => { this.route = 'tabs'; },
            onChanged: () => this.revision += 1 })
        } else if (this.route === 'security') {
          SecurityPage({ authStore: this.authStore, appStore: this.appStore,
            account: this.authStore.currentAccount, revision: this.revision,
            onBack: () => { this.route = 'tabs'; }, onChanged: () => this.refreshAfterAuth() })
        } else {
          UserTabs({ authStore: this.authStore, appStore: this.appStore,
            account: this.authStore.currentAccount, revision: this.revision,
            accessToken: this.authStore.session?.token ?? '', apiRepository: this.contentApiRepository,
            onChanged: () => this.refreshContent(),
            onOpenPost: (postId: string) => { this.selectedPostId = postId; this.route = 'detail'; },
            onEditProfile: () => { this.route = 'profile-edit'; },
            onSecurity: () => { this.route = 'security'; },
             unreadCount: this.appStore.unreadNotificationCount(),
             onMessagesOpened: () => {
               this.markNotificationsRead();
             } })
        }
        if (this.operationError.length > 0) {
          Text(this.operationError).fontSize(13).fontColor(COLOR_DANGER).backgroundColor('#FFF0EF')
            .padding(10).margin({ top: 10 }).borderRadius(10)
        }
      }.width('100%').height('100%')
    }
    .hideTitleBar(true)
    .width('100%')
    .height('100%')
    .backgroundColor(COLOR_BACKGROUND)
  }
}

@Component
struct LoadingPage {
  build() {
    Column({ space: 16 }) {
      Text('校园失物招领').fontSize(30).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT)
      LoadingProgress().width(36).height(36).color(COLOR_PRIMARY)
      Text('正在恢复账号与会话').fontSize(14).fontColor(COLOR_SECONDARY)
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor(COLOR_BACKGROUND)
  }
}

@Component
struct StartupErrorPage {
  message: string = '';
  onRetry: () => void = () => {};

  build() {
    Column({ space: 16 }) {
      Text('暂时无法打开应用').fontSize(26).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT)
      Text(this.message).fontSize(14).fontColor(COLOR_SECONDARY).textAlign(TextAlign.Center)
      Button('重新加载').backgroundColor(COLOR_PRIMARY).onClick(this.onRetry)
    }.padding(28).width('100%').height('100%').justifyContent(FlexAlign.Center).backgroundColor(COLOR_BACKGROUND)
  }
}

@Component
struct AuthPage {
  @ObjectLink store: AuthStore;
  @Prop revision: number = 0;
  onChanged: () => void = () => {};
  @State pageMode: number = 0;
  @State loginMethod: LoginMethod = LoginMethod.PASSWORD;
  @State passwordAccount: string = '13800000001';
  @State loginPassword: string = 'Campus123';
  @State codeAccount: string = '13800000001';
  @State loginCode: string = '';
  @State error: string = '';
  @State registerStep: number = 1;
  @State registerByEmail: boolean = false;
  @State role: IdentityRole = IdentityRole.STUDENT;
  @State phone: string = '';
  @State email: string = '';
  @State nickname: string = '';
  @State realName: string = '';
  @State identityNumber: string = '';
  @State department: string = '';
  @State grade: string = '';
  @State campus: string = '主校区';
  @State password: string = '';
  @State code: string = '';
  @State agreed: boolean = false;
  @State forgotPhone: string = '';
  @State forgotPassword: string = '';

  @Builder
  modeButton(label: string, mode: number) {
    Button(label)
      .fontSize(14).fontColor(this.pageMode === mode ? COLOR_SURFACE : COLOR_SECONDARY)
      .backgroundColor(this.pageMode === mode ? COLOR_PRIMARY : '#E9E9ED')
      .borderRadius(18).layoutWeight(1)
      .onClick(() => { this.pageMode = mode; this.error = ''; })
  }

  @Builder
  inputField(label: string, value: string, placeholder: string, password: boolean = false,
    onChange: (value: string) => void) {
    Column({ space: 6 }) {
      Text(label).fontSize(13).fontColor(COLOR_SECONDARY).width('100%')
      TextInput({ text: value, placeholder: placeholder })
        .type(password ? InputType.Password : InputType.Normal)
        .height(48).backgroundColor('#F2F2F7').borderRadius(12).padding({ left: 14, right: 14 })
        .onChange(onChange)
    }.width('100%').alignItems(HorizontalAlign.Start)
  }

  @Builder
  loginContent() {
    Column({ space: 14 }) {
      if (this.loginMethod === LoginMethod.PASSWORD) {
        this.inputField('手机号或学校邮箱', this.passwordAccount, '请输入手机号或学校邮箱', false,
          (value: string) => this.passwordAccount = value)
      } else {
        this.inputField('手机号或学校邮箱', this.codeAccount, '请输入手机号或学校邮箱', false,
          (value: string) => this.codeAccount = value)
      }
      Row({ space: 8 }) {
        Button('密码登录').layoutWeight(1).fontSize(13)
          .fontColor(this.loginMethod === LoginMethod.PASSWORD ? COLOR_SURFACE : COLOR_SECONDARY)
          .backgroundColor(this.loginMethod === LoginMethod.PASSWORD ? COLOR_PRIMARY : '#EFEFF4')
          .onClick(() => { this.loginMethod = LoginMethod.PASSWORD; this.error = ''; })
        Button('验证码登录').layoutWeight(1).fontSize(13)
          .fontColor(this.loginMethod === LoginMethod.CODE ? COLOR_SURFACE : COLOR_SECONDARY)
          .backgroundColor(this.loginMethod === LoginMethod.CODE ? COLOR_PRIMARY : '#EFEFF4')
          .onClick(() => { this.loginMethod = LoginMethod.CODE; this.error = ''; })
      }.width('100%')
      if (this.loginMethod === LoginMethod.PASSWORD) {
        this.inputField('密码', this.loginPassword, '请输入密码', true,
          (value: string) => this.loginPassword = value)
      } else {
        this.inputField('验证码', this.loginCode, '请输入6位验证码', false,
          (value: string) => this.loginCode = value)
        Row() {
          Button('获取演示验证码').fontSize(13).backgroundColor('#EAF3FF').fontColor(COLOR_PRIMARY)
            .onClick(() => { this.error = this.store.sendCode(this.codeAccount, VerificationPurpose.LOGIN); })
          Blank()
          if (this.store.demoCode.length > 0) {
            Text(`演示验证码：${this.store.demoCode}`).fontSize(13).fontColor(COLOR_WARNING)
          }
        }.width('100%')
      }
      Button('登录').width('100%').height(50).borderRadius(14).backgroundColor(COLOR_PRIMARY)
        .onClick(() => {
          const account: string = this.loginMethod === LoginMethod.PASSWORD ? this.passwordAccount : this.codeAccount;
          const credential: string = this.loginMethod === LoginMethod.PASSWORD ? this.loginPassword : this.loginCode;
          this.store.login(this.loginMethod, account, credential).then((message: string) => {
            this.error = message;
            if (message.length === 0) { this.onChanged(); }
          }).catch(() => this.error = '登录失败，请稍后重试');
        })
      Row({ space: 18 }) {
        Text('注册账号').fontSize(13).fontColor(COLOR_PRIMARY)
          .onClick(() => { this.pageMode = 1; this.error = ''; })
        Text('找回密码').fontSize(13).fontColor(COLOR_PRIMARY)
          .onClick(() => { this.pageMode = 2; this.error = ''; })
      }.justifyContent(FlexAlign.Center).width('100%')
      Text('学生演示：13800000001 / lin@campus.edu.cn / Campus123').fontSize(12).fontColor(COLOR_SECONDARY)
      Text('管理员：admin@campus.edu.cn / Admin1234').fontSize(12).fontColor(COLOR_SECONDARY)
      Text('验证码为临时凭据，仅用于验证码登录').fontSize(12).fontColor(COLOR_SECONDARY)
    }.width('100%')
  }

  @Builder
  registerContent() {
    Column({ space: 14 }) {
      Text(`注册步骤 ${this.registerStep}/3`).fontSize(15).fontWeight(FontWeight.Medium).fontColor(COLOR_PRIMARY).width('100%')
      if (this.registerStep === 1) {
        Row({ space: 10 }) {
          Button('手机号注册').layoutWeight(1).backgroundColor(!this.registerByEmail ? COLOR_PRIMARY : '#EFEFF4')
            .fontColor(!this.registerByEmail ? COLOR_SURFACE : COLOR_SECONDARY).onClick(() => this.registerByEmail = false)
          Button('学校邮箱注册').layoutWeight(1).backgroundColor(this.registerByEmail ? COLOR_PRIMARY : '#EFEFF4')
            .fontColor(this.registerByEmail ? COLOR_SURFACE : COLOR_SECONDARY).onClick(() => this.registerByEmail = true)
        }.width('100%')
        this.inputField(this.registerByEmail ? '学校邮箱' : '手机号', this.registerByEmail ? this.email : this.phone,
          this.registerByEmail ? 'name@campus.edu.cn' : '请输入手机号', false,
          (value: string) => { if (this.registerByEmail) { this.email = value; } else { this.phone = value; } })
        Text('选择身份').fontSize(13).fontColor(COLOR_SECONDARY).width('100%')
        Row({ space: 8 }) {
          ForEach([IdentityRole.STUDENT, IdentityRole.TEACHER, IdentityRole.STAFF], (item: IdentityRole) => {
            Button(roleLabel(item)).layoutWeight(1).fontSize(13)
              .backgroundColor(this.role === item ? COLOR_PRIMARY : '#EFEFF4')
              .fontColor(this.role === item ? COLOR_SURFACE : COLOR_SECONDARY)
              .onClick(() => { this.role = item; this.grade = ''; })
          })
        }.width('100%')
        Button('继续').width('100%').backgroundColor(COLOR_PRIMARY).onClick(() => this.registerStep = 2)
      } else if (this.registerStep === 2) {
        this.inputField('真实姓名', this.realName, '仅本人和管理员可见', false, (value: string) => this.realName = value)
        this.inputField(this.role === IdentityRole.STUDENT ? '学号' : '工号', this.identityNumber,
          '请输入认证编号', false, (value: string) => this.identityNumber = value)
        this.inputField(this.role === IdentityRole.STAFF ? '所属部门' : '所在院系', this.department,
          '例如：计算机学院', false, (value: string) => this.department = value)
        if (this.role === IdentityRole.STUDENT) {
          this.inputField('入学年份', this.grade, '例如：2024级', false, (value: string) => this.grade = value)
        }
        this.inputField('昵称', this.nickname, '2~16个字符且不可重复', false, (value: string) => this.nickname = value)
        Row({ space: 10 }) {
          Button('主校区').layoutWeight(1).backgroundColor(this.campus === '主校区' ? COLOR_PRIMARY : '#EFEFF4')
            .fontColor(this.campus === '主校区' ? COLOR_SURFACE : COLOR_SECONDARY).onClick(() => this.campus = '主校区')
          Button('分校区').layoutWeight(1).backgroundColor(this.campus === '分校区' ? COLOR_PRIMARY : '#EFEFF4')
            .fontColor(this.campus === '分校区' ? COLOR_SURFACE : COLOR_SECONDARY).onClick(() => this.campus = '分校区')
        }.width('100%')
        Row({ space: 10 }) {
          Button('上一步').layoutWeight(1).backgroundColor('#EFEFF4').fontColor(COLOR_SECONDARY).onClick(() => this.registerStep = 1)
          Button('继续').layoutWeight(1).backgroundColor(COLOR_PRIMARY).onClick(() => this.registerStep = 3)
        }.width('100%')
      } else {
        this.inputField('设置密码', this.password, '8~20位，包含字母和数字', true, (value: string) => this.password = value)
        this.inputField('验证码', this.code, '请输入6位验证码', false, (value: string) => this.code = value)
        Row() {
          Button('获取演示验证码').fontSize(13).backgroundColor('#EAF3FF').fontColor(COLOR_PRIMARY)
            .onClick(() => {
              const target: string = this.registerByEmail ? this.email : this.phone;
              this.error = this.store.sendCode(target, VerificationPurpose.REGISTER);
            })
          Blank()
          if (this.store.demoCode.length > 0) {
            Text(`演示验证码：${this.store.demoCode}`).fontSize(13).fontColor(COLOR_WARNING)
          }
        }.width('100%')
        Row({ space: 8 }) {
          Checkbox({ name: 'agreement', group: 'register' }).select(this.agreed)
            .selectedColor(COLOR_PRIMARY).onChange((value: boolean) => this.agreed = value)
          Text('我已阅读并同意《用户协议》和《隐私政策》').fontSize(12).fontColor(COLOR_SECONDARY)
        }.width('100%')
        Row({ space: 10 }) {
          Button('上一步').layoutWeight(1).backgroundColor('#EFEFF4').fontColor(COLOR_SECONDARY).onClick(() => this.registerStep = 2)
          Button('创建账号').layoutWeight(1).backgroundColor(COLOR_PRIMARY).onClick(() => {
            const request: RegisterRequest = { phone: this.registerByEmail ? '' : this.phone,
              email: this.registerByEmail ? this.email : '', nickname: this.nickname, realName: this.realName,
              identityNumber: this.identityNumber, identityRole: this.role, department: this.department,
              grade: this.grade, campus: this.campus, password: this.password,
              verificationCode: this.code, agreed: this.agreed };
            this.store.register(request).then((message: string) => {
              this.error = message;
              if (message.length === 0) { this.onChanged(); }
            }).catch(() => this.error = '注册失败，请稍后重试');
          })
        }.width('100%')
      }
    }.width('100%')
  }

  @Builder
  forgotContent() {
    Column({ space: 14 }) {
      this.inputField('已绑定手机号', this.forgotPhone, '请输入手机号', false, (value: string) => this.forgotPhone = value)
      this.inputField('新密码', this.forgotPassword, '8~20位，包含字母和数字', true, (value: string) => this.forgotPassword = value)
      this.inputField('验证码', this.code, '请输入6位验证码', false, (value: string) => this.code = value)
      Row() {
        Button('获取演示验证码').backgroundColor('#EAF3FF').fontColor(COLOR_PRIMARY)
          .onClick(() => this.error = this.store.sendCode(this.forgotPhone, VerificationPurpose.RESET_PASSWORD))
        Blank()
        if (this.store.demoCode.length > 0) { Text(`演示验证码：${this.store.demoCode}`).fontSize(13).fontColor(COLOR_WARNING) }
      }.width('100%')
      Button('重置密码').width('100%').backgroundColor(COLOR_PRIMARY).onClick(() => {
        this.store.resetPassword(this.forgotPhone, this.forgotPassword, this.code).then((message: string) => {
          this.error = message.length === 0 ? '密码已重置，请返回登录' : message;
        }).catch(() => this.error = '密码重置失败，请稍后重试');
      })
    }.width('100%')
  }

  build() {
    Scroll() {
      Column({ space: 22 }) {
        Column({ space: 8 }) {
          Text('校园失物招领').fontSize(32).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT)
          Text('让每一件物品，都有回家的线索').fontSize(15).fontColor(COLOR_SECONDARY)
        }.alignItems(HorizontalAlign.Start).width('100%')
        Column() {
          if (this.pageMode === 0) { this.loginContent() }
          else if (this.pageMode === 1) { this.registerContent() }
          else { this.forgotContent() }
        }.width('100%').padding(20).backgroundColor(COLOR_SURFACE).borderRadius(20)
        if (this.pageMode !== 0) {
          Button('返回登录').width('100%').backgroundColor(Color.Transparent).fontColor(COLOR_PRIMARY)
            .onClick(() => { this.pageMode = 0; this.error = ''; })
        }
        if (this.error.length > 0) {
          Text(this.error).width('100%').padding(12).borderRadius(10).backgroundColor('#FFF4E5')
            .fontColor(this.error.includes('成功') || this.error.includes('生成') ? COLOR_SUCCESS : COLOR_DANGER).fontSize(13)
        }
      }.padding({ left: 22, right: 22, top: 56, bottom: 36 }).width('100%')
    }.width('100%').height('100%').backgroundColor(COLOR_BACKGROUND).scrollBar(BarState.Off)
  }
}

@Component
struct UserTabs {
  @ObjectLink authStore: AuthStore;
  @ObjectLink appStore: AppStore;
  account: UserAccount = placeholderAccount();
  @Prop revision: number = 0;
  onChanged: () => void = () => {};
  onOpenPost: (postId: string) => void = () => {};
  onEditProfile: () => void = () => {};
  onSecurity: () => void = () => {};
  accessToken: string = '';
  apiRepository: ContentApiRepository = new ContentApiRepository();
  unreadCount: number = 0;
  onMessagesOpened: () => void = () => {};
  @State selectedTab: number = 0;

  build() {
    Tabs({ barPosition: BarPosition.End, index: this.selectedTab }) {
      TabContent() { HomePage({ store: this.appStore, revision: this.revision,
        unreadCount: this.unreadCount, onOpenMessages: () => { this.selectedTab = 2; this.onMessagesOpened(); },
        onChanged: this.onChanged, onOpenPost: this.onOpenPost }) }.tabBar('首页')
      TabContent() { PublishPage({ store: this.appStore, account: this.account,
        revision: this.revision, accessToken: this.accessToken, apiRepository: this.apiRepository,
        onChanged: this.onChanged, onOpenPost: this.onOpenPost }) }.tabBar('发布')
      TabContent() { MessagePage({ store: this.appStore, revision: this.revision,
        onChanged: this.onChanged, onOpenPost: this.onOpenPost }) }.tabBar('消息')
      TabContent() { ProfilePage({ authStore: this.authStore, appStore: this.appStore,
        account: this.account, revision: this.revision, onOpenPost: this.onOpenPost,
        onEditProfile: this.onEditProfile, onSecurity: this.onSecurity }) }.tabBar('我的')
    }
    .barMode(BarMode.Fixed).barBackgroundColor(COLOR_SURFACE).backgroundColor(COLOR_BACKGROUND)
    .onChange((index: number) => {
      this.selectedTab = index;
      if (index === 2) this.onMessagesOpened();
    })
  }
}

@Component
struct HomePage {
  @ObjectLink store: AppStore;
  @Prop revision: number = 0;
  onChanged: () => void = () => {};
  onOpenPost: (postId: string) => void = () => {};
  onOpenMessages: () => void = () => {};
  unreadCount: number = 0;
  @State keyword: string = '';
  @State selectedKind: number = 0;
  @State category: string = '';
  @State statusIndex: number = 0;

  private visiblePosts(): Post[] {
    return this.store.query({ keyword: this.keyword,
      kind: this.selectedKind === 0 ? undefined : (this.selectedKind === 1 ? PostKind.LOST_NOTICE : PostKind.SEARCH_NOTICE),
      category: this.category,
      status: this.statusIndex === 0 ? undefined : (this.statusIndex === 1 ? PostStatus.ACTIVE :
        (this.statusIndex === 2 ? PostStatus.CLAIMING : PostStatus.RESOLVED)) });
  }

  build() {
    Column() {
      Scroll() {
        Column({ space: 16 }) {
          Row() {
            Column({ space: 4 }) {
              Text('校园失物招领').fontSize(30).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT)
              Text('主校区 · 今日有 8 条新线索').fontSize(13).fontColor(COLOR_SECONDARY)
             }.alignItems(HorizontalAlign.Start)
             Blank().layoutWeight(1)
             Stack({ alignContent: Alignment.TopEnd }) {
              Button('🔔').fontSize(20).width(44).height(44).padding(0)
                .backgroundColor(COLOR_SURFACE).borderRadius(22).onClick(this.onOpenMessages)
              if (this.unreadCount > 0) {
                Text(this.unreadCount > 99 ? '99+' : `${this.unreadCount}`).fontSize(9).fontColor(Color.White)
                  .width(18).height(18).textAlign(TextAlign.Center).backgroundColor(COLOR_DANGER).borderRadius(9)
              }
            }.width(44).height(44)
          }.width('100%')
          TextInput({ text: this.keyword, placeholder: '搜索物品、地点或描述' })
            .height(48).backgroundColor(COLOR_SURFACE).borderRadius(14).padding({ left: 14, right: 14 })
            .onChange((value: string) => this.keyword = value)
          Row({ space: 8 }) {
            ForEach(['全部', '失物', '寻物'], (label: string, index: number) => {
              Button(label).fontSize(13).backgroundColor(this.selectedKind === index ? COLOR_TEXT : COLOR_SURFACE)
                .fontColor(this.selectedKind === index ? COLOR_SURFACE : COLOR_SECONDARY).borderRadius(18)
                .onClick(() => this.selectedKind = index)
            })
          }.width('100%')
          Row({ space: 8 }) {
            ForEach(['全部状态', '待认领', '认领中', '已归还'], (label: string, index: number) => {
              Button(label).fontSize(12).backgroundColor(this.statusIndex === index ? '#EAF3FF' : COLOR_SURFACE)
                .fontColor(this.statusIndex === index ? COLOR_PRIMARY : COLOR_SECONDARY)
                .onClick(() => this.statusIndex = index)
            })
          }.width('100%')
          Scroll() {
            Row({ space: 8 }) {
              ForEach(['', '证件卡类', '电子数码', '钥匙钱包', '书本文具', '生活用品'], (item: string) => {
                Button(item.length === 0 ? '全部分类' : item).fontSize(12)
                  .backgroundColor(this.category === item ? '#EAF3FF' : COLOR_SURFACE)
                  .fontColor(this.category === item ? COLOR_PRIMARY : COLOR_SECONDARY)
                  .onClick(() => this.category = item)
              })
            }
          }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
          Row() {
            Text('最新动态').fontSize(20).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT)
            Blank()
            Text(`${this.visiblePosts().length} 条`).fontSize(13).fontColor(COLOR_SECONDARY)
          }.width('100%')
          if (this.visiblePosts().length === 0) {
            Column({ space: 10 }) {
              Text('🔎').fontSize(40)
              Text('没有找到相关信息').fontSize(16).fontWeight(FontWeight.Medium)
              Button('清除筛选').backgroundColor('#EAF3FF').fontColor(COLOR_PRIMARY)
                .onClick(() => { this.keyword = ''; this.category = ''; this.selectedKind = 0; this.statusIndex = 0; })
            }.width('100%').padding(30).backgroundColor(COLOR_SURFACE).borderRadius(18)
          } else {
            ForEach(this.visiblePosts(), (post: Post) => {
              PostCard({ post: post, onOpen: this.onOpenPost })
            }, (post: Post) => post.id)
          }
        }.padding({ left: 18, right: 18, top: 24, bottom: 30 }).width('100%')
      }.scrollBar(BarState.Off)
    }.width('100%').height('100%').backgroundColor(COLOR_BACKGROUND)
  }
}

@Component
struct PostCard {
  post: Post = placeholderPost();
  onOpen: (postId: string) => void = () => {};

  private emoji(): string {
    if (this.post.category === '电子数码') { return '📱'; }
    if (this.post.category === '证件卡类') { return '💳'; }
    if (this.post.category === '钥匙钱包') { return '🔑'; }
    if (this.post.category === '书本文具') { return '📚'; }
    if (this.post.category === '运动器材') { return '🏸'; }
    return '🎒';
  }

  build() {
    Column({ space: 12 }) {
      Row({ space: 14 }) {
        if (this.post.imageKey.length > 0) {
          Image(this.post.imageKey).width(78).height(78).objectFit(ImageFit.Cover).borderRadius(16)
        } else {
          Text(this.emoji()).fontSize(42).width(78).height(78).textAlign(TextAlign.Center)
            .backgroundColor(this.post.kind === PostKind.LOST_NOTICE ? '#EAF3FF' : '#FFF4E5').borderRadius(16)
        }
        Column({ space: 6 }) {
          Row({ space: 6 }) {
            Text(this.post.kind === PostKind.LOST_NOTICE ? '失物' : '寻物').fontSize(11)
              .fontColor(this.post.kind === PostKind.LOST_NOTICE ? COLOR_PRIMARY : COLOR_WARNING)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(this.post.kind === PostKind.LOST_NOTICE ? '#EAF3FF' : '#FFF4E5').borderRadius(8)
            Text(this.post.status === PostStatus.RESOLVED ? '已归还' : (this.post.status === PostStatus.CLAIMING ? '认领中' : '待认领'))
              .fontSize(11).fontColor(COLOR_SECONDARY)
          }
          Text(this.post.title).fontSize(17).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT).maxLines(1)
          Text(`${this.post.location} · ${this.post.occurredAt}`).fontSize(12).fontColor(COLOR_SECONDARY).maxLines(1)
          Text(`${this.post.ownerName}  ·  ♡ ${this.post.likeCount}  💬 ${this.post.commentCount}`)
            .fontSize(12).fontColor(COLOR_SECONDARY)
        }.alignItems(HorizontalAlign.Start).layoutWeight(1)
      }.width('100%')
    }.width('100%').padding(16).backgroundColor(COLOR_SURFACE).borderRadius(18)
      .onClick(() => this.onOpen(this.post.id))
  }
}

@Component
struct PublishPage {
  @ObjectLink store: AppStore;
  account: UserAccount = placeholderAccount();
  @Prop revision: number = 0;
  onChanged: () => void = () => {};
  onOpenPost: (postId: string) => void = () => {};
  @State kind: PostKind = PostKind.LOST_NOTICE;
  @State title: string = '';
  @State description: string = '';
  @State category: string = '电子数码';
  @State location: string = '';
  @State occurredAt: string = '今天';
  @State imageKey: string = 'placeholder';
  @State selectedUris: string[] = [];
  @State submitting: boolean = false;
  @State message: string = '';
  accessToken: string = '';
  apiRepository: ContentApiRepository = new ContentApiRepository();
  private fileApiRepository: FileApiRepository = new FileApiRepository();

  private async chooseImages(): Promise<void> {
    try {
      this.selectedUris = await new ImagePickerService().pickImages(6);
      this.message = this.selectedUris.length > 0 ? `已选择 ${this.selectedUris.length} 张图片` : '';
    } catch (error) {
      this.message = '图片选择已取消';
    }
  }

  private async submit(): Promise<void> {
    if (this.title.trim().length === 0 || this.description.trim().length < 10 || this.location.trim().length === 0) {
      this.message = '请完整填写名称、地点和至少10字描述';
      return;
    }
    this.submitting = true;
    try {
      const draft: PostDraft = { kind: this.kind, title: this.title.trim(), description: this.description.trim(),
        category: this.category, location: this.location.trim(), occurredAt: this.occurredAt, imageKey: this.imageKey };
      if (this.accessToken.length > 0) {
        const contact: string = this.account.phone.length > 0 ? this.account.phone : this.account.email;
        let imageIds: string[] = [];
        if (this.selectedUris.length > 0) {
          const context: common.UIAbilityContext = this.getUIContext().getHostContext() as common.UIAbilityContext;
          const images = await this.fileApiRepository.uploadImages(context, this.accessToken, this.selectedUris);
          imageIds = images.map((image) => image.id);
        }
        const post: Post = await this.apiRepository.createPost(this.accessToken, draft, this.account.campus, contact, imageIds);
        this.message = '发布成功，内容已同步';
        this.onChanged();
        this.onOpenPost(post.id);
      } else {
        const id: string = this.store.publish(draft, this.account.nickname);
        this.onChanged();
        this.onOpenPost(id);
      }
    } catch (error) {
      this.message = error instanceof Error ? error.message : '发布失败，请稍后重试';
    } finally {
      this.submitting = false;
    }
  }

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('发布信息').fontSize(30).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT).width('100%')
        Row({ space: 10 }) {
          Button('发布失物').layoutWeight(1).backgroundColor(this.kind === PostKind.LOST_NOTICE ? COLOR_PRIMARY : COLOR_SURFACE)
            .fontColor(this.kind === PostKind.LOST_NOTICE ? COLOR_SURFACE : COLOR_SECONDARY).onClick(() => this.kind = PostKind.LOST_NOTICE)
          Button('发布寻物').layoutWeight(1).backgroundColor(this.kind === PostKind.SEARCH_NOTICE ? COLOR_PRIMARY : COLOR_SURFACE)
            .fontColor(this.kind === PostKind.SEARCH_NOTICE ? COLOR_SURFACE : COLOR_SECONDARY).onClick(() => this.kind = PostKind.SEARCH_NOTICE)
        }.width('100%')
        Column({ space: 12 }) {
          TextInput({ text: this.title, placeholder: '物品名称' }).height(48).backgroundColor('#F2F2F7').borderRadius(12)
            .onChange((value: string) => this.title = value)
          TextArea({ text: this.description, placeholder: '描述颜色、型号、独有特征等（10~500字）' })
            .height(110).backgroundColor('#F2F2F7').borderRadius(12).onChange((value: string) => this.description = value)
          TextInput({ text: this.location, placeholder: '丢失或拾获地点' }).height(48).backgroundColor('#F2F2F7').borderRadius(12)
            .onChange((value: string) => this.location = value)
          Text('选择分类').fontSize(13).fontColor(COLOR_SECONDARY).width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(['电子数码', '证件卡类', '钥匙钱包', '书本文具', '生活用品', '运动器材'], (item: string) => {
              Button(item).fontSize(12).margin(4).backgroundColor(this.category === item ? '#EAF3FF' : '#EFEFF4')
                .fontColor(this.category === item ? COLOR_PRIMARY : COLOR_SECONDARY).onClick(() => this.category = item)
            })
          }.width('100%')
          Row({ space: 12 }) {
            Button(this.selectedUris.length > 0 ? `📷 ${this.selectedUris.length}` : '📷')
              .fontSize(24).width(72).height(72).backgroundColor('#EAF3FF').borderRadius(14)
              .onClick(() => this.chooseImages())
            Column({ space: 4 }) {
              Text(this.selectedUris.length > 0 ? '已选择图片' : '添加物品图片').fontSize(14).fontWeight(FontWeight.Medium)
              Text('最多选择 6 张，发布时上传到图片服务').fontSize(12).fontColor(COLOR_SECONDARY)
            }.alignItems(HorizontalAlign.Start)
          }.width('100%')
          Button(this.submitting ? '提交中…' : '提交发布').width('100%').height(50).backgroundColor(COLOR_PRIMARY)
            .borderRadius(14).enabled(!this.submitting).onClick(() => this.submit())
          if (this.message.length > 0) { Text(this.message).fontSize(13).fontColor(COLOR_DANGER) }
        }.width('100%').padding(18).backgroundColor(COLOR_SURFACE).borderRadius(18)
      }.padding({ left: 18, right: 18, top: 24, bottom: 30 }).width('100%')
    }.width('100%').height('100%').backgroundColor(COLOR_BACKGROUND).scrollBar(BarState.Off)
  }
}

@Component
struct MessagePage {
  @ObjectLink store: AppStore;
  @Prop revision: number = 0;
  onChanged: () => void = () => {};
  onOpenPost: (postId: string) => void = () => {};

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Text('消息').fontSize(30).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT).width('100%')
        if (this.store.notifications.length === 0) {
          Column({ space: 8 }) {
            Text('暂无消息').fontSize(17).fontWeight(FontWeight.Medium).fontColor(COLOR_TEXT)
            Text('认领、线索和归还状态会显示在这里').fontSize(13).fontColor(COLOR_SECONDARY)
          }.width('100%').padding(28).backgroundColor(COLOR_SURFACE).borderRadius(18)
        }
        ForEach(this.store.notifications, (notice: AppNotification) => {
          Row({ space: 14 }) {
            Text(notice.type === 'CLAIM' ? '🙋' : (notice.type === 'CLUE' ? '💡' : '🔔')).fontSize(28)
              .width(52).height(52).textAlign(TextAlign.Center).backgroundColor('#EAF3FF').borderRadius(16)
            Column({ space: 5 }) {
              Text(notice.title).fontSize(16).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT)
              Text(notice.content).fontSize(13).fontColor(COLOR_SECONDARY).maxLines(2)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            if (!notice.read) { Circle({ width: 8, height: 8 }).fill(COLOR_PRIMARY) }
          }.width('100%').padding(16).backgroundColor(COLOR_SURFACE).borderRadius(18)
            .onClick(() => {
              if (this.store.markNotificationRead(notice.id)) {
                this.onChanged();
              }
              this.onOpenPost(notice.postId);
            })
        })
      }.padding({ left: 18, right: 18, top: 24, bottom: 30 }).width('100%').alignItems(HorizontalAlign.Start)
    }.width('100%').height('100%').backgroundColor(COLOR_BACKGROUND).scrollBar(BarState.Off)
  }
}

@Component
struct ProfilePage {
  @ObjectLink authStore: AuthStore;
  @ObjectLink appStore: AppStore;
  account: UserAccount = placeholderAccount();
  @Prop revision: number = 0;
  onOpenPost: (postId: string) => void = () => {};
  onEditProfile: () => void = () => {};
  onSecurity: () => void = () => {};

  build() {
    Scroll() {
      Column({ space: 16 }) {
        Text('我的').fontSize(30).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT).width('100%')
        Row({ space: 16 }) {
          Text(this.account.identityRole === IdentityRole.STUDENT ? '🎓' : (this.account.identityRole === IdentityRole.TEACHER ? '👩‍🏫' : '🛡️'))
            .fontSize(42).width(78).height(78).textAlign(TextAlign.Center).backgroundColor('#EAF3FF').borderRadius(24)
          Column({ space: 6 }) {
            Text(this.account.nickname).fontSize(22).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT)
            Text(`${roleLabel(this.account.identityRole)} · ${this.account.department}`).fontSize(13).fontColor(COLOR_SECONDARY)
            Text(`${this.account.campus} · 信用分 ${this.account.creditScore}`).fontSize(13).fontColor(COLOR_PRIMARY)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button('编辑').fontSize(12).backgroundColor('#EFEFF4').fontColor(COLOR_PRIMARY).onClick(this.onEditProfile)
        }.width('100%').padding(18).backgroundColor(COLOR_SURFACE).borderRadius(20)
        Row({ space: 10 }) {
          this.statCard('我的发布', `${this.appStore.myPosts().length}`)
          this.statCard('认领/线索', `${this.appStore.myClaims().length + this.appStore.clues.length}`)
          this.statCard('收藏', `${this.appStore.favoritePosts().length}`)
        }.width('100%')
        Text('我的发布').fontSize(20).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT).width('100%')
        ForEach(this.appStore.myPosts(), (post: Post) => {
          PostCard({ post: post, onOpen: this.onOpenPost })
        }, (post: Post) => post.id)
        Text('我的收藏').fontSize(20).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT).width('100%')
        if (this.appStore.favoritePosts().length === 0) {
          Text('暂无收藏').fontSize(14).fontColor(COLOR_SECONDARY).width('100%')
            .padding({ top: 8, bottom: 8 })
        } else {
          ForEach(this.appStore.favoritePosts(), (post: Post) => {
            PostCard({ post: post, onOpen: this.onOpenPost })
          }, (post: Post) => post.id)
        }
        Button('账号与安全').width('100%').height(48).backgroundColor(COLOR_SURFACE).fontColor(COLOR_TEXT)
          .onClick(this.onSecurity)
      }.padding({ left: 18, right: 18, top: 24, bottom: 30 }).width('100%')
    }.width('100%').height('100%').backgroundColor(COLOR_BACKGROUND).scrollBar(BarState.Off)
  }

  @Builder
  statCard(label: string, value: string) {
    Column({ space: 4 }) {
      Text(value).fontSize(22).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT)
      Text(label).fontSize(11).fontColor(COLOR_SECONDARY)
    }.layoutWeight(1).padding(14).backgroundColor(COLOR_SURFACE).borderRadius(16)
  }
}

@Component
struct PostDetailPage {
  @ObjectLink store: AppStore;
  account: UserAccount = placeholderAccount();
  postId: string = '';
  @Prop revision: number = 0;
  onBack: () => void = () => {};
  onChanged: () => void = () => {};
  @State claimInput: string = '';
  @State commentInput: string = '';
  @State message: string = '';
  @State remoteClaims: ClaimRequest[] = [];
  @State remoteComments: PostComment[] = [];
  @State remotePost: Post | undefined = undefined;
  @State busy: boolean = false;
  @State interactionBusy: boolean = false;
  accessToken: string = '';
  apiRepository: ContentApiRepository = new ContentApiRepository();

  aboutToAppear(): void {
    this.loadRemoteClaims();
  }

  private async loadRemoteClaims(): Promise<void> {
    if (this.accessToken.length === 0) return;
    try {
      const remotePost: Post = await this.apiRepository.getPost(this.accessToken, this.postId);
      this.remotePost = remotePost;
      this.remoteClaims = remotePost.ownerId === this.account.id ?
        await this.apiRepository.listClaims(this.accessToken, this.postId) : [];
      this.remoteComments = await this.apiRepository.listComments(this.accessToken, this.postId);
      this.remotePost = this.withCommentCount(this.remotePost as Post, this.remoteComments.length);
    } catch (error) {
      this.remoteClaims = [];
      this.remoteComments = [];
    }
  }

  private currentPost(): Post | undefined {
    return this.remotePost ?? this.store.findPost(this.postId);
  }

  private withInteractions(post: Post, likeCount: number, isLiked: boolean, isFavorite: boolean): Post {
    return {
      id: post.id, ownerId: post.ownerId, ownerName: post.ownerName, kind: post.kind, status: post.status,
      title: post.title, description: post.description, category: post.category, location: post.location,
      occurredAt: post.occurredAt, imageKey: post.imageKey, likeCount: likeCount, commentCount: post.commentCount,
      isLiked: isLiked, isFavorite: isFavorite, createdAt: post.createdAt
    };
  }

  private withCommentCount(post: Post, commentCount: number): Post {
    return {
      id: post.id, ownerId: post.ownerId, ownerName: post.ownerName, kind: post.kind, status: post.status,
      title: post.title, description: post.description, category: post.category, location: post.location,
      occurredAt: post.occurredAt, imageKey: post.imageKey, likeCount: post.likeCount, commentCount: commentCount,
      isLiked: post.isLiked, isFavorite: post.isFavorite, createdAt: post.createdAt
    };
  }

  private async toggleLike(post: Post): Promise<void> {
    if (this.interactionBusy) return;
    const enabled = !post.isLiked;
    this.interactionBusy = true;
    if (this.accessToken.length === 0) {
      this.store.toggleLike(post.id);
      this.onChanged();
      this.interactionBusy = false;
      return;
    }
    this.remotePost = this.withInteractions(post, Math.max(0, post.likeCount + (enabled ? 1 : -1)), enabled, post.isFavorite);
    try {
      const result = await this.apiRepository.setLike(this.accessToken, post.id, enabled);
      this.remotePost = this.withInteractions(this.remotePost as Post, result.likeCount, result.isLiked, post.isFavorite);
      this.store.updatePostInteractions(post.id, result.likeCount, result.isLiked, post.isFavorite);
    } catch (error) {
      this.remotePost = post;
      this.message = '点赞操作失败，请稍后重试';
    } finally {
      this.interactionBusy = false;
    }
  }

  private async toggleFavorite(post: Post): Promise<void> {
    if (this.interactionBusy) return;
    const enabled = !post.isFavorite;
    this.interactionBusy = true;
    if (this.accessToken.length === 0) {
      this.store.toggleFavorite(post.id);
      this.onChanged();
      this.interactionBusy = false;
      return;
    }
    this.remotePost = this.withInteractions(post, post.likeCount, post.isLiked, enabled);
    try {
      const result = await this.apiRepository.setFavorite(this.accessToken, post.id, enabled);
      this.remotePost = this.withInteractions(this.remotePost as Post, post.likeCount, post.isLiked, result.isFavorite);
      this.store.updatePostInteractions(post.id, post.likeCount, post.isLiked, result.isFavorite);
    } catch (error) {
      this.remotePost = post;
      this.message = '收藏操作失败，请稍后重试';
    } finally {
      this.interactionBusy = false;
    }
  }

  private async submitAction(post: Post): Promise<void> {
    if (this.claimInput.trim().length === 0) {
      this.message = '请先填写说明';
      return;
    }
    this.busy = true;
    try {
      if (this.accessToken.length > 0) {
        if (post.kind === PostKind.LOST_NOTICE) {
          await this.apiRepository.submitClaim(this.accessToken, post.id, this.claimInput.trim());
        } else {
          await this.apiRepository.submitClue(this.accessToken, post.id, this.claimInput.trim());
        }
        this.message = '提交成功，状态已实时同步';
        this.claimInput = '';
        await this.loadRemoteClaims();
        this.onChanged();
      } else {
        if (post.kind === PostKind.LOST_NOTICE) this.store.submitClaim(post.id, this.claimInput);
        else this.store.submitClue(post.id, this.claimInput);
        this.message = '提交成功，进度已同步到消息与我的记录';
        this.claimInput = '';
        this.onChanged();
      }
    } catch (error) {
      this.message = error instanceof Error ? error.message : '提交失败，请稍后重试';
    } finally {
      this.busy = false;
    }
  }

  private async submitComment(post: Post): Promise<void> {
    const content: string = this.commentInput.trim();
    if (content.length < 1 || content.length > 200) {
      this.message = '评论须为1~200个字符';
      return;
    }
    this.busy = true;
    try {
      if (this.accessToken.length > 0) {
        const comment: PostComment = await this.apiRepository.createComment(this.accessToken, post.id, content);
        this.remoteComments = this.remoteComments.concat([comment]);
        this.store.updatePostCommentCount(post.id, this.remoteComments.length);
        if (this.remotePost !== undefined) {
          this.remotePost = this.withCommentCount(this.remotePost, this.remoteComments.length);
        }
      } else {
        const error: string = this.store.addComment(post.id, this.account.nickname, content);
        if (error.length > 0) {
          this.message = error;
          return;
        }
        this.commentInput = '';
        this.message = '评论成功';
        this.onChanged();
        return;
      }
      this.commentInput = '';
      this.message = '评论成功';
    } catch (error) {
      this.message = error instanceof Error ? error.message : '评论失败，请稍后重试';
    } finally {
      this.busy = false;
    }
  }

  private async confirmRemoteReturn(claimId: string): Promise<void> {
    this.busy = true;
    try {
      await this.apiRepository.confirmReturn(this.accessToken, claimId);
      this.message = '已确认归还，状态已实时同步';
      await this.loadRemoteClaims();
      this.onChanged();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '确认归还失败，请稍后重试';
    } finally {
      this.busy = false;
    }
  }

  build() {
    Column() {
      Row() {
        Button('‹ 返回').backgroundColor(Color.Transparent).fontColor(COLOR_PRIMARY).onClick(this.onBack)
        Blank()
      }.width('100%').height(56).padding({ left: 8, right: 18 })
      if (this.currentPost() === undefined) {
        Column({ space: 10 }) { Text('信息不存在').fontSize(18); Button('返回').onClick(this.onBack) }
          .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        this.detailContent(this.currentPost() as Post)
      }
    }.width('100%').height('100%').backgroundColor(COLOR_BACKGROUND)
  }

  @Builder
  detailContent(post: Post) {
    Scroll() {
      Column({ space: 16 }) {
        if (post.imageKey.length > 0) {
          Image(post.imageKey).width('100%').height(210).objectFit(ImageFit.Contain)
            .backgroundColor(post.kind === PostKind.LOST_NOTICE ? '#EAF3FF' : '#FFF4E5').borderRadius(22)
        } else {
          Text(post.category === '电子数码' ? '📱' : (post.category === '证件卡类' ? '💳' : '🎒'))
            .fontSize(86).width('100%').height(210).textAlign(TextAlign.Center)
            .backgroundColor(post.kind === PostKind.LOST_NOTICE ? '#EAF3FF' : '#FFF4E5').borderRadius(22)
        }
        Row({ space: 8 }) {
          Text(post.kind === PostKind.LOST_NOTICE ? '失物' : '寻物').fontSize(12).fontColor(COLOR_PRIMARY)
            .padding({ left: 10, right: 10, top: 4, bottom: 4 }).backgroundColor('#EAF3FF').borderRadius(8)
          Text(postStatusLabel(post.status))
            .fontSize(12).fontColor(post.status === PostStatus.RESOLVED ? COLOR_SUCCESS : COLOR_WARNING)
        }.width('100%')
        Text(post.title).fontSize(27).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT).width('100%')
        Text(`${post.location} · ${post.occurredAt}`).fontSize(14).fontColor(COLOR_SECONDARY).width('100%')
        Text(post.description).fontSize(16).fontColor(COLOR_TEXT).lineHeight(25).width('100%')
        Row() {
          Text(`发布者：${post.ownerName}`).fontSize(14).fontColor(COLOR_SECONDARY)
          Blank()
          Button(post.isLiked ? `♥ ${post.likeCount}` : `♡ ${post.likeCount}`).fontSize(13)
            .backgroundColor('#EFEFF4').fontColor(post.isLiked ? COLOR_DANGER : COLOR_SECONDARY)
            .enabled(!this.interactionBusy && !this.busy)
            .onClick(() => this.toggleLike(post))
          Button(post.isFavorite ? '\u5df2\u6536\u85cf' : '\u6536\u85cf').fontSize(13).backgroundColor('#EFEFF4')
            .fontColor(COLOR_PRIMARY).enabled(!this.interactionBusy && !this.busy)
            .onClick(() => this.toggleFavorite(post))
        }.width('100%')
        if (post.status === PostStatus.ACTIVE && post.ownerId !== this.account.id) {
          Text('\u8BA4\u9886\u4FE1\u606F').fontSize(18).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT).width('100%')
          TextArea({ text: this.claimInput, placeholder: post.kind === PostKind.LOST_NOTICE ? '描述物品独有特征，防止冒领' : '填写你掌握的地点或时间线索' })
            .height(90).backgroundColor(COLOR_SURFACE).borderRadius(14).onChange((value: string) => this.claimInput = value)
          Button(this.busy ? '提交中…' : (post.kind === PostKind.LOST_NOTICE ? '这是我的' : '提供线索')).width('100%').height(50)
            .backgroundColor(COLOR_PRIMARY).borderRadius(14).enabled(!this.busy).onClick(() => this.submitAction(post))
        }
        if (post.ownerId === this.account.id) {
          Text('\u8BA4\u9886\u4FE1\u606F').fontSize(18).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT).width('100%')
          ForEach((this.accessToken.length > 0 ? this.remoteClaims : this.store.claims)
            .filter((claim: ClaimRequest) => claim.postId === post.id), (claim: ClaimRequest) => {
            Column({ space: 10 }) {
              Text('认领申请').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
              Text(claim.answer).fontSize(14).fontColor(COLOR_SECONDARY).width('100%')
              if (claim.status === ClaimStatus.PENDING) {
                if (this.accessToken.length === 0) {
                  Row({ space: 10 }) {
                    Button('拒绝').layoutWeight(1).backgroundColor('#EFEFF4').fontColor(COLOR_DANGER)
                      .onClick(() => { this.message = this.store.reviewClaim(this.account.id, claim.id, false); this.onChanged(); })
                    Button('同意认领').layoutWeight(1).backgroundColor(COLOR_PRIMARY)
                      .onClick(() => { this.message = this.store.reviewClaim(this.account.id, claim.id, true); this.onChanged(); })
                  }.width('100%')
                } else {
                  Button('确认已归还').width('100%').backgroundColor(COLOR_SUCCESS)
                    .enabled(!this.busy).onClick(() => this.confirmRemoteReturn(claim.id))
                }
              } else if (claim.status === ClaimStatus.APPROVED) {
                Button('确认已归还').width('100%').backgroundColor(COLOR_SUCCESS)
                  .onClick(() => {
                    if (this.accessToken.length > 0) this.confirmRemoteReturn(claim.id);
                    else { this.message = this.store.confirmReturn(this.account.id, claim.id); this.onChanged(); }
                  })
              } else {
                Text(claim.status === ClaimStatus.COMPLETED ? '已完成归还' : '申请已拒绝').fontColor(COLOR_SECONDARY)
              }
            }.width('100%').padding(16).backgroundColor(COLOR_SURFACE).borderRadius(16)
          })
        }
        Text('\u8BC4\u8BBA').fontSize(18).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT).width('100%')
        Row({ space: 10 }) {
          TextInput({ text: this.commentInput, placeholder: '发表评论（最多200字）' }).layoutWeight(1).backgroundColor(COLOR_SURFACE).borderRadius(14)
            .onChange((value: string) => this.commentInput = value)
          Button('发送').backgroundColor(COLOR_TEXT).enabled(!this.busy).onClick(() => {
            this.submitComment(post);
          })
        }.width('100%')
        ForEach((this.accessToken.length > 0 ? this.remoteComments : this.store.comments)
          .filter((comment: PostComment) => comment.postId === post.id), (comment: PostComment) => {
          Column({ space: 4 }) {
            Text(comment.userName).fontSize(13).fontColor(COLOR_SECONDARY).width('100%')
            Text(comment.content).fontSize(15).fontColor(COLOR_TEXT).width('100%')
          }.width('100%').padding(14).backgroundColor(COLOR_SURFACE).borderRadius(14)
        }, (comment: PostComment) => comment.id)
        if (this.message.length > 0) { Text(this.message).fontSize(13).fontColor(this.message.includes('成功') ? COLOR_SUCCESS : COLOR_DANGER) }
      }.padding({ left: 18, right: 18, bottom: 36 }).width('100%')
    }.scrollBar(BarState.Off).layoutWeight(1)
  }
}

@Component
struct EditProfilePage {
  @ObjectLink store: AuthStore;
  account: UserAccount = placeholderAccount();
  @Prop revision: number = 0;
  onBack: () => void = () => {};
  onChanged: () => void = () => {};
  @State nickname: string = '';
  @State department: string = '';
  @State grade: string = '';
  @State campus: string = '';
  @State contact: string = '';
  @State message: string = '';

  aboutToAppear(): void {
    this.nickname = this.account.nickname; this.department = this.account.department; this.grade = this.account.grade;
    this.campus = this.account.campus; this.contact = this.account.contact;
  }

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Row() { Button('‹ 返回').backgroundColor(Color.Transparent).fontColor(COLOR_PRIMARY).onClick(this.onBack); Blank() }.width('100%')
        Text('编辑个人资料').fontSize(30).fontWeight(FontWeight.Bold).width('100%')
        Text(`真实姓名：${this.account.realName}`).fontSize(14).fontColor(COLOR_SECONDARY).width('100%')
        Text(`${this.account.identityRole === IdentityRole.STUDENT ? '学号' : '工号'}：${this.account.identityNumber}`)
          .fontSize(14).fontColor(COLOR_SECONDARY).width('100%')
        TextInput({ text: this.nickname, placeholder: '昵称' }).backgroundColor(COLOR_SURFACE).onChange((value: string) => this.nickname = value)
        TextInput({ text: this.department, placeholder: '院系/部门' }).backgroundColor(COLOR_SURFACE).onChange((value: string) => this.department = value)
        if (this.account.identityRole === IdentityRole.STUDENT) {
          TextInput({ text: this.grade, placeholder: '年级' }).backgroundColor(COLOR_SURFACE).onChange((value: string) => this.grade = value)
        }
        TextInput({ text: this.contact, placeholder: '可选手机号或微信联系方式' }).backgroundColor(COLOR_SURFACE).onChange((value: string) => this.contact = value)
        Row({ space: 10 }) {
          Button('主校区').layoutWeight(1).backgroundColor(this.campus === '主校区' ? COLOR_PRIMARY : COLOR_SURFACE)
            .fontColor(this.campus === '主校区' ? COLOR_SURFACE : COLOR_SECONDARY).onClick(() => this.campus = '主校区')
          Button('分校区').layoutWeight(1).backgroundColor(this.campus === '分校区' ? COLOR_PRIMARY : COLOR_SURFACE)
            .fontColor(this.campus === '分校区' ? COLOR_SURFACE : COLOR_SECONDARY).onClick(() => this.campus = '分校区')
        }.width('100%')
        Button('保存资料').width('100%').backgroundColor(COLOR_PRIMARY).onClick(() => {
          this.store.updateProfile({ nickname: this.nickname, department: this.department, grade: this.grade,
            campus: this.campus, contact: this.contact }).then((value: string) => {
            this.message = value.length === 0 ? '资料已保存' : value; this.onChanged();
          }).catch(() => this.message = '资料保存失败，请稍后重试');
        })
        if (this.message.length > 0) { Text(this.message).fontColor(this.message.includes('保存') ? COLOR_SUCCESS : COLOR_DANGER) }
      }.padding(18).width('100%')
    }.width('100%').height('100%').backgroundColor(COLOR_BACKGROUND).scrollBar(BarState.Off)
  }
}

@Component
struct SecurityPage {
  @ObjectLink authStore: AuthStore;
  @ObjectLink appStore: AppStore;
  account: UserAccount = placeholderAccount();
  @Prop revision: number = 0;
  onBack: () => void = () => {};
  onChanged: () => void = () => {};
  @State oldPassword: string = '';
  @State newPassword: string = '';
  @State phone: string = '';
  @State email: string = '';
  @State code: string = '';
  @State message: string = '';
  @State confirmDelete: boolean = false;

  build() {
    Scroll() {
      Column({ space: 14 }) {
        Row() { Button('‹ 返回').backgroundColor(Color.Transparent).fontColor(COLOR_PRIMARY).onClick(this.onBack); Blank() }.width('100%')
        Text('账号与安全').fontSize(30).fontWeight(FontWeight.Bold).width('100%')
        Column({ space: 10 }) {
          Text('修改密码').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
          TextInput({ text: this.oldPassword, placeholder: '原密码（或使用下方手机验证码）' }).type(InputType.Password).backgroundColor('#F2F2F7')
            .onChange((value: string) => this.oldPassword = value)
          TextInput({ text: this.newPassword, placeholder: '新密码' }).type(InputType.Password).backgroundColor('#F2F2F7')
            .onChange((value: string) => this.newPassword = value)
          TextInput({ text: this.code, placeholder: '验证码（可选）' }).backgroundColor('#F2F2F7').onChange((value: string) => this.code = value)
          Row() {
            Button('发送手机验证码').backgroundColor('#EAF3FF').fontColor(COLOR_PRIMARY)
              .onClick(() => this.message = this.authStore.sendCode(this.account.phone, VerificationPurpose.RESET_PASSWORD))
            Blank()
            if (this.authStore.demoCode.length > 0) { Text(`演示码 ${this.authStore.demoCode}`).fontSize(12).fontColor(COLOR_WARNING) }
          }.width('100%')
          Button('更新密码').width('100%').backgroundColor(COLOR_PRIMARY).onClick(() => {
            this.authStore.changePassword(this.oldPassword, this.newPassword, this.code).then((value: string) =>
              this.message = value.length === 0 ? '密码已更新' : value)
              .catch(() => this.message = '密码更新失败，请稍后重试');
          })
        }.width('100%').padding(16).backgroundColor(COLOR_SURFACE).borderRadius(18)
        Column({ space: 10 }) {
          Text('绑定联系方式').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
          Text(`当前手机：${this.account.phone.length > 0 ? this.account.phone : '未绑定'}`).fontSize(13).fontColor(COLOR_SECONDARY).width('100%')
          TextInput({ text: this.phone, placeholder: '新手机号' }).backgroundColor('#F2F2F7').onChange((value: string) => this.phone = value)
          Button('获取新手机号验证码').width('100%').backgroundColor('#EAF3FF').fontColor(COLOR_PRIMARY)
            .onClick(() => this.message = this.authStore.sendCode(this.phone, VerificationPurpose.BIND_PHONE))
          Button('确认换绑手机').width('100%').backgroundColor(COLOR_PRIMARY).onClick(() => {
            this.authStore.bindPhone(this.phone, this.code)
              .then((value: string) => this.message = value.length === 0 ? '手机号已更新' : value)
              .catch(() => this.message = '手机号更新失败，请稍后重试');
          })
          Text(`当前邮箱：${this.account.email.length > 0 ? this.account.email : '未绑定'}`).fontSize(13).fontColor(COLOR_SECONDARY).width('100%')
          TextInput({ text: this.email, placeholder: '新学校邮箱' }).backgroundColor('#F2F2F7').onChange((value: string) => this.email = value)
          Button('获取新邮箱验证码').width('100%').backgroundColor('#EAF3FF').fontColor(COLOR_PRIMARY)
            .onClick(() => this.message = this.authStore.sendCode(this.email, VerificationPurpose.BIND_EMAIL))
          Button('确认换绑邮箱').width('100%').backgroundColor(COLOR_PRIMARY).onClick(() => {
            this.authStore.bindEmail(this.email, this.code)
              .then((value: string) => this.message = value.length === 0 ? '邮箱已更新' : value)
              .catch(() => this.message = '邮箱更新失败，请稍后重试');
          })
        }.width('100%').padding(16).backgroundColor(COLOR_SURFACE).borderRadius(18)
        if (this.message.length > 0) { Text(this.message).fontSize(13).fontColor(this.message.includes('已') ? COLOR_SUCCESS : COLOR_DANGER) }
        Button('退出登录').width('100%').backgroundColor(COLOR_SURFACE).fontColor(COLOR_TEXT)
          .onClick(() => this.authStore.logout().then(() => this.onChanged())
            .catch(() => this.message = '退出失败，请稍后重试'))
        Button(this.confirmDelete ? '再次点击确认注销账号' : '注销账号').width('100%').backgroundColor('#FFE8E6').fontColor(COLOR_DANGER).onClick(() => {
          if (!this.confirmDelete) { this.confirmDelete = true; this.message = '注销后无法恢复，请再次点击确认'; return; }
          this.authStore.deleteSelf(this.appStore.hasOpenPosts()).then((value: string) => {
            this.message = value.length === 0 ? '账号已注销' : value;
            this.confirmDelete = false;
            if (value.length === 0) { this.onChanged(); }
          }).catch(() => this.message = '账号注销失败，请稍后重试');
        })
        if (this.appStore.hasOpenPosts()) {
          Text('当前存在未完结动态，需完成归还或关闭后才能注销。').fontSize(12).fontColor(COLOR_WARNING)
        }
      }.padding(18).width('100%')
    }.width('100%').height('100%').backgroundColor(COLOR_BACKGROUND).scrollBar(BarState.Off)
  }
}

@Component
struct AdminDashboard {
  @ObjectLink store: AuthStore;
  @ObjectLink contentStore: AppStore;
  account: UserAccount = placeholderAccount();
  @Prop revision: number = 0;
  accessToken: string = '';
  apiRepository: ContentApiRepository = new ContentApiRepository();
  onChanged: () => void = () => {};
  onLogout: () => void = () => {};
  @State roleFilter: string = '';
  @State statusFilter: string = '';
  @State departmentFilter: string = '';
  @State selectedUserId: string = '';
  @State reason: string = '';
  @State message: string = '';
  @State confirmAction: string = '';
  @State managedPosts: Post[] = [];
  @State postsLoading: boolean = false;

  aboutToAppear(): void {
    this.loadManagedPosts();
  }

  private async loadManagedPosts(): Promise<void> {
    this.postsLoading = true;
    try {
      this.managedPosts = this.accessToken.length > 0 ?
        await this.apiRepository.listAdminPosts(this.accessToken) : this.contentStore.posts.slice();
    } catch (error) {
      this.message = '帖子列表加载失败，请稍后重试';
      this.managedPosts = this.contentStore.posts.slice();
    } finally {
      this.postsLoading = false;
    }
  }

  private async changePostStatus(post: Post, status: PostStatus): Promise<void> {
    try {
      const updated: Post = this.accessToken.length > 0 ?
        (status === PostStatus.DELETED ? await this.apiRepository.setPostDeleted(this.accessToken, post.id) :
          await this.apiRepository.restorePost(this.accessToken, post.id)) : post;
      if (this.accessToken.length === 0) {
        this.contentStore.setAdminPostStatus(post.id, status);
        this.managedPosts = this.contentStore.posts.slice();
      } else {
        const index: number = this.managedPosts.findIndex((item: Post) => item.id === post.id);
        if (index >= 0) {
          this.managedPosts[index] = updated;
          this.managedPosts = this.managedPosts.slice();
        }
      }
      this.message = status === PostStatus.DELETED ? '帖子已删除，可随时恢复' : '帖子已恢复';
      this.onChanged();
    } catch (error) {
      this.message = error instanceof Error ? error.message : '帖子操作失败，请稍后重试';
    }
  }

  private selectedUser(): UserAccount | undefined {
    return this.store.accounts.find((item: UserAccount) => item.id === this.selectedUserId);
  }

  build() {
    if (this.selectedUserId.length > 0 && this.selectedUser() !== undefined) {
      this.userDetail(this.selectedUser() as UserAccount)
    } else {
      this.userList()
    }
  }

  @Builder
  userList() {
    Scroll() {
      Column({ space: 14 }) {
        Row() {
          Column({ space: 4 }) {
            Text('用户管理').fontSize(30).fontWeight(FontWeight.Bold).fontColor(COLOR_TEXT)
            Text(`管理员：${this.account.nickname}`).fontSize(13).fontColor(COLOR_SECONDARY)
          }.alignItems(HorizontalAlign.Start)
          Blank()
          Button('退出').backgroundColor('#EFEFF4').fontColor(COLOR_DANGER).onClick(this.onLogout)
        }.width('100%')
        TextInput({ text: this.departmentFilter, placeholder: '按院系或部门精确筛选' }).backgroundColor(COLOR_SURFACE)
          .onChange((value: string) => this.departmentFilter = value)
        Scroll() {
          Row({ space: 8 }) {
            ForEach(['', IdentityRole.STUDENT, IdentityRole.TEACHER, IdentityRole.STAFF], (item: string) => {
              Button(item.length === 0 ? '全部角色' : roleLabel(item as IdentityRole)).fontSize(12)
                .backgroundColor(this.roleFilter === item ? COLOR_PRIMARY : COLOR_SURFACE)
                .fontColor(this.roleFilter === item ? COLOR_SURFACE : COLOR_SECONDARY).onClick(() => this.roleFilter = item)
            })
          }
        }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
        Row({ space: 8 }) {
          ForEach(['', AccountStatus.NORMAL, AccountStatus.FROZEN, AccountStatus.DELETED], (item: string) => {
            Button(item.length === 0 ? '全部状态' : (item === AccountStatus.NORMAL ? '正常' : (item === AccountStatus.FROZEN ? '冻结' : '已注销')))
              .fontSize(12).backgroundColor(this.statusFilter === item ? COLOR_TEXT : COLOR_SURFACE)
              .fontColor(this.statusFilter === item ? COLOR_SURFACE : COLOR_SECONDARY).onClick(() => this.statusFilter = item)
          })
        }.width('100%')
        Text(`${this.store.filteredUsers(this.roleFilter, this.departmentFilter, this.statusFilter).length} 位用户`)
          .fontSize(14).fontColor(COLOR_SECONDARY).width('100%')
        ForEach(this.store.filteredUsers(this.roleFilter, this.departmentFilter, this.statusFilter), (user: UserAccount) => {
          Row({ space: 14 }) {
            Text(user.isAdmin ? '🛡️' : (user.identityRole === IdentityRole.STUDENT ? '🎓' : '👤')).fontSize(28)
              .width(54).height(54).textAlign(TextAlign.Center).backgroundColor('#EAF3FF').borderRadius(16)
            Column({ space: 5 }) {
              Row({ space: 6 }) {
                Text(user.nickname).fontSize(16).fontWeight(FontWeight.Bold)
                if (user.isAdmin) { Text('管理员').fontSize(10).fontColor(COLOR_PRIMARY) }
              }
              Text(`${roleLabel(user.identityRole)} · ${user.department}`).fontSize(12).fontColor(COLOR_SECONDARY)
              Text(user.status === AccountStatus.NORMAL ? '正常' : (user.status === AccountStatus.FROZEN ? '已冻结' : '已注销'))
                .fontSize(12).fontColor(user.status === AccountStatus.NORMAL ? COLOR_SUCCESS : COLOR_DANGER)
            }.alignItems(HorizontalAlign.Start).layoutWeight(1)
            Text('›').fontSize(24).fontColor(COLOR_SECONDARY)
          }.width('100%').padding(16).backgroundColor(COLOR_SURFACE).borderRadius(18)
            .onClick(() => this.selectedUserId = user.id)
        }, (user: UserAccount) => user.id)
        this.postManagement()
      }.padding({ left: 18, right: 18, top: 28, bottom: 36 }).width('100%')
    }.width('100%').height('100%').backgroundColor(COLOR_BACKGROUND).scrollBar(BarState.Off)
  }

  @Builder
  postManagement() {
    Column({ space: 10 }) {
      Row() {
        Text('帖子管理').fontSize(18).fontWeight(FontWeight.Bold)
        Blank()
        if (this.postsLoading) { Text('加载中…').fontSize(12).fontColor(COLOR_SECONDARY) }
      }.width('100%')
      if (!this.postsLoading && this.managedPosts.length === 0) {
        Text('暂无帖子').fontSize(13).fontColor(COLOR_SECONDARY).width('100%')
      }
      ForEach(this.managedPosts, (post: Post) => {
        Row({ space: 10 }) {
          Column({ space: 4 }) {
            Text(post.title).fontSize(14).fontWeight(FontWeight.Medium).width('100%')
            Text(`${post.ownerName} · ${post.status === PostStatus.DELETED ? '已删除' : postStatusLabel(post.status)}`)
              .fontSize(12).fontColor(post.status === PostStatus.DELETED ? COLOR_DANGER : COLOR_SECONDARY)
          }.alignItems(HorizontalAlign.Start).layoutWeight(1)
          Button(post.status === PostStatus.DELETED ? '恢复' : '删除').fontSize(12)
            .backgroundColor(post.status === PostStatus.DELETED ? '#E8F8EC' : '#FFE8E6')
            .fontColor(post.status === PostStatus.DELETED ? COLOR_SUCCESS : COLOR_DANGER)
            .onClick(() => this.changePostStatus(post, post.status === PostStatus.DELETED ? PostStatus.ACTIVE : PostStatus.DELETED))
        }.width('100%').padding(12).backgroundColor(COLOR_SURFACE).borderRadius(14)
      }, (post: Post) => post.id)
      if (this.message.length > 0) {
        Text(this.message).fontSize(13).fontColor(this.message.includes('失败') ? COLOR_DANGER : COLOR_SUCCESS)
          .width('100%')
      }
    }.width('100%').padding(16).backgroundColor('#F7F8FC').borderRadius(18)
  }

  @Builder
  userDetail(user: UserAccount) {
    Scroll() {
      Column({ space: 14 }) {
        Row() { Button('‹ 用户列表').backgroundColor(Color.Transparent).fontColor(COLOR_PRIMARY).onClick(() => this.selectedUserId = ''); Blank() }.width('100%')
        Row({ space: 16 }) {
          Text(user.isAdmin ? '🛡️' : '👤').fontSize(44).width(78).height(78).textAlign(TextAlign.Center).backgroundColor('#EAF3FF').borderRadius(24)
          Column({ space: 5 }) {
            Text(user.nickname).fontSize(24).fontWeight(FontWeight.Bold)
            Text(`${roleLabel(user.identityRole)} · ${user.isAdmin ? '管理员权限' : '普通权限'}`).fontSize(13).fontColor(COLOR_PRIMARY)
            Text(user.status === AccountStatus.NORMAL ? '账号正常' : (user.status === AccountStatus.FROZEN ? '账号已冻结' : '账号已注销'))
              .fontSize(13).fontColor(user.status === AccountStatus.NORMAL ? COLOR_SUCCESS : COLOR_DANGER)
          }.alignItems(HorizontalAlign.Start)
        }.width('100%')
        Column({ space: 8 }) {
          Text('认证资料').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
          Text(`真实姓名：${user.realName}`).fontSize(14).fontColor(COLOR_SECONDARY).width('100%')
          Text(`${user.identityRole === IdentityRole.STUDENT ? '学号' : '工号'}：${user.identityNumber}`).fontSize(14).fontColor(COLOR_SECONDARY).width('100%')
          Text(`院系/部门：${user.department}`).fontSize(14).fontColor(COLOR_SECONDARY).width('100%')
          Text(`手机号：${user.phone}  邮箱：${user.email}`).fontSize(14).fontColor(COLOR_SECONDARY).width('100%')
          Text(`校区：${user.campus}  信用分：${user.creditScore}`).fontSize(14).fontColor(COLOR_SECONDARY).width('100%')
        }.width('100%').padding(16).backgroundColor(COLOR_SURFACE).borderRadius(18)
        Column({ space: 8 }) {
          Text('发布记录').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
          if (this.contentStore.posts.filter((post: Post) => post.ownerId === user.id).length === 0) {
            Text('暂无发布记录').fontSize(13).fontColor(COLOR_SECONDARY).width('100%')
          }
          ForEach(this.contentStore.posts.filter((post: Post) => post.ownerId === user.id), (post: Post) => {
            Row() {
              Text(post.title).fontSize(14).fontColor(COLOR_TEXT).layoutWeight(1)
              Text(post.status === PostStatus.ACTIVE ? '进行中' : (post.status === PostStatus.CLAIMING ? '认领中' : '已结束'))
                .fontSize(12).fontColor(COLOR_SECONDARY)
            }.width('100%')
          }, (post: Post) => post.id)
        }.width('100%').padding(16).backgroundColor(COLOR_SURFACE).borderRadius(18)
        Column({ space: 8 }) {
          Text('违规与管理记录').fontSize(18).fontWeight(FontWeight.Bold).width('100%')
          if (user.violations.length === 0 && user.auditLogs.length === 0) { Text('暂无违规或管理记录').fontColor(COLOR_SECONDARY) }
          ForEach(user.violations, (item: string) => { Text(`• ${item}`).fontSize(13).fontColor(COLOR_DANGER).width('100%') })
          ForEach(user.auditLogs, (item: AuditLog) => { Text(`${item.action} · ${item.reason}`).fontSize(13).fontColor(COLOR_SECONDARY).width('100%') })
        }.width('100%').padding(16).backgroundColor(COLOR_SURFACE).borderRadius(18)
        TextInput({ text: this.reason, placeholder: '冻结或注销原因（冻结时必填）' }).backgroundColor(COLOR_SURFACE)
          .onChange((value: string) => this.reason = value)
        if (user.status === AccountStatus.NORMAL) {
          Button(this.confirmAction === 'freeze' ? '再次点击确认冻结' : '冻结账号').width('100%').backgroundColor('#FFF4E5').fontColor(COLOR_WARNING).onClick(() => {
            if (this.confirmAction !== 'freeze') { this.confirmAction = 'freeze'; this.message = '请再次点击确认冻结该账号'; return; }
            this.store.freezeUser(user.id, this.reason).then((value: string) => {
              this.message = value.length === 0 ? '账号已冻结' : value; this.confirmAction = ''; this.onChanged();
            }).catch(() => this.message = '冻结操作失败，请稍后重试');
          })
        } else if (user.status === AccountStatus.FROZEN) {
          Button('解除冻结').width('100%').backgroundColor('#E8F8EC').fontColor(COLOR_SUCCESS).onClick(() => {
            this.store.unfreezeUser(user.id).then((value: string) => {
              this.message = value.length === 0 ? '账号已解冻' : value; this.onChanged();
            }).catch(() => this.message = '解冻操作失败，请稍后重试');
          })
        }
        if (user.status !== AccountStatus.DELETED) {
          Button(this.confirmAction === 'role' ? '再次点击确认权限变更' : (user.isAdmin ? '降级为普通用户' : '提升为管理员'))
            .width('100%').backgroundColor('#EAF3FF').fontColor(COLOR_PRIMARY)
            .onClick(() => {
              if (this.confirmAction !== 'role') { this.confirmAction = 'role'; this.message = '请再次点击确认权限变更'; return; }
              this.store.setAdmin(user.id, !user.isAdmin).then((value: string) => {
                this.message = value.length === 0 ? '角色权限已更新' : value; this.confirmAction = ''; this.onChanged();
              }).catch(() => this.message = '权限更新失败，请稍后重试');
            })
          Button(this.confirmAction === 'delete' ? '再次点击确认强制注销' : '强制注销账号')
            .width('100%').backgroundColor('#FFE8E6').fontColor(COLOR_DANGER).onClick(() => {
            if (this.confirmAction !== 'delete') { this.confirmAction = 'delete'; this.message = '请再次点击确认强制注销'; return; }
            this.store.deleteUser(user.id, this.reason).then((value: string) => {
              this.message = value.length === 0 ? '账号已强制注销' : value; this.confirmAction = ''; this.onChanged();
            }).catch(() => this.message = '注销操作失败，请稍后重试');
          })
        }
        if (this.message.length > 0) { Text(this.message).fontSize(13).fontColor(this.message.includes('已') ? COLOR_SUCCESS : COLOR_DANGER) }
        Text('高影响操作在演示环境中立即生效并写入审计记录。').fontSize(12).fontColor(COLOR_SECONDARY)
      }.padding(18).width('100%')
    }.width('100%').height('100%').backgroundColor(COLOR_BACKGROUND).scrollBar(BarState.Off)
  }
}
