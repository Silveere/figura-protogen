At it's fundamentals, KattArmor changes the texture of specific user defined cubes to different textures depending on the detected material of the worn armor.

# Initializing the KattArmor library

First step is to `require` KattArmor into your own script. KattArmor itself should never be modified.
Curious about that extra `()`? KattArmor supports multiple Instances of itself. Those will be described later.
```lua
local kattArmor=require("KattArmor")()
```

# Creating Armor cubes

For vanilla armor, a template avatar is provided that contains the correct setup for vanilla armor.

The exact size, position, rotation or armor cubes does not matter. However, the uvs of the cubes do matter. In the template, a texture the same size as the vanilla armor textures is used to align the uvs correctly, and it makes editing the model in blockbench easier. If anything goes wrong, the texture assigned to the cubes in blockbench will be what appears.

To create vanilla-like armor, duplicate the cube you are wrapping the armor around, then inflate it by 0.25, 0.5, 0.75, or 1. Then switch the texture to one that allows you to align the uvs.

# Registering ModelParts to the KattArmor Library

Inside `kattArmor` is `Armor`, which contains `Helmet`, `Chestplate`, `Leggings`, and `Boots`. Calling `addParts` on any of these will add the given ModelParts to that Armor piece. 

The ModelParts will be visible while armor is equipped in those slots, and the ModelParts will have their texture changed based on the material of the equipped armor.
```lua
kattArmor.Armor.Helmet
    :addParts(
      models.model.Head.Helmet,
      models.model.Head.HelmetHat
    )
kattArmor.Armor.Chestplate
    :addParts(
      models.model.Body.Chestplate,
      models.model.RightArm.RightArmArmor,
      models.model.LeftArm.LeftArmArmor
    )
kattArmor.Armor.Leggings
    :addParts(
      models.model.Body.Belt,
      models.model.RightLeg.RightLegArmor,
      models.model.LeftLeg.LeftLegArmor
    )
kattArmor.Armor.Boots
    :addParts(
      models.model.RightLeg.RightBoot,
      models.model.LeftLeg.LeftBoot
    )
```

# Identifying Materials

Materials are gotten from the itemID of armor. `minecraft:leather_helmet` has the material `"leather"` because it follows the format `namespace:material_armor`

This is known as a MaterialID. The vanilla materialIDs are as follows: `"leather"`, `"chainmail"`, `"iron"`, `"golden"`, `"diamond"`, `"netherite"`, and `"turtle"`.

There is the special Material which is the boolean value `true`, which represents having no equipped armor.

# Changing the texture of Materials

Materials are stored in the `Materials` table in `kattArmor`. It contains all Materials, even ones that do not exist.

It contains `Material` objects, which we can call `setTexture` and `setTextureLayer2` on. In vanilla, armor is divided into 2 layers: Layer 1 which contains textures for the helmet, chestplate, and boots, and Layer 2 which contains textures for the leggings.

By default, all materials will attempt to find a texture for itself in the resource location `minecraft:textures/models/armor`. If it cannot find a texture there, the error texture will be shown which is the texture defined in blockbench for the ModelParts.

You can manually set the texture by calling `setTexture` and `setTextureLayer2` on a Material, passing in either a resource location, or a Texture object.
```lua
kattArmor.Materials.leather
    :setTexture(textures["customLeather"])
    :setTextureLayer2(textures["customLeatherLayer2"])
```

To access the `true` material, you need to use `[]` indexing instead of `.` indexing, as the value used is a boolean value, not a string.
`true` was used to prevent any clashing with potential custom materials.
```lua
kattArmor.Materials[true]
    :setVisible(true)
    :setTexture(textures["armorDefault"])
    :setTextureLayer2(textures["armorDefaultLayer2"])
```

# Custom Armor

If your character does not conform to vanilla armor, you do not have to worry about conforming to vanilla's standards at all. 

Your UVs can be whereever you feel is best, your armor cubes can be in whatever shape you feel like, and you can ignore legging's layer2 shenanigans. If you do not use layer2 and do not set any textures to use layer2, be sure to set the layer that the Leggings use to layer2.
```lua
kattArmor.Armor.Leggings:setLayer(2)
```

# Modded armors

Some modded armors will be recognized by the script and have the textures accounted for. However, most mods do not use the vanilla rendering system for armor, meaning KattArmor will not be able to find the textures.

The fix is simple. Figure out the Material of the modded armor, and set the texture to the correct resource location.

For example, the fiery armor from the twilight forrest mod. It's helmet has the itemID `twilightforest:fiery_helmet`, and following the pattern `namespace:material_armor`, `"fiery"` is determined to be the material for this item.
```lua
kattArmor.Materials.fiery
    :setTexture("twilightforest:textures/armor/fiery_1.png")
    :setTextureLayer2("twilightforest:textures/armor/fiery_2.png")
```

