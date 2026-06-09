local _G = GLOBAL
local containers = require("containers")
local ZIP_SOAK_L = require("zip_soak_legion")
local pondspices = ZIP_SOAK_L.spices

--------------------------------------------------------------------------
--[[ 容器数据设定 ]]
--------------------------------------------------------------------------

local cooking = require("cooking")
local params = {}
local pas = {}
local newbox, cac, cac2

pas.items_allowed = {
    oceanfishingrod = true, --海钓竿
    antlionhat = true, --刮地皮头盔
    wortox_nabbag = true, --强抢袋
    slingshot = true, --可靠的弹弓
    battlesong_container = true, --战斗号子罐
    slingshotammo_container = true, --弹药袋
    elixir_container = true, --野餐盒
    beargerfur_sack = true, --极地熊獾桶
    houndstooth_blowpipe = true, --嚎弹炮
    tacklecontainer = true, --钓具箱
    supertacklecontainer = true, --超级钓具箱
    alterguardianhat = true, --启迪之冠
    alterguardianhatshard = true, --启迪碎片
    moonrockseed = true, --天体宝球(可以放进云青松容器，用以判断世界原点)
    hermit_pearl = true, --珍珠的珍珠 --世界唯一物品应该是不同担心的，下线会自动掉落
    hermit_cracked_pearl = true, --开裂珍珠
    storage_robot = true, --瓦器人
    terrarium = true, --盒中泰拉
    atrium_key = true, --远古钥匙
    klaussackkey = true, --麋鹿茸

    lance_carrot_l = true, --胡萝卜长枪
    agronssword = true, --艾力冈的剑
    refractedmoonlight = true, --月折宝剑

    --【能力勋章】
    medal_farm_plow_item = true, --高效耕地机
    medal_resonator_item = true, --宝藏探测仪
}

pas.Check = function(container, item, slot)
    if pas.items_allowed[item.prefab] or --白名单里的物品
        item:HasTag("boxallowed_l") --兼容其他模组。如果其他模组物品具有容器组件但又想放入棱镜容器，就可以加这个标签
    then
        return true
    end
    if item:HasAnyTag("irreplaceable", "nobundling", "pineopener_l") then --世界唯一、特殊物品、子圭·系不能被放入
        return false
    end
    if item:HasTag("unwrappable") then --打包好的包裹，可以放入
        return true
    end
    if not item:HasAnyTag("_container", "bundle") then --有容器组件、包裹组件的不能放入
        return true
    end
end

------
--靠背熊
------

local slotbg_backcub = { image = "slot_bearspaw_l.tex", atlas = "images/slot_bearspaw_l.xml" }
local function MakeBackcub(name, animbuild)
    params[name] = {
        widget = {
            slotpos = {},
            slotbg = { [11] = slotbg_backcub, [12] = slotbg_backcub },
            animbank = "ui_piggyback_2x6", animbuild = animbuild,
            pos = Vector3(-5, -90, 0),
            dragtype = "pack_l_slot12" --用于拖拽识别与分类。所有的棱镜12格背包容器都能统一记录拖动位置
        },
        issidewidget = true,
        type = "pack",
        openlimit = 1
    }
    newbox = params[name].widget.slotpos
    for y = 0, 5 do
        table.insert(newbox, Vector3(-162     , -75*y + 170, 0))
        table.insert(newbox, Vector3(-162 + 75, -75*y + 170, 0))
    end
end
MakeBackcub("backcub", "ui_piggyback_2x6")
MakeBackcub("backcub_fans2", "ui_backcub_fans2_2x6")

------
--巨人之脚
------

params.giantsfoot = {
    widget = {
        slotpos = {},
        animbank = "ui_backpack_2x4", animbuild = "ui_backpack_2x4",
        pos = Vector3(-5, -80, 0),
        dragtype = "pack_l_slot8"
    },
    issidewidget = true,
    type = "pack",
    openlimit = 1,
    priorityfn = function(container, item, slot)
        return item.prefab == "cane" or item.prefab == "ruins_bat" or item:HasTag("weapon")
    end
}
newbox = params.giantsfoot.widget.slotpos
for y = 0, 3 do
    table.insert(newbox, Vector3(-162     , -75*y + 114, 0))
    table.insert(newbox, Vector3(-162 + 75, -75*y + 114, 0))
end

------
--月藏宝匣
------

