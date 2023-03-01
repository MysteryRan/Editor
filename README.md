# Editor

<h3>FFmpeg解码</h3>

<h3>GPUImage添加滤镜与转场</h3>

<h3>AVPlayer播放音频</h3>

<h3>AVMutableComposition添加多轨音频</h3>

<h3>FFmpeg编码的h264文件与音频合成pcm文件合成新的mp4</h3>

***
<h3>需要用到FFmpeg,libyuv</h3>  

[FFmpeg编译与导入](https://juejin.cn/post/6844903857097539591)

[FFmpeg编译脚本](https://github.com/kewlbear/FFmpeg-iOS-build-script)

<ol>
<li>FF_VERSION="4.3.1" 自己选择的FFmpeg版本</li>
<li>ARCHS="arm64 armv7 x86_64 i386" 自己需要的架构</li>
</ol>

[libyuv编译](https://chromium.googlesource.com/libyuv/libyuv/+/HEAD/docs/getting_started.md)

[视频缩略图](https://github.com/VideoFlint/VITimelineView)

***
<h3>issue</h3>
<ol>
<li>采用定时器来控制转场,滤镜的添加.会使合成时间过长,后续采用pts来控制时间</li>
<li>音频与画面分离,合成后音画可能不同步</li>
<li>不支持暂停与seek</li>
</ol>

![项目示例](https://github.com/MysteryRan/Editor/blob/main/img/demo.gif "界面")
