# 校园失物招领测试流程

本流程覆盖启动白屏回归、账号与内容持久化、账号隔离、核心认领流程、验证码规则和管理员操作。项目未配置签名，本流程不要求生成 HAP 或发布安装包。

## 一、测试前准备

1. 使用与工程匹配的 DevEco Studio 和 HarmonyOS 6.1.1 / API 24 SDK。
2. 连接模拟器或真机；若只做自动化检查，可以不连接设备。
3. 如需从全新数据开始，在设备系统设置中手动清除本应用数据，再首次启动应用。
4. 验证跨重启持久化时，不要通过会卸载应用的运行方式重装；在 DevEco Studio 的 Run/Debug Configuration 中启用 **Keep Application Data**，或从设备最近任务中结束后直接重新打开。
5. 演示账号：
   - 学生：`13800000001` / `lin@campus.edu.cn` / `Campus123`
   - 管理员：`admin@campus.edu.cn` / `Admin1234`

## 二、自动化检查

在项目根目录的 PowerShell 中执行 ArkTS 编译检查：

```powershell
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$env:Path = 'C:\Program Files\Huawei\DevEco Studio\tools\node;' + $env:Path
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module `
  -p product=default `
  -p module=entry@default `
  -p buildMode=debug `
  'default@CompileArkTS' `
  --no-daemon `
  --no-incremental
```

预期：输出 `BUILD SUCCESSFUL`，不存在 ArkTS Compiler Error。

执行 Hypium 测试：

```powershell
$env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk'
$env:Path = 'C:\Program Files\Huawei\DevEco Studio\tools\node;' + $env:Path
& 'C:\Program Files\Huawei\DevEco Studio\tools\hvigor\bin\hvigorw.bat' `
  --mode module `
  -p product=default `
  -p module=entry@default `
  -p buildMode=debug `
  test `
  --no-daemon `
  --no-incremental
```

预期：测试任务和构建均成功。重点覆盖验证码冷却/过期/一次性消费、邮箱规范化、内容快照深拷贝、消息已读、认领授权、归还状态流和 Preferences 大数据分片。

## 三、启动白屏回归

1. 启动应用并观察首屏。
2. 冷启动时应短暂显示“正在恢复账号与会话”，随后显示登录页或已恢复的业务首页。
3. 等待 10 秒并切换前后台一次。

预期：页面始终有可见内容且可以点击；不会出现整页空白；初始化失败时显示“暂时无法打开应用”和“重新加载”，而不是永久加载或白屏。

## 四、登录、会话与验证码

1. 在“密码登录”中分别使用学生手机号 `13800000001` 和学校邮箱 `lin@campus.edu.cn`，搭配密码 `Campus123` 登录。
2. 退出后选择“验证码登录”，确认页面只有“手机号或学校邮箱”和“验证码”字段，不出现密码标签、密码占位符或密码输入键盘。
3. 保留默认手机号 `13800000001` 并获取演示验证码；不刷新页面、不切换页签，确认六位验证码立即显示。
4. 立即再次获取验证码，确认提示稍后再试；输入页面验证码并点击一次登录，确认直接进入首页。
5. 退出后再次使用上一步验证码，确认验证码不能重用。
6. 再次进入“验证码登录”，输入 ` LIN@CAMPUS.EDU.CN `（含首尾空格和大写字母），获取新验证码并登录。
7. 退出后输入未注册手机号 `13999999999` 获取验证码，确认不显示可用验证码并提示未注册。
8. 使用已冻结账号 `13800000005` 获取验证码，确认提示账号已冻结。
9. 在“密码登录”中使用 ` ADMIN@CAMPUS.EDU.CN ` / `Admin1234`，确认进入管理员工作台。

预期：密码与验证码模式的字段不会互相残留；手机号和学校邮箱都能使用验证码登录；验证码和登录结果无需刷新、切换页面或重启应用即可显示；60 秒内不能重复发送；验证码只能用于发放时的手机号或邮箱且成功使用一次后失效；邮箱登录忽略首尾空格和大小写差异；未知、冻结或注销账号不能获取登录验证码。

## 五、普通用户内容与重启持久化

1. 登录学生账号。
2. 在首页任选一条动态，执行点赞、收藏和评论。
3. 发布一条标题唯一的新动态，例如“持久化测试-当前时间”。
4. 在消息页点击一条带蓝点的未读消息，再返回消息页。
5. 结束应用进程但保留应用数据，然后重新打开。

预期：登录会话自动恢复；点赞、收藏、评论、新发布动态和消息已读状态均保留；消息蓝点不会重新出现。

## 六、账号隔离

1. 记下学生账号刚发布的唯一标题并退出登录。
2. 通过注册页创建一个新的普通账号；验证码直接使用页面显示的演示码。
3. 登录新账号，检查首页、收藏和“我的发布”。
4. 在新账号发布另一条唯一标题后退出，再登录原学生账号。

预期：两个账号各自恢复自己的内容快照；对方的唯一标题、点赞/收藏和消息已读状态不会串号。

## 七、认领、线索与授权

1. 登录学生演示账号，打开本人发布的“图书馆拾到钥匙串”。
2. 对预置认领申请点击“同意认领”，确认状态变为“认领中”。
3. 点击“确认已归还”，确认状态变为“已归还”，消息中出现完成通知。
4. 打开其他用户发布的失物信息，填写特征后提交认领。
5. 打开其他用户发布的寻物信息，填写地点或时间线索并提交。
6. 重新打开应用复查上述状态。

预期：只有动态发布者看到审核与确认归还按钮；非发布者不能审核；所有状态和记录在重启后保留；已关闭状态显示“已关闭”而不是“已归还”。

## 八、资料、安全与管理员操作

1. 编辑昵称或院系并保存，重启应用后检查资料。
2. 修改密码，退出后分别用旧密码和新密码登录。
3. 进入管理员工作台，选择非当前管理员账号，依次验证冻结、解冻和管理员权限变更的二次确认。
4. 尝试对当前管理员本人执行冻结、注销或降级。

预期：资料和密码修改持久化；旧密码失效、新密码有效；管理员操作有明确成功或失败提示；管理员不能冻结、注销或降级自己；存储操作失败时页面给出错误消息，不会无反馈。

## 九、华为官方 API 核对点

- [Navigation 组件参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/ts-basic-components-navigation-V5#hidenavbar9)：`hideNavBar(true)` 隐藏的是 Navigation 导航栏区域，不适用于本项目这种直接在导航栏区域渲染根内容的结构；本项目仅使用 `hideTitleBar(true)` 隐藏标题栏。
- [Preferences API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references-V5/js-apis-data-preferences-V5)：账号和内容写入后调用并等待 `flush()`；账号列表和内容快照按 8000 字符分片，避免超过 SDK 声明的 `MAX_VALUE_LENGTH`。
- [ArkUI @State](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides-V2/arkts-state-0000001474017162-V2)：启动、错误和修订状态使用 `@State`，状态变化触发页面重新渲染。

## 十、结果记录模板

| 用例 | 结果 | 设备/系统 | 备注 |
| --- | --- | --- | --- |
| ArkTS 编译 | 通过/失败 | 本机 |  |
| Hypium 测试 | 通过/失败 | 本机 |  |
| 冷启动无白屏 | 通过/失败 |  |  |
| 会话跨重启 | 通过/失败 |  |  |
| 内容跨重启 | 通过/失败 |  |  |
| 账号隔离 | 通过/失败 |  |  |
| 消息已读 | 通过/失败 |  |  |
| 认领授权与归还 | 通过/失败 |  |  |
| 管理员操作 | 通过/失败 |  |  |
