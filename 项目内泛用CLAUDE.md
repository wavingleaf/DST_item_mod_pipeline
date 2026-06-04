# CLAUDE.md — 饥荒 Mod 开发项目约定

## 参与者预设

代码和文档的目标读者是：
- 受过高等教育，有编程常识（变量、函数、表、控制流等概念已知）
- **不是**熟练 Lua 语言开发者（对 Lua 特有的闭包、元表、`self` 语法糖、模块加载机制等需要解释）
- **不是** DST Mod 开发者（对 Klei 框架的 `AddPrefabPostInit`、`modimport`、`GLOBAL` 代理、`PrefabFiles`、`TUNING`、`net_var` 等需要解释）

## 注释详细程度

### 应该解释的

| 类别 | 示例 |
|------|------|
| Lua 特有的写法 | `self:Method()` 等价于 `self.Method(self)`、元表 `__index` 代理机制 |
| DST 框架惯用模式 | `AddPrefabPostInit` 的执行时机、`modimport` 的"就地粘贴"语义、`GLOBAL.setmetatable(env, ...)` 为什么放在顶部 |
| 函数参数的含义 | `AddRecipe(name, ingredients, tab, level, ...)` 每个位置代表什么 |
| 为什么用 A 不用 B | 例：这里用 `AddPrefabPostInit` 而非 `GLOBAL.require()`，因为前者影响实例、后者影响定义表 |
| 看似多余、实际必要的代码 | 例：modmain 顶部的 `GLOBAL.setmetatable` 注入，不写的话下面每个全局都要加 `GLOBAL.` 前缀 |

### 不需要解释的

- 通用的编程概念（什么是 if/else、for 循环、函数调用）
- 代码的字面含义（`TUNING.AXE_DAMAGE * 2` 不需要注释"把斧子伤害乘以 2"）
- 文件路径/项目结构类信息（这些记录在 `mod制作基础/` 文档中即可）

## 语言约定

- **自创目录与文件名**：使用中文命名，便于直接在 IDE 中识别内容（如 `mod制作基础/`、`热重载测试/`）
- **自创 Skill 名**：使用中文命名（如「功能摘抄」），Skill 的说明文字也使用中文
- **代码注释**：尽可能使用中文撰写，降低读者的语言切换成本
- 引用游戏引擎中的固有术语时保留英文原文（如 `modmain.lua`、`AddPrefabPostInit`、`TUNING`）

## 改动缘由记录

当代码发生修改时，注释应说明**为什么这样改**，特别是：

- **Debug 导致的改动** — 必须记录：原写法是什么、踩了什么坑、为什么新写法是对的。例："`GetModConfigData` 不能在回调内调用，必须提到顶层存为局部变量再用"
- **选择了非显而易见的方案** — 为什么不用更直观的写法。例："保留 `GLOBAL.require()` 前缀，因为标准 Lua `require` 不知道 Klei 的 scripts.zip 路径"
- **数值/常量的来源** — 如果某个值不是随意选的，注明出处。例："原版 `TUNING.AXE_DAMAGE = 27.2`，此处取 2 倍"

注释格式不拘，但**每条 debug 驱动的改动**至少包含：遇到的问题 + 为什么当前写法是正确的。

## 组件调用安全规范

DST 中并非所有实体都拥有当前上下文中需要的组件。在调用组件方法之前，**必须先检查该组件是否存在**，否则会因访问 `nil` 的字段而直接导致游戏崩溃。

```lua
-- ❌ 错误写法：假设 health 组件一定存在
if inst.components.health:GetPercent() <= 0.5 then
    -- ...
end

-- ✅ 正确写法：先检查组件是否存在，短路保护
if inst.components.health and inst.components.health:GetPercent() <= 0.5 then
    -- ...
end
```

这条规则适用于所有组件访问：
- 读取属性前检查（`if inst.components.combat then local dmg = inst.components.combat.defaultdamage end`）
- 调用方法前检查（`if inst.components.inventory then inst.components.inventory:GetEquippedItem(...) end`）
- 添加组件前先检查是否已存在（如果用 `AddPrefabPostInit`，同一实体可能被多个 mod 重复修改）

写代码时假设"这个实体不一定有我要的组件"，养成习惯。

## 游戏数据查找纪律

当用户提到游戏内的物品 ID、参数名、中文名时，**禁止凭空猜测、凭记忆推理、或联网搜索**。必须：

1. **先查项目内的本体文件**：
   - Prefab ID / 是否存在某个物品 → 查 `github同步/命名、参数记录/DST本体/prefablist.lua`
   - 全局参数值（如 `TUNING.AXE_DAMAGE`）→ 查 `github同步/命名、参数记录/DST本体/tuning.lua`
   - 中文名 / ID ↔ 中文名互查 → 查 `github同步/命名、参数记录/DST本体/chinese_s.po`
   - 算法逻辑 / 组件实现 → 查「本地的DST源码文件」下对应目录

2. **查不到时**：明确告知用户"在项目现有本体文件中未找到"，并建议用户从游戏安装目录的 `scripts.zip` 中补充对应文件到「本地的DST源码文件」目录。

3. **Mod 相关数据**：若用户提到某个 Mod 的参数、命名、功能，项目内没有该 Mod 的源码时，**提醒用户去搜集**——把 Mod 文件夹复制到工作区，或解包后放入对应目录。不要编造 Mod 的参数名和数值。
