# Prefab 与实体修改

```lua
-- ============================================================
-- Prefab 与实体修改
-- 三种常用手段：AddPrefabPostInit / AddComponentPostInit / GLOBAL.require()
-- ============================================================

-- 前置：确保已在 modmain.lua 顶部做了 GLOBAL 环境注入
-- GLOBAL.setmetatable(env, { __index = function(t,k) return GLOBAL.rawget(GLOBAL,k) end })

-- ──────────────────────────────
-- 手段一：AddPrefabPostInit（最推荐）
-- 在某个 Prefab 的每个实例生成后附加逻辑
-- ──────────────────────────────

-- 语法：AddPrefabPostInit("prefab_name", function(inst) ... end)
-- inst 是刚生成的实体对象，拥有完整的 components 体系

-- 例1：修改武器属性
AddPrefabPostInit("axe", function(inst)
    -- inst 就是这把斧子
    if inst.components.weapon then
        -- 把攻击力翻倍
        inst.components.weapon:SetDamage(TUNING.AXE_DAMAGE * 2)
    end
end)

-- 例2：修改角色属性
AddPrefabPostInit("wilson", function(inst)
    -- 让 Wilson 跑更快、血更多
    if inst.components.locomotor then
        inst.components.locomotor.runspeed = TUNING.WILSON_RUN_SPEED * 1.2
    end
    if inst.components.health then
        inst.components.health:SetMaxHealth(200)  -- 原版 150
    end
end)

-- 例3：给物品增加新功能
AddPrefabPostInit("backpack", function(inst)
    -- 背包额外带保温效果（原版背包没有）
    if inst.components.container and not inst.components.insulator then
        inst:AddComponent("insulator")
        inst.components.insulator:SetInsulation(TUNING.INSULATION_MED)
    end
end)

-- 例4：修改生物掉落
AddPrefabPostInit("spider", function(inst)
    if inst.components.lootdropper then
        -- 添加额外掉落
        inst.components.lootdropper:AddChanceLoot("silk", 0.5)  -- 50%概率多掉一个蛛丝
    end
end)

-- ──────────────────────────────
-- 手段二：AddComponentPostInit（影响所有使用者）
-- 修改组件定义本身，所有使用该组件的实体都受影响
-- ──────────────────────────────

-- 语法：AddComponentPostInit("component_name", function(self) ... end)
-- self 是组件实例（不是实体！），修改发生在组件首次被创建时

-- 例1：覆盖组件方法（保存原始函数）
AddComponentPostInit("health", function(self)
    local old_SetMaxHealth = self.SetMaxHealth  -- 保存原函数
    if old_SetMaxHealth then
        function self:SetMaxHealth(amount, ...)
            -- 所有生物的最大生命值提高 50%
            local boosted = amount * 1.5
            return old_SetMaxHealth(self, boosted, ...)
        end
    end
end)

-- 例2：给组件新增方法
AddComponentPostInit("edible", function(self)
    -- 给所有食物组件增加一个自定义方法
    function self:IsSuperFood()
        return self:GetHunger() > 50
    end
end)

-- 例3：修改容器容量
AddComponentPostInit("container", function(self)
    local old_SetNumSlots = self.SetNumSlots
    if old_SetNumSlots then
        function self:SetNumSlots(num, ...)
            -- 所有容器增加 2 格
            return old_SetNumSlots(self, num + 2, ...)
        end
    end
end)

-- ──────────────────────────────
-- 手段三：GLOBAL.require()（修改 Prefab 原表）
-- 直接 require 原版脚本，修改其中定义的函数或常量表
-- ──────────────────────────────

-- 这种方式在 require 时立即生效，影响的是"定义"而非"实例"
-- 优点是简单直接，缺点是与 PostInit 不同，需注意执行时机

-- 例1：修改矛的伤害数值（修改原表中的常量）
-- local spear = GLOBAL.require("prefabs/spear")
-- if spear then
--     spear.TUNING.SPEAR_DAMAGE = 34 * 2  -- 原版 34，翻倍为 68
-- end

-- 例2：修改斧子的耐久
-- local axe = GLOBAL.require("prefabs/axe")
-- if axe then
--     axe.TUNING.AXE_USES = 200  -- 原版 100，翻倍
-- end

-- 例3：覆盖某个 Prefab 的主函数 fn()（谨慎使用）
-- local old_fn = axe.fn
-- axe.fn = function(...)
--     local inst = old_fn(...)
--     inst:AddComponent("my_custom_component")
--     return inst
-- end

-- ──────────────────────────────
-- 三种手段的选用建议
-- ──────────────────────────────

-- AddPrefabPostInit     → 修改特定物品/生物的实例属性，首选！
-- AddComponentPostInit  → 修改某个组件的通用行为（影响所有使用者）
-- GLOBAL.require()      → 修改 Prefab 的静态常量或完全替换 fn()

-- ──────────────────────────────
-- 补充：监听游戏事件（非修改实体，但常配合使用）
-- ──────────────────────────────

-- 进入世界后执行
-- AddPrefabPostInit("world", function(inst)
--     inst:ListenForEvent("ms_cyclechange", function(world, phase)
--         -- phase: "day" / "dusk" / "night"
--         if phase == "night" then
--             print("天黑啦！")
--         end
--     end, TheWorld)  -- TheWorld 由 metatable 从 GLOBAL 代理，无需显式前缀
-- end)

-- 玩家加入世界时
-- AddPlayerPostInit(function(inst)
--     -- 每个玩家（包括主机）进入世界时触发
--     inst:ListenForEvent("onbecamehuman", function(player)
--         print("有玩家变成了人类形态")
--     end)
-- end)
```