# Adding Material Specific ModelParts to Materials

If a ModelPart is supposed to render on a specific Material and no-where else, you can call the `addParts` function on a Material object, passing in the Armor part object you want to add the ModelPart to.

As an example, this is how the leather layer is done on the template avatar. It uses this Material Parts system.

Material Parts do not change textures and do not change color. They appear when the Material is worn, and disappear when the Material is not worn. However, they do have enchantment glint if the armor item itself is enchanted.
```lua
kattArmor.Materials.leather
    :addParts(kattArmor.Armor.Helmet,
      models.model.Head.HelmetLeather,
      models.model.Head.HelmetHatLeather
    )
    :addParts(kattArmor.Armor.Chestplate,
      models.model.Body.ChestplateLeather,
      models.model.RightArm.RightArmArmorLeather,
      models.model.LeftArm.LeftArmArmorLeather
    )
    :addParts(kattArmor.Armor.Leggings,
      models.model.Body.BeltLeather,
      models.model.RightLeg.RightLegLeather,
      models.model.LeftLeg.LeftLegLeather
    )
    :addParts(kattArmor.Armor.Boots,
      models.model.RightLeg.RightBootLeather,
      models.model.LeftLeg.LeftBootLeather
    )
```

# Custom Materials

You can define custom materials with KattArmor, allowing for unique textures for unique situations.

For an example, we will be defining a custom `"philza"` material.

First step is to define the custom material. This is done by indexing `Materials` like you would for materials that you know exist.

Indexing `Materials` will create a new Material object if the Material didnt exist previously. Plot twist: Zero materials exist when KattArmor is initialized. They are generated when you wear armor for the first time, because KattArmor itself indexes Materials.

We then call `setTexture` and `setTextureLayer2` on the Material to define the textures to use when we use the material.

```lua
kattArmor.Materials.philza
    :setTexture(textures["model.philzaLayer1"])
    :setTextureLayer2(textures["model.philzaLayer2"])
```

We then need to define when the script will use the custom material. This is done via the `registerOnChange` function.

It takes in a function that should return a string or nil. When the function returns a string, KattArmor will use that as the Material. When it is nil, KattArmor will parse the MaterialID from the itemID as normal.

```lua
kattArmor.registerOnChange(function (partID, item)
  -- When the name of the item is "Philza Helmet" on the helmet slot, return "philza".
  -- The compared name is "Philza Chestplate", "Philza Leggings", and "Philza Boots" for the other armor parts
  -- Functions return nil when no return is defined.
  if item:getName() == ("Philza " .. partID) then
    return "philza"
  end
end)
```

And thats it. KattArmor will now use the `"philza"` material when the armor item's name is correct.

# Armor Trims

KattArmor supports armor trims.

Setting them up requires a bit of work. First of all, duplicate all of your armor cubes and give the duplicate a unique name. Do not touch the scale, leave it the same as the original cube.

You probably want to take the time to make a dummy trim texture in blockbench so that your bbmodel stays readable. A dummy texture for the vanilla armor is available in the template. This is not required by KattArmor and you can leave the trim cube's texture as whatever it was set to before. 

Then in KattArmor, register the new cubes as Trim Parts via the `addTrimParts` function.
```lua
kattArmor.Armor.Chestplate:addTrimParts(
      models.model.Body.ChestplateTrim,
      models.model.RightArm.RightArmArmorTrim,
      models.model.LeftArm.LeftArmArmorTrim
    )
```

Now the new cubes will use the vanilla trim textures.

# Custom Armor Trims

Fuck custom armor trims.

KattArmor does not support custom Armor Trims in the same format as vanilla, where a source trim texture is provided and using some palate textures, extra textures are dynamically generated.

No. In KattArmor, you have 4 choices for Custom Armor Trims:
* Dont at all
* Dont, instead using the Custom Material system
  * for when you have one specific material-pattern combo that you care about and will ignore the rest
* Set a single texture per trim pattern and allow KattArmor to setColor the cube based on the trim material
  * for when you have a large project and want everything perfect, within reason
* Set a texture for each material-pattern combo, preferably using a texture generation system
  * For when you want to absolutely demolish your instruction count or file size. Texture manipulation is *very* expensive, which is why KattArmor does not care to do it.

Info for 2:
    Trim data is stored in nbt, and can be accessed via `item.tag.Trim.pattern` and `item.tag.Trim.material`. Dont forget to do a nil check for `item.tag.Trim`. 

