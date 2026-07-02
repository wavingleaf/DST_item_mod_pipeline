# 0001 — 双 Prefab 架构：物品栏形态与地面家具形态分别独立为两个 Prefab

便携衣柜需要以两种形态存在——物品栏中可随身携带的物品、部署在地面上的家具。两个形态有各自不同的组件集合和交互行为（物品栏版用 `deployable` 和 `inventoryitem`，地面版用 `portablestructure` 和 `workable`），但需要共享同一组容器内容。

## 决定

采用两个独立 Prefab（`portable_wardrobe_ly` 和 `portable_wardrobe_deployed_ly`），在形态转换时销毁旧实体并生成新实体，容器内容逐槽手动转移。

## 考虑的替代方案

**单一 Prefab + 动态增减组件**：同一个实体在部署/收回时通过 `AddComponent`/`RemoveComponent` 切换形态。容器内容自然保留，无需手动转移。

### 为什么选了双 Prefab

1. **遵循原版模式**：便携帐篷（`portabletent_item` ↔ `portabletent`）和便携煮锅（`portablecookpot_item` ↔ `portablecookpot`）都使用双 Prefab 模式。走原版走过的路，减少未知风险。
2. **组件集合差异大**：物品栏版需要 `inventoryitem`、`deployable`、`inventoryfloatable`，地面版需要 `workable`、`portablestructure`、`inspectable`（作为独立家具）。DST 的 `RemoveComponent` 并非所有组件都安全移除，部分组件的 `OnRemoveFromEntity` 有副作用。
3. **切换 Prefab 是原版惯用法**：`ReplacePrefab` 在原版中被广泛使用（宝箱变宝箱怪等场景）。双 Prefab 模式下逐槽转移 `container.slots` 的代码量不大（循环 6 格），且逻辑透明可控。

### 代价

- 容器内容不自动保留，需要写转移代码（但 6 格的循环很轻量）
- 两个 Prefab 文件需要维护同步的容器配置（`WidgetSetup` 参数、`containers.lua` 定义共用）
