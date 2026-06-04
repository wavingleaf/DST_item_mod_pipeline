local minisign_show_list = {
	"unsafehat",--不安全帽
}


--兼容小木牌显示
local function draw(inst)
	if inst.components.drawable then
		local oldondrawnfn = inst.components.drawable.ondrawnfn or nil
		inst.components.drawable.ondrawnfn = function(inst, image, src, atlas, bgimagename, bgatlasname)
			if oldondrawnfn ~= nil then
				oldondrawnfn(inst, image, src, atlas, bgimagename, bgatlasname)
			end
			-- print(image,atlas)
			if image ~= nil and table.contains(minisign_show_list,image) then --是我的物品
				if atlas==nil then
					atlas="images/"..image..".xml"
				end
				local atlas_path=resolvefilepath_soft(atlas)
				if atlas_path then
					inst.AnimState:OverrideSymbol("SWAP_SIGN", atlas_path, image..".tex")
				end
			end
		end
	end
end

AddPrefabPostInit("minisign", draw)
AddPrefabPostInit("minisign_drawn", draw)
AddPrefabPostInit("decor_pictureframe", draw)