# Editor

<h3>FFmpeg解码</h3>
<h3>GPUImage添加滤镜与转场</h3>

<h4>利用FFmpeg进行解码,支持暂停和seek</h4>
<h4>转场逻辑:  转场前:单个输入源 ----> GPUImageView || 转场开始: 双输入源 -----> GPUImageView</h4>
<h4>转场逻辑:  转场中: 利用GPUImageTwoInputFilter给shader时间参数赋值 || 转场后: 单输入源 -----> GPUImageView</h4>

[转场网站](https://gl-transitions.com/gallery)
<br></br>
[视频缩略图](https://github.com/VideoFlint/VITimelineView)
<br></br>
[FFmpeg编译与导入](https://juejin.cn/post/6844903857097539591)
<br></br>
[FFmpeg编译脚本](https://github.com/kewlbear/FFmpeg-iOS-build-script)
<br></br>
[libyuv编译](https://chromium.googlesource.com/libyuv/libyuv/+/HEAD/docs/getting_started.md)
<br></br>

![项目示例](https://github.com/MysteryRan/Editor/blob/main/img/demo.gif "界面")

***
<h3>issue</h3>
<ol>
  合并两个视频时,需要通过pts*time_base来获得时间,不同的视频时间精度会有差别,需在使用视频前进行统一time_base的重新导出操作。
  增加转场时,会有两个视频重叠的部分，并且同时解码，会出现两个pts，有没有什么好的方案使得时间戳唯一且连续。
</ol>


