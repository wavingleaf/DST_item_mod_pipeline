# modmain.lua 总览

> 这是 Mod 主逻辑入口文件。游戏加载 Mod 时自动执行其中的顶层代码，**服务端 + 客户端双端执行**。以下是最小骨架 + 各专题文件的索引。

```lua
-- ============================================================
-- modmain.lua — Mod 主逻辑入口
-- ============================================================

-- ──────────────────────────────────────
-- 1. [必备] GLOBAL 环境注入
-- ──────────────────────────────────────

GLOBAL.setmetatable(env, {
    __index = function(t, k)
        return GLOBAL.rawget(GLOBAL, k)
    end
})
-- 之后可直接使用 TUNING, SpawnPrefab, STRINGS, RECIPETABS... 无需 GLOBAL. 前缀

-- ──────────────────────────────────────
-- 2. [按需] 声明自定义实体
-- ──────────────────────────────────────

PrefabFiles = {
    -- "my_item",     -- 对应 scripts/prefabs/my_item.lua
    -- "my_creature", -- 对应 scripts/prefabs/my_creature.lua
}

-- ──────────────────────────────────────
-- 3. [按需] 声明自定义资源
-- ──────────────────────────────────────

Assets = {
    -- Asset("ANIM", "anim/my_anim.zip"),
    -- Asset("IMAGE", "images/my_image.tex"),
    -- Asset("ATLAS", "images/my_atlas.xml"),
}

-- ──────────────────────────────────────
-- 4. [推荐] 拆分大型 Mod → modimport()
-- ──────────────────────────────────────

-- modimport 的效果等同于把目标文件的内容"原样粘贴"到这一行位置执行。
-- 因此：
--   1. 执行顺序由上到下，被 import 的文件里的代码会在 modimport 这一行立即运行
--   2. 被 import 的文件共享 modmain.lua 的环境——第1节 setmetatable 注入的
--      GLOBAL 代理对被调用文件同样有效，那里的代码也无需再写 GLOBAL. 前缀
--   3. 被 import 文件可以直接使用 modmain.lua 中已定义的局部变量
--   4. 只能在顶层作用域调用，不能放在 AddPrefabPostInit 等回调函数里
-- modimport("scripts/recipes.lua")      -- → 见 配方注册.md
-- modimport("scripts/strings.lua")      -- → 见 字符串与本地化.md
-- modimport("scripts/tuning.lua")       -- → 见 配置选项与调试.md
-- modimport("scripts/rpc.lua")          -- → 见 网络同步.md
-- modimport("scripts/postinits.lua")    -- → 见 Prefab与实体修改.md

-- ──────────────────────────────────────
-- 5. [按需] 读取 Mod 配置
-- ──────────────────────────────────────

-- local my_opt = GetModConfigData("MY_OPTION")  -- 只能在顶层调用！
```

## 专题文件索引

| 文件 | 内容 |
|------|------|
| [配方注册.md](modmain调用模块/配方注册.md) | AddRecipe / AddRecipe2、材料表、制作栏分页、科技等级、自定义分页 |
| [Prefab与实体修改.md](modmain调用模块/Prefab与实体修改.md) | AddPrefabPostInit、AddComponentPostInit、GLOBAL.require()、事件监听 |
| [配置选项与调试.md](modmain调用模块/配置选项与调试.md) | GetModConfigData、TUNING 直接修改、print/TheNet:Announce 调试、原版源码路径 |
| [字符串与本地化.md](modmain调用模块/字符串与本地化.md) | STRINGS.NAMES / DESCRIBE / RECIPE_DESC 重载、多语言 .po 文件 |
| [网络同步.md](modmain调用模块/网络同步.md) | net_var 双向同步、自定义 RPC、SendModRPCToServer/Client、双端判别 |
```