params.hiddenmoonlight = {
    widget = {
        slotpos = {},
        animbank = "ui_chest_3x3", animbuild = "ui_hiddenmoonlight_4x4",
        -- animbank_upgraded = "ui_chest_3x3",
        animbuild_upgraded = "ui_hiddenmoonlight_inf_4x4",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160
    },
    type = "chest",
    itemtestfn = function(container, item, slot)
        if item:HasAnyTag("icebox_valid", "smallcreature") then
            return true
        end
        if cooking.IsCookingIngredient(item.prefab) then --只要是烹饪食材，就能放入
            return true
        end
        if not item:HasAnyTag("fresh", "stale", "spoiled") then
            return false
        end
        for k, v in pairs(FOODTYPE) do
            if item:HasTag("edible_"..v) then
                return true
            end
        end
        return false
    end
}
newbox = params.hiddenmoonlight.widget.slotpos
for y = 3, 0, -1 do
    for x = 0, 3 do
        table.insert(newbox, Vector3(80*(x - 2) + 37, 80*(y - 2) + 43, 0))
    end
end

------
--月轮宝盘
------

params.revolvedmoonlight = {
    widget = {
        slotpos = {},
        animbank = "ui_chest_3x3", animbuild = "ui_revolvedmoonlight_4x3",
        pos = Vector3(0, -260, 0), --越小越低
        dragtype = "revolvedmoonlight"
    },
    -- issidewidget = true, --Tip：这个位置一般是背包在用，所以不会被闪电惊吓、物品栏隐藏之类的原因导致强制关闭。但不兼容融合模式
    type = "box_legion",
    lowpriorityselection = true,
    openlimit = 1,
    itemtestfn = pas.Check
}
newbox = params.revolvedmoonlight.widget.slotpos
for y = 2, 1, -1 do
    for x = 0, 2 do
        table.insert(newbox, Vector3(80*x - 88, 80*y - 113, 0))
    end
end

params.revolvedmoonlight_pro = {
    widget = {
        slotpos = {},
        animbank = "ui_chest_3x3", animbuild = "ui_revolvedmoonlight_4x3",
        pos = Vector3(0, -260, 0),
        dragtype = "revolvedmoonlight"
    },
    type = "box_legion",
    lowpriorityselection = true,
    openlimit = 1,
    itemtestfn = pas.Check
}
newbox = params.revolvedmoonlight_pro.widget.slotpos
for y = 0, 2 do --               x轴基础      y轴基础
    table.insert(newbox, Vector3(-122      , 80 - y*79, 0))
    table.insert(newbox, Vector3(-122 + 75 , 80 - y*79, 0))
    table.insert(newbox, Vector3(-122 + 150, 80 - y*79, 0))
    table.insert(newbox, Vector3(-122 + 225, 80 - y*79, 0))
end

--月轮宝盘皮肤
local function MakeSkin_revolvedmoonlight(data)
    local name = "revolvedmoonlight_"..data.skin
    local animbuild = "ui_"..name.."_4x3"
    params[name] = {
        widget = {
            slotpos = {},
            animbank = "ui_chest_3x3", animbuild = animbuild,
            pos = Vector3(0, -260, 0),
            dragtype = "revolvedmoonlight"
        },
        type = "box_legion",
        lowpriorityselection = true,
        openlimit = 1,
        itemtestfn = pas.Check
    }
    newbox = params[name].widget.slotpos
    for y = 2, 1, -1 do
        for x = 0, 2 do
            table.insert(newbox, Vector3(80*x - 88, 80*y - 113, 0))
        end
    end

    name = "revolvedmoonlight_pro_"..data.skin
    params[name] = {
        widget = {
            slotpos = {},
            animbank = "ui_chest_3x3", animbuild = animbuild,
            pos = Vector3(0, -260, 0),
            dragtype = "revolvedmoonlight"
        },
        type = "box_legion",
        lowpriorityselection = true,
        openlimit = 1,
        itemtestfn = pas.Check
    }
    newbox = params[name].widget.slotpos
    for y = 0, 2 do --               x轴基础      y轴基础
        table.insert(newbox, Vector3(-122      , 80 - y*79, 0))
        table.insert(newbox, Vector3(-122 + 75 , 80 - y*79, 0))
        table.insert(newbox, Vector3(-122 + 150, 80 - y*79, 0))
        table.insert(newbox, Vector3(-122 + 225, 80 - y*79, 0))
    end
