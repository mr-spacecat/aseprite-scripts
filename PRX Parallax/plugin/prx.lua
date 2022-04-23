-- Script
-- TODO: code comments
-- TODO: help dialog
-- TODO: help on markdown with examples
-- isavailable = true
function ParallaxGenerator()
    -- Section: factor suggestion
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
    function ParallaxScroll(movement)
        local cel = app.activecel
        local bounds = cel.bounds
        -- For a perfect loop, initial image of each layer MUST
        -- be exactly the canvas size on x axis
        -- be aligned to the left canvas border i.e. starting x position is 0
        -- parallax value for the layer must be a factor of the canvas size
        if math.abs(bounds.x) >= sprite.width then
            -- Reset position
            cel.position = {-movement, cel.position.y}
        else
            -- Move image
            cel.position = {cel.position.x - movement, cel.position.y}
        end
    end
    -- End scroll function

    -- Section: wrap function
    function ParallaxWrap(movement)
        local cel = app.activecel
        local bounds = sprite.bounds:union(Rectangle(cel.bounds))
        app.activeLayer = cel.layer
        sprite.selection = Selection(bounds)
        app.command.MoveMask {
            target = 'content',
            wrap = true,
            direction = 'left',
            units = 'pixel',
            quantity = movement
        }
        app.command.DeselectMask()
    end
    -- End wrap function

    -- Section: generate frame
    function GenerateFrame(data, iterator)
        local frames = sprite.frames
        local modifyprx = false

        -- Always append new frames or overwrite cels depending on switch in dialog
        if data["isappend"] then
            sprite:newFrame(#frames)
            app.activeframe = #frames
        else
            if frames[iterator] == nil then
                sprite:newFrame(#frames)
                app.activeframe = #frames
            else
                app.activeframe = iterator
                -- Remember that we need to adjust how far 
                -- to move the content if the frame exists
                modifyprx = true
            end
        end

        -- Work only on cels of parallax-enabled layers
        for i, layer in ipairs(parallaxLayers) do
            local prxvalue = data[layer.name]
            if prxvalue ~= 0 and prxvalue ~= nil then
                app.activecel = layer:cel(app.activeframe)
                if modifyprx then
                    -- Adjust parallax value multiplier if frame exists
                    -- because we can't rely on copying position from previous frame  
                    prxvalue = prxvalue * (iterator - 1)
                end
                -- Select parallax function
                if data["scroll"] then
                    ParallaxScroll(prxvalue)
                else
                    ParallaxWrap(prxvalue)
                end
            end
        end
    end
    -- End generate frame

    -- Section: copy loop
    function CopyLoop(data, iterator)
        for i, layer in ipairs(loopingLayers) do
            local looplength = data[layer.name]
            if looplength ~= 0 and looplength ~= nil and iterator > looplength then
                local source = layer:cel(iterator - looplength)
                local target = layer:cel(iterator)
                -- Check for image equality before copying
                -- Is it more performant than simply replacing though?
                if target.image ~= source.image then
                    target.image = source.image
                end
            end
        end
    end
    -- End copy loop

    -- Section: MAIN
    sprite = app.activeSprite
    function GenerateAll(data)
        local framestogenerate = data["frame-quantity"]
        local iterator
        if data["isappend"] then
            iterator = 1
        else
            iterator = 2
        end

        -- Generate parallax frames
        if framestogenerate ~= 0 and data["doprx"] then
            app.transaction(function()
                for i = iterator, framestogenerate do
                    GenerateFrame(data, i)
                end
            end)
        elseif framestogenerate == 0 and data["doprx"] then
            app.alert {
                title = "Error!",
                text = "Frame generation quantity is set to 0."
            }
        end

        -- Generate looping frames
        if data["doloop"] then
            app.transaction(function()
                for i = iterator, #(sprite.frames) do
                    CopyLoop(data, i)
                end
            end)
        end
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
            if frames == 0 or frames == nil then
                isvisible = false
            elseif frames > 9999999 then
                -- Prevent accidental freezing
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
        id = "scroll",
        label = "Generation method",
        text = "Scroll",
        selected = false
    }:radio{
        id = "replace",
        text = "Wrap (Experimental)",
        selected = true
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
        text = "Parallax movement values"
    }
    if next(parallaxLayers) ~= nil then
        dlg:check{
            id = "doprx",
            label = "Generate parallax frames",
            selected = true,
            onclick = function()
                local data = dlg.data
                for i, layer in ipairs(parallaxLayers) do
                    dlg:modify{
                        id = layer.name,
                        visible = data["doprx"]
                    }
                end
            end
        }
        for i, layer in ipairs(parallaxLayers) do
            local _, startingvalue = string.match(layer.name, "(PRX%-)(%d+)")
            if startingvalue == nil then
                startingvalue = "0"
            end
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
        text = "Looping layer loop length"
    }
    if next(loopingLayers) ~= nil then
        dlg:check{
            id = "doloop",
            label = "Generate looping frames",
            selected = true,
            onclick = function()
                local data = dlg.data
                for i, layer in ipairs(loopingLayers) do
                    dlg:modify{
                        id = layer.name,
                        visible = data["doloop"]
                    }
                end
            end
        }
        for i, layer in ipairs(loopingLayers) do
            local _, startingvalue = string.match(layer.name, "(LOOP%-)(%d+)")
            if startingvalue == nil then
                startingvalue = "0"
            end
            dlg:number{
                id = layer.name,
                label = layer.name,
                text = startingvalue,
                decimals = integer
            }
        end
    else
        dlg:label{
            label = "No layers marked as looping."
        }
    end
    -- Bottom buttons
    dlg:button{
        id = "generate",
        text = "Generate",
        onclick = function()
            GenerateAll(dlg.data)
        end
    }:button{
        id = "close",
        text = "Close",
        onclick = function()
            -- isavailable = true
            dlg:close()
        end
    }
    -- End dialog
    dlg:show()
end

-- Plugin
function init(plugin)
    plugin:newCommand{
        id = "prx-dialog",
        title = "Parallax",
        -- FOR SOME UNKNOWN REASON ASEPRITE CRASHES IF MENU IS NOT cel_popup_properties
        group = "fx_popup_menu",
        onclick = function()
            ParallaxGenerator()
            -- isavailable = false
        end
        -- onenabled = function()
        --     return isavailable
        -- end
    }
end
