local prefs = {}
local TOOLS_L = require("tools_legion")
local COOKING = require("cooking")
local fns = {} --lua的限制，一个域里只能有最多200个局部变量，否则会报错。通过把所有变量都存进一个主变量，来预防这个问题
local pas = {} --专门放各个prefab独特的变量

--------------------------------------------------------------------------
--[[ 通用函数 ]]
--------------------------------------------------------------------------

fns.MakeItem = function(sets)
    local basename = sets.name.."_item"
    table.insert(prefs, Prefab(basename, function()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank(sets.name)
        inst.AnimState:SetBuild(sets.name)
        inst.AnimState:PlayAnimation("idle_item")

        LS_C_Init(inst, basename, true)

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then return inst end

        inst:AddComponent("inspectable")

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.imagename = basename
        inst.components.inventoryitem.atlasname = "images/inventoryimages/"..basename..".xml"

        inst:AddComponent("upgradekit")
        inst.components.upgradekit:SetData(sets.kitdata)

        MakeHauntableLaunch(inst)

        return inst
    end, {
        Asset("ANIM", "anim/"..sets.name..".zip"),
        Asset("ATLAS", "images/inventoryimages/"..basename..".xml"),
        Asset("IMAGE", "images/inventoryimages/"..basename..".tex"),
        Asset("ATLAS_BUILD", "images/inventoryimages/"..basename..".xml", 256)
    }, sets.prefabs))
end

fns.DropGems = function(inst, gemname)
    local numgems = inst.components.upgradeable:GetStage() - 1
    if numgems > 0 then
        TOOLS_L.SpawnStackDrop(gemname, numgems, inst:GetPosition(), nil, nil, nil)
    end
end
fns.OnUpgradeFn = function(inst, doer, item)
    (inst.SoundEmitter or doer.SoundEmitter):PlaySound("dontstarve/common/telebase_gemplace")
end
fns.NameDetail = function(inst, max)
    local lvl = inst._lvl_l:value()
    if lvl == nil or lvl < 0 then
        lvl = 0
    end
    return subfmt(STRINGS.NAMEDETAIL_L.MOONTREASURE, { lvl = tostring(lvl), lvlmax = tostring(max) })
end
fns.InitLevelNet = function(inst, fn_detail)
    inst._lvl_l = net_byte(inst.GUID, "moonlight_l._lvl_l", "lvl_l_dirty")
    inst._lvl_l:set_local(0)
    inst.legion_namedetail = fn_detail
end
fns.SetLevel = function(inst)
    inst._lvl_l:set(inst.components.upgradeable:GetStage() - 1)
end
fns.NoWorked = function(inst, worker)
    if worker ~= nil and (worker:HasTag("player") or worker.components.walkableplatform ~= nil) then
        return false
    end
    return true
end
fns.OnFinished_base = function(inst, worker, x, y, z, gemname, itemname)
    fns.DropGems(inst, gemname) --归还宝石
    local skin = inst.components.skinedlegion:GetSkin()
    if skin == nil then
        inst.components.lootdropper:SpawnLootPrefab(itemname)
    else
        inst.components.lootdropper:SpawnLootPrefab(itemname, nil, skin, nil, LS_GetID(inst, worker))
    end
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(x, y, z)
    fx:SetMaterial("stone")
    inst:Remove()
end
fns.SetRotatable_com = function(inst)
    inst:AddTag("rotatableobject") --能让栅栏击剑起作用
    inst:AddTag("flatrotated_l") --棱镜标签：旋转时旋转180度
    inst.Transform:SetTwoFaced() --两个面，这样就可以左右不同（再多貌似有问题）
end

--------------------------------------------------------------------------
--[[ 月藏宝匣（蓝宝石） ]]
--------------------------------------------------------------------------

pas.times_hidden = CONFIGS_LEGION.HIDDENUPDATETIMES or 20

pas.UpdatePerishRate_hidden = function(inst)
    local lvl = inst.components.upgradeable:GetStage() - 1
    if lvl > pas.times_hidden then --在设置变换中，会出现当前等级大于最大等级的情况
        lvl = pas.times_hidden
    elseif lvl < 0 then
        lvl = 0
    end
    if inst.upgradetarget == "icebox" then
        inst.perishrate_l = Remap(lvl, 0, pas.times_hidden, 0.4, 0.1)
    else
        inst.perishrate_l = Remap(lvl, 0, pas.times_hidden, 0.3, 0.0)
    end
end
pas.SetTarget_hidden = function(inst, targetprefab)
    inst.upgradetarget = targetprefab
    if targetprefab ~= "icebox" then
        inst.AnimState:OverrideSymbol("base", inst.AnimState:GetBuild() or "hiddenmoonlight", "saltbase")
    end