end
MakeSkin_revolvedmoonlight({ skin = "taste" })
MakeSkin_revolvedmoonlight({ skin = "taste2" })
MakeSkin_revolvedmoonlight({ skin = "taste3" })
MakeSkin_revolvedmoonlight({ skin = "taste4" })

------
--脱壳之翅
------

params.boltwingout = {
    widget = {
        slotpos = {},
        animbank = "ui_piggyback_2x6", animbuild = "ui_piggyback_2x6",
        pos = Vector3(-5, -90, 0),
        dragtype = "pack_l_slot12"
    },
    issidewidget = true,
    type = "pack",
    openlimit = 1,
    priorityfn = function(container, item, slot)
        return BOLTCOST_LEGION[item.prefab] ~= nil or item:HasTag("yes_boltout")
    end
}
newbox = params.boltwingout.widget.slotpos
for y = 0, 5 do
    table.insert(newbox, Vector3(-162     , -75*y + 170, 0))
    table.insert(newbox, Vector3(-162 + 75, -75*y + 170, 0))
end

------
--打窝饵制作器
------

params.fishhomingtool = {
    widget = {
        slotpos = {
            Vector3(-37.5, 32 + 4, 0),
            Vector3(37.5, 32 + 4, 0),
            Vector3(-37.5, -(32 + 4), 0),
            Vector3(37.5, -(32 + 4), 0),
        },
        animbank = "ui_bundle_2x2", animbuild = "ui_bundle_2x2",
        pos = Vector3(200, 0, 0),
        side_align_tip = 120,
        buttoninfo = {
            text = STRINGS.ACTIONS_LEGION.MAKE,
            position = Vector3(0, -100, 0),
            validfn = function(inst)
                return inst.replica.container ~= nil and not inst.replica.container:IsEmpty()
            end,
            fn = function(inst, doer)
                if inst.components.container ~= nil then
                    BufferedAction(doer, inst, ACTIONS.WRAPBUNDLE):Do()
                elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
                    SendRPCToServer(RPC.DoWidgetButtonAction, ACTIONS.WRAPBUNDLE.code, inst, ACTIONS.WRAPBUNDLE.mod_name)
                end
            end
        }
    },
    type = "cooker",
    itemtestfn = function(container, item, slot)
        if item.prefab == "fruitflyfruit" then
            return not item:HasTag("fruitflyfruit") --没有 fruitflyfruit 就代表是枯萎了
        elseif item.prefab == "glommerflower" then
            return not item:HasTag("glommerflower") --没有 glommerflower 就代表是枯萎了
        end
        if COMPATIBLE_LEGION.fishhoming_ingredients[item.prefab] ~= nil or not item:HasAnyTag("irreplaceable", "nobundling") then
            return true
        end
        return false
    end
}

------
--胡萝卜长枪
------

local function IsCarrot(container, item, slot)
    return item.prefab == "carrot" or item.prefab == "carrot_cooked" or item.prefab == "carrat"
end

params.lance_carrot_l = {
    widget = {
        slotpos = {
            Vector3(0,   32 + 4,  0),
            Vector3(0, -(32 + 4), 0)
        },
        animbank = "ui_cookpot_1x2", animbuild = "ui_cookpot_1x2",
        pos = Vector3(0, 60, 0),
        dragtype = "hand_l_slot2"
    },
    type = "hand_inv",
    excludefromcrafting = true,
    priorityfn = IsCarrot,
    itemtestfn = function(container, item, slot)
        return IsCarrot(container, item, slot) or item.prefab == "spoiled_food"
    end
}

------
--巨食草
------

local slotbg_bubble = { image = "slot_juice_l.tex", atlas = "images/slot_juice_l.xml" }
params.plant_nepenthes_l = {
    widget = {
        slotpos = {}, slotbg = {},
        animbank = "ui_chest_3x3", animbuild = "ui_nepenthes_l_4x4",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160
    },
    type = "chest",
    itemtestfn = function(container, item, slot)
        if item.prefab == "fruitflyfruit" then
            return not item:HasTag("fruitflyfruit") --没有 fruitflyfruit 就代表是枯萎了
        elseif item.prefab == "glommerflower" then
            return not item:HasTag("glommerflower") --没有 glommerflower 就代表是枯萎了
        end
        return not item:HasAnyTag("irreplaceable", "nobundling", "nodigest_l")
    end
}
newbox = params.plant_nepenthes_l.widget
for y = 3, 0, -1 do
    for x = 0, 3 do
        table.insert(newbox.slotpos, Vector3(80*(x - 2) + 40, 80*(y - 2) + 40, 0))
        table.insert(newbox.slotbg, slotbg_bubble)
    end