Info for 3:
    use the `setTexture` and `setTextureLayer2` function on a TrimPattern object.
```lua
    kattArmor.TrimPatterns.wild
            :setTexture(textures["model.sentry"])
            :setTextureLayer2(textures["model.sentry_leggings"])
```
    The textures should be a gray-scale image so that ModelPart:setColor can do it's work.

    If you do not like the colors that I defined for each material, you can set them yourself via the `setColor` function on a TrimMaterial object.
```lua
    -- setColor expects a Vector3. I myself was lazy and used hex code number literals converted to Vec3 rbg via the `intToRGB` function.
    kattArmor.TrimMaterials.amethyst:setColor(vectors.intToRGB(0x9a5cc6))
```

Info for 4:
    you can use the `setTexture` and `setTextureLayer2` functions on a TrimMaterial object to completely override the texture used by a material-pattern combo.
```lua
    kattArmor.TrimMaterials.lapis:setTexture("ward", textures["model.sentry"])
```
    This texture is expected to be full color. KattArmor will apply no colors or other modifiers to the texture.

    As stated before, this is expected to be used by your own instruction burning texture generating script, or by burning file size by manually creating textures in Blockbench for each material-pattern combo

    I might make a texture generating script at some point, just so I can say that KattArmor *can* do it. Or I might not. Probably wont. Regardless, advanced texture manipulation will never be a base KattArmor feature due to it's expensive nature.

# KattArmor Instances

You heard at the top. KattArmor has instances. What does that mean?

`require` returns a function that when called, creates a new KattArmor instance. Every instance has it's own armor cubes, materials, textures, trim data. Basically, its a duplicated KattArmor script file. 

This allows asset creators to create assets that depend on KattArmor, without denying the user the ability to use KattArmor.

Before, each material had a single texture per layer. This meant that if you wanted to merge 2 projects that used KattArmor, you would either need to have a duplicate KattArmor script file, or merge the 2 projects so that the custom textures and uvs worked properly with each other.

You can see how this can be a pain for users that don't even know what they are doing.

There are some things that are shared globally with all instances.
* The `forceUpdate` function found in all instances will cause *all* instances to update when called.
* All onChange functions get added to a global list, meaning all instances will obey the material changing brought by onChange.
  * when multiple onChange functions are registered, the first truthy value will be used and all functions afterwords will not be called.
* `ArmorPart_SlotID_Map` and `SlotID_ArmorPart_Map`, which are static utility tables for mapping ArmorPartIDs with Slot numbers.

One thing that asset creators *do* have to worry about is giving users access to your KattArmor instance so they can add textures for their custom materials or modded armors. That is, unless you want the users to edit your script, making it difficult for users to update to newer versions of the asset.

# Custom Custom Custom Custom Custom

Not enough for you? There is `onRender` event which gets called after KattArmor has finished all of it's processing. In it's arguments is every single variable that KattArmor uses for determining how to render armor/trims.
```lua
kattArmor.registerOnRender(function (materialID, partID, item, visible, renderType, color, texture, textureType, texture_e, textureType_e, damageOverlay, trim, trimPattern, trimMaterial, trimTexture, trimTextureType, trimColor, trimUV)
  print("oh god thats alot")
end)
```
yea its a bit of a joke. The most useful things are the first 3 arguments anyways, but who knows. Someone might find it useful. For the record, you do not need to define every argument. You can ignore the ones you do not use, using `_` to pad out the positions.
```lua
kattArmor.registerOnRender(function (materialID, partID, item)
  print("ok this is more managable")
end)
kattArmor.registerOnRender(function (materialID, partID, item, _, _, _, _, _, _, _, _, trim, trimPattern, trimMaterial)
  print("I just want trim data for `x` reason")
end)
```

# Armor doesn't update when I do stuff?

KattArmor only updates Armor Parts when the equipped item changes. 

If you have additional code executing that onChange needs to watch for, you have to call `forceUpdate` when the variables change so that KattArmor knows to update the visuals.

Additionally, KattArmor functions do not automatically update the armor visuals, meaning you have to call `forceUpdate` when you modify Material textures or add more parts during tick, neither of which you should be doing anyways. Material textures should instead be handled via custom materials, and adding parts during tick should never be done in the first place.

```lua
local animatedArmor=0
function events.tick()
    if world.getTime()%4==0 then
        animatedArmor=(animatedArmor+1)%4
        kattArmor.forceUpdate()
    end
end

kattArmor.registerOnChange(function(partID, item)
    if item.id == "minecraft:netherite_"..partID:lower() then
        -- returns either "netherite-0", "netherite-1", "netherite-2", "netherite-3", which are custom materials.
        return "netherite-"..animatedArmor
    end
end)
```
