# 计划书

创建一个用于方便调用gpt-image-2（OpenAI生图接口）的flutter客户端，需要支持windows、mac、iOS、Android部署。

## UI

所有的页面设计，请先用合理的关键字调用图像生成（gpt-image-2）来生成一个轻量简洁美观精致的现代的UI，颜色为浅蓝色为主色调，然后传递给stitch的mcp来进行设计。

支持OpenAI的文生图（生成）、图生图（修改）接口。

没有底部tab，直接为一整页

使用列表布局，标注每一个的尺寸（小标签）、质量等标签，长按可以选择以此改图并跳转至改图页面填充输入框。

### 列表Cell

左侧显示大图（保证铺满固定尺寸），移动端一屏大约能显示4-5个的样子，右侧显示对应的标签tag（尺寸（实际尺寸以及生出来的图的尺寸）、质量等），侧滑弹出选项：复用、修改，来填充底部提示词以及附件图片。

未设置key时，设计为一个空页面，指引调用到

### 底部为输入框

设计上浮动、圆角，美观简洁

支持按Ctrl+回车换行，直接回车是发送，包含多个选项，支持以下选项：

* 附件（别针样式）

如果选择了附件，支持选择多个图片作为附件，选择后在输入框顶部显示出来缩略图（叠放），则应该调用图生图（修改）接口。

* 尺寸

<select class="field-control" id="scene-preset" name="scenePreset" data-testid="scene-preset"><option value="square-1k">方形成图 1K - 1024 x 1024</option><option value="poster-portrait">竖版海报 - 1024 x 1536</option><option value="poster-landscape">横版海报 - 1536 x 1024</option><option value="story-9-16">竖屏故事 - 1088 x 1920</option><option value="video-16-9">视频封面 - 1920 x 1088</option><option value="wide-2k">宽屏展示 2K - 2560 x 1440</option><option value="portrait-2k">高清竖图 2K - 1440 x 2560</option><option value="square-2k">高清方图 2K - 2048 x 2048</option><option value="portrait-4k">高清竖图 4K - 2160 x 3840</option><option value="wide-4k">宽屏展示 4K - 3840 x 2160</option><option value="custom">自定义尺寸</option></select>

其中自定义需要弹出尺寸输入框。

* 质量

低、中、高，请根据OpenAI的实际参数决定

* 生成数量

默认为1个，可选择1-16个，可多选，等于多次请求？

* 源API名

可切换设置中的多组配置。

* 设置

独立的齿轮按钮，弹出页面用于设置自定义BaseUrl、模型名、key等，在baseUrl输入框下小字提示最终拼接好的URL是什么样，比如 https://xxxx/v1/images/xxxx

模型名默认显示gpt-image-2

支持多组BaseUrl+模型名+key的组合，并支持为其命名，第一个为“默认”


## 其他细节

* 本机未安装flutter，请安装最新版本以及对应需求的tools。
* 图片生成时间都很长，移动端看是否需要保活。
* 支持同时多组生成，开始生成后列表Cell就加入，显示loading状态。

## 目标结果

* 在当前进程完成windows平台，以及目前可调试的移动平台测试。
* 建立单元测试保证接口可调用生成图片。

## 用于gpt-image-2测试的平台

baseUrl=https://www.packyapi.com

key=sk-QuuaU2jb4FNOQC6HPIBEYGMyoHrUcF7GYX3jHiq2WOQ40EOQ

model=gpt-image-2

