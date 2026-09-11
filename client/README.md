# Flutter 客户端

当前为页面入口代码基础，未生成 Android 平台工程，未接入内核，也未完成构建验证。完整进度见 ../docs/IMPLEMENTATION-PLAN.md。

工具链准备好后，在本目录执行：

```powershell
flutter create --platforms=android --android-language=kotlin --project-name=lansway --org=dev.lansway .
flutter pub get
flutter analyze
flutter test
flutter run
```

dev.lansway 为开发阶段命名，发布应用 ID 与签名需在发行前确定。不要提交 local.properties、SDK、签名密钥或生成产物。Flutter SDK 当前使用 stable 渠道；首次成功构建时记录并锁定版本。生成模板后检查已有 lib/main.dart 与测试，避免模板计数器覆盖应用入口。
