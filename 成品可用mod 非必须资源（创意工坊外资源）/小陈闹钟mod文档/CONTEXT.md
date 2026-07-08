# 小陈闹钟

一个 DST Mod 物品——定时触发 + 玩家靠近触发的农场辅助闹钟。无容器、无碰撞、仅右键收回。

## 语言

### 核心概念

**小陈闹钟 (Chen's Alarm Clock)**：
以两种形态存在的农场辅助物品。物品形态无任何效果，建筑物形态在触发条件满足时播放音频、照料周围作物、播一段小动画。
_Avoid_：闹钟、贝壳钟改版

### 实体形态

**物品形态 (Item Form)**：
Prefab `chen_alarm_item_ly`。纯物品，无任何特效。可右键部署到地面。
_Avoid_：手持版

**建筑物形态 (Deployed Form)**：
Prefab `chen_alarm_deployed_ly`。地面结构物，承载全部触发逻辑。右键收回为物品形态。
_Avoid_：地面版、种地版

### 形态转换

**部署 (Deploy)**：物品形态 → 建筑物形态。`deployable` 组件触发。

**收回 (Dismantle)**：建筑物形态 → 物品形态。右键触发 `portablestructure` 组件。

### 触发系统

**触发源**：两个独立的触发条件，触发完全相同的效果（播音频 + 照料作物 + 动画）。

- **天色切换触发**：`WatchWorldState("phase")` 监听，白天↔黄昏↔夜晚任意 direction 变化均触发
- **玩家靠近触发**：`playerprox` 组件，`AllPlayers` 模式，每个玩家独立追踪进出

**冷却**：全局冷却 2 秒，挂在建筑实例上。冷却期间所有触发源均不响应。退出读档时冷却剩余时间正确恢复。

**触发效果**：
1. 从 3 段自定义音频中加权随机选取并播放（50%/25%/25%）
2. 照料周围作物（`farmplanttendable:TendTo(doer)`）
3. 播放 squash & stretch 抖动动画（挤压缩放 + 左右摇摆 → 回到 idle）

**照料参数**：
- 玩家靠近触发时 doer = 该玩家
- 天色切换触发时 doer = nil（`TendTo(nil)` 已测试安全，棱镜 mod 也传 nil）

### 交互

- 无碰撞体积
- 不可锤（不挂 `workable`）
- 无容器
- 右键收回走 `portablestructure`，无数量限制

### 放置

无限制——地皮、船上、洞穴均可部署，数量不限。

## 美术

| 资源 | 格式 | 尺寸 | 说明 |
|------|------|------|------|
| 实体动画 | `anim/chen_alarm_ly.zip` | 256×256 sprite, scale 0.8 | 2 动画：idle（单帧静止）、music（5 帧 squash & stretch） |
| 物品栏图标 | `images/inventoryimages/chen_alarm_item_ly_inv.{tex,xml}` | 58×64 | 经 png.exe 编译为 DXT5 纹理 |
| 小地图图标 | `minimap/chen_alarm_minimap.{tex,xml}` | 96×96 | priority 6，注册 `AddMinimapAtlas` |
| Mod 图标 | `modicon.{tex,xml}` | 256×256, 213×235 居中补边 | 经预乘 Alpha 处理 |
| SCML 源 | `exported/chen_alarm_ly/chen_alarm_ly.scml` | — | 手工编写，结构参照便携衣柜 |

美术源素材：微信终末地表情包 03「惊讶」

## 音频

| 资源 | 格式 | 说明 |
|------|------|------|
| 事件定义 | `sound/chen_alarm.fev` | FMOD Designer 4.44.64 导出（构建流程见 `犯错经验记录/音频相关.md`） |
| 音频数据 | `sound/chen_alarm.fsb` | 同上 |
| 事件 1 | `chen_alarm/sound/dangdang` | 0.70s，权重 50% |
| 事件 2 | `chen_alarm/sound/dangpojipo` | 1.36s，权重 25% |
| 事件 3 | `chen_alarm/sound/dangduanjiduan` | 1.10s，权重 25% |

音频模式：**x_3d**（3D 空间音效）。音量 0.4，mindistance=3（3 单位内满音量），maxdistance=30（30 单位外静音），Linear 衰减。SoundEmitter 所在实体的世界坐标自动驱动左右声道偏转和距离衰减。

音频来源：BV1DbAazeEYP 中截取 3 段语音

### 音量调参过程

| 尝试 | 值 | 效果 | 结论 |
|------|-----|------|------|
| 初始 | 1.0 | 偏大 | 模板节奏声的音量到在农场上有点吓人 |
| 第 1 次 | 0.67 | 感觉没变化 | GUI 保存覆盖了音量回 1，而且 2D 全局模式下音量本身不随距离衰减 |
| 第 2 次 | 0.5 | 还是偏大 | — |
| 第 3 次 | 0.2 | 偏小，但发现了问题并切换到 3D 模式 | 3D 模式下近处和远处音量差异明显 |
| 最终 | 0.4 | 正常 | 3D 模式下 0.4 音量 + 30 单位衰减，近处清晰、远处自然淡出 |

### 2D vs 3D 模式

初始 Event 设为 `x_2d` 模式（maxdistance=10000），无论闹钟离玩家多远音量都完全一样——全图满音量播放。FMOD Designer 创建 Simple Event 时默认就是 2D。

改为 `x_3d` + maxdistance=30 + mindistance=3 后，闹钟才具备真实的距离感：站旁边响、走远渐弱、30 单位外完全听不到。DST 的 `SoundEmitter` 会自动把实体世界坐标传给 FMOD 引擎做衰减计算。

## 获取途径

配方，二本科技（`TECH.SCIENCE_TWO`），工具栏（`TOOLS`）。

- 原料：1 × `singingshell_octave4`（中音贝壳钟）+ 2 × `lightninggoathorn`（电羊角）
- 制作栏描述：「定时？！当当！？（注：植物也会听）」
- 检查描述（物品&建筑统）：「会时不时发出声音，植物也听得见」

## Mod 配置

| 配置项 | 默认值 | 可选范围 |
|--------|--------|----------|
| 生效范围 | 20 | 10 / 15 / 20 / 25 / 30 |
| 触发范围 | 12 | 6 / 9 / 12 / 15 / 18 |
| 音效开关 | 开启 | 开启 / 关闭 |

触发范围取较大值（NEAR > 14）时缓冲半径从 2 增至 3，避免大范围频繁进出抖动。

配置值在 `modmain.lua` 顶层通过 `GetModConfigData` 读入 `GLOBAL.TUNING.CHEN_ALARM_*`，prefab 在运行期读取 TUNING。

## 命名体系

| 层级 | 命名 | 说明 |
|------|------|------|
| Mod 前缀 | `chen_alarm_` | Chen（陈千语英文指代）+ alarm（闹钟） |
| 物品 Prefab | `chen_alarm_item_ly` | item = 物品形态 |
| 建筑 Prefab | `chen_alarm_deployed_ly` | deployed = 建筑物形态 |
| 动画 Bank/Build | `chen_alarm_ly` | 与 SCML entity name 一致 |
| 作者标记 | `_ly` | 和便携衣柜一致 |

## 关键文件索引

| 文件 | 角色 |
|------|------|
| `modinfo.lua` | Mod 元数据 + 配置选项 |
| `modmain.lua` | 入口：配置读取、AddMinimapAtlas、配方、声音资源、本地化 |
| `scripts/prefabs/chen_alarm_item_ly.lua` | 物品形态：部署 + 浮动 + 物品栏图标 |
| `scripts/prefabs/chen_alarm_deployed_ly.lua` | 建筑物形态：双触发 + 音频 + 动画 + 照料 + 收回 + 存档 |
| `exported/chen_alarm_ly/chen_alarm_ly.scml` | Spriter 动画源文件（手写） |

## 参考

- 触发逻辑参考：贝壳钟 `singingshell.lua`（`TendTo` 照料作物、`OnCycle` 回调模式）
- 双 Prefab 模式参考：便携衣柜全套代码
- 天色监听参考：`WatchWorldState("phase", fn)`
- 玩家靠近参考：`playerprox` 组件（项目文档 `功能摘抄记录/游戏本体_范围边界进出识别/`）
- `TargetModes` 访问：通过组件实例 `inst.components.playerprox.TargetModes.AllPlayers`（走元表），参考能力勋章 `medal_origin_tree.lua:1030`
- SCML 格式参考：便携衣柜 `portable_wardrobe_ly.scml`
- 小地图图标注册参考：能力勋章 `modmain.lua:178-202`（AddMinimapAtlas）

## Debug 记录

### OverrideSymbol 缺失导致地面版不显示贴图（已废弃，动画已替换）

原 singingshell build 中 shell_placeholder 是空占位符，我们的自定义 build 无此问题。

### 配方未注册导致无法制作（已修复）

用 `AddRecipe2` + `Ingredient` 注册二本科技配方。

### 小地图图标 missing_asset（已修复）

缺少 `AddMinimapAtlas("minimap/chen_alarm_minimap.xml")`。详见错误记录 `美术相关.md#小地图图标：AddMinimapAtlas 不能省略`。

### 动画实体不可见（已修复）

根因：SCML 中 `spin="0"` 未被引擎正常渲染，`object_ref` 含多余 `folder/file` 属性，`length="1"` 太短。全部修正为便携衣柜对齐格式。详见 `美术相关.md#SCML 编译` 三条记录。

### 动画高度严重偏下（已修复）

根因：地面结构物 `pivot_y="1.0"` 时 y 偏移不够大。y 从 15 拉到 200。详见 `美术相关.md#SCML：地面结构物的 y 偏移`。

### 图标白边/透明度问题（已修复）

PNG 未做预乘 Alpha 处理。在 scml 编译前用 Pillow `ImageChops.multiply` 预乘。详见 `美术相关.md#PNG→TEX 转换：预乘 Alpha`。

### scml.exe 中文路径编码问题（已修复）

scml.exe 内部调用 Python 27，中文文件名导致 subprocess 失败。每次从 ASCII 路径（d:/tmp/alarm_build）编译。

### Steam 创意工坊描述格式

使用 BBCode，非 Markdown。常用：`[h1]标题[/h1]`、`[b]粗体[/b]`、`[list][*]条目[/list]`、`[url=链接]名称[/url]`。
