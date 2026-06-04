-- ============================================================
-- 范围边界进出识别 — DIY 方案核心 API 片段
-- 摘录自：entityscript.lua + simutil.lua
-- 说明：这些是所有 DST 实体可用的距离检测方法，不需要引入任何额外组件。
--       playerprox 底层也调用这些函数。
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- 来自 entityscript.lua（EntityScript 类的方法）
-- 所有 Prefab 通过 inst: 直接调用
-- ──────────────────────────────────────────────────────────

--- 计算到另一个实体的距离平方（仅水平面 xz，忽略 y 高度）
--- 返回平方值，避免 sqrt 开销
function EntityScript:GetDistanceSqToInst(inst)
    assert(self:IsValid() and inst:IsValid())
    local p1x, p1y, p1z = self.Transform:GetWorldPosition()
    local p2x, p2y, p2z = inst.Transform:GetWorldPosition()
    return distsq(p1x, p1z, p2x, p2z)
end

--- 判断另一个实体是否在以 self 为圆心、dist 为半径的圆形范围内
--- 内部用距离平方比较，避免 sqrt
function EntityScript:IsNear(otherinst, dist)
    return otherinst ~= nil and self:GetDistanceSqToInst(otherinst) < dist * dist
end

--- 到某个世界坐标的距离平方
function EntityScript:GetDistanceSqToPoint(x, y, z)
    -- 如果只传了一个参数，假定是 Vector3 或 Point 对象
    if x and not y and not z then
        x, y, z = x:Get()
    end
    local x1, y1, z1 = self.Transform:GetWorldPosition()
    return distsq(x, z, x1, z1)
end

--- 是否有任意玩家在范围内（布尔，比 FindPlayersInRange 更轻量）
function EntityScript:IsNearPlayer(range, isalive)
    local x, y, z = self.Transform:GetWorldPosition()
    return IsAnyPlayerInRange(x, y, z, range, isalive)
end

--- 获取离自己最近的玩家（返回实体，范围不限）
function EntityScript:GetNearestPlayer(isalive)
    local x, y, z = self.Transform:GetWorldPosition()
    return FindClosestPlayer(x, y, z, isalive)
end

--- 获取到最近玩家的距离平方
function EntityScript:GetDistanceSqToClosestPlayer(isalive)
    local x, y, z = self.Transform:GetWorldPosition()
    local player, distsq = FindClosestPlayer(x, y, z, isalive)
    return distsq or math.huge  -- 没有玩家时返回无穷大
end

-- ──────────────────────────────────────────────────────────
-- 来自 simutil.lua（全局函数，不需要调用者实体）
-- 在任何脚本中直接用函数名调用
-- ──────────────────────────────────────────────────────────

--[[
isalive 参数说明（所有函数通用）：
  nil    — 不区分死活（默认）
  true   — 只匹配活着的（非幽灵）
  false  — 只匹配死了的（幽灵状态）
--]]

--- 在圆形范围内找最近的玩家
--- 返回：玩家实体（或 nil）、距离平方（或 nil）
function FindClosestPlayerInRangeSq(x, y, z, rangesq, isalive)
    local closestPlayer = nil
    for i, v in ipairs(AllPlayers) do
        if (isalive == nil or isalive ~= IsEntityDeadOrGhost(v)) and
            v.entity:IsVisible() then
            local distsq = v:GetDistanceSqToPoint(x, y, z)
            if distsq < rangesq then
                rangesq = distsq
                closestPlayer = v
            end
        end
    end
    return closestPlayer, closestPlayer ~= nil and rangesq or nil
end

--- 对 FindClosestPlayerInRangeSq 的封装，接受普通距离（非平方）
function FindClosestPlayerInRange(x, y, z, range, isalive)
    return FindClosestPlayerInRangeSq(x, y, z, range * range, isalive)
end

--- 找最近的玩家（不限范围）
function FindClosestPlayer(x, y, z, isalive)
    return FindClosestPlayerInRangeSq(x, y, z, math.huge, isalive)
end

--- 便捷方法——以某个实体为中心找最近玩家
function FindClosestPlayerToInst(inst, range, isalive)
    local x, y, z = inst.Transform:GetWorldPosition()
    return FindClosestPlayerInRange(x, y, z, range, isalive)
end

--- 获取圆形范围内的所有玩家（返回 table）
function FindPlayersInRangeSq(x, y, z, rangesq, isalive)
    local players = {}
    for i, v in ipairs(AllPlayers) do
        if (isalive == nil or isalive ~= IsEntityDeadOrGhost(v)) and
            v.entity:IsVisible() and
            v:GetDistanceSqToPoint(x, y, z) < rangesq then
            table.insert(players, v)
        end
    end
    return players
end

--- 对 FindPlayersInRangeSq 的封装，接受普通距离
function FindPlayersInRange(x, y, z, range, isalive)
    return FindPlayersInRangeSq(x, y, z, range * range, isalive)
end

--- 是否有任意玩家在范围内（返回布尔值；比 FindPlayersInRange 更轻量——找到第一个就返回 true）
function IsAnyPlayerInRangeSq(x, y, z, rangesq, isalive)
    for i, v in ipairs(AllPlayers) do
        if (isalive == nil or isalive ~= IsEntityDeadOrGhost(v)) and
            v.entity:IsVisible() and
            v:GetDistanceSqToPoint(x, y, z) < rangesq then
            return true
        end
    end
    return false
end

function IsAnyPlayerInRange(x, y, z, range, isalive)
    return IsAnyPlayerInRangeSq(x, y, z, range * range, isalive)
end

-- ──────────────────────────────────────────────────────────
-- 扩展：TheSim:FindEntities — 扫描任意实体（不仅是玩家）
-- 适用于需要检测怪物、物品等非玩家实体的场景
-- ──────────────────────────────────────────────────────────

--[[
TheSim:FindEntities(x, y, z, radius, must_tags, cant_tags, has_any_tags)
  参数:
    x, y, z      — 圆心世界坐标
    radius        — 半径
    must_tags     — 必须全部拥有的 tag（string 或 table，nil 表示不限制）
    cant_tags     — 不能拥有的 tag
    has_any_tags  — 至少拥有其一的 tag
  返回: { entity1, entity2, ... }  范围内的实体列表
  示例（眼球塔用法）:
    local ents = TheSim:FindEntities(x, y, z, 20, "_combat", {"INLIMBO", "player", "eyeturret"})
    -- 在 20 范围内找所有带 "_combat" 标签、且不带 "INLIMBO"/"player"/"eyeturret" 标签的实体
--]]
