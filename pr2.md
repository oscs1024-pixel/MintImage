# GPT Image Flutter — 详细需求文档 v2

> 基于 pr.md 进一步细化，补充架构、数据模型、API 参数、组件规范及测试方案。  
> 最后更新：同步 pr.md 补充内容（多图附件、多组API配置、底部输入框浮动样式、源API选择器）。

---

## 0. 开发环境准备

> 本机当前未安装 Flutter，需在开始编码前完成以下安装步骤。

| 步骤 | 操作 |
|------|------|
| 1 | 下载并安装 [Flutter 最新稳定版](https://docs.flutter.dev/get-started/install)，配置 `PATH` |
| 2 | 运行 `flutter doctor`，按提示修复所有依赖项 |
| 3 | **Windows**：安装 Visual Studio（含 Desktop Development with C++） |
| 4 | **Android**：安装 Android Studio + SDK，接受 licenses（`flutter doctor --android-licenses`） |
| 5 | **iOS/macOS**：需 Mac 环境，安装 Xcode + CocoaPods |
| 6 | 安装 VS Code Flutter 插件（或 Android Studio Flutter 插件） |

---

## 1. 项目概述

| 项目 | 内容 |
|------|------|
| 名称 | gpt_image_flutter |
| 描述 | 跨平台 Flutter 客户端，用于调用 OpenAI gpt-image-2 文生图 / 图生图接口 |
| 目标平台 | Windows · macOS · iOS · Android |
| 当前优先 | Windows + 当前可连调的移动平台 |
| 主色调 | 浅蓝色（#4FC3F7 / #0288D1 系列） |
| 开发前置 | 本机未安装 Flutter，需先安装最新稳定版及对应平台 tools（Android SDK、Xcode、VS Build Tools 等） |

---

## 2. 技术栈与架构

### 2.1 依赖库

| 分类 | 包名 | 用途 |
|------|------|------|
| 状态管理 | `flutter_riverpod` | 全局状态 |
| HTTP | `dio` | API 请求，支持取消、进度 |
| 本地持久化 | `drift` + `sqlite3_flutter_libs` | 历史记录存储 |
| 设置 | `shared_preferences` | key / baseUrl / model 持久化（支持多组配置） |
| 图片缓存 | `cached_network_image` | 列表缩略图缓存 |
| 图片选择 | `image_picker` | 移动端选图；`file_picker` 桌面端 |
| 文件保存 | `path_provider` + `flutter_file_dialog` | 本地保存图片 |
| 后台保活 | `flutter_background_service` | 移动端生成时保活（可选） |
| 图片预览 | `photo_view` | 全屏预览 |
| 通知 | `flutter_local_notifications` | 移动端生成完成推送 |

### 2.2 目录结构

```
lib/
├── main.dart
├── app.dart                        # MaterialApp + theme
├── core/
│   ├── api/
│   │   ├── openai_client.dart      # Dio 实例，BaseUrl 动态注入
│   │   ├── image_generation_api.dart
│   │   └── image_edit_api.dart
│   ├── models/
│   │   ├── generation_request.dart
│   │   ├── generation_result.dart
│   │   └── settings_model.dart
│   ├── database/
│   │   ├── app_database.dart       # Drift DB
│   │   └── image_record_dao.dart
│   └── providers/
│       ├── settings_provider.dart
│       ├── image_list_provider.dart
│       └── generation_provider.dart
├── features/
│   ├── home/
│   │   └── home_page.dart
│   ├── image_list/
│   │   ├── image_list_widget.dart
│   │   └── image_cell.dart
│   ├── input/
│   │   ├── bottom_input_bar.dart
│   │   ├── attachment_preview_strip.dart  # 多图叠放缩略图
│   │   ├── size_selector.dart
│   │   ├── quality_selector.dart
│   │   ├── quantity_selector.dart
│   │   └── api_profile_selector.dart     # 源API名切换
│   └── settings/
│       ├── settings_page.dart
│       └── api_profile_edit_page.dart    # 单组配置编辑页
└── shared/
    ├── theme.dart
    └── widgets/
        ├── loading_image_cell.dart
        └── empty_state.dart
test/
├── api/
│   ├── image_generation_test.dart
│   └── image_edit_test.dart
└── models/
    └── generation_request_test.dart
```

---

## 3. 数据模型

### 3.1 `ImageRecord`（Drift 表，持久化）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (UUID) | 主键 |
| prompt | String | 用户输入提示词 |
| sourceImagePath | String? | 图生图时的原图本地路径 |
| resultImagePath | String? | 生成结果本地缓存路径 |
| resultImageUrl | String? | 返回的 URL（url 模式） |
| resultB64 | String? | Base64 原始数据（b64_json 模式） |
| width | int | 实际请求宽度（px） |
| height | int | 实际请求高度（px） |
| quality | String | low / medium / high |
| model | String | 模型名称，默认 gpt-image-2 |
| status | String | pending / loading / done / error |
| errorMessage | String? | 错误原因 |
| createdAt | DateTime | 创建时间戳 |
| durationMs | int? | 生成耗时（毫秒） |

### 3.2 `ApiProfile`（单组 API 配置）与 `SettingsModel`

**`ApiProfile`**（多组配置的单条记录，持久化为 JSON 列表存入 SharedPreferences）

| 字段 | 类型 | 说明 |
|------|------|------|
| id | String (UUID) | 唯一标识 |
| name | String | 用户命名，第一组固定显示"默认" |
| baseUrl | String | 如 `https://api.openai.com` |
| apiKey | String | 对应 key |
| model | String | 默认 `gpt-image-2` |

**`SettingsModel`**（内存 + 持久化）

| 字段 | 类型 | 默认值 |
|------|------|--------|
| profiles | `List<ApiProfile>` | 含一条默认配置 |
| activeProfileId | String | 第一条配置的 id |
| responseFormat | String | `b64_json` |

> 底部输入区域的"源API名"选择器直接切换 `activeProfileId`，生成请求使用当前激活的 Profile。

### 3.3 `GenerationRequest`（内存，发起请求前构建）

```dart
class GenerationRequest {
  final String prompt;
  final List<String> imagePaths;  // 图生图用，支持多张；空列表 = 文生图
  final SizePreset sizePreset;    // 枚举 + 自定义
  final int customWidth;
  final int customHeight;
  final ImageQuality quality;     // low / medium / high
  final int count;                // 1–16，触发 count 次独立请求
  final String apiProfileId;      // 使用哪组 API 配置
}
```

---

## 4. API 集成

### 4.1 文生图接口

```
POST {baseUrl}/v1/images/generations
Content-Type: application/json
Authorization: Bearer {apiKey}

{
  "model": "{model}",
  "prompt": "{prompt}",
  "n": 1,                        // 固定 1，由客户端循环 count 次
  "size": "{width}x{height}",   // 如 "1024x1024"
  "quality": "low|medium|high",
  "response_format": "b64_json"  // 推荐，避免 URL 过期
}
```

**响应**

```json
{
  "created": 1715000000,
  "data": [
    { "b64_json": "..." }
  ]
}
```

### 4.2 图生图接口

```
POST {baseUrl}/v1/images/edits
Content-Type: multipart/form-data
Authorization: Bearer {apiKey}

model={model}
image[]=@{imagePath1}           // 支持多张图，gpt-image-2 edits API 可接受多个 image 字段
image[]=@{imagePath2}           // PNG，每张 ≤ 25MB
prompt={prompt}
n=1
size={width}x{height}
quality=low|medium|high
response_format=b64_json
```

> 若代理服务不支持多图，退化为仅发送第一张图并在界面提示。

### 4.3 尺寸映射表

| 选项标签 | 发送给 API 的 size |
|----------|-------------------|
| 方形成图 1K | `1024x1024` |
| 竖版海报 | `1024x1536` |
| 横版海报 | `1536x1024` |
| 竖屏故事 9:16 | `1088x1920` |
| 视频封面 16:9 | `1920x1088` |
| 宽屏展示 2K | `2560x1440` |
| 高清竖图 2K | `1440x2560` |
| 高清方图 2K | `2048x2048` |
| 高清竖图 4K | `2160x3840` |
| 宽屏展示 4K | `3840x2160` |
| 自定义 | 弹出输入框，用户填写 width × height |

> ⚠️ gpt-image-2 官方仅明确支持 `1024x1024`、`1024x1536`、`1536x1024`；2K/4K 等超分辨率取决于第三方代理（如 packyapi）的兼容性。界面上所有选项均可发送，API 若返回错误则展示错误信息。

### 4.4 并发策略

- `count > 1` 时，客户端在 `GenerationProvider` 内并发发起 `count` 个独立 HTTP 请求（Future.wait），而非等待顺序完成。
- 每个请求对应一个列表 Cell，独立维护 loading / done / error 状态。
- 每个 Dio 请求绑定一个 `CancelToken`，支持用户手动取消。

---

## 5. 页面与组件

### 5.1 主页面（HomePage）

布局（单页，无底部 Tab）：

```
┌─────────────────────────────┐
│  AppBar: "GPT Image"  ⚙️    │
├─────────────────────────────┤
│                             │
│      ImageListWidget        │  ← 可滚动，占满剩余高度
│                             │
├─────────────────────────────┤
│      BottomInputBar         │  ← 固定在底部，随键盘上移
└─────────────────────────────┘
```

- AppBar 右侧放**齿轮按钮**，点击打开 SettingsPage（push route）。
- 未设置 API Key 时，ImageListWidget 替换为 **EmptyState**（见 5.5）。

---

### 5.2 图片列表（ImageListWidget）

- 使用 `ListView.builder`，数据源为 `imageListProvider`（Riverpod）。
- 列表按 `createdAt` 倒序（最新在顶部）。
- 支持下拉刷新（`RefreshIndicator`），重新从数据库加载。
- 生成中的 Cell 插入列表顶部，状态为 loading。

---

### 5.3 图片列表单元格（ImageCell）

**布局（水平）：**

```
┌─────────────────────────────────────────────┐
│ [图片缩略图]  │ 提示词（最多 2 行，省略）     │
│  固定 80×80  │ 📐 1024×1024  ✨ 高质量       │
│  cover fit  │ 🤖 gpt-image-2  ⏱ 3.2s        │
│             │ 🕐 2025-01-01 12:00            │
└─────────────────────────────────────────────┘
```

- **左侧图片区**：固定 `80×80`（移动端），桌面端 `100×100`，`BoxFit.cover`，加载中显示 `CircularProgressIndicator`，错误显示错误图标。
- **右侧标签区**：
  - 提示词（灰色，最多 2 行）
  - 尺寸标签（实际请求尺寸）
  - 质量标签
  - 模型名
  - 耗时（若已完成）
  - 时间戳
- **移动端一屏可见 4–5 个** Cell（Cell 高度约 88dp）。

**交互：**

| 操作 | 行为 |
|------|------|
| 点击 | 全屏预览图片（`photo_view`），底部显示提示词 |
| 长按 | 弹出 `BottomSheet`，含"以此改图"和"复用提示词"两个选项 |
| 侧滑（移动端） | 右滑显示"复用"和"修改"操作按钮（`Dismissible` 或自定义滑动） |
| 点击"复用" | 将该记录的 prompt 填入 BottomInputBar 输入框 |
| 点击"修改" | 将该记录的 prompt + 图片填入 BottomInputBar（图生图模式） |

---

### 5.4 底部输入区域（BottomInputBar）

**视觉设计：**

- **浮动样式**：InputBar 不贴屏幕底边，四周留边距（水平 12dp，底部 12dp + SafeArea）。
- **圆角卡片**：整体包裹在 `Container` 内，`BorderRadius.circular(24)`，`BoxShadow` 轻微投影，背景白色。
- 随软键盘弹出整体上移（`resizeToAvoidBottomInset: true`）。

```
  ╭──────────────────────────────────────────────────╮
  │ [附件缩略图叠放区（有附件时显示）]                  │
  │────────────────────────────────────────────────── │
  │  📎  [提示词输入框（多行）]                  [▶]  │
  │──────────────────────────────────────────────────│
  │  [尺寸▼]  [质量▼]  [数量▼]  [源API▼]            │
  ╰──────────────────────────────────────────────────╯
```

**输入框：**

- 多行 `TextField`，`minLines: 1`，`maxLines: 6`。
- 桌面端：`Enter` 发送，`Ctrl+Enter` 换行。
- 移动端：软键盘换行键换行，点击发送按钮发送。
- 附件图片预览：选择图片后，在输入框**上方**显示 `AttachmentPreviewStrip`（叠放缩略图，每张可独立删除）。

**附件按钮（📎）：**

- 移动端：调用 `image_picker`（`ImageSource.gallery`），**支持多选**（`pickMultiImage`）。
- 桌面端：调用 `file_picker`，过滤 `.png .jpg .jpeg .webp`，**允许多选**（`allowMultiple: true`）。
- 选择图片后自动切换为图生图模式；所有图片清除后恢复文生图模式。

**附件缩略图区（AttachmentPreviewStrip）：**

- 水平 `Row`，图片叠放（后一张向左偏移约 12dp，`Stack` 实现）。
- 每张缩略图固定 `48×48`，圆角，右上角显示 `×` 删除按钮。
- 超过 5 张时最后一位显示 `+N` 更多标记。

**尺寸选择器（BottomSheet 或 DropdownButton）：**

- 列出 10 个预设 + "自定义"。
- 选择"自定义"时弹出 `AlertDialog`，含 width 和 height 两个数字输入框，确认后关闭。
- 当前选中尺寸以标签形式展示在按钮上（如"1024×1024"）。

**质量选择器：**

- 三个选项：低（`low`）/ 中（`medium`）/ 高（`high`）。
- 默认：中。

**数量选择器：**

- 范围 1–16，默认 1。
- 使用 `DropdownButton` 或横向滚动的数字选择器。

**源API名选择器（ApiProfileSelector）：**

- 以 `DropdownButton` 或 `SegmentedButton` 展示所有已命名的 API Profile。
- 选中后立即更新 `SettingsProvider.activeProfileId`，后续发送请求使用该配置。
- 若仅有一组配置则仍显示（标签显示其名称），方便用户快速识别当前使用的配置。

**发送逻辑：**

1. 校验：API Key 不为空、prompt 不为空；否则提示 SnackBar。
2. 调用 `GenerationProvider.submit(request)`。
3. 按 count 数量在列表顶部插入 count 个 loading Cell。
4. 清空输入框（保留尺寸 / 质量 / 数量设置）。

---

### 5.5 空状态页面（EmptyState）

- 显示于 API Key 未设置时。
- 内容：应用图标 + 提示文案"请先设置 API Key" + "前往设置"按钮。
- 点击按钮跳转设置页。

---

### 5.6 设置页面（SettingsPage）

设置页分为两层：**Profile 列表页** 和 **单条 Profile 编辑页**。

**Profile 列表页（SettingsPage）：**

- 顶部展示所有已保存的 API Profile，以卡片列表呈现。
- 每张卡片显示：名称、baseUrl（截断）、模型名、当前是否激活（✓ 标记）。
- 右上角"+"按钮新增配置，跳转至编辑页。
- 长按 / 滑动卡片可删除（不可删除最后一条）。
- 点击卡片设为当前激活配置。
- 底部：清除历史记录按钮（红色，二次确认）。

**单条 Profile 编辑页（ApiProfileEditPage）：**

| 字段 | 控件 | 说明 |
|------|------|------|
| 名称 | `TextFormField` | 新建时默认"默认" / "配置 N" |
| Base URL | `TextFormField` | 不含路径；默认 `https://api.openai.com` |
| API Key | `TextFormField`（obscureText） | 明文/密文切换按钮 |
| 模型名 | `TextFormField` | 默认 `gpt-image-2` |
| 最终 URL 预览 | 只读小字 | 实时拼接，如 `https://www.packyapi.com/v1/images/generations` |
| 保存 | `ElevatedButton` | 写入 SharedPreferences，更新 Provider |

---

## 6. 状态管理详细说明

### 6.1 `SettingsProvider`（StateNotifierProvider）

- 启动时从 SharedPreferences 反序列化 `List<ApiProfile>` 和 `activeProfileId`。
- 提供方法：
  - `addProfile(ApiProfile)` — 新增
  - `updateProfile(ApiProfile)` — 编辑
  - `deleteProfile(String id)` — 删除（至少保留 1 条）
  - `setActiveProfile(String id)` — 切换激活
- `activeProfile` 计算属性：返回当前激活的 `ApiProfile`（供 Dio 客户端使用）。
- 监听者：`openAiClient`（重建 Dio BaseOptions，使用 `activeProfile` 的 baseUrl / apiKey）。

### 6.2 `ImageListProvider`（StateNotifierProvider）

- 维护 `List<ImageRecord>` 状态。
- 启动时从 Drift 加载全部记录（按 createdAt DESC）。
- `addPending(records)`：插入 loading 状态的占位记录。
- `updateRecord(id, result)`：生成完成后更新。
- `removeRecord(id)`：取消或删除。

### 6.3 `GenerationProvider`（StateNotifierProvider）

- 持有当前活跃请求的 `CancelToken` 列表。
- `submit(GenerationRequest)`：
  1. 从 `request.apiProfileId` 取对应的 `ApiProfile`，构建专用 Dio 实例。
  2. 构建 `count` 个 `ImageRecord`（status=pending），调用 `imageListProvider.addPending`。
  3. 并发发起 API 请求。
  4. 图生图时：将 `imagePaths` 所有图片以 `MultipartFile` 形式附加到请求体。
  5. 每个请求完成后解码 Base64 → 写入本地文件 → 更新 ImageRecord（status=done）。
  6. 出错时更新 status=error，存入 errorMessage。

---

## 7. 错误处理

| 场景 | 处理方式 |
|------|---------|
| API Key 为空 | 发送按钮置灰 + SnackBar 提示 |
| 网络超时 | Cell 显示错误图标 + 错误文案，提供"重试"按钮 |
| API 返回 4xx/5xx | 解析 error.message 展示在 Cell 上 |
| 多图代理不兼容 | 退化为仅发第一张图，界面显示黄色提示 |
| 图片文件过大（>25MB） | 选择后立即提示，不允许发送 |
| Base64 解码失败 | Cell 显示通用错误 |
| 取消请求 | Cell 移除或显示"已取消"状态（可配置） |

---

## 8. 平台适配

### 8.1 键盘快捷键（桌面）

```dart
// Enter → 发送，Ctrl+Enter → 换行
RawKeyboardListener / Focus + LogicalKeyboardKey.enter
```

### 8.2 移动端保活

- 使用 `flutter_background_service` 在 Android/iOS 后台维持请求。
- 生成完成后通过 `flutter_local_notifications` 发送本地通知。
- iOS 需在 `Info.plist` 中声明 Background Modes（fetch / remote notification）。

### 8.3 桌面端文件选择

- 使用 `file_picker` 替代 `image_picker`（桌面不支持 image_picker）。
- Windows 需配置 `windows/runner/CMakeLists.txt` 添加 sqlite3 依赖。

### 8.4 图片保存

- 全屏预览时提供"保存到本地"按钮。
- Android：`MediaStore` API（通过 `path_provider`）。
- iOS：`Photos` framework。
- 桌面：`FileSaveDialog`。

---

## 9. 单元测试方案

### 9.1 API 接口测试（`test/api/`）

```dart
// image_generation_test.dart
void main() {
  group('ImageGenerationApi', () {
    test('文生图 - 返回 b64_json 且可解码为图片', () async {
      final api = ImageGenerationApi(
        baseUrl: 'https://www.packyapi.com',
        apiKey: '...',  // 从环境变量读取，不硬编码
      );
      final result = await api.generate(GenerationRequest(
        prompt: 'a red apple on white background',
        sizePreset: SizePreset.square1k,
        quality: ImageQuality.low,
        count: 1,
      ));
      expect(result.first.status, equals(GenerationStatus.done));
      expect(result.first.resultImagePath, isNotNull);
    });

    test('图生图 - 上传图片并返回修改结果', () async { ... });

    test('API Key 无效时抛出 AuthException', () async { ... });
  });
}
```

### 9.2 模型测试（`test/models/`）

- `GenerationRequest` 序列化 / 反序列化。
- `SizePreset` 枚举 → API size 字符串映射。

### 9.3 测试凭据管理

测试用凭据**通过环境变量或 `.env` 文件注入**，不硬编码到代码中：

```bash
TEST_BASE_URL=https://www.packyapi.com
TEST_API_KEY=sk-QuuaU2jb4FNOQC6HPIBEYGMyoHrUcF7GYX3jHiq2WOQ40EOQ
TEST_MODEL=gpt-image-2
```

在 CI 中配置为 GitHub Actions Secrets。

---

## 10. UI 设计生成流程

1. 使用如下提示词调用 gpt-image-2 生成 UI 参考图：

   > "Modern minimal Flutter app UI, light blue color scheme (#4FC3F7), image generation client, list view with thumbnail cards, bottom prompt input bar, clean white background, Material Design 3, mobile and desktop layout, subtle shadows"

2. 将生成图传递给 Stitch MCP 生成可用 Flutter 代码片段。
3. 参考生成结果，在实际组件中落地，保持与参考图视觉一致。

---

## 11. 开发优先级

| 优先级 | 功能 |
|--------|------|
| P0 | 文生图接口调用 + 列表显示 + 设置页（多组配置） |
| P0 | 底部输入框（浮动圆角 + prompt + 尺寸 + 质量 + 源API选择） |
| P1 | 图生图（多图附件 + 叠放预览 + edit 接口） |
| P1 | 数量选择 + 并发请求 |
| P1 | 侧滑操作 / 长按菜单 |
| P2 | 全屏预览 + 本地保存 |
| P2 | 移动端保活 + 完成通知 |
| P2 | 单元测试 CI |

---

## 附：测试环境配置（仅本地调试，勿提交）

```
baseUrl = https://www.packyapi.com
key     = sk-QuuaU2jb4FNOQC6HPIBEYGMyoHrUcF7GYX3jHiq2WOQ40EOQ
model   = gpt-image-2
```

建议使用 `--dart-define` 注入，避免硬编码：

```bash
flutter run --dart-define=BASE_URL=https://www.packyapi.com \
            --dart-define=API_KEY=sk-xxx \
            --dart-define=MODEL=gpt-image-2
```