end

------
--白木展示台（大一点）
------

params.chest_ww = {
    widget = {
        slotpos = {},
        animbank = "ui_chester_shadow_3x4", animbuild = "ui_chest_whitewood_3x6",
        -- animbank_upgraded = "ui_chester_shadow_3x4",
        animbuild_upgraded = "ui_chest_whitewood_inf_3x6",
        pos = Vector3(0, 220, 0),
        side_align_tip = 160
    },
    type = "chest"
}
newbox = params.chest_ww.widget.slotpos
for y = 3.5, -1.5, -1 do
    for x = 0, 2 do
        table.insert(newbox, Vector3(75*x - 74, 75*y - 83, 0))
    end
end

------
--白木展示台（小一点）
------

params.chest_ww2 = {
    widget = {
        slotpos = {},
        animbank = "ui_chester_shadow_3x4", animbuild = "ui_chest_whitewood_3x4",
        -- animbank_upgraded = "ui_chester_shadow_3x4",
        animbuild_upgraded = "ui_chest_whitewood_inf_3x4",
        pos = Vector3(0, 220, 0),
        side_align_tip = 160
    },
    type = "chest"
}
newbox = params.chest_ww2.widget.slotpos
for y = 2.5, -0.5, -1 do
    for x = 0, 2 do
        table.insert(newbox, Vector3(75*x - 74, 75*y - 86, 0))
    end
end

------
--白木展示柜（大一点）
------

params.chest_ww_big = {
    widget = {
        slotpos = {},
        animbank = "ui_bookstation_4x5", animbuild = "ui_chest_whitewood_4x8",
        -- animbank_upgraded = "ui_bookstation_4x5",
        animbuild_upgraded = "ui_chest_whitewood_inf_4x8",
        pos = Vector3(0, 240, 0),
        side_align_tip = 160
    },
    type = "chest"
}
newbox = params.chest_ww_big.widget.slotpos
for y = 0, 7 do
    table.insert(newbox, Vector3(-112      , 228 - y*79, 0))
    table.insert(newbox, Vector3(-112 + 75 , 228 - y*79, 0))
    table.insert(newbox, Vector3(-112 + 150, 228 - y*79, 0))
    table.insert(newbox, Vector3(-112 + 225, 228 - y*79, 0))
end

------
--白木展示柜（小一点）
------

params.chest_ww2_big = {
    widget = {
        slotpos = {},
        animbank = "ui_bookstation_4x5", animbuild = "ui_chest_whitewood_4x6",
        -- animbank_upgraded = "ui_bookstation_4x5",
        animbuild_upgraded = "ui_chest_whitewood_inf_4x6",
        pos = Vector3(0, 270, 0),
        side_align_tip = 160
    },
    type = "chest"
}
newbox = params.chest_ww2_big.widget.slotpos
for y = 0, 5 do
    table.insert(newbox, Vector3(-112      , 156 - y*79, 0))
    table.insert(newbox, Vector3(-112 + 75 , 156 - y*79, 0))
    table.insert(newbox, Vector3(-112 + 150, 156 - y*79, 0))
    table.insert(newbox, Vector3(-112 + 225, 156 - y*79, 0))
end

------
--子圭·釜
------

params.siving_suit_gold = {
    widget = {
        slotpos = {},
        animbank = "ui_piggyback_2x6", animbuild = "ui_piggyback_2x6",
        pos = Vector3(-5, -90, 0),
        dragtype = "pack_l_slot12"
    },
    issidewidget = true,
    type = "pack",
    openlimit = 1
}
newbox = params.siving_suit_gold.widget.slotpos
for y = 0, 5 do
    table.insert(newbox, Vector3(-162     , -75*y + 170, 0))
    table.insert(newbox, Vector3(-162 + 75, -75*y + 170, 0))
end

------
--云青松容器
------

