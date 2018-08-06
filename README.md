# Unity-Screen-Space-Decals

工作：管理特效播放，特效需要地面裂痕，所以想到解决方案是加进贴花系统
> 引用：[screen-space-decals-in-warhammer-40000-space-marine](https://www.slideshare.net/blindrenderer/screen-space-decals-in-warhammer-40000-space-marine-14699854)

Demo图：
![](https://i.imgur.com/XCxpjJk.png)

## 2018年4月17日21:35:26更新：
1. 修正高光贴图的使用细节代码：高光贴图直接取其rgb， a通道为粗糙度
2. 添加与纹理的正片叠底的颜色融合

图例：
![](https://i.imgur.com/Y5jD25H.png)

## 2018年4月20日19:01:00更新：
1. 引用unity的PBR渲染算法。复刻Standard Shader的GI效果
2. 新建动态判断投影面的渲染shader

PS:传统做法的贴花，由于只能投影一个平面，一般为xz轴进行采样，所以当投影拐角时，需要手动将投影面进行旋转，来得到效果。而作者的该做法，将动态检测视角面，将坐标转换到视角面，避免了动态时，无法预先旋转的拐角贴花穿帮问题。
不足之处：因为是直接切换坐标空间，所以比传统手工旋转，立体感有所降低。


图例：
![](https://i.imgur.com/cXkipwx.png)

## 2018年6月27日13:37:35更新：

新增一种贴花实现方式：
与之前的利用Commandbuffer不同，这次是将贴花直接写在DrawMesh的Shader上。避免DrawLight时，Buffer中的颜色进行正片叠底。

A：老贴花
B: 新贴花
Panel：为Panel mesh 的Standard Shader渲染。
效果对比如下：
![](https://i.imgur.com/WNVlqm4.png)

##2018年8月6日18:16:48 更新：
发现老版本的问题：

1. 如果使用延迟渲染没有办法 获取当前帧的法线贴图，只能得到上一帧的发现
2. 使用CommandBuffer能获取当前帧法线，但会跟环境光混淆失真，且diffColor会被阴影覆盖

新版本：
	使用前向渲染，自行进行光照计算	
	接受阴影