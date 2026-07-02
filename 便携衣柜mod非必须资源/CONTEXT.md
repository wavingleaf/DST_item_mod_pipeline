# 便携衣柜

一个 DST Mod 物品——可随身携带的装备收纳容器，兼具背包的便携性和箱子的地面部署能力。按装备部位（头部/身体）和天气属性（保暖/防水/隔热）分类收纳。

## 语言

### 核心概念

**便携衣柜 (Portable Wardrobe)**：
本 Mod 的总体概念——一个能以两种形态存在的装备收纳容器。内部 2 行 × 3 列共 6 格。
_Avoid_：装备收纳架、装备箱、衣物柜

### 实体形态

**物品栏形态 (Inventory Form)**：
Prefab 名 `portable_wardrobe_ly`。背包状的物品，放在物品栏中，右键打开容器 UI，拖到地面可部署为家具形态。
_Avoid_：背包版、手持版、物品版

**地面家具形态 (Deployed Form)**：
Prefab 名 `portable_wardrobe_deployed_ly`。部署在地面上的家具，左键打开容器 UI，右键收回为物品栏形态。内部容器内容在形态转换时逐槽保留。
_Avoid_：家具版、地面版、部署版

### 形态转换

**部署 (Deploy)**：
物品栏形态 → 地面家具形态。通过 `deployable` 组件实现，销毁物品栏实体并生成地面家具实体，容器内容逐槽转移。

**收回 (Dismantle)**：
地面家具形态 → 物品栏形态。右键地面家具触发（通过 `portablestructure` 组件）。仅在容器关闭时可执行。

### 槽位规则

**装备部位行**：
- 第 1 行（上方）：仅接受 `equippable.equipslot == "head"`（头部装备）
- 第 2 行（下方）：仅接受 `equippable.equipslot == "body"`（身体装备）
- 兼容五格装备栏 Mod：该 Mod 新增 `BACK` / `NECK` 槽，`HEAD` / `BODY` 值不变，无需特殊处理。

**天气属性列**：
- 第 1 列（左）：保暖——`insulator` 存在 且 `type == WINTER` 且 `insulation > 0`
- 第 2 列（中）：防水——`waterproofer` 存在 且 `effectiveness > 0`
- 第 3 列（右）：隔热——`insulator` 存在 且 `type == SUMMER` 且 `insulation > 0`
- 一个物品可同时匹配多列。

**槽位迭代规则**：
物品放入时，框架按 `containers.lua` 定义的槽顺序依次调用 `itemtestfn(container, item, slot)`，首个返回 `true` 的槽即为放置位置。不设优先级函数。

**阈值判断**：
暂定为 `> 0`（有相关组件即可）。后续可通过 Mod 配置收紧。

### 参考 Mod

**五格装备栏 (Extra Equip Slots)**：
Mod 文件位于 `github同步/功能摘抄记录/mod_最好的那个五格_全部文件记录/`。在 `EQUIPSLOTS` 中新增 `BACK = "back"` 和 `NECK = "neck"`，`HEAD` 和 `BODY` 保持不变。