------超级
params.cloudpine_box_l4 = {
    widget = {
        slotpos = {},
        animbank = "ui_bookstation_4x5", animbuild = "ui_cloudpine_box_5x6",
        pos = Vector3(0, 280, 0),
        side_align_tip = 160,
        dragtype = "cloudpine_box_l4" --云青松容器每级都不一样，所以为了不统一，故意添加该变量
    },
    type = "pine_legion",
    lowpriorityselection = true,
    itemtestfn = pas.Check
}
newbox = params.cloudpine_box_l4.widget.slotpos
for y = 0, 5 do
    cac = 128 - y*79
    for x = 1, 5, 1 do
        table.insert(newbox, Vector3(-77 + (x-2)*75, cac, 0))
    end
end

------高级
params.cloudpine_box_l3 = {
    widget = {
        slotpos = {},
        animbank = "ui_bookstation_4x5", animbuild = "ui_cloudpine_box_4x6",
        pos = Vector3(0, 280, 0),
        side_align_tip = 160,
        dragtype = "cloudpine_box_l3"
    },
    type = "pine_legion",
    lowpriorityselection = true,
    itemtestfn = pas.Check
}
newbox = params.cloudpine_box_l3.widget.slotpos
cac2 = -113
for y = 0, 5 do
    cac = 128 - y*79
    for x = 0, 3, 1 do
        table.insert(newbox, Vector3(cac2 + x*75, cac, 0))
    end
end

------中级
params.cloudpine_box_l2 = {
    widget = {
        slotpos = {},
        animbank = "ui_bookstation_4x5", animbuild = "ui_cloudpine_box_4x3",
        pos = Vector3(0, 200, 0),
        side_align_tip = 160,
        dragtype = "cloudpine_box_l2"
    },
    type = "pine_legion",
    lowpriorityselection = true,
    itemtestfn = pas.Check
}
newbox = params.cloudpine_box_l2.widget.slotpos
for y = 0, 2 do
    cac = 79 - y*79
    for x = 0, 3, 1 do
        table.insert(newbox, Vector3(cac2 + x*75, cac, 0))
    end
end

------低级
params.cloudpine_box_l1 = {
    widget = {
        slotpos = {
            Vector3(cac2      , 0, 0),
            Vector3(cac2 + 75 , 0, 0),
            Vector3(cac2 + 150, 0, 0),
            Vector3(cac2 + 225, 0, 0)
        },
        animbank = "ui_bookstation_4x5", animbuild = "ui_cloudpine_box_4x1",
        pos = Vector3(0, 160, 0),
        side_align_tip = 160,
        dragtype = "cloudpine_box_l1"
    },
    type = "pine_legion",
    lowpriorityselection = true,
    itemtestfn = pas.Check
}

------
--夜盏花
------

params.plant_lightbulb_l = {
    widget = {
        slotpos = {
            Vector3(0, 64 + 32 + 8 + 4, 0),
            Vector3(0, 32 + 4, 0),
            Vector3(0, -(32 + 4), 0),
            Vector3(0, -(64 + 32 + 8 + 4), 0)
        },
        animbank = "ui_lamp_1x4", animbuild = "ui_lamp_1x4",
        pos = Vector3(200, 0, 0),
        side_align_tip = 100
    },
    acceptsstacks = false,
    type = "cooker",
    itemtestfn = function(container, item, slot)
        return item:HasAnyTag("lightbattery", "spore", "lightcontainer")
    end
}

------
--月炆宝炊
------

local function HasRowItem(inst, idx1, idx2, exclude_col)
    local items = inst.replica.container ~= nil and inst.replica.container:GetItems() or nil
    if items ~= nil then
        for i = idx1, idx2, 1 do
            if items[i] ~= nil and (exclude_col == nil or i%exclude_col ~= 0) then --只要有物品，按钮就生效
                return true
            end
        end
    end
    return false
end
local function HasColItem(inst, colnum, rolnum)
    local items = inst.replica.container ~= nil and inst.replica.container:GetItems() or nil
    if items ~= nil then
        local idx = 0
        for i = 1, rolnum, 1 do
            idx = idx + colnum
            if items[idx] ~= nil then --只要有物品，按钮就生效
                return true
            end
        end
    end
    return false
end
local function CanTryCooking(items, idx)
    local item, hasdish, hasspice
    local num_ingredient = 0
    for i = 0, 3, 1 do
        item = items[i+idx]
        if item ~= nil then
            if item:HasTag("spice") then
                hasspice = true
                num_ingredient = 0
            else
                --有些模组会把烹饪成品也做为烹饪原料，得兼容这种情况
                if not hasspice then
                    if cooking.IsCookingIngredient(item.prefab) then
                        num_ingredient = num_ingredient + 1
                    else
                        num_ingredient = 0
                    end
                end
                if not hasdish and item:HasTag("preparedfood") and not item:HasTag("spicedfood") then
                    hasdish = true
                end
            end
        end
    end
    if num_ingredient >= 4 then
        return true
    else
        return hasdish and hasspice
    end
