local ADDON, Private = ...

-- Private API
local Colors = Private.Colors
local GetAuraFilter = Private.GetAuraFilter
local GetFont = Private.GetFont
local GetMedia = Private.GetMedia
local GetSchematic = Private.GetSchematic

-- Applied to aura buttons
-- Keep these in a manner that works without knowing the size.
Private.RegisterSchematic("Widget::AuraButton::Large", "Legacy", {
	{
		type = "ModifyWidgets",
		widgets = {
			{
				parent = nil, ownerKey = "Icon", objectType = "Texture",
				chain = {
					"SetPosition", { "CENTER", 0, 0 },
					"SetTexCoord", { 5/64, 59/64, 5/64, 59/64 },
					"SetSizeOffset", -10
				} 
			},
			{
				parent = nil, ownerKey = "Count", objectType = "FontString",
				chain = {
					"SetPosition", { "BOTTOMRIGHT", 2, -2 },
					"SetFontObject", Private.GetFont(14, true),
					"SetTextColor", { Colors.normal[1], Colors.normal[2], Colors.normal[3], .85 }
				}
			},
			{
				parent = nil, ownerKey = "Time", objectType = "FontString",
				chain = {
					"SetPosition", { "TOPLEFT", -2, 2 },
					"SetFontObject", Private.GetFont(14, true)
				}
			}
		}
	},
	{
		type = "CreateWidgets",
		widgets = {
			{
				parent = "self", ownerKey = "Border", objectType = "Frame", objectSubType = "Frame",
				chain = {
					"SetFrameLevelOffset", 2,
					"SetBackdrop", {{ edgeFile = Private.GetMedia("aura_border"), edgeSize = 16 }},
					"SetBackdropBorderColor", { Colors.ui[1] *.3, Colors.ui[2] *.3, Colors.ui[3] *.3, 1 },
					"ClearAllPoints", "SetPoint", { "TOPLEFT", -7, 7 }, "SetPoint", { "BOTTOMRIGHT", 7, -7 }
				}

			}
		}
	}
})