end
pas.DoBenefit_hidden = function(inst)
    local items = inst.components.container:GetAllItems()
    local items_valid = {}
    for _,v in pairs(items) do
        if v ~= nil and
            v.components.perishable ~= nil and v.components.perishable:GetPercent() < 0.995
        then
            table.insert(items_valid, v)
        end
    end

    local benifitnum = #items_valid
    if benifitnum == 0 then
        return
    end

    local value = 2.5
    local needs = 0.0
    while value > 0 and benifitnum > 0 do
        local benifititem = table.remove(items_valid, math.random(#items_valid))
        benifitnum = benifitnum - 1
        needs = 1 - benifititem.components.perishable:GetPercent()
        if value >= needs then
            benifititem.components.perishable:SetPercent(1)
            value = value - needs
        else
            benifititem.components.perishable:ReducePercent(-value)
            value = 0
        end
    end

    if not inst:IsAsleep() then --未加载状态就不产生特效了
        local fx = SpawnPrefab("chesterlight")
        if fx ~= nil then
            fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
            fx:TurnOn()
            inst.SoundEmitter:PlaySound("dontstarve/creatures/chester/raise")
            fx:DoTaskInTime(2, function()
                if fx:IsAsleep() then
                    fx:Remove()
                else
                    fx:TurnOff()
                end
            end)
        end
    end
end
pas.OnFullMoon_hidden = function(inst)
    if TheWorld.state.isfullmoon then
        if inst:IsAsleep() then
            pas.DoBenefit_hidden(inst)
        else
            inst:DoTaskInTime(math.random() + 0.4, pas.DoBenefit_hidden)
        end
    end
end
pas.OnUpgrade_hidden = function(item, doer, target, result)
    if result.SoundEmitter ~= nil then
        result.SoundEmitter:PlaySound("dontstarve/common/place_structure_straw")
    end
    local skin = item.components.skinedlegion:GetSkin()
    if skin ~= nil then
        result.components.skinedlegion:SetSkin(skin, LS_GetID(item, doer))
    end
    pas.SetTarget_hidden(result, target.prefab)
    pas.UpdatePerishRate_hidden(result)

    --将原箱子中的物品转移到新箱子中
    if target.components.container ~= nil then
        local x, y, z = target.Transform:GetWorldPosition()
        local cpt = result.components.container
        target.components.container:Close() --强制关闭使用中的箱子
        target.components.container.canbeopened = false
        if cpt ~= nil then
            local allitems = target.components.container:RemoveAllItems()
            for _, v in ipairs(allitems) do
                v.Transform:SetPosition(x, y, z) --防止放不进容器时，掉在世界原点
                cpt:GiveItem(v)
            end
        else
            target.components.container:DropEverything()
        end
    end
    item:Remove() --该道具是一次性的
    pas.OnFullMoon_hidden(result)
end

fns.MakeItem({
    name = "hiddenmoonlight",
    prefabs = { "hiddenmoonlight" },
    kitdata = {
        icebox = { prefabresult = "hiddenmoonlight", onupgradefn = pas.OnUpgrade_hidden },
        saltbox = { prefabresult = "hiddenmoonlight", onupgradefn = pas.OnUpgrade_hidden }
    }
})

--------------------

pas.OnReplicated_hidden = function(inst)
    if inst.replica.container ~= nil then
        inst.replica.container:WidgetSetup("hiddenmoonlight")
    end
end
pas.OnOpen_hidden = function(inst)
    inst.AnimState:PlayAnimation("open")
    inst.AnimState:PushAnimation("opened", true)
    if inst._dd ~= nil and inst._dd.openfn ~= nil then
        inst._dd.openfn(inst)
    end
    if not inst.SoundEmitter:PlayingSound("idlesound1") then
        inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/spore_cloud_LP", "idlesound1", 0.7)
    end
    if not inst.SoundEmitter:PlayingSound("idlesound2") then
        inst.SoundEmitter:PlaySound("dontstarve/bee/bee_hive_LP", "idlesound2", 0.7)
    end
    inst.SoundEmitter:PlaySound("dontstarve/cave/mushtree_tall_spore_land")
end
pas.OnClose_hidden = function(inst)
    inst.AnimState:PlayAnimation("close")
    inst.AnimState:PushAnimation("closed", true)

    inst.SoundEmitter:KillSound("idlesound1")
    inst.SoundEmitter:KillSound("idlesound2")
    inst.SoundEmitter:PlaySound("dontstarve/cave/mushtree_tall_spore_land")
end
pas.SetPerishRate_hidden = function(inst, item)
    if item == nil or not item:HasTag("frozen") then
        return inst.perishrate_l
    end
    return 0
end
pas.SetLevel_hidden = function(inst)
    fns.SetLevel(inst)
    pas.UpdatePerishRate_hidden(inst)
end
pas.OnSave_hidden = function(inst, data)
	if inst.upgradetarget ~= "icebox" then
        data.upgradetarget = inst.upgradetarget
    end
    if inst.legiontag_chestupgraded then
        data.legiontag_chestupgraded = true
    end
end
pas.OnLoad_hidden = function(inst, data)
	if data ~= nil then
        if data.upgradetarget ~= nil then
            pas.SetTarget_hidden(inst, data.upgradetarget)
        end
        if data.legiontag_chestupgraded then
            inst.legiontag_chestupgraded = true
        end
    end
    pas.SetLevel_hidden(inst)
end
pas.OnWorked_hidden = function(inst, worker, workleft, numworks)
    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PushAnimation("closed", true)
    inst.components.container:Close()
    if fns.NoWorked(inst, worker) then --只能被玩家或者船体破坏
        inst.components.workable:SetWorkLeft(5)
        return
    end
    -- inst.components.container:DropEverything()
end
pas.OnFinished_hidden = function(inst, worker)
    inst.components.container:DropEverything()
    if inst.legiontag_chestupgraded then
        inst.components.lootdropper:SpawnLootPrefab("chestupgrader_l")
    elseif inst.prefab == "hiddenmoonlight_inf" then
        inst.components.lootdropper:SpawnLootPrefab("chestupgrade_stacksize")
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    if inst.upgradetarget ~= nil then
        local box = SpawnPrefab(inst.upgradetarget)
        if box ~= nil then
            box.Transform:SetPosition(x, y, z)
        end
    end
    fns.OnFinished_base(inst, worker, x, y, z, "bluegem", "hiddenmoonlight_item")
end
pas.NameDetail_hidden = function(inst)
    return fns.NameDetail(inst, pas.times_hidden)
end

pas.OnWorked_hidden_inf = function(inst, worker, workleft, numworks)
    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PushAnimation("closed", true)
    inst.components.container:Close()
    if worker == nil or not worker:HasTag("player") then --只能被玩家破坏。没必要弄烂箱子设定
        inst.components.workable:SetWorkLeft(5)
        return
    end
    inst.components.container:DropEverything(nil, true)
    if not inst.components.container:IsEmpty() then --如果箱子里还有物品，那就不能被破坏
        inst.components.workable:SetWorkLeft(5)
    end
end
pas.OnUpgrade_hidden_inf = function(inst, item, doer)
    local is_chestupgrader_l = item:HasTag("chestupgrader_l")
    if item.components.stackable ~= nil then
		item.components.stackable:Get(1):Remove()
	else
		item:Remove()
	end
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("chestupgrade_stacksize_fx")
    if fx ~= nil then
        fx.Transform:SetPosition(x, y, z)
    end
    local newbox = SpawnPrefab("hiddenmoonlight_inf")
    if newbox ~= nil then
        local skin = inst.components.skinedlegion:GetSkin()
        if skin ~= nil then
            newbox.components.skinedlegion:SetSkin(skin, LS_GetID(inst, doer))
        end
        newbox.legiontag_chestupgraded = is_chestupgrader_l --表明这是用月石角撑升级的
        pas.SetTarget_hidden(newbox, inst.upgradetarget)

        --继承等级
        newbox.components.upgradeable:SetStage(inst.components.upgradeable:GetStage())
        pas.SetLevel_hidden(newbox)

        --继承能力勋章的不朽等级
        local cpt = inst.components.medal_immortal
        if cpt ~= nil and newbox.components.medal_immortal ~= nil then
            local ilvl = cpt.GetLevel ~= nil and cpt:GetLevel() or 0
            if ilvl > 0 and cpt.SetImmortal ~= nil then
                newbox.components.medal_immortal:SetImmortal(ilvl)
            end
        end

        newbox.Transform:SetPosition(x, y, z)

        --将原箱子中的物品转移到新箱子中
        cpt = inst.components.container
        if cpt ~= nil then
            cpt:Close() --强制关闭使用中的箱子
            cpt.canbeopened = false
            if not cpt:IsEmpty() then
                if newbox.components.container ~= nil then
                    local allitems = cpt:RemoveAllItems()
                    for _, v in ipairs(allitems) do
                        v.Transform:SetPosition(x, y, z) --防止放不进容器时，掉在世界原点
                        newbox.components.container:GiveItem(v)
                    end
                else
                    cpt:DropEverything()
                end
            end
        end
    end
    inst:Remove()
end

fns.MakeHidden = function(dd)
    table.insert(prefs, Prefab(dd.name, function()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddNetwork()

        inst.MiniMapEntity:SetIcon("hiddenmoonlight.tex")
        inst:SetDeploySmartRadius(0.25) --冰箱是0.75

        inst:AddTag("structure")
        inst:AddTag("fridge") --加了该标签，就能给热能石降温啦
        inst:AddTag("meteor_protection") --防止被流星破坏
        inst:AddTag("moontreasure_l")

        if dd.fn_common ~= nil then
            dd.fn_common(inst)
        end
        inst.AnimState:PlayAnimation("closed", true)

        fns.SetRotatable_com(inst)
        fns.InitLevelNet(inst, pas.NameDetail_hidden)

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            inst.OnEntityReplicated = pas.OnReplicated_hidden
            return inst
        end

        inst.upgradetarget = "icebox"
        inst.perishrate_l = 0.5

        inst:AddComponent("inspectable")
        inst:AddComponent("savedrotation")

        inst:AddComponent("container")
        inst.components.container:WidgetSetup("hiddenmoonlight")
        inst.components.container.onopenfn = pas.OnOpen_hidden
        inst.components.container.onclosefn = pas.OnClose_hidden
        inst.components.container.skipclosesnd = true
        inst.components.container.skipopensnd = true

        inst:AddComponent("preserver")
        inst.components.preserver:SetPerishRateMultiplier(pas.SetPerishRate_hidden)

        inst:AddComponent("lootdropper")

        inst:AddComponent("workable")
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(5)

        inst:AddComponent("upgradeable")
        inst.components.upgradeable.upgradetype = UPGRADETYPES.HIDDEN_L
        inst.components.upgradeable.onupgradefn = fns.OnUpgradeFn --升级时
        inst.components.upgradeable.onstageadvancefn = pas.SetLevel_hidden --等级变化时
        inst.components.upgradeable.numstages = pas.times_hidden + 1
        inst.components.upgradeable.upgradesperstage = 1

        inst:WatchWorldState("isfullmoon", pas.OnFullMoon_hidden)

        MakeHauntableLaunchAndDropFirstItem(inst)

        TOOLS_L.MakeSnowCovered_serv(inst)
        TOOLS_L.RandomAnimFrame(inst)

        inst.OnSave = pas.OnSave_hidden
        inst.OnLoad = pas.OnLoad_hidden

        if TUNING.SMART_SIGN_DRAW_ENABLE then
            SMART_SIGN_DRAW(inst)
        end
        if TUNING.FUNCTIONAL_MEDAL_IS_OPEN then
            SetImmortalable(inst, 2, nil)
        end

        if dd.fn_server ~= nil then
            dd.fn_server(inst)
        end

        return inst
    end, dd.assets, dd.prefabs))
end
fns.MakeHidden({
    name = "hiddenmoonlight",
    assets = {
        Asset("ANIM", "anim/ui_chest_3x3.zip"), --官方的容器栏背景动画模板
        Asset("ANIM", "anim/ui_hiddenmoonlight_4x4.zip"),
        Asset("ANIM", "anim/hiddenmoonlight.zip")
    },
    prefabs = {
        "hiddenmoonlight_item",
        "hiddenmoonlight_inf",
        "chesterlight",
        "chestupgrade_stacksize_fx"
    },
    fn_common = function(inst)
        inst:AddTag("chest_upgradeable") --能被 弹性空间制造器 升级
        inst.AnimState:SetBank("hiddenmoonlight")
        inst.AnimState:SetBuild("hiddenmoonlight")
        LS_C_Init(inst, "hiddenmoonlight_item", false, "data_up")
    end,
    fn_server = function(inst)
        inst.components.workable:SetOnWorkCallback(pas.OnWorked_hidden)
        inst.components.workable:SetOnFinishCallback(pas.OnFinished_hidden)

        inst.legionfn_chestupgrade = pas.OnUpgrade_hidden_inf
    end
})
fns.MakeHidden({
    name = "hiddenmoonlight_inf",
    assets = {
        Asset("ANIM", "anim/ui_chest_3x3.zip"), --官方的容器栏背景动画模板
        Asset("ANIM", "anim/ui_hiddenmoonlight_inf_4x4.zip"),
        Asset("ANIM", "anim/hiddenmoonlight_inf.zip")
    },
    prefabs = {
        "hiddenmoonlight_item",
        "chesterlight",
        "chestupgrade_stacksize"
    },
    fn_common = function(inst)
        inst.AnimState:SetBank("hiddenmoonlight")
        inst.AnimState:SetBuild("hiddenmoonlight_inf")
        LS_C_Init(inst, "hiddenmoonlight_item", false, "data_upinf")
    end,
    fn_server = function(inst)
        inst.components.container:EnableInfiniteStackSize(true)

        inst.components.workable:SetOnWorkCallback(pas.OnWorked_hidden_inf)
        inst.components.workable:SetOnFinishCallback(pas.OnFinished_hidden)
    end
})

--------------------------------------------------------------------------
--[[ 月轮宝盘（黄宝石） ]]
--------------------------------------------------------------------------

pas.OnUpgrade_revolved = function(item, doer, target, result)
    if result.SoundEmitter ~= nil then
        result.SoundEmitter:PlaySound("dontstarve/common/place_structure_straw")
    end
    local skin = item.components.skinedlegion:GetSkin()
    if skin ~= nil then
        result.components.skinedlegion:SetSkin(skin, LS_GetID(item, doer))
    end
    local cpt = target.components.container
    if cpt ~= nil then
        cpt:Close() --强制关闭使用中的箱子
        cpt.canbeopened = false
        cpt:DropEverything() --因为格子数比背包少，所以只能全丢地上
    end
    cpt = target.components.medal_immortal --继承能力勋章的不朽等级
    if cpt ~= nil and result.components.medal_immortal ~= nil then
        local ilvl = cpt.GetLevel ~= nil and cpt:GetLevel() or 0
        if ilvl > 0 and cpt.SetImmortal ~= nil then
            result.components.medal_immortal:SetImmortal(ilvl)
        end
    end
    item:Remove() --该道具是一次性的
end
fns.MakeItem({
    name = "revolvedmoonlight",
    prefabs = { "revolvedmoonlight", "revolvedmoonlight_pro" },
    kitdata = {
        piggyback = { prefabresult = "revolvedmoonlight", onupgradefn = pas.OnUpgrade_revolved },
        krampus_sack = { prefabresult = "revolvedmoonlight_pro", onupgradefn = pas.OnUpgrade_revolved }
    }
})

--------------------

pas.times_revolved_pro = CONFIGS_LEGION.REVOLVEDUPDATETIMES or 10
pas.value_revolved = 5/pas.times_revolved_pro
pas.cool_revolved = TUNING.TOTAL_DAY_TIME/pas.times_revolved_pro
pas.temp_revolved = 35/pas.times_revolved_pro
pas.times_revolved = math.floor(pas.times_revolved_pro/2) + 1
pas.times_revolved_pro = pas.times_revolved_pro + 1

fns.LightOn = function(light)
    if not light.Light:IsEnabled() then
        light.Light:Enable(true)
    end
end
fns.LightOff = function(light)
    if light.Light:IsEnabled() then
        light.Light:Enable(false)
    end
end

pas.OnOpen_revolved = function(inst, data)
    inst.AnimState:PlayAnimation("open")
    inst.AnimState:PushAnimation("opened", true)

    inst.SoundEmitter:PlaySound("dontstarve/cave/mushtree_tall_spore_land", nil, 0.6)

    local gowner = inst.components.inventoryitem:GetGrandOwner()
    if gowner == nil then --说明自己不在容器里，可以发出循环声音
        if not inst.SoundEmitter:PlayingSound("idlesound1") then
            inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/spore_cloud_LP", "idlesound1", 0.7)
        end
        if not inst.SoundEmitter:PlayingSound("idlesound2") then
            inst.SoundEmitter:PlaySound("dontstarve/bee/bee_hive_LP", "idlesound2", 0.7)
        end
    end
end
pas.OnClose_revolved = function(inst, doer)
    inst.AnimState:PlayAnimation("close")
    inst.AnimState:PushAnimation("closed")

    inst.SoundEmitter:KillSound("idlesound1")
    inst.SoundEmitter:KillSound("idlesound2")
    inst.SoundEmitter:PlaySound("dontstarve/cave/mushtree_tall_spore_land", nil, 0.6)
end
pas.OnTempDelta_revolved = function(owner, data)
    if data == nil or data.new == nil or data.new >= 6 or --低温特效出现前就执行
        owner._revolves_l == nil or owner.components.temperature == nil or owner:HasTag("playerghost") or
        owner.components.health == nil or owner.components.health:IsDead()
    then
        return
    end
    local chosen = nil
    for k, _ in pairs(owner._revolves_l) do
        if k:IsValid() then
            if k.components.rechargeable:IsCharged() then --冷却完毕，可以用
                chosen = k
                break
            end
        end
    end
    if chosen == nil then
        return
    end

    local temper = owner.components.temperature
    local stagenow = chosen.components.upgradeable:GetStage()
    if stagenow > pas.times_revolved_pro then --在设置变换中，会出现当前等级大于最大等级的情况
        stagenow = pas.times_revolved_pro
    end
    chosen.components.rechargeable:Discharge(3 + pas.cool_revolved*(pas.times_revolved_pro-stagenow))
    stagenow = 7 + pas.temp_revolved*(stagenow-1) --7-42
    stagenow = math.min(stagenow, temper.overheattemp-5-temper.current) --可不能让温度太高了
    if stagenow > 0 then
        temper:SetTemperature(temper.current + stagenow)
    end

    if owner.task_l_heatfx ~= nil then
        owner.task_l_heatfx:Cancel()
    end
    local count = 0
    owner.task_l_heatfx = owner:DoPeriodicTask(0.5, function(owner)
        local fx = SpawnPrefab("revolvedmoonlight_fx")
        if fx ~= nil then
            fx.Transform:SetPosition(owner.Transform:GetWorldPosition())
        end
        count = count + 1
        if count >= 5 then
            owner.task_l_heatfx:Cancel()
            owner.task_l_heatfx = nil
        end
    end, 0)
end
pas.UpdateLight_revolved = function(inst, owner) --更新光照范围
    if owner == inst then
        owner = nil
    end
    local stagenow = inst.components.upgradeable:GetStage()
    if stagenow > 1 then
        if stagenow > pas.times_revolved_pro then --在设置变换中，会出现当前等级大于最大等级的情况
            stagenow = pas.times_revolved_pro
        end
        local rad = 0.25 + (stagenow-1)*pas.value_revolved
        if owner ~= nil then --被携带时，发光范围减半
            rad = rad / 2
            inst._light.Light:SetFalloff(0.65)
        else
            inst._light.Light:SetFalloff(0.7)
        end
        inst._light.Light:SetRadius(rad) --最大约2.75和5.25半径
    end
end
pas.UpdateOwnerLights_revolved = function(owner) --统一管理，只更新等级最高的那一个
    if owner._revolves_l == nil then
        return
    end
    local chosen = nil
    local lvl = 0
    for k, _ in pairs(owner._revolves_l) do
        if k:IsValid() then
            local stagenow = k.components.upgradeable:GetStage()
            if stagenow > lvl then
                lvl = stagenow
                chosen = k
            end
        end
    end
    if chosen ~= nil then
        pas.UpdateLight_revolved(chosen, owner)
        for k, _ in pairs(owner._revolves_l) do
            if k:IsValid() then
                if k == chosen then
                    fns.LightOn(k._light)
                else
                    fns.LightOff(k._light)
                end
            end
        end
    end
end
pas.ClearOwnerData_revolved = function(inst)
    local ownerold = inst.owner_l
    if ownerold ~= nil and ownerold ~= inst and ownerold:IsValid() then
        if ownerold._revolves_l ~= nil then
            local newtbl
            ownerold._revolves_l[inst] = nil
            for k, _ in pairs(ownerold._revolves_l) do
                if k:IsValid() then
                    if newtbl == nil then
                        newtbl = {}
                    end
                    newtbl[k] = true
                end
            end
            ownerold._revolves_l = newtbl
            if newtbl == nil then
                ownerold:RemoveEventCallback("temperaturedelta", pas.OnTempDelta_revolved)
            else
                pas.UpdateOwnerLights_revolved(ownerold)
            end
        else
            ownerold:RemoveEventCallback("temperaturedelta", pas.OnTempDelta_revolved)
        end
    end
end
pas.OnOwnerChange_revolved = function(inst, owner, newowners)
    if inst.owner_l == owner then --没变化
        return
    end
    --先取消以前的对象
    pas.ClearOwnerData_revolved(inst)

    --再尝试设置目前的对象
    inst.owner_l = owner
    inst._light.entity:SetParent(owner.entity)
    if owner ~= inst then
        if owner:HasTag("pocketdimension_container") or owner:HasTag("buried") then
            inst.components.container.droponopen = true --世界容器里，打开时会自动掉地上，防止崩溃
            fns.LightOff(inst._light)
        else
            inst.components.container.droponopen = nil
            if owner._revolves_l == nil then
                owner._revolves_l = {}
                if owner:HasTag("player") then
                    owner:ListenForEvent("temperaturedelta", pas.OnTempDelta_revolved)
                    --温度监听 触发非常频繁，所以应该不需要主动触发一次
                    -- pas.OnTempDelta_revolved(owner, { last = 0, new = owner.components.temperature:GetCurrent() })
                end
            end
            owner._revolves_l[inst] = true
            pas.UpdateOwnerLights_revolved(owner)
        end
    else
        pas.UpdateLight_revolved(inst, nil)
        fns.LightOn(inst._light)
        inst.components.container.droponopen = nil
    end
end
pas.OnRemove_revolved = function(inst)
    pas.ClearOwnerData_revolved(inst)
    inst.owner_l = nil
    inst._light:Remove()
end

pas.OnStageUp_revolved = function(inst)
    inst.components.rechargeable:SetPercent(1) --每次升级，重置冷却时间
    fns.SetLevel(inst)

    local ownerold = inst.owner_l
    inst.owner_l = nil
    pas.OnOwnerChange_revolved(inst, ownerold)
end
pas.OnSave_revolved = function(inst, data)
    if inst.tryopenbox_l or (inst.components.container:IsOpen() and inst.components.inventoryitem:IsHeld()) then
        data.tryopenbox_l = true
    end
end
pas.OnLoad_revolved = function(inst, data) --由于 upgradeable 组件不会自己重新初始化，只能这里再初始化
    pas.UpdateLight_revolved(inst, nil)
    fns.SetLevel(inst)
    if data ~= nil and data.tryopenbox_l then --加载时自动打开容器，这样上下洞穴就不用反复打开容器了
        inst.tryopenbox_l = true
        inst:DoTaskInTime(0.2, function()
            inst.tryopenbox_l = nil
            if not inst.components.container.canbeopened then return end
            local owner = inst.components.inventoryitem:GetGrandOwner()
            if owner ~= nil and owner:HasTag("player") and not owner:HasTag("playerghost") and
                owner.components.health ~= nil and not owner.components.health:IsDead()
            then
                owner:PushEvent("opencontainer", { container = inst })
                inst.components.container:Open(owner)
            end
        end)
    end
end
pas.OnWorked_revolved = function(inst, worker, workleft, numworks)
    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PushAnimation("closed")
    inst.SoundEmitter:PlaySound("grotto/common/turf_crafting_station/hit")
    inst.components.container:Close()
    if worker == nil or not worker:HasTag("player") then --不能被非玩家破坏
        inst.components.workable:SetWorkLeft(5)
        return
    end
    -- inst.components.container:DropEverything()
end
pas.OnFinished_revolved = function(inst, worker)
    inst.components.container:DropEverything()
    local x, y, z = inst.Transform:GetWorldPosition()
    local back = SpawnPrefab(inst.prefab == "revolvedmoonlight" and "piggyback" or "krampus_sack")
    if back ~= nil then
        back.Transform:SetPosition(x, y, z)
    end
    fns.OnFinished_base(inst, worker, x, y, z, "yellowgem", "revolvedmoonlight_item")
end
pas.OnPutInInventory_revolved = function(inst)
    inst.components.container:Close()
    inst.AnimState:PlayAnimation("closed")
end

pas.OnReplicated_revolved = function(inst)
    if inst.replica.container ~= nil then
        inst.replica.container:WidgetSetup("revolvedmoonlight")
    end
end
pas.OnReplicated_revolved2 = function(inst)
    if inst.replica.container ~= nil then
        inst.replica.container:WidgetSetup("revolvedmoonlight_pro")
    end
end
pas.NameDetail_revolved = function(inst)
    return fns.NameDetail(inst, pas.times_revolved-1)
end
pas.NameDetail_revolved2 = function(inst)
    return fns.NameDetail(inst, pas.times_revolved_pro-1)
end

fns.MakeRevolved = function(sets)
    table.insert(prefs, Prefab(sets.name, function()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddNetwork()

        MakeInventoryPhysics(inst)

        inst.AnimState:SetBank("revolvedmoonlight")
        inst.AnimState:SetBuild("revolvedmoonlight")
        inst.AnimState:PlayAnimation("closed")

        if sets.ispro then
            inst.AnimState:OverrideSymbol("decorate", "revolvedmoonlight", "decoratepro")
            inst:SetPrefabNameOverride("revolvedmoonlight")
            LS_C_Init(inst, "revolvedmoonlight_item", true, "data_uppro")
            fns.InitLevelNet(inst, pas.NameDetail_revolved2)
        else
            LS_C_Init(inst, "revolvedmoonlight_item", true, "data_up")
            fns.InitLevelNet(inst, pas.NameDetail_revolved)
        end

        inst:AddTag("meteor_protection") --防止被流星破坏
        --因为有容器组件，所以不会被猴子、食人花、坎普斯等拿走
        inst:AddTag("nosteal") --防止被火药猴偷走
        inst:AddTag("NORATCHECK") --mod兼容：永不妥协。该道具不算鼠潮分
        inst:AddTag("moontreasure_l")

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            inst.OnEntityReplicated = sets.ispro and pas.OnReplicated_revolved2 or pas.OnReplicated_revolved
            return inst
        end

        inst._owner_temp = nil
        inst._owner_light = nil

        inst:AddComponent("inspectable")

        inst:AddComponent("inventoryitem")
        inst.components.inventoryitem.imagename = sets.name
        inst.components.inventoryitem.atlasname = "images/inventoryimages/"..sets.name..".xml"
        inst.components.inventoryitem:SetOnPutInInventoryFn(pas.OnPutInInventory_revolved)

        inst:AddComponent("container")
        inst.components.container:WidgetSetup(sets.name)
        inst.components.container.onopenfn = pas.OnOpen_revolved
        inst.components.container.onclosefn = pas.OnClose_revolved
        inst.components.container.skipclosesnd = true
        inst.components.container.skipopensnd = true
        -- inst.components.container.stay_open_on_hide = true --因为容器type不同，这个机制没法正常用，该隐藏时会无法隐藏

        inst:AddComponent("lootdropper")

        inst:AddComponent("workable")
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(5)
        inst.components.workable:SetOnWorkCallback(pas.OnWorked_revolved)
        inst.components.workable:SetOnFinishCallback(pas.OnFinished_revolved)

        inst:AddComponent("upgradeable")
        inst.components.upgradeable.upgradetype = UPGRADETYPES.REVOLVED_L
        inst.components.upgradeable.onupgradefn = fns.OnUpgradeFn
        inst.components.upgradeable.onstageadvancefn = pas.OnStageUp_revolved
        inst.components.upgradeable.numstages = sets.ispro and pas.times_revolved_pro or pas.times_revolved
        inst.components.upgradeable.upgradesperstage = 1

        inst:AddComponent("rechargeable")
        -- inst.components.rechargeable:SetOnChargedFn(function(inst)end)

        inst.OnSave = pas.OnSave_revolved
        inst.OnLoad = pas.OnLoad_revolved

        --Create light
        inst._light = SpawnPrefab("heatrocklight")
        inst._light.Light:SetRadius(0.25)
        inst._light.Light:SetFalloff(0.7) --Tip：削弱系数：相同半径时，值越小会让光照范围越大
        inst._light.Light:SetColour(255/255, 242/255, 169/255)
        inst._light.Light:SetIntensity(0.75)
        inst._light.Light:Enable(true)
        TOOLS_L.ListenOwnerChange(inst, pas.OnOwnerChange_revolved, pas.OnRemove_revolved)

        if TUNING.FUNCTIONAL_MEDAL_IS_OPEN then
            SetImmortalable(inst, 2, nil)
        end

        return inst
    end, {
        Asset("ANIM", "anim/ui_chest_3x3.zip"), --官方的容器栏背景动画模板
        Asset("ANIM", "anim/ui_revolvedmoonlight_4x3.zip"),
        Asset("ANIM", "anim/revolvedmoonlight.zip"),
        Asset("ATLAS", "images/inventoryimages/"..sets.name..".xml"),
        Asset("IMAGE", "images/inventoryimages/"..sets.name..".tex"),
        Asset("ATLAS_BUILD", "images/inventoryimages/"..sets.name..".xml", 256)
    }, {
        "revolvedmoonlight_item",
        "yellowgem",
        "heatrocklight",
        "revolvedmoonlight_fx"
    }))
end
fns.MakeRevolved({ name = "revolvedmoonlight" })
fns.MakeRevolved({ name = "revolvedmoonlight_pro", ispro = true })

--------------------------------------------------------------------------
--[[ 月折宝剑（彩虹宝石） ]]
--------------------------------------------------------------------------

pas.atk_rf_buff = 40
pas.atk_rf = 10
pas.atk2_rf_buff = 20
pas.atk2_rf = 5
pas.atkmult_rf_hurt = 0.1
pas.atkmult_rf = 1
pas.bonus_rf = 1
pas.bonus_rf_buff = 1.2
pas.count_rf_max = 4
pas.lvls_rf = {}
for i = 1, 14, 1 do
    pas.lvls_rf[i] = i*CONFIGS_LEGION.REFRACTEDUPDATETIMES/14
end

pas.SetCount_refracted = function(inst, value)
    value = math.clamp(value, 0, pas.count_rf_max)
    inst._count = value
    inst:PushEvent("percentusedchange", { percent = value/pas.count_rf_max }) --界面需要一个百分比
    if value >= 1 then
        inst:AddTag("canmoonsurge_l")
        inst:RemoveTag("cansurge_l")
    elseif value > 0 then
        inst:RemoveTag("canmoonsurge_l")
        inst:AddTag("cansurge_l")
    else
        inst:RemoveTag("canmoonsurge_l")
        inst:RemoveTag("cansurge_l")
    end
end
pas.SetAtk_refracted = function(inst)
    inst.components.weapon:SetDamage(math.floor( (inst._atk+inst._atk_lvl)*inst._atkmult ))
    inst.components.planardamage:SetBaseDamage(math.floor( (inst._atk_sp+inst._atk_sp_lvl)*inst._atkmult ))
end
pas.TrySetOwnerSymbol_rf = function(inst, doer, revolt)
    if doer == nil then --因为此时有可能不再是装备状态，doer 发生了改变
        doer = inst.components.inventoryitem:GetGrandOwner()
    end
    if doer then
        if doer:HasTag("player") then
            if doer.components.health and doer.components.inventory then
                if inst == doer.components.inventory:GetEquippedItem(EQUIPSLOTS.HANDS) then
                    doer.AnimState:OverrideSymbol("swap_object", inst._dd.build, revolt and "swap2" or "swap1")
                end
            end
        elseif doer:HasTag("equipmentmodel") then
            doer.AnimState:OverrideSymbol("swap_object", inst._dd.build, revolt and "swap2" or "swap1")
        end
    end
    if revolt then
        inst.components.inventoryitem.atlasname = inst._dd.img_atlas2
        inst.components.inventoryitem:ChangeImageName(inst._dd.img_tex2)
        inst.AnimState:PlayAnimation("idle2", true)
    else
        inst.components.inventoryitem.atlasname = inst._dd.img_atlas
        inst.components.inventoryitem:ChangeImageName(inst._dd.img_tex)
        inst.AnimState:PlayAnimation("idle", true)
    end
end
pas.DoFxTask_refracted = function(inst)
    if inst._task_fx == nil then
        inst._task_fx = inst:DoPeriodicTask(0.7, function(inst)
            local owner = inst.components.inventoryitem:GetGrandOwner() or inst
            if owner:IsAsleep() then
                return
            end
            local fx = SpawnPrefab(inst._dd.fx or "refracted_l_spark_fx")
            if fx ~= nil then
                if not owner:HasTag("player") then
                    local xx, yy, zz = owner.Transform:GetWorldPosition()
                    fx.Transform:SetPosition(xx, yy+1.4, zz)
                    return
                end
                fx.entity:SetParent(owner.entity)
                if inst._equip_l then
                    fx.entity:AddFollower()
                    fx.Follower:FollowSymbol(owner.GUID, "swap_object", 10, -80, 0)
                else
                    fx.Transform:SetPosition(0, 1.4, 0)
                end
            end
        end, math.random())
    end
end
pas.TriggerRevolt_rf = function(inst, doer, doit)
    inst._revolt_l = doit
    if doit then
        if inst._dd.fxfn ~= nil then
            inst._dd.fxfn(inst)
        else
            pas.DoFxTask_refracted(inst)
        end

        inst._atk = pas.atk_rf_buff
        inst._atk_sp = pas.atk2_rf_buff
        inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, pas.bonus_rf_buff, "moonsurge")

        if inst._lvl >= pas.lvls_rf[8] then
            inst.components.weapon:SetRange(2)
        else
            inst.components.weapon:SetRange(0)
        end

        pas.TrySetOwnerSymbol_rf(inst, doer, true)
    else
        if inst._task_fx ~= nil then
            inst._task_fx:Cancel()
            inst._task_fx = nil
        end
        if inst._dd.fxendfn ~= nil then
            inst._dd.fxendfn(inst)
        end

        inst._atk = pas.atk_rf
        inst._atk_sp = pas.atk2_rf
        inst.components.damagetypebonus:RemoveBonus("shadow_aligned", inst, "moonsurge")

        inst.components.weapon:SetRange(0)

        pas.TrySetOwnerSymbol_rf(inst, nil, false)
    end
    pas.SetAtk_refracted(inst)
    if inst._lvl >= pas.lvls_rf[4] then
        inst._light.Light:SetRadius(inst._revolt_l and 4 or 1)
        fns.LightOn(inst._light)
    else
        fns.LightOff(inst._light)
    end
end
pas.TryRevolt_refracted = function(inst, doer)
    if doer == nil then
        doer = inst.components.inventoryitem:GetGrandOwner()
    end
    if inst._count <= 0 then
        return 0
    elseif inst._count < 1 then
        if doer and doer.components.health and doer.components.health:GetPercent() < 1 then
            doer.components.health:DoDelta(20*inst._count, true, "debug_key", true, nil, true) --对旺达回血要特定原因才行
            pas.SetCount_refracted(inst, 0)
        end
        return 1
    else
        pas.SetCount_refracted(inst, inst._count - 1)
    end

    local time = 90
    if inst._lvl >= pas.lvls_rf[14] then
        local timeleft = inst.components.timer:GetTimeLeft("moonsurge") or 0
        if timeleft > 0 then
            time = math.min(time + timeleft, 480)
        end
    else
        if inst._lvl < pas.lvls_rf[2] then
            time = 30
        end
    end
    inst.components.timer:StopTimer("moonsurge")
    inst.components.timer:StartTimer("moonsurge", time)
    pas.TriggerRevolt_rf(inst, doer, true)

    return 2
end

pas.OnEquip_refracted = function(inst, owner) --装备武器时
    TOOLS_L.hand_on(owner, inst._dd.build, inst.components.timer:TimerExists("moonsurge") and "swap2" or "swap1")
    inst._equip_l = true
    if owner:HasTag("equipmentmodel") then return end --假人

    owner:ListenForEvent("healthdelta", inst.fn_onHealthDelta)
    inst:ListenForEvent("attacked", inst.fn_onAttacked, owner)
    inst.fn_onHealthDelta(owner, nil)
    inst:DoTaskInTime(0, function() --需要主动更新一下，不然没反应
        inst:PushEvent("percentusedchange", { percent = inst._count/pas.count_rf_max })
    end)
end
pas.OnUnequip_refracted = function(inst, owner) --卸下武器时
    TOOLS_L.hand_off(inst, owner)
    inst._equip_l = nil
    owner:RemoveEventCallback("healthdelta", inst.fn_onHealthDelta)
    inst:RemoveEventCallback("attacked", inst.fn_onAttacked, owner)
    if inst._atkmult == pas.atkmult_rf_hurt then
        inst.fn_onHealthDelta(owner, { newpercent = 1 }) --卸下时，恢复武器默认攻击力，为了正常显示数值
    end
end
pas.OnAttack_refracted = function(inst, owner, target)
    if not inst._revolt_l or inst._lvl >= pas.lvls_rf[10] then
        pas.SetCount_refracted(inst, inst._count + (inst._lvl >= pas.lvls_rf[12] and 0.1 or 0.05))
    end
    if inst._lvl >= pas.lvls_rf[6] and inst._revolt_l then
        if target ~= nil and target:IsValid() then
            if inst._dd.atkfn ~= nil then
                inst._dd.atkfn(inst, owner, target, true)
            else
                local fx = SpawnPrefab(inst._dd.fx or "refracted_l_spark_fx")
                if fx ~= nil then
                    local xx, yy, zz = target.Transform:GetWorldPosition()
                    local x, y, z = TOOLS_L.GetCalculatedPos(xx, yy, zz, 0.1+math.random()*0.9, nil)
                    fx.Transform:SetPosition(x, y+math.random()*2, z)
                end
            end
        end
        if owner.components.health and owner.components.health:GetPercent() < 1 then
            owner.components.health:DoDelta(1.5, true, "debug_key", true, nil, true) --对旺达回血要特定原因才行
            return
        end
    else
        if inst._dd.atkfn ~= nil then
            if target ~= nil and target:IsValid() then
                inst._dd.atkfn(inst, owner, target)
            end
        end
    end
    if inst._atkmult == pas.atkmult_rf_hurt then
        inst.fn_onHealthDelta(owner, nil)
    end
end

pas.OnStageUp_refracted = function(inst)
    local lvl = inst.components.upgradeable:GetStage() - 1
    inst._lvl = lvl
    inst._lvl_l:set(lvl)
    inst.components.workable:SetWorkLeft(5)
    if lvl >= pas.lvls_rf[13] then
        inst._atk_lvl = 80
        inst._atk_sp_lvl = 60
    elseif lvl >= pas.lvls_rf[11] then
        inst._atk_lvl = 60
        inst._atk_sp_lvl = 60
    elseif lvl >= pas.lvls_rf[9] then
        inst._atk_lvl = 60
        inst._atk_sp_lvl = 40
    elseif lvl >= pas.lvls_rf[7] then
        inst._atk_lvl = 40
        inst._atk_sp_lvl = 40
    elseif lvl >= pas.lvls_rf[5] then
        inst._atk_lvl = 40
        inst._atk_sp_lvl = 20
    elseif lvl >= pas.lvls_rf[3] then
        inst._atk_lvl = 20
        inst._atk_sp_lvl = 20
    elseif lvl >= pas.lvls_rf[1] then
        inst._atk_lvl = 20
        inst._atk_sp_lvl = 0
    else
        inst._atk_lvl = 0
        inst._atk_sp_lvl = 0
        inst.components.workable:SetWorkable(false) --0级时不可以被锤
    end
    pas.TriggerRevolt_rf(inst, nil, inst._revolt_l or inst.components.timer:TimerExists("moonsurge"))
end
pas.TimerDone_refracted = function(inst, data)
    if data.name == "moonsurge" then
        pas.TriggerRevolt_rf(inst, nil, false)
    end
end
pas.OnOwnerChange_refracted = function(inst, owner, newowners)
    if owner:HasTag("pocketdimension_container") or owner:HasTag("buried") then
		inst._light.entity:SetParent(inst.entity)
		if not inst._light:IsInLimbo() then
			inst._light:RemoveFromScene() --直接隐藏，就算因为等级变化导致亮起来了也没事
		end
	else
		inst._light.entity:SetParent(owner.entity)
		if inst._light:IsInLimbo() then
			inst._light:ReturnToScene()
		end
	end
end
pas.OnRemove_refracted = function(inst)
    inst._light:Remove()
end
pas.OnWorked_refracted = function(inst, worker, workleft, numworks)
    if worker == nil or not worker:HasTag("player") then --不能被非玩家破坏
        inst.components.workable:SetWorkLeft(5)
    end
end
pas.OnFinished_refracted = function(inst, worker)
    --归还宝石
    fns.DropGems(inst, "opalpreciousgem")
    --恢复数据
    inst.components.upgradeable:SetStage(1)
    pas.OnStageUp_refracted(inst)
    --特效
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("stone")
end
pas.NameDetail_refracted = function(inst)
    return fns.NameDetail(inst, CONFIGS_LEGION.REFRACTEDUPDATETIMES)
end
pas.OnSave_refracted = function(inst, data)
	if inst._count > 0 then
		data.count = inst._count
	end
end
pas.OnLoad_refracted = function(inst, data)
	if data ~= nil then
		if data.count ~= nil then
			inst._count = data.count
		end
	end
    pas.SetCount_refracted(inst, inst._count)
    pas.OnStageUp_refracted(inst)
end
pas.Wax_refracted = function(inst, doer, waxitem, right)
    local dd = { state = inst._revolt_l and 2 or 3 }
    return TOOLS_L.WaxObject(inst, doer, waxitem, "refractedmoonlight_item_waxed", dd, nil)
end

table.insert(prefs, Prefab("refractedmoonlight", function()
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddMiniMapEntity() --要在小地图上显示的话，记得加这句
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("refractedmoonlight")
    inst.AnimState:SetBuild("refractedmoonlight")
    inst.AnimState:PlayAnimation("idle", true)

    inst:AddTag("sharp") --武器的标签跟攻击方式跟攻击音效有关 没有特殊的话就用这两个
    inst:AddTag("pointy")
    inst:AddTag("nonpotatable") --这个貌似是不可食用标签？
    inst:AddTag("NORATCHECK") --mod兼容：永不妥协。该道具不算鼠潮分
    inst:AddTag("moontreasure_l")
    inst:AddTag("weapon")
    inst:AddTag("waxable_l")
    inst:AddTag("nomimic_l") --棱镜标签。不让拟态蠕虫进行复制
    if CONFIGS_LEGION.WORLDSWORDLIMITATION then
        inst:AddTag("meteor_protection") --防止被流星破坏
        inst:AddTag("noattack") --防止被巨型蠕虫吃掉
        inst:AddTag("nobundling") --不能被打包、不会被巨食草消化
    else
        inst:AddTag("irreplaceable") --防止被猴子、食人花、坎普斯等拿走，防止被流星破坏，并使其下线时会自动掉落
    end

    inst.MiniMapEntity:SetIcon("refractedmoonlight.tex")
    inst.MiniMapEntity:SetPriority(5) --稀有物品，优先级设高点

    fns.InitLevelNet(inst, pas.NameDetail_refracted)
    LS_C_Init(inst, "refractedmoonlight", false)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end

    inst._dd = {
        img_tex = "refractedmoonlight", img_atlas = "images/inventoryimages/refractedmoonlight.xml",
        img_tex2 = "refractedmoonlight2", img_atlas2 = "images/inventoryimages/refractedmoonlight2.xml",
        build = "refractedmoonlight", fx = "refracted_l_spark_fx"
    }
    -- inst._equip_l = nil
    -- inst._task_fx = nil
    -- inst._revolt_l = nil
    inst._atk = pas.atk_rf
    inst._atk_sp = pas.atk2_rf
    inst._atk_lvl = 0
    inst._atk_sp_lvl = 0
    inst._atkmult = pas.atkmult_rf
    inst._count = 0
    inst._lvl = 0
    inst.fn_onHealthDelta = function(owner, data)
        local percent = 0
        if data and data.newpercent then
            percent = 1 - data.newpercent
        else
            if owner.components.health ~= nil then
                percent = 1 - owner.components.health:GetPercent()
            end
        end
        if percent <= inst._count then
            inst._atkmult = pas.atkmult_rf
        else
            inst._atkmult = pas.atkmult_rf_hurt
        end
        pas.SetAtk_refracted(inst)
    end
    inst.fn_onAttacked = function(owner, data)
        if inst._count > 0 then
            pas.SetCount_refracted(inst, inst._count - 0.5)
        end
    end
    inst.fn_tryRevolt = pas.TryRevolt_refracted
    inst.fn_doFxTask = pas.DoFxTask_refracted
    inst.legionfn_wax = pas.Wax_refracted

    inst:AddComponent("inspectable")

    inst:AddComponent("z_refractedmoonlight")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "refractedmoonlight"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/refractedmoonlight.xml"
    -- inst.components.inventoryitem:SetSinks(true) --落水时会下沉，但是因为标签的关系会回到绚丽大门

    inst:AddComponent("weapon")
    inst.components.weapon:SetDamage(pas.atk_rf)
    inst.components.weapon:SetOnAttack(pas.OnAttack_refracted)

    inst:AddComponent("planardamage")
    inst.components.planardamage:SetBaseDamage(pas.atk2_rf)

    inst:AddComponent("damagetypebonus")
    inst.components.damagetypebonus:AddBonus("shadow_aligned", inst, pas.bonus_rf)

    inst:AddComponent("equippable")
    inst.components.equippable:SetOnEquip(pas.OnEquip_refracted)
    inst.components.equippable:SetOnUnequip(pas.OnUnequip_refracted)

    inst:AddComponent("upgradeable")
    inst.components.upgradeable.upgradetype = UPGRADETYPES.REFRACTED_L
    inst.components.upgradeable.onupgradefn = fns.OnUpgradeFn
    inst.components.upgradeable.onstageadvancefn = pas.OnStageUp_refracted
    inst.components.upgradeable.numstages = CONFIGS_LEGION.REFRACTEDUPDATETIMES + 1 --因为初始等级为1
    inst.components.upgradeable.upgradesperstage = 1

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(5)
    inst.components.workable:SetOnWorkCallback(pas.OnWorked_refracted)
    inst.components.workable:SetOnFinishCallback(pas.OnFinished_refracted)
    inst.components.workable:SetWorkable(false) --0级时不可以被锤

    inst:AddComponent("timer")
    inst:ListenForEvent("timerdone", pas.TimerDone_refracted)

    inst._light = SpawnPrefab("alterguardianhatlight")
    -- inst._light.Light:SetRadius(0.25)
    -- inst._light.Light:SetFalloff(0.7)
    inst._light.Light:SetColour(180/255, 195/255, 150/255)
    -- inst._light.Light:SetIntensity(0.75)
    inst._light.Light:Enable(false)
    TOOLS_L.ListenOwnerChange(inst, pas.OnOwnerChange_refracted, pas.OnRemove_refracted)

    MakeHauntableLaunch(inst)

    inst.OnSave = pas.OnSave_refracted
    inst.OnLoad = pas.OnLoad_refracted

    return inst
end, {
    Asset("ANIM", "anim/refractedmoonlight.zip"),
    Asset("ATLAS", "images/inventoryimages/refractedmoonlight.xml"),
    Asset("IMAGE", "images/inventoryimages/refractedmoonlight.tex"),
    Asset("ATLAS_BUILD", "images/inventoryimages/refractedmoonlight.xml", 256),
    Asset("ATLAS", "images/inventoryimages/refractedmoonlight2.xml"),
    Asset("IMAGE", "images/inventoryimages/refractedmoonlight2.tex"),
    Asset("ATLAS_BUILD", "images/inventoryimages/refractedmoonlight2.xml", 256)
}, {
    "refracted_l_spark_fx", "refracted_l_wave_fx",
    "refracted_l_skylight_fx", "refracted_l_light_fx",
    "alterguardianhatlight"
}))

--------------------------------------------------------------------------
--[[ 月炆宝炊（红宝石） ]]
--------------------------------------------------------------------------

pas.OnUpgrade_simmer_item = function(item, doer, target, result)
    local vari = result.SoundEmitter or doer.SoundEmitter
    if vari ~= nil then
        vari:PlaySound("dontstarve/common/place_structure_straw")
    end
    local skin = item.components.skinedlegion:GetSkin()
    if skin ~= nil then
        result.components.skinedlegion:SetSkin(skin, LS_GetID(item, doer))
    end
    ------将原箱子中的物品转移到新箱子中
    local x, y, z = target.Transform:GetWorldPosition()
    local cpt = result.components.container
    local cpt2 = target.components.container
    local moon = result.components.moonsimmered
    if moon ~= nil then moon.cooking = true end
    if cpt2 ~= nil then
        cpt2:Close() --强制关闭使用中的箱子
        cpt2.canbeopened = false
        if cpt ~= nil then
            local allitems = cpt2:RemoveAllItems()
            for slot, v in ipairs(allitems) do
                v.Transform:SetPosition(x, y, z) --防止放不进容器时，掉在世界原点
                cpt:GiveItem(v, slot) --传入slot，是为了保持物品单个的状态，而不是自动被叠加在一起
            end
        else
            cpt2:DropEverything()
        end
    end
    ------继承烹饪数据
    cpt2 = target.components.stewer
    if cpt2 ~= nil and cpt2.product ~= nil then
        local allitems = {}
        if cpt2.done then --已经烹饪完成，只生成料理
            allitems[5] = SpawnPrefab(cpt2.product)
            if allitems[5] ~= nil and allitems[5].components.stackable ~= nil then --还得考虑烹饪数量大于1的情况
                local rp = COOKING.GetRecipe("portablecookpot", cpt2.product)
                if rp ~= nil and rp.stacksize ~= nil and rp.stacksize > 1 then
                    allitems[5].components.stackable:SetStackSize(rp.stacksize)
                end
            end
        elseif cpt2.ingredient_prefabs ~= nil then --还在烹饪中，那就生成食材，并自动开始烹饪
            local it
            for _, name in pairs(cpt2.ingredient_prefabs) do
                it = SpawnPrefab(name)
                if it ~= nil then
                    table.insert(allitems, it)
                end
            end
        end
        for slot, v in pairs(allitems) do
            v.Transform:SetPosition(x, y, z) --防止放不进容器时，掉在世界原点
            if cpt ~= nil then
                cpt:GiveItem(v, slot) --传入slot，是为了保持物品单个的状态，而不是自动被叠加在一起
            end
        end
        if moon ~= nil then
            moon.cooking = nil
            if not cpt2.done then
                moon:TryCooking(doer)
            end
        end
    elseif moon ~= nil then
        moon.cooking = nil
    end

    --因为套件只能升级地面上的对象，不能对格子里的物品生效。所以不用考虑 被升级物品 在容器里的情况
    item:Remove() --该道具是一次性的
end
fns.MakeItem({
    name = "simmeredmoonlight",
    prefabs = { "simmeredmoonlight", "simmeredmoonlight_pro", "simmeredmoonlight_pro_item" },
    kitdata = {
        cookpot = { prefabresult = "simmeredmoonlight", onupgradefn = pas.OnUpgrade_simmer_item },
        portablecookpot = { prefabresult = "simmeredmoonlight_pro", onupgradefn = pas.OnUpgrade_simmer_item },
        portablecookpot_item = { prefabresult = "simmeredmoonlight_pro_item", onupgradefn = pas.OnUpgrade_simmer_item }
    }
})

--------------------

pas.times_simmer = CONFIGS_LEGION.SIMMERUPDATETIMES or 20
pas.lightrad_simmer = { 0.3, 2.5 }
pas.spiceanims = { --用来主动兼容别的模组的香料贴图
    spice_jelly = { --香料key，与在食谱recipe里的 spice 变量相同(但是字符要全小写)
        build = "medal_spices", --香料所在文件名
        symbol = "spice_jelly" --香料所在的symbol名。空值时默认为 香料key
    },
    spice_voltjelly = { build = "medal_spices" },
    spice_phosphor = { build = "medal_spices" },
    spice_moontree_blossom = { build = "medal_spices" },
    spice_cactus_flower = { build = "medal_spices" },
    spice_blood_sugar = { build = "medal_spices" },
    spice_rage_blood_sugar = { build = "medal_spices" },
    spice_soul = { build = "medal_spices" },
    spice_potato_starch = { build = "medal_spices" },
    spice_poop = { build = "medal_spices" },
    spice_plantmeat = { build = "medal_spices" },
    spice_mandrake_jam = { build = "medal_spices" },
    spice_pomegranate = { build = "medal_spices" },
    spice_withered_royal_jelly = { build = "medal_spices" }
}

pas.OnReplicated_simmer_inf = function(inst)
    if inst.replica.container ~= nil then
        inst.replica.container:WidgetSetup("simmeredmoonlight_inf")
    end
end
pas.OnReplicated_simmer = function(inst)
    if inst.replica.container ~= nil then
        inst.replica.container:WidgetSetup("simmeredmoonlight")
    end
end
pas.SetPerishRate_simmer = function(inst, item)
    return inst.perishrate_l
end
pas.OnOpen_simmer = function(inst, data)
    if data.doer ~= nil and inst.components.moonsimmered ~= nil then
        inst.components.moonsimmered:OnBoxOpen(data.doer)
    end
    inst.AnimState:PlayAnimation("open")
    inst.AnimState:PushAnimation("opened", true)
    -- if inst._dd ~= nil and inst._dd.openfn ~= nil then
    --     inst._dd.openfn(inst)
    -- end
    if not inst.SoundEmitter:PlayingSound("idlesound1") then
        inst.SoundEmitter:PlaySound("dontstarve/creatures/together/toad_stool/spore_cloud_LP", "idlesound1", 0.7)
    end
    if not inst.SoundEmitter:PlayingSound("idlesound2") then
        inst.SoundEmitter:PlaySound("hookline_2/common/moon_alter/cosmic_crown/LP", "idlesound2", 0.7)
    end
    inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_open")
end
pas.OnClose_simmer = function(inst, doer)
    if inst.components.moonsimmered ~= nil then
        inst.components.moonsimmered:OnBoxClose()
    end
    inst.AnimState:PlayAnimation("close")
    inst.AnimState:PushAnimation("closed", false)

    inst.SoundEmitter:KillSound("idlesound1")
    inst.SoundEmitter:KillSound("idlesound2")
    -- inst.SoundEmitter:PlaySound("dontstarve/impacts/impact_shell_armour_sharp")
    inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_close")
end
pas.SetLevel_simmer = function(inst)
    local lvl = inst.components.upgradeable:GetStage() - 1
    inst._lvl_l:set(lvl)
    if lvl > pas.times_simmer then --在设置变换中，会出现当前等级大于最大等级的情况
        lvl = pas.times_simmer
    elseif lvl < 0 then
        lvl = 0
    end
    inst.Light:SetRadius(Remap(lvl, 0, pas.times_simmer, pas.lightrad_simmer[1], pas.lightrad_simmer[2])) --发光范围
    if inst.components.moonsimmered ~= nil then
        inst.components.moonsimmered.perishpercent = Remap(lvl, 0, pas.times_simmer, 0, 0.5) --对烹饪产物的新鲜度比例的加成
        inst.components.moonsimmered.time_mult = Remap(lvl, 0, pas.times_simmer, 1.0, 10.0) --对烹饪速度的加成
    end
end
pas.OnSave_simmer = function(inst, data)
    if inst.legiontag_chestupgraded then
        data.legiontag_chestupgraded = true
    end
end
pas.OnLoad_simmer = function(inst, data)
	if data ~= nil then
        if data.legiontag_chestupgraded then
            inst.legiontag_chestupgraded = true
        end
    end
    pas.SetLevel_simmer(inst)
end
pas.DealData_simmer = function(inst, data)
    local res
    if data.st ~= nil then
        res = STRINGS.NAMEDETAIL_L.MOONSIMMERED[data.st]
    end
    if res == nil then
        return fns.NameDetail(inst, pas.times_simmer)
    else
        return fns.NameDetail(inst, pas.times_simmer).."\n"..res
    end
end
pas.GetData_simmer = function(inst)
    local data = {}
    local cpt = inst.components.moonsimmered
    if cpt.fx ~= nil then --有特效代表着有烹制数据
        if cpt.show.prefab_spice ~= nil or cpt.lastinfokey == 1 then --有香料贴图，代表是调味
            data.st = 4
        elseif cpt.show.name ~= nil or cpt.lastinfokey == 2 then --有料理贴图，代表是烹饪
            data.st = 1
        else --烤制
            data.st = 7
        end
        if cpt.todokey == nil then --说明已经结束
            data.st = data.st + 2
        elseif cpt.task_simmer == nil then --说明暂停中
            data.st = data.st + 1
        end
    end
    return data
end

fns.MakeSimmered = function(dd)
    table.insert(prefs, Prefab(dd.name, function()
        local inst = CreateEntity()
        inst.entity:AddTransform()
        inst.entity:AddAnimState()
        inst.entity:AddSoundEmitter()
        inst.entity:AddMiniMapEntity()
        inst.entity:AddLight()
        inst.entity:AddNetwork()

        inst.MiniMapEntity:SetIcon("simmeredmoonlight.tex")
        inst:SetDeploySmartRadius(0.5) --锅是1
        inst:SetPhysicsRadiusOverride(0.25) --锅是0.5
        MakeObstaclePhysics(inst, inst.physicsradiusoverride)

        inst.Light:SetRadius(pas.lightrad_simmer[1])
        inst.Light:SetFalloff(0.85)
        inst.Light:SetIntensity(0.75)
        inst.Light:SetColour(180/255, 195/255, 150/255)
        inst.Light:Enable(true)

        inst:AddTag("structure")
        inst:AddTag("meteor_protection") --防止被流星破坏
        inst:AddTag("moontreasure_l")

        inst.AnimState:SetBank("simmeredmoonlight")
        inst.AnimState:SetBuild("simmeredmoonlight")
        inst.AnimState:PlayAnimation("closed", false)
        inst.AnimState:SetLightOverride(0.1)
        if dd.fn_common ~= nil then
            dd.fn_common(inst)
        end

        fns.SetRotatable_com(inst)
        fns.InitLevelNet(inst)
        TOOLS_L.InitMouseInfo(inst, pas.DealData_simmer, pas.GetData_simmer)

        inst.entity:SetPristine()
        if not TheWorld.ismastersim then
            inst.OnEntityReplicated = dd.isinf and pas.OnReplicated_simmer_inf or pas.OnReplicated_simmer
            return inst
        end

        inst.perishrate_l = 0.75

        inst:AddComponent("inspectable")
        inst:AddComponent("savedrotation")

        inst:AddComponent("container")
        if dd.isinf then
            inst.components.container:WidgetSetup("simmeredmoonlight_inf")
            inst.components.container:EnableInfiniteStackSize(true)
        else
            inst.components.container:WidgetSetup("simmeredmoonlight")
        end
        inst.components.container.onopenfn = pas.OnOpen_simmer
        inst.components.container.onclosefn = pas.OnClose_simmer
        inst.components.container.skipclosesnd = true
        inst.components.container.skipopensnd = true

        inst:AddComponent("preserver")
        inst.components.preserver:SetPerishRateMultiplier(pas.SetPerishRate_simmer)

        inst:AddComponent("lootdropper")

        inst:AddComponent("moonsimmered") --关键组件！批量烹饪
        inst.components.moonsimmered.spiceanims = pas.spiceanims --别的模组也可以改这个数据，来让自己的香料能被显示出来

        inst:AddComponent("workable")
        inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
        inst.components.workable:SetWorkLeft(5)

        inst:AddComponent("upgradeable")
        inst.components.upgradeable.upgradetype = UPGRADETYPES.SIMMER_L
        inst.components.upgradeable.onupgradefn = fns.OnUpgradeFn --升级时
        inst.components.upgradeable.onstageadvancefn = pas.SetLevel_simmer --等级变化时
        inst.components.upgradeable.numstages = pas.times_simmer + 1
        inst.components.upgradeable.upgradesperstage = 1

        MakeHauntable(inst)
        TOOLS_L.MakeSnowCovered_serv(inst)

        inst.OnSave = pas.OnSave_simmer
        inst.OnLoad = pas.OnLoad_simmer

        -- if TUNING.SMART_SIGN_DRAW_ENABLE then --不需要兼容智能木牌
        --     SMART_SIGN_DRAW(inst)
        -- end
        if TUNING.FUNCTIONAL_MEDAL_IS_OPEN then
            SetImmortalable(inst, 2, nil)
        end
        if dd.fn_server ~= nil then
            dd.fn_server(inst)
        end

        return inst
    end, dd.assets, dd.prefabs))
end

pas.OnUpgrade_simmer = function(inst, item, doer)
    local is_chestupgrader_l = item:HasTag("chestupgrader_l")
    if item.components.stackable ~= nil then
		item.components.stackable:Get(1):Remove()
	else
		item:Remove()
	end
    local x, y, z = inst.Transform:GetWorldPosition()
    local fx = SpawnPrefab("chestupgrade_stacksize_fx")
    if fx ~= nil then
        fx.Transform:SetPosition(x, y, z)
    end
    local newbox = SpawnPrefab(inst.prefab.."_inf")
    if newbox ~= nil then
        local skin = inst.components.skinedlegion:GetSkin()
        if skin ~= nil then
            newbox.components.skinedlegion:SetSkin(skin, LS_GetID(inst, doer))
        end
        newbox.legiontag_chestupgraded = is_chestupgrader_l --表明这是用月石角撑升级的

        --继承等级
        newbox.components.upgradeable:SetStage(inst.components.upgradeable:GetStage())
        pas.SetLevel_simmer(newbox)

        --继承能力勋章的不朽等级
        local cpt = inst.components.medal_immortal
        if cpt ~= nil and newbox.components.medal_immortal ~= nil then
            local ilvl = cpt.GetLevel ~= nil and cpt:GetLevel() or 0
            if ilvl >= 2 and cpt.SetImmortal ~= nil then --由于升级后格子变多，为了平衡，只能升一半
                newbox.components.medal_immortal:SetImmortal(1)
            end
        end

        --继承已经过时间。感觉意义不是很大
        cpt = inst.components.moonsimmered
        if cpt ~= nil and newbox.components.moonsimmered ~= nil then
            cpt:PauseSimmering()
            newbox.components.moonsimmered.time_pass = cpt.time_pass
        end

        newbox.Transform:SetPosition(x, y, z)

        --将原箱子中的物品转移到新箱子中
        cpt = inst.components.container
        if cpt ~= nil then
            cpt:Close() --强制关闭使用中的箱子
            cpt.canbeopened = false
            if not cpt:IsEmpty() then
                if newbox.components.container ~= nil then
                    local allitems = cpt:RemoveAllItems()
                    for _, v in ipairs(allitems) do
                        v.Transform:SetPosition(x, y, z) --防止放不进容器时，掉在世界原点
                        newbox.components.container:GiveItem(v)
                    end
                else
                    cpt:DropEverything()
                end
            end
        end
    end
    inst:Remove()
end
pas.OnDismantle_simmer_pro = function(inst, doer)
    local isinf = inst.prefab == "simmeredmoonlight_pro_inf"
    local box = SpawnPrefab(isinf and "simmeredmoonlight_pro_inf_item" or "simmeredmoonlight_pro_item")
    local skin = inst.components.skinedlegion:GetSkin()
    if skin ~= nil then
        box.components.skinedlegion:SetSkin(skin, LS_GetID(inst, doer))
    end
    box.components.upgradeable:SetStage(inst.components.upgradeable:GetStage()) --继承等级
    fns.SetLevel(box)
    local cpt = inst.components.container
    if not cpt:IsEmpty() then --继承容器信息
        local data = {}
        local vcpt
        for k, v in pairs(cpt.slots) do
            if v:IsValid() and v.persists then
                local data2 = { saved = v:GetSaveRecord() }
                vcpt = v.components.stackable
                if vcpt ~= nil and vcpt:IsOverStacked() then --无限叠加时才需要额外记录数量和新鲜度数据
                    data2.num = vcpt:StackSize()
                    vcpt = v.components.perishable
                    if vcpt ~= nil then
                        data2.percent = vcpt:GetPercent()
                        if not vcpt:IsPerishing() then
                            data2.pause = true
                        end
                    end
                end
                data[k] = data2
            end
        end
        box.boxitems_l = data
        cpt = inst.components.moonsimmered --保存烹饪数据
        if cpt ~= nil then
            cpt:PauseSimmering()
            box.cookdd_l = cpt:OnSave()
        end
    end
    cpt = inst.components.medal_immortal
    if cpt ~= nil and cpt.GetLevel ~= nil then --保存能力勋章的不朽等级
        cpt = cpt:GetLevel() or 0
        if cpt > 0 then
            box.medal_ilvl = cpt
        end
    end
    box.legiontag_chestupgraded = inst.legiontag_chestupgraded --继承无限升级物
    box.Transform:SetPosition(inst.Transform:GetWorldPosition())
    if doer ~= nil then
        if doer.components.inventory ~= nil and box.components.inventoryitem ~= nil then
            doer.components.inventory:GiveItem(box) --收起时直接放身上，就不用再捡一遍了
        end
        if doer.SoundEmitter ~= nil then --锅会被移除，物品锅会被捡起，所以只能由doer自己发出声音了
            doer.SoundEmitter:PlaySound("dontstarve/common/cookingpot_close")
        end
    end
    inst:Remove()
end
pas.OnWorked_simmer = function(inst, worker, workleft, numworks) --敲击时
    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PushAnimation("closed", false)
    inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_close")
    inst.components.container:Close()
    if fns.NoWorked(inst, worker) then --只能被玩家或者船体破坏
        inst.components.workable:SetWorkLeft(5)
        return
    end
    -- inst.components.container:DropEverything()
end
pas.OnFinished_simmer = function(inst, worker) --破坏时，丢出容器内物品、返还无限升级物、锅、宝石、套件
    if inst.components.container ~= nil then
        if inst.components.moonsimmered ~= nil then --后续不用恢复了，反正inst就要被删除了
            inst.components.moonsimmered.cooking = true
        end
        inst.components.container:DropEverything()
    end
    if inst.legiontag_chestupgraded then
        inst.components.lootdropper:SpawnLootPrefab("chestupgrader_l")
    elseif inst.prefab == "simmeredmoonlight_inf" or inst.prefab == "simmeredmoonlight_pro_inf_item" then
        inst.components.lootdropper:SpawnLootPrefab("chestupgrade_stacksize")
    end
    local x, y, z = inst.Transform:GetWorldPosition()
    local box = SpawnPrefab(inst.components.container ~= nil and "cookpot" or "portablecookpot_item")
    if box ~= nil then
        box.Transform:SetPosition(x, y, z)
    end
    fns.OnFinished_base(inst, worker, x, y, z, "redgem", "simmeredmoonlight_item")
end
pas.OnFinished_simmer_pro = function(inst, worker) --破坏时，记录烹饪数据，并变回物品锅状态
    local fx = SpawnPrefab("collapse_small")
    fx.Transform:SetPosition(inst.Transform:GetWorldPosition())
    fx:SetMaterial("stone")
    pas.OnDismantle_simmer_pro(inst, nil)
    if worker ~= nil and worker.SoundEmitter ~= nil then --锅会被移除，所以只能由worker自己发出声音了
        worker.SoundEmitter:PlaySound("dontstarve/common/cookingpot_close")
    end
end
pas.OnWorked_simmer_inf = function(inst, worker, workleft, numworks) --敲击时，尝试掉落一轮容器内物品，直到容器空了才被真的破坏
    inst.AnimState:PlayAnimation("hit")
    inst.AnimState:PushAnimation("closed", false)
    inst.SoundEmitter:PlaySound("dontstarve/common/cookingpot_close")
    inst.components.container:Close()
    if worker == nil or not worker:HasTag("player") then --只能被玩家破坏。没必要弄烂箱子设定
        inst.components.workable:SetWorkLeft(5)
        return
    end
    local cpt = inst.components.moonsimmered --敲击时要停止烹饪
    cpt.cooking = true
    cpt.time_pass = nil
    cpt:StopSimmering()
    cpt:SetFx(false)
    cpt:ShowOff()
    inst.components.container:DropEverything(nil, true)
    cpt.cooking = nil
    if not inst.components.container:IsEmpty() then --如果箱子里还有物品，那就不能被破坏
        inst.components.workable:SetWorkLeft(5)
    end
end

fns.MakeSimmered({ --普通版
    name = "simmeredmoonlight",
    assets = {
        Asset("ANIM", "anim/ui_chest_3x3.zip"), --官方的容器栏背景动画模板
        Asset("ANIM", "anim/ui_simmeredmoonlight_5x1.zip"),
        Asset("ANIM", "anim/simmeredmoonlight.zip")
    },
    prefabs = {
        "simmeredmoonlight_item", "simmeredmoonlight_inf", "chestupgrade_stacksize_fx", "simmerfire_l_fx"
    },
    fn_common = function(inst)
        inst:AddTag("chest_upgradeable") --能被 弹性空间制造器 升级
        LS_C_Init(inst, "simmeredmoonlight_item", false, "data_up")
    end,
    fn_server = function(inst)
        inst.legionfn_chestupgrade = pas.OnUpgrade_simmer
        inst.components.workable:SetOnWorkCallback(pas.OnWorked_simmer)
        inst.components.workable:SetOnFinishCallback(pas.OnFinished_simmer)
    end
})
fns.MakeSimmered({ --便携版
    name = "simmeredmoonlight_pro",
    assets = {
        Asset("ANIM", "anim/ui_chest_3x3.zip"), --官方的容器栏背景动画模板
        Asset("ANIM", "anim/ui_simmeredmoonlight_5x1.zip"),
        Asset("ANIM", "anim/simmeredmoonlight.zip")
    },
    prefabs = {
        "simmeredmoonlight_pro_item", "simmeredmoonlight_pro_inf", "chestupgrade_stacksize_fx", "simmerfire_l_fx"
    },
    fn_common = function(inst)
        inst:AddTag("chest_upgradeable") --能被 弹性空间制造器 升级
        inst.AnimState:OverrideSymbol("potbase", "simmeredmoonlight", "potbase_pro")
        LS_C_Init(inst, "simmeredmoonlight_item", false, "data_uppro")
    end,
    fn_server = function(inst)
        inst.legionfn_chestupgrade = pas.OnUpgrade_simmer
        inst.components.inspectable.nameoverride = "simmeredmoonlight"
        inst.components.workable:SetOnWorkCallback(pas.OnWorked_simmer)
        inst.components.workable:SetOnFinishCallback(pas.OnFinished_simmer_pro)
        inst:AddComponent("portablestructure")
        inst.components.portablestructure:SetOnDismantleFn(pas.OnDismantle_simmer_pro)
    end
})
fns.MakeSimmered({ --普通版(无限)
    name = "simmeredmoonlight_inf", isinf = true,
    assets = {
        Asset("ANIM", "anim/ui_chest_3x3.zip"), --官方的容器栏背景动画模板
        Asset("ANIM", "anim/ui_simmeredmoonlight_inf_5x4.zip"),
        Asset("ANIM", "anim/simmeredmoonlight.zip")
    },
    prefabs = {
        "simmeredmoonlight_item", "chestupgrade_stacksize", "simmerfire_l_fx"
    },
    fn_common = function(inst)
        inst.AnimState:OverrideSymbol("pot", "simmeredmoonlight", "pot_inf")
        LS_C_Init(inst, "simmeredmoonlight_item", false, "data_up_inf")
    end,
    fn_server = function(inst)
        inst.components.workable:SetOnWorkCallback(pas.OnWorked_simmer_inf)
        inst.components.workable:SetOnFinishCallback(pas.OnFinished_simmer)
    end
})
fns.MakeSimmered({ --便携版(无限)
    name = "simmeredmoonlight_pro_inf", isinf = true,
    assets = {
        Asset("ANIM", "anim/ui_chest_3x3.zip"), --官方的容器栏背景动画模板
        Asset("ANIM", "anim/ui_simmeredmoonlight_inf_5x4.zip"),
        Asset("ANIM", "anim/simmeredmoonlight.zip")
    },
    prefabs = {
        "simmeredmoonlight_pro_inf_item", "simmerfire_l_fx"
    },
    fn_common = function(inst)
        inst.AnimState:OverrideSymbol("pot", "simmeredmoonlight", "pot_inf")
        inst.AnimState:OverrideSymbol("potbase", "simmeredmoonlight", "potbase_pro")
        LS_C_Init(inst, "simmeredmoonlight_item", false, "data_uppro_inf")
    end,
    fn_server = function(inst)
        inst.components.inspectable.nameoverride = "simmeredmoonlight_inf"
        inst.components.workable:SetOnWorkCallback(pas.OnWorked_simmer)
        inst.components.workable:SetOnFinishCallback(pas.OnFinished_simmer_pro)
        inst:AddComponent("portablestructure")
        inst.components.portablestructure:SetOnDismantleFn(pas.OnDismantle_simmer_pro)
    end
})

pas.OnDeploy_simmer_pro_item = function(inst, pt, deployer, rot)
    local isinf = inst.prefab == "simmeredmoonlight_pro_inf_item"
    local pot = SpawnPrefab(isinf and "simmeredmoonlight_pro_inf" or "simmeredmoonlight_pro")
    if pot ~= nil then
        local skin = inst.components.skinedlegion:GetSkin()
        if skin ~= nil then
            pot.components.skinedlegion:SetSkin(skin, LS_GetID(inst, deployer))
        end
        pot.components.upgradeable:SetStage(inst.components.upgradeable:GetStage()) --继承等级
        pas.SetLevel_simmer(pot)
        if inst.medal_ilvl ~= nil and inst.medal_ilvl > 0 then --继承能力勋章的不朽等级
            local cpt = pot.components.medal_immortal
            if cpt ~= nil and cpt.SetImmortal ~= nil then
                cpt:SetImmortal(inst.medal_ilvl)
            end
        end
        pot.legiontag_chestupgraded = inst.legiontag_chestupgraded --继承无限升级物

        pot.Physics:SetCollides(false)
        pot.Physics:Teleport(pt.x, 0, pt.z)
        pot.Physics:SetCollides(true)
        pot.AnimState:PlayAnimation("close")
        pot.AnimState:PushAnimation("closed", false)
        pot.SoundEmitter:PlaySound("dontstarve/common/cookingpot_close")

        if inst.boxitems_l ~= nil then --还原锅里的物品
            local cpt, time
            local potcpt = pot.components.moonsimmered
            local cookdd = inst.cookdd_l
            if inst.medal_ilvl == nil and --兼容不朽
                (cookdd == nil or not (cookdd.fx or cookdd.todokey ~= nil)) --烹饪时或未打开时，就是永久保鲜的
            then
                time = (inst.itemdt_l + GetTime() - inst.itemtime_l) * 0.75 --也要用上保鲜系数
            end
            potcpt.cooking = true
            for slot, v in pairs(inst.boxitems_l) do
                if v.saved ~= nil and v.saved.prefab ~= nil then
                    local item = SpawnPrefab(v.saved.prefab, v.saved.skinname, v.saved.skin_id)
                    if item ~= nil then
                        item:SetPersistData(v.saved.data, nil)
                        if v.num ~= nil and v.num > 0 then --数量是可能会有变动的
                            cpt = item.components.stackable
                            if cpt ~= nil and cpt:StackSize() ~= v.num then
                                cpt:SetStackSize(v.num)
                            end
                        end
                        if time ~= nil then --平衡性考虑：不可能让食物在里面永久保鲜的，得同步修正新鲜度
                            cpt = item.components.perishable
                            if cpt ~= nil and cpt:IsPerishing() and cpt.perishtime ~= nil and
                                cpt.perishremainingtime ~= nil and cpt.perishremainingtime > 3
                            then --保留3秒，让腐烂操作之后自己完成，这里就不用管腐烂操作了
                                cpt.perishremainingtime = math.max(3, cpt.perishremainingtime - time)
                            end
                        end
                        item.Transform:SetPosition(pt.x, 0, pt.z) --防止放不进容器时，掉在世界原点
                        pot.components.container:GiveItem(item, slot)
                    end
                end
            end
            inst.boxitems_l = nil
            potcpt.cooking = nil
            if cookdd ~= nil then --继承烹饪数据
                potcpt:OnLoad(cookdd)
            end
        end

        inst:Remove()
        PreventCharacterCollisionsWithPlacedObjects(pot)
    end
end
pas.OnWorked_simmer_pro_item = function(inst, worker, workleft, numworks) --敲击时，丢出一组容器物品，直到丢完才能被破坏
    if worker == nil or not worker:HasTag("player") then --只能被玩家破坏
        inst.components.workable:SetWorkLeft(2)
        return
    end
    if inst.boxitems_l ~= nil then --丢出一组物品
        local item, cpt, hasitem, time
        local x, y, z = inst.Transform:GetWorldPosition()
        local cookdd = inst.cookdd_l
        if inst.medal_ilvl == nil and --兼容不朽
            (cookdd == nil or not (cookdd.fx or cookdd.todokey ~= nil)) --烹饪时或未打开时，就是永久保鲜的
        then
            time = (inst.itemdt_l + GetTime() - inst.itemtime_l) * 0.75 --也要用上保鲜系数
        end
        for k, v in pairs(inst.boxitems_l) do
            if v.saved ~= nil and v.saved.prefab ~= nil then
                item = SpawnPrefab(v.saved.prefab, v.saved.skinname, v.saved.skin_id)
                if item ~= nil then
                    if v.num ~= nil then --说明是无限叠加的
                        if v.num > 0 then
                            cpt = item.components.stackable
                            if cpt == nil then
                                v.num = nil
                            else
                                if v.num >= cpt.maxsize then
                                    cpt:SetStackSize(cpt.maxsize)
                                    v.num = v.num - cpt.maxsize
                                else
                                    cpt:SetStackSize(v.num)
                                    v.num = 0
                                    item:PushEvent("l_autostack") --堆叠没满，可以自动堆叠
                                end
                            end
                        end
                        if v.percent ~= nil and v.percent > 0 then
                            cpt = item.components.perishable
                            if cpt ~= nil then
                                if v.pause then
                                    cpt:StopPerishing()
                                end
                                cpt:SetPercent(v.percent)
                            end
                        end
                    else
                        item:SetPersistData(v.saved.data, nil)
                        if item.components.stackable ~= nil and not item.components.stackable:IsFull() then
                            item:PushEvent("l_autostack") --堆叠没满，可以自动堆叠
                        end
                    end
                    if time ~= nil then --平衡性考虑：不可能让食物在里面永久保鲜的，得同步修正新鲜度
                        cpt = item.components.perishable
                        if cpt ~= nil and cpt:IsPerishing() and cpt.perishtime ~= nil and
                            cpt.perishremainingtime ~= nil and cpt.perishremainingtime > 3
                        then --保留3秒，让腐烂操作之后自己完成，这里就不用管腐烂操作了
                            cpt.perishremainingtime = math.max(3, cpt.perishremainingtime - time)
                        end
                    end
                    item.Transform:SetPosition(x, y, z)
                    if item.components.inventoryitem ~= nil then
                        item.components.inventoryitem:OnDropped(true)
                    end
                end
            else
                item = nil
            end
            if item == nil or v.num == nil or v.num <= 0 then
                inst.boxitems_l[k] = nil
            else
                hasitem = true
            end
        end
        if hasitem then
            inst.components.workable:SetWorkLeft(2) --如果还有容器物品，那就不能被破坏
        else
            inst.boxitems_l = nil
        end
    end
end
pas.NameDetail_simmer_pro_item = function(inst)
    return fns.NameDetail(inst, pas.times_simmer)
end
pas.OnSave_simmer_pro_item = function(inst, data)
    if inst.legiontag_chestupgraded then
        data.legiontag_chestupgraded = true
    end
    if inst.boxitems_l ~= nil then
        data.boxitems_l = inst.boxitems_l
        data.itemdt_l = inst.itemdt_l + GetTime() - inst.itemtime_l
        data.cookdd_l = inst.cookdd_l
    end
    data.medal_ilvl = inst.medal_ilvl
end
pas.OnLoad_simmer_pro_item = function(inst, data)
	if data ~= nil then
        if data.legiontag_chestupgraded then
            inst.legiontag_chestupgraded = true
        end
        if type(data.boxitems_l) == "table" then
            inst.boxitems_l = data.boxitems_l
            if data.itemdt_l ~= nil then
                inst.itemdt_l = data.itemdt_l
            end
            if type(data.cookdd_l) == "table" then
                inst.cookdd_l = data.cookdd_l
            end
        end
        if data.medal_ilvl ~= nil then
            inst.medal_ilvl = data.medal_ilvl
        end
    end
    fns.SetLevel(inst)
end
pas.OnLongUpdate_simmer_pro_item = function(inst, dt)
    if inst.boxitems_l ~= nil then
        local timenow = GetTime()
        if timenow > inst.itemtime_l then
            local dtt = timenow - inst.itemtime_l
            if dtt >= dt then --从洞穴上地面，地面对象可能就是触发这个情况。别把时间算多了
                dt = dtt
            else --这种应该是单纯的跳时间，比如用t键模组跳时间。需要把已经过去的时间给补上
                dt = dt + dtt
            end
        end
        inst.itemdt_l = inst.itemdt_l + dt
        inst.itemtime_l = timenow
    end
end
pas.OnUpgrade_simmer_pro_item = function(inst, item, doer)
    local is_chestupgrader_l = item:HasTag("chestupgrader_l")
    if item.components.stackable ~= nil then
		item.components.stackable:Get(1):Remove()
	else
		item:Remove()
	end
    local x, y, z = inst.Transform:GetWorldPosition()
    local newbox = SpawnPrefab("simmeredmoonlight_pro_inf_item")
    if newbox ~= nil then
        local skin = inst.components.skinedlegion:GetSkin()
        if skin ~= nil then
            newbox.components.skinedlegion:SetSkin(skin, LS_GetID(inst, doer))
        end
        newbox.legiontag_chestupgraded = is_chestupgrader_l --表明这是用月石角撑升级的
        newbox.components.upgradeable:SetStage(inst.components.upgradeable:GetStage()) --继承等级
        fns.SetLevel(newbox)
        if inst.boxitems_l ~= nil then --继承容器物品与烹饪数据
            newbox.boxitems_l = inst.boxitems_l
            newbox.itemdt_l = inst.itemdt_l or 0
            newbox.cookdd_l = inst.cookdd_l
        end
        if inst.medal_ilvl ~= nil then --继承能力勋章的不朽等级
            newbox.medal_ilvl = inst.medal_ilvl
        end

        local owner = inst.components.inventoryitem.owner
        if owner ~= nil then --说明原物品是在某个容器或物品栏里
            local cpt = owner.components.inventory or owner.components.container
            x, y, z = doer.Transform:GetWorldPosition()
            --由于容器中的物品的位置可能是世界原点，这里以doer的为准，防止失败时掉到世界原点
            newbox.Transform:SetPosition(x, y, z)
            if cpt ~= nil then
                local slot = cpt:GetItemSlot(inst) --获取当前所在格子
                if slot ~= nil then
                    --先把原物品给挪出来，腾出位置。原物品会在之后被删除，所以不用管移出来后如何处理
                    if cpt.RemoveItem_Internal ~= nil then --container组件才有的
                        cpt:RemoveItem_Internal(inst, slot, true)
                    elseif cpt.RemoveItem ~= nil then
                        cpt:RemoveItem(inst, true, false)
                    end
                    cpt:GiveItem(newbox, slot) --然后把新物品放入原位置
                end
            end
        else --不考虑是否被装饰的情况了。因为官方也没有给 被装饰物 加任何标记，所以不好判定
            newbox.Transform:SetPosition(x, y, z)
        end
    end
    local fx = SpawnPrefab("chestupgrade_stacksize_fx")
    if fx ~= nil then
        fx.Transform:SetPosition(x, y, z)
    end
    inst:Remove()
end

table.insert(prefs, Prefab("simmeredmoonlight_pro_item", function() --便携版(物品)
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower() --能当装饰品需要这个
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("simmeredmoonlight")
    inst.AnimState:SetBuild("simmeredmoonlight")
    inst.AnimState:PlayAnimation("idle_pro_item")
    inst.AnimState:SetLightOverride(0.1)
    inst:AddTag("furnituredecor") --能当装饰品
    inst:AddTag("chest_upgradeable") --能被 弹性空间制造器 升级
    inst:AddTag("portableitem") --用来确定deployable动作的显示名称
    LS_C_Init(inst, "simmeredmoonlight_item", true, "data_uppro_item")
    fns.InitLevelNet(inst, pas.NameDetail_simmer_pro_item)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end

    inst.itemtime_l = GetTime()
    inst.itemdt_l = 0

    inst:AddComponent("inspectable")
    inst.components.inspectable.nameoverride = "simmeredmoonlight"

    inst:AddComponent("lootdropper")
    inst:AddComponent("furnituredecor")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "simmeredmoonlight_pro_item"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/simmeredmoonlight_pro_item.xml"

    inst:AddComponent("deployable")
    inst.components.deployable.ondeploy = pas.OnDeploy_simmer_pro_item
    -- inst.components.deployable:SetDeployMode(mode)
    -- inst.components.deployable:SetDeploySpacing(spacing or DEPLOYSPACING.LESS)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(2)
    inst.components.workable:SetOnWorkCallback(pas.OnWorked_simmer_pro_item)
    inst.components.workable:SetOnFinishCallback(pas.OnFinished_simmer)

    inst:AddComponent("upgradeable")
    inst.components.upgradeable.upgradetype = UPGRADETYPES.SIMMER_L
    inst.components.upgradeable.onupgradefn = fns.OnUpgradeFn --升级时
    inst.components.upgradeable.onstageadvancefn = fns.SetLevel --等级变化时
    inst.components.upgradeable.numstages = pas.times_simmer + 1
    inst.components.upgradeable.upgradesperstage = 1

    MakeHauntableLaunch(inst)

    inst.OnSave = pas.OnSave_simmer_pro_item
    inst.OnLoad = pas.OnLoad_simmer_pro_item
    inst.OnLongUpdate = pas.OnLongUpdate_simmer_pro_item
    inst.legionfn_chestupgrade = pas.OnUpgrade_simmer_pro_item

    return inst
end, {
    Asset("ANIM", "anim/simmeredmoonlight.zip"),
    Asset("ATLAS", "images/inventoryimages/simmeredmoonlight_pro_item.xml"),
    Asset("IMAGE", "images/inventoryimages/simmeredmoonlight_pro_item.tex"),
    Asset("ATLAS_BUILD", "images/inventoryimages/simmeredmoonlight_pro_item.xml", 256)
}, { "simmeredmoonlight_item", "simmeredmoonlight_pro", "simmeredmoonlight_pro_inf_item", "chestupgrade_stacksize_fx" }))

table.insert(prefs, Prefab("simmeredmoonlight_pro_inf_item", function() --便携版(无限)(物品)
    local inst = CreateEntity()
    inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddFollower() --能当装饰品需要这个
    inst.entity:AddNetwork()
    MakeInventoryPhysics(inst)
    inst.AnimState:SetBank("simmeredmoonlight")
    inst.AnimState:SetBuild("simmeredmoonlight")
    inst.AnimState:PlayAnimation("idle_pro_inf_item")
    inst.AnimState:SetLightOverride(0.1)
    inst:AddTag("furnituredecor") --能当装饰品
    inst:AddTag("portableitem") --用来确定deployable动作的显示名称
    LS_C_Init(inst, "simmeredmoonlight_item", true, "data_uppro_inf_item")
    fns.InitLevelNet(inst, pas.NameDetail_simmer_pro_item)

    inst.entity:SetPristine()
    if not TheWorld.ismastersim then return inst end

    inst.itemtime_l = GetTime()
    inst.itemdt_l = 0

    inst:AddComponent("inspectable")
    inst.components.inspectable.nameoverride = "simmeredmoonlight_inf"

    inst:AddComponent("lootdropper")
    inst:AddComponent("furnituredecor")

    inst:AddComponent("inventoryitem")
    inst.components.inventoryitem.imagename = "simmeredmoonlight_pro_inf_item"
    inst.components.inventoryitem.atlasname = "images/inventoryimages/simmeredmoonlight_pro_inf_item.xml"

    inst:AddComponent("deployable")
    inst.components.deployable.ondeploy = pas.OnDeploy_simmer_pro_item
    -- inst.components.deployable:SetDeployMode(mode)
    -- inst.components.deployable:SetDeploySpacing(spacing or DEPLOYSPACING.LESS)

    inst:AddComponent("workable")
    inst.components.workable:SetWorkAction(ACTIONS.HAMMER)
    inst.components.workable:SetWorkLeft(2)
    inst.components.workable:SetOnWorkCallback(pas.OnWorked_simmer_pro_item)
    inst.components.workable:SetOnFinishCallback(pas.OnFinished_simmer)

    inst:AddComponent("upgradeable")
    inst.components.upgradeable.upgradetype = UPGRADETYPES.SIMMER_L
    inst.components.upgradeable.onupgradefn = fns.OnUpgradeFn --升级时
    inst.components.upgradeable.onstageadvancefn = fns.SetLevel --等级变化时
    inst.components.upgradeable.numstages = pas.times_simmer + 1
    inst.components.upgradeable.upgradesperstage = 1

    MakeHauntableLaunch(inst)

    inst.OnSave = pas.OnSave_simmer_pro_item
    inst.OnLoad = pas.OnLoad_simmer_pro_item
    inst.OnLongUpdate = pas.OnLongUpdate_simmer_pro_item

    return inst
end, {
    Asset("ANIM", "anim/simmeredmoonlight.zip"),
    Asset("ATLAS", "images/inventoryimages/simmeredmoonlight_pro_inf_item.xml"),
    Asset("IMAGE", "images/inventoryimages/simmeredmoonlight_pro_inf_item.tex"),
    Asset("ATLAS_BUILD", "images/inventoryimages/simmeredmoonlight_pro_inf_item.xml", 256)
}, { "simmeredmoonlight_item", "chestupgrade_stacksize" }))

--------------------
--------------------

return unpack(prefs)