end

params.simmeredmoonlight = {
    widget = {
        slotpos = {},
        animbank = "ui_chest_3x3", animbuild = "ui_simmeredmoonlight_5x1",
        pos = Vector3(200, 0, 0),
        side_align_tip = 160,
        dragtype = "simmeredmoonlight",
        buttoninfo = {
            text = STRINGS.ACTIONS.COOK,
            position = Vector3(52, -92, 0),
            validfn = function(inst)
                local items = inst.replica.container ~= nil and inst.replica.container:GetItems() or nil
                if items ~= nil and CanTryCooking(items, 1) then
                    return true
                end
            end,
            fn = function(inst, doer)
                if inst.components.container ~= nil then
                    BufferedAction(doer, inst, ACTIONS.SIMMER_L_COOK):Do()
                elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
                    SendModRPCToServer(GetModRPC("LegionMsg", "SimmerCMD"), inst, "buttoninfo")
                end
            end
        },
        btns_legion = {
            roast = {
                text = STRINGS.ACTIONS_LEGION.ROAST,
                position = Vector3(-52, -92, 0),
                validfn = function(inst) return HasRowItem(inst, 1, 4) end,
                fn = function(inst, doer)
                    if inst.components.container ~= nil then
                        BufferedAction(doer, inst, ACTIONS.SIMMER_L_ROAST):Do()
                    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
                        SendModRPCToServer(GetModRPC("LegionMsg", "SimmerCMD"), inst, "roast")
                    end
                end
            },
            clearrow1 = {
                isiconbtn = true, iconname = "update.tex", position = Vector3(-255, -4, 0),
                text = STRINGS.ACTIONS_LEGION.CLEARROW,
                validfn = function(inst) return HasRowItem(inst, 1, 5) end,
                fn = function(inst, doer)
                    if inst.components.container ~= nil then
                        inst.legion_cleardd = { idx1 = 1, idx2 = 5 }
                        BufferedAction(doer, inst, ACTIONS.SIMMER_L_CLEAR):Do()
                        inst.legion_cleardd = nil
                    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
                        SendModRPCToServer(GetModRPC("LegionMsg", "SimmerCMD"), inst, "clearrow1")
                    end
                end
            }
        }
    },
    type = "cooker",
    openlimit = 1,
    itemtestfn = function(container, item, slot)
        if item.prefab == "spoiled_food" or item.prefab == "rottenegg" then --腐烂物、腐烂鸟蛋
            return true
        end
        --官方的容器接纳物品做不到我想要的效果，所以干脆不弄这些花哨的细节了
        -- if slot ~= nil and slot%5 == 0 then --第五列只能放入料理，不能放食材和香料
        --     return item:HasTag("preparedfood")
        -- end
        return cooking.IsCookingIngredient(item.prefab) or --烹饪食材
            item:HasAnyTag("preparedfood", "spice") or --料理(包含撒过料的料理)、香料
            cooking.GetRecipe("portablecookpot", item.prefab) ~= nil --烹饪成品(成品不一定会有料理标签，比如琥珀美食、牛奶帽)
    end
}
newbox = params.simmeredmoonlight.widget.slotpos
for x = 0, 4, 1 do
    if x == 4 then
        table.insert(newbox, Vector3(-138 + x*75, -1, 0))
    else
        table.insert(newbox, Vector3(-158 + x*75, -1, 0))
    end
end

