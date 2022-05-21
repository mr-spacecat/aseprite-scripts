-- TODO: help dialog
-- TODO: help on markdown with examples
-- TODO: reset to initial pos on scroll
-- TODO: prx wrap cant activate proper cel/frame/whatever
-- TODO: prx value multipler return it back  
-- Script
function ParallaxGenerator()
    -- Exit if no active sprite
    sprite = app.activeSprite
    if not sprite then
        app.alert("No sprite is loaded!")
        return
    end

    -- Section: factor suggestion
    -- Suggests optimal parallax shift values
    -- based on the entered number of frames 
    function GetFrameFactors(frames)
        local factors = {}
        for i = 1, frames do
            if frames % i == 0 then
                table.insert(factors, frames / i)
            end
        end
        return factors
    end

    -- Section: layer fetcher
    -- Gets all image layers, including nested ones
    function RecursiveGetLayers(list, input, layertype)
        for i, layer in ipairs(input) do
            if layer.layers ~= nil then
                RecursiveGetLayers(list, layer.layers, layertype)
            elseif string.find(layer.name, layertype) == 1 then
                table.insert(list, layer)
            end
        end
    end
    -- End layer fetcher

    -- Section: scroll function
    function ParallaxScroll(movement, data)
        -- Temporarily removed reset to intial position
        -- because direction was implpemented and
        -- cases where initial position is not 0, y  or x, 0 were not covered anyway
        local direction = data["direction"]:lower()
        local cel = app.activecel
        local bounds = cel.bounds
        -- Idea: working on new frame with cel copied from the previous one
        -- or cel in initial position
        -- if cel edge = canvas edge i.e. the cell would shift to emptiness this movement
        -- we reset the cell position to initial instead. 
        -- Get initial position from cell index = this cell - framestogenerate/prxvalue
        -- Execute move
        local x, y
        if direction == "left" then
            x, y = cel.position.x - movement, cel.position.y
        elseif direction == "right" then
            x, y = cel.position.x + movement, cel.position.y
        elseif direction == "up" then
            x, y = cel.position.x, cel.position.y - movement
        elseif direction == "down" then
            x, y = cel.position.x, cel.position.y + movement
        end
        cel.position = {x, y}
        -- end
    end
    -- End scroll function

    -- Section: wrap function
    function ParallaxWrap(movement, data)
        local bounds = sprite.bounds:union(Rectangle(app.activeCel.bounds))
        sprite.selection = Selection(bounds)

        -- Execute move
        app.command.MoveMask {
            targetCel = "content",
            wrap = true,
            direction = data["direction"]:lower(),
            units = "pixel",
            quantity = movement
        }
        app.command.DeselectMask()
    end
    -- End wrap function

    -- Section: parallax shift
    function ProcessParallaxLayers(data, iterator, didFrameExist)
        for i, layer in ipairs(parallaxLayers) do
            -- Get shift amount from dialog field
            local prxvalue = data[layer.name]

            if prxvalue ~= 0 and prxvalue ~= nil then
                -- Activate correct cel and layer
                app.activeCel = layer:cel(app.activeFrame)
                app.activeLayer = layer

                -- Adjust parallax value multiplier if frame exists
                -- because we can't rely on copying position from previous frame  
                if didFrameExist then
                    prxvalue = prxvalue * (iterator - 1)
                end

                -- Select parallax function
                if data["scroll"] then
                    -- Parallax scroll disabled until loop within is implemented
                    -- ParallaxScroll(prxvalue, data)
                else
                    ParallaxWrap(prxvalue, data)
                end
            end
        end
    end
    -- End parallax shift

    -- Section: copy loop
    function ProcessLoopingLayers(data, iterator)

        for i, layer in ipairs(loopingLayers) do
            -- Get loop length from dialog field
            local looplength = data[layer.name]

            local r = iterator % looplength
            if r == 0 then
                r = looplength
            end

            -- Get source cel
            local sourceCel = layer:cel(r)
            local targetCel = layer:cel(iterator)
            if targetCel == nil then
                targetCel = sprite:newCel(layer, iterator)
            end
            if targetCel.image ~= sourceCel.image then
                targetCel.image = sourceCel.image
                targetCel.position = sourceCel.position
            end
        end
    end
    -- End copy loop

    -- Section: Generate empty frame or jump to next frame
    function GenerateFrame(data, iterator)
        local frames = sprite.frames
        local didFrameExist = false

        if data["isappend"] or frames[iterator] == nil then
            -- Need new frame
            sprite:newFrame(#frames)
            app.activeFrame = #frames
        else
            -- Use existing frame
            app.activeFrame = iterator
            didFrameExist = true
        end

        if data["doprx"] then
            ProcessParallaxLayers(data, iterator, didFrameExist)
        end
        if data["doloop"] then
            ProcessLoopingLayers(data, iterator)
        end
    end
    -- End generate empty frame or jump to next frame

    -- Section: MAIN
    function Main(data)
        local framestogenerate = data["frame-quantity"]
        local startingFrame = 2 - (data["isappend"] and 1 or 0)

        -- Frame number is invalid, throw alert and do nothing
        if framestogenerate == 0 then
            app.alert {
                title = "Error!",
                text = "Frame generation quantity is set to 0."
            }
            return
            -- Both features are disabled, throw alert and do nothing
        elseif not data["doprx"] and not data["doloop"] then
            app.alert {
                title = "Error!",
                text = "No generation options selected."
            }
            return
        else
        end

        -- Process frames one by one
        -- Within each frame, do cels for all layers
        app.transaction(function()
            for i = startingFrame, framestogenerate do
                GenerateFrame(data, i)
            end
        end)
    end
    -- End MAIN

    -- Section: dialog
    local dlg = Dialog("Parallax")
    -- Frame quantity
    dlg:separator{
        id = "main",
        text = "Generation settings"
    }:number{
        id = "frame-quantity",
        label = "Frame quantity",
        text = "10",
        decimals = integer,
        onchange = function()
            local data = dlg.data
            local frames = data["frame-quantity"]
            local isvisible = true
            local stringbuilder = "1"
            -- Hide helper just for prettiness if frame number is invalid
            if frames == 0 or frames == nil then
                isvisible = false
            elseif frames > 9999999 then
                -- Prevent accidental freezing due to factorization of large numbers
                stringbuilder = "Too many frames to factorize"
            else
                -- Factorize
                local factors = GetFrameFactors(frames)
                for i = #factors - 1, 1, -1 do
                    stringbuilder = stringbuilder .. ", " .. tostring(math.modf(factors[i]))
                end
            end
            dlg:modify{
                id = "factors",
                text = stringbuilder,
                visible = isvisible
            }
        end
    }:label{
        id = "factors",
        label = "Suggested PRX values:",
        text = "1, 2, 5, 10",
        visible = true
    }:separator{}
    -- Generation methods
    dlg:radio{
        id = "wrap",
        label = "Generation method",
        text = "Wrap",
        selected = true
    }:radio{
        id = "scroll",
        text = "Scroll (Experimental)",
        selected = false
    }
    dlg:check{
        id = "isappend",
        label = "Append to current timeline",
        selected = false
    }
    -- PRX layers
    parallaxLayers = {}
    RecursiveGetLayers(parallaxLayers, sprite.layers, "PRX")
    dlg:separator{
        id = "layer-prx",
        text = "Parallax"
    }
    -- Show section only if there are PRX-marked layers
    if next(parallaxLayers) ~= nil then
        dlg:check{
            id = "doprx",
            label = "Generate parallax frames",
            selected = true,
            onclick = function()
                local data = dlg.data
                dlg:modify{
                    id = "direction",
                    visible = data["doprx"]
                }
                for i, layer in ipairs(parallaxLayers) do
                    dlg:modify{
                        -- Hide layers in dialog if PRX generation disabled
                        -- Can be useful if too many PRX+LOOP layers make dialog go out of screen bounds
                        id = layer.name,
                        visible = data["doprx"]
                    }
                end
            end
        }:combobox{
            id = "direction",
            label = "Movement direction",
            option = "Left",
            options = {"Left", "Right", "Down", "Up"}
        }
        for i, layer in ipairs(parallaxLayers) do
            -- Get default parallax speed from layer name
            local _, startingvalue = string.match(layer.name, "(PRX%-)(%d+)")
            if startingvalue == nil then
                startingvalue = "0"
            end
            -- Generate field for each layer
            dlg:number{
                id = layer.name,
                label = layer.name,
                text = startingvalue,
                decimals = integer
            }
        end
    else
        dlg:label{
            label = "No layers marked as parallax."
        }
    end
    -- LOOP layers
    loopingLayers = {}
    RecursiveGetLayers(loopingLayers, sprite.layers, "LOOP")
    dlg:separator{
        id = "layer-loop",
        text = "Static loops"
    }
    -- Show section only if there are LOOP-marked layers
    if next(loopingLayers) ~= nil then
        dlg:check{
            id = "doloop",
            label = "Generate loop frames",
            selected = true,
            onclick = function()
                local data = dlg.data
                for i, layer in ipairs(loopingLayers) do
                    dlg:modify{
                        -- Hide layers in dialog if LOOP generation disabled
                        -- Can be useful if too many PRX+LOOP layers make dialog go out of screen bounds
                        id = layer.name,
                        visible = data["doloop"]
                    }
                end
            end
        }
        for i, layer in ipairs(loopingLayers) do
            -- Get default loop length from layer name
            local _, startingvalue = string.match(layer.name, "(LOOP%-)(%d+)")
            if startingvalue == nil then
                startingvalue = "0"
            end
            -- Generate field for each layer
            dlg:number{
                id = layer.name,
                label = layer.name,
                text = startingvalue,
                decimals = integer
            }
        end
    else
        dlg:label{
            label = "No layers marked as loops."
        }
    end
    -- Bottom buttons
    dlg:button{
        id = "generate",
        text = "Generate",
        onclick = function()
            Main(dlg.data)
        end
    }:button{
        id = "close",
        text = "Close",
        onclick = function()
            dlg:close()
        end
    }
    -- End dialog
    dlg:show()
end

ParallaxGenerator()

