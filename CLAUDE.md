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

## 改动缘由记录

当代码发生修改时，注释应说明**为什么这样改**，特别是：

- **Debug 导致的改动** — 必须记录：原写法是什么、踩了什么坑、为什么新写法是对的。例："`GetModConfigData` 不能在回调内调用，必须提到顶层存为局部变量再用"
- **选择了非显而易见的方案** — 为什么不用更直观的写法。例："保留 `GLOBAL.require()` 前缀，因为标准 Lua `require` 不知道 Klei 的 scripts.zip 路径"
- **数值/常量的来源** — 如果某个值不是随意选的，注明出处。例："原版 `TUNING.AXE_DAMAGE = 27.2`，此处取 2 倍"

注释格式不拘，但**每条 debug 驱动的改动**至少包含：遇到的问题 + 为什么当前写法是正确的。