params.simmeredmoonlight_inf = {
    widget = {
        slotpos = {},
        animbank = "ui_chest_3x3", animbuild = "ui_simmeredmoonlight_inf_5x4",
        pos = Vector3(200, 0, 0),
        side_align_tip = 160,
        dragtype = "simmeredmoonlight_inf",
        buttoninfo = {
            text = STRINGS.ACTIONS.COOK,
            position = Vector3(50, -213, 0),
            validfn = function(inst)
                local items = inst.replica.container ~= nil and inst.replica.container:GetItems() or nil
                if items ~= nil then
                    if CanTryCooking(items, 1) or CanTryCooking(items, 6) or CanTryCooking(items, 11) or CanTryCooking(items, 16) then
                        return true
                    end
                end
            end,
            fn = params.simmeredmoonlight.widget.buttoninfo.fn
        },
        btns_legion = {
            roast = {
                text = STRINGS.ACTIONS_LEGION.ROAST,
                position = Vector3(-54, -213, 0),
                validfn = function(inst) return HasRowItem(inst, 1, 19, 5) end,
                fn = params.simmeredmoonlight.widget.btns_legion.roast.fn
            },
            clearrow1 = {
                isiconbtn = true, iconname = "update.tex", position = Vector3(-257, 115, 0),
                text = STRINGS.ACTIONS_LEGION.CLEARROW,
                validfn = function(inst) return HasRowItem(inst, 1, 5) end,
                fn = params.simmeredmoonlight.widget.btns_legion.clearrow1.fn
            },
            clearrow2 = {
                isiconbtn = true, iconname = "update.tex", position = Vector3(-257, 115-80, 0),
                text = STRINGS.ACTIONS_LEGION.CLEARROW,
                validfn = function(inst) return HasRowItem(inst, 6, 10) end,
                fn = function(inst, doer)
                    if inst.components.container ~= nil then
                        inst.legion_cleardd = { idx1 = 6, idx2 = 10 }
                        BufferedAction(doer, inst, ACTIONS.SIMMER_L_CLEAR):Do()
                        inst.legion_cleardd = nil
                    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
                        SendModRPCToServer(GetModRPC("LegionMsg", "SimmerCMD"), inst, "clearrow2")
                    end
                end
            },
            clearrow3 = {
                isiconbtn = true, iconname = "update.tex", position = Vector3(-257, 115-80*2, 0),
                text = STRINGS.ACTIONS_LEGION.CLEARROW,
                validfn = function(inst) return HasRowItem(inst, 11, 15) end,
                fn = function(inst, doer)
                    if inst.components.container ~= nil then
                        inst.legion_cleardd = { idx1 = 11, idx2 = 15 }
                        BufferedAction(doer, inst, ACTIONS.SIMMER_L_CLEAR):Do()
                        inst.legion_cleardd = nil
                    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
                        SendModRPCToServer(GetModRPC("LegionMsg", "SimmerCMD"), inst, "clearrow3")
                    end
                end
            },
            clearrow4 = {
                isiconbtn = true, iconname = "update.tex", position = Vector3(-257, 115-80*3, 0),
                text = STRINGS.ACTIONS_LEGION.CLEARROW,
                validfn = function(inst) return HasRowItem(inst, 16, 20) end,
                fn = function(inst, doer)
                    if inst.components.container ~= nil then
                        inst.legion_cleardd = { idx1 = 16, idx2 = 20 }
                        BufferedAction(doer, inst, ACTIONS.SIMMER_L_CLEAR):Do()
                        inst.legion_cleardd = nil
                    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
                        SendModRPCToServer(GetModRPC("LegionMsg", "SimmerCMD"), inst, "clearrow4")
                    end
                end
            },
            clearall = {
                isiconbtn = true, iconname = "updateall.tex", position = Vector3(-257, 115-80*4, 0),
                text = STRINGS.ACTIONS_LEGION.CLEARALL,
                validfn = function(inst) return HasRowItem(inst, 1, 20) end,
                fn = function(inst, doer)
                    if inst.components.container ~= nil then
                        inst.legion_cleardd = { idx1 = 1, idx2 = 20 }
                        BufferedAction(doer, inst, ACTIONS.SIMMER_L_CLEAR):Do()
                        inst.legion_cleardd = nil
                    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
                        SendModRPCToServer(GetModRPC("LegionMsg", "SimmerCMD"), inst, "clearall")
                    end
                end
            },
            cleardish = {
                isiconbtn = true, iconname = "goto_url.tex", position = Vector3(166, -216, 0),
                text = STRINGS.ACTIONS_LEGION.CLEARCOL,
                validfn = function(inst) return HasColItem(inst, 5, 4) end,
                fn = function(inst, doer)
                    if inst.components.container ~= nil then
                        inst.legion_cleardd = { 5, 10, 15, 20 }
                        BufferedAction(doer, inst, ACTIONS.SIMMER_L_CLEAR):Do()
                        inst.legion_cleardd = nil
                    elseif inst.replica.container ~= nil and not inst.replica.container:IsBusy() then
                        SendModRPCToServer(GetModRPC("LegionMsg", "SimmerCMD"), inst, "cleardish")
                    end
                end
            }
        }
    },
    type = "cooker",
    openlimit = 1,
    itemtestfn = params.simmeredmoonlight.itemtestfn
}
newbox = params.simmeredmoonlight_inf.widget.slotpos
for y = 3, 0, -1 do
    for x = 0, 4, 1 do --格子顺序是先从左往右，再从上到下，所以x的循环得在y循环里面
        if x == 4 then
            table.insert(newbox, Vector3(-140 + x*75, -122 + 80*y, 0))
        else
            table.insert(newbox, Vector3(-160 + x*75, -122 + 80*y, 0))
        end
    end
