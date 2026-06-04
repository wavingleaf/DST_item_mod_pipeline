assets =
{
    Asset("ANIM", "anim/unsafehat.zip"),
    Asset("ATLAS", "images/unsafehat.xml"),
	Asset("ATLAS_BUILD", "images/unsafehat.xml",256),
}
prefabs =
{
}

local function onequip(inst, owner)
	owner.AnimState:OverrideSymbol("swap_hat", "unsafehat", "swap_hat")
	owner.AnimState:Show("HAT")
    owner.AnimState:Show("HAIR_HAT")
    owner.AnimState:Hide("HAIR_NOHAT")
    owner.AnimState:Hide("HAIR")
	
	if owner:HasTag("player") then
        owner.AnimState:Hide("HEAD")
        owner.AnimState:Show("HEAD_HAT")
    end

	if owner:HasTag("equipmentmodel") then return end--假人就不往下走了

	owner:AddTag("item_decorator")--道具装饰者
end

local function onunequip(inst, owner)
    owner.AnimState:ClearOverrideSymbol("swap_hat")
    owner.AnimState:Hide("HAT")
    owner.AnimState:Hide("HAIR_HAT")
    owner.AnimState:Show("HAIR_NOHAT")
    owner.AnimState:Show("HAIR")
	if owner:HasTag("player") then
        owner.AnimState:Show("HEAD")
        owner.AnimState:Hide("HEAD_HAT")
    end

	if owner:HasTag("equipmentmodel") then return end--假人就不往下走了

	owner:RemoveTag("item_decorator")--道具装饰者
end

local function fn()
    local inst = CreateEntity()
	
	inst.entity:AddTransform()
    inst.entity:AddAnimState()
    inst.entity:AddNetwork()

    MakeInventoryPhysics(inst)

    inst.AnimState:SetBank("unsafehat")
    inst.AnimState:SetBuild("unsafehat")
    inst.AnimState:PlayAnimation("anim")
	
	inst:AddTag("hat")
	
	MakeInventoryFloatable(inst,"med",0.1,0.65)

    inst.entity:SetPristine()
	
    if not TheWorld.ismastersim then
        return inst
    end
    inst:AddComponent("inspectable")

    inst:AddComponent("inventoryitem")
	inst.components.inventoryitem.imagename = "unsafehat"
    inst.components.inventoryitem.atlasname = "images/unsafehat.xml"
	
	
    inst:AddComponent("equippable")
    inst.components.equippable.equipslot = EQUIPSLOTS.HEAD
    inst.components.equippable:SetOnEquip(onequip)
    inst.components.equippable:SetOnUnequip(onunequip)
	
	MakeHauntableLaunch(inst)
    return inst
end


return Prefab( "unsafehat", fn, assets, prefabs)