end

------
--澡花壳
------

params.pondbldg_soak = {
    widget = {
        slotpos = {}, slotbg = {},
        animbank = "ui_chest_3x3", animbuild = "ui_l_pond_3x2",
        pos = Vector3(200, 0, 0),
        side_align_tip = 160
    },
    type = "cooker",
    openlimit = 1,
    itemtestfn = function(container, item, slot)
        return pondspices[item.prefab] ~= nil
    end
}
newbox = params.pondbldg_soak.widget
for y = 0, 1 do
    for x = 0, 2, 1 do
        table.insert(newbox.slotpos, Vector3(-80 + x*79, 40 - y*79, 0))
        table.insert(newbox.slotbg, slotbg_bubble)
    end
end

------
--鱼栖壳
------

params.pondbldg_fish = {
    widget = {
        slotpos = {}, slotbg = {},
        animbank = "ui_bookstation_4x5", animbuild = "ui_l_pond_6x6",
        pos = Vector3(0, 280, 0),
        side_align_tip = 160
    },
    type = "chest",
    itemtestfn = function(container, item, slot)
        return item:HasAnyTag("pondfish", "smalloceancreature") --海洋鱼、龙虾、池塘鱼、鳗鱼
    end
}
newbox = params.pondbldg_fish.widget
for y = 0, 5 do
    for x = 0, 5, 1 do
        table.insert(newbox.slotpos, Vector3(-198 + 79*x, 106 - y*79, 0))
        table.insert(newbox.slotbg, slotbg_bubble)
    end
end

--------------------------------------------------------------------------
--[[ 修改容器注册函数 ]]
--------------------------------------------------------------------------

for k, v in pairs(params) do
    containers.params[k] = v

    --更新容器格子数量的最大值
    containers.MAXITEMSLOTS = math.max(containers.MAXITEMSLOTS, v.widget.slotpos ~= nil and #v.widget.slotpos or 0)
end
params = nil
newbox = nil
cac = nil
cac2 = nil

--------------------------------------------------------------------------
--mod兼容：Show Me (中文)
--------------------------------------------------------------------------

------以下代码参考自风铃草大佬的穹妹------

local showmeneed = { --这里的名字是指容器所属预制物的名字，不是指容器本身的名字
    "backcub", "giantsfoot",
    "hiddenmoonlight", "hiddenmoonlight_inf", "revolvedmoonlight", "revolvedmoonlight_pro",
    "boltwingout", "plant_nepenthes_l", "plant_lightbulb_l",
    "chest_whitewood", "chest_whitewood_big", "chest_whitewood_inf", "chest_whitewood_big_inf",
    "siving_suit_gold", "simmeredmoonlight", "simmeredmoonlight_pro", "simmeredmoonlight_inf",
    "simmeredmoonlight_pro_inf", "pondbldg_soak", "pondbldg_fish"
}

--showme优先级如果比本mod高，那么这部分代码会生效
for k, mod in pairs(ModManager.mods) do
    if mod and _G.rawget(mod, "SHOWME_STRINGS") then --showme特有的全局变量
        if mod.postinitfns and mod.postinitfns.PrefabPostInit and mod.postinitfns.PrefabPostInit.treasurechest then
            for _, v in ipairs(showmeneed) do
				mod.postinitfns.PrefabPostInit[v] = mod.postinitfns.PrefabPostInit.treasurechest
			end
        end
        break
    end
end

--showme优先级如果比本mod低，那么这部分代码会生效
TUNING.MONITOR_CHESTS = TUNING.MONITOR_CHESTS or {}
for _, v in ipairs(showmeneed) do
	TUNING.MONITOR_CHESTS[v] = true
end

showmeneed = nil
