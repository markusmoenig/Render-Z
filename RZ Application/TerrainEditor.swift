//
//  TerrainEditor.swift
//  Shape-Z
//
//  Created by Markus Moenig on 13/5/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class LayerListItem : MMTreeWidgetItem
{
    enum LayerType : Int {
        case PaintLayer, NoiseLayer
    }
    
    var name         : String
    var uuid         : UUID
    var color        : SIMD4<Float>? = SIMD4<Float>(0.5, 0.5, 0.5, 1)
    var children     : [MMTreeWidgetItem]? = nil
    var folderOpen   : Bool = false
    
    var layerType    : LayerType
    
    var layer        : TerrainLayer?
            
    init(_ name: String, _ uuid: UUID,_ type: LayerType, layer: TerrainLayer?)
    {
        self.name = name
        self.uuid = uuid
        layerType = type
        self.layer = layer
    }
}

class TerrainEditor         : PropertiesWidget
{
    enum ActionState : Int {
        case None, PaintHeight
    }
    
    var actionState         : ActionState = .None

    var terrain             : Terrain!
    
    var mouseIsDown         : Bool = false
    var mouseDownPos        : SIMD2<Float> = SIMD2<Float>()
    
    var layerListWidget     : MMTreeWidget
    var layerItems          : [LayerListItem] = []

    var currentLayerItem    : LayerListItem!

    var originTexture       : MTLTexture? = nil
    var directionTexture    : MTLTexture? = nil
    
    var addLayerButton      : MMButtonWidget!
    var deleteLayerButton   : MMButtonWidget!
    
    let height               : Float = 200

    override required init(_ view: MMView)
    {
        layerListWidget = MMTreeWidget(view)
        
        layerListWidget.skin.selectionColor = SIMD4<Float>(0.5,0.5,0.5,1)
        
        //layerListWidget.itemRound = 0
        //layerListWidget.textOnly = true
        //layerListWidget.unitSize -= 5
        //layerListWidget.itemSize -= 5*/
        
        layerListWidget.selectionColor = SIMD4<Float>(0.2, 0.2, 0.2, 1)
        
        super.init(view)
        
        addLayerButton = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Add", fixedWidth: buttonWidth)
        addLayerButton.clicked = { (event) in
            let layer = TerrainLayer()
            let item = LayerListItem("Noise Layer #" + String(self.layerItems.count), UUID(), .NoiseLayer, layer: layer)
            self.layerItems.insert(item, at: 0)
            self.terrain.layers.insert(layer, at: 0)
        }
        
        deleteLayerButton = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Delete", fixedWidth: buttonWidth)
        deleteLayerButton.clicked = { (event) in
        }
    }
    
    func activate()
    {
        mmView.registerPriorityWidgets(widgets: self)
        computeCameraTextures()
    }
    
    func deactivate()
    {
        mmView.deregisterWidgets(widgets: self)
        originTexture = nil
        directionTexture = nil
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
        
        actionState = .None
        
        if event.y < rect.bottom() - height {
            // inside the upper area
            
            globalApp!.currentPipeline?.setMinimalPreview(true)
            
            if let loc = getHitLocationAt(event) {
                                
                let val = getValue(loc)
                setValue(loc, value: Int8(val + 1))

                globalApp!.currentEditor.updateOnNextDraw(compile: false)
                
                actionState = .PaintHeight
            }
            return
        }
        
        if layerListWidget.rect.contains(event.x, event.y) {
            let changed = layerListWidget.selectAt(event.x - layerListWidget.rect.x, (event.y - layerListWidget.rect.y), items: layerItems)
            if changed {
                
                layerListWidget.build(items: layerItems, fixedWidth: 150)
                if let item = layerListWidget.getCurrentItem() as? LayerListItem {
                    setLayerItem(item)
                }
            }
            return
        }
        
        super.mouseDown(event)
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if actionState == .PaintHeight {
            if let loc = getHitLocationAt(event) {
                let val = getValue(loc)
                setValue(loc, value: Int8(val + 1))

                globalApp!.currentEditor.updateOnNextDraw(compile: false)
                
                actionState = .PaintHeight
            }
            
            return
        }
        
        super.mouseMoved(event)
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
        if layerListWidget.rect.contains(event.x, event.y) {
            layerListWidget.mouseUp(event)
            return
        }
        
        if actionState == .PaintHeight {
            globalApp!.currentPipeline?.setMinimalPreview()
        }
        
        super.mouseUp(event)

        actionState = .None
    }
    
    func terrainNeedsUpdate(_ compile: Bool = true)
    {
        if compile == true {
            if let component = getComponent(name: "Ground") {
                if let stageItem = globalApp!.project.selected!.getStageItem(component, selectIt: false) {
                    globalApp!.developerEditor.codeEditor.markStageItemInvalid(stageItem)
                }
            }
        }
        globalApp!.currentEditor.updateOnNextDraw(compile: compile)
    }
    
    func setLayerItem(_ item: LayerListItem)
    {
        layerListWidget.selectedItems = [item.uuid]
        currentLayerItem = item
        updateUI()
        layerListWidget.build(items: layerItems, fixedWidth: 150)
    }
    
    func setTerrain(_ terrain: Terrain)
    {
        self.terrain = terrain
        
        // Build Layer List
        
        layerItems = []

        let item = LayerListItem("Paint Layer", UUID(), .PaintLayer, layer: nil)
        layerItems.append(item)
        
        for (index, l) in terrain.layers.enumerated() {
            let item = LayerListItem("Noise Layer #" + String(index+1), UUID(), .NoiseLayer, layer: l)
            layerItems.insert(item, at: index)
        }
        
        setLayerItem(layerItems.last!)
    }
    
    func updateUI()
    {
        clear()
        
        addButton(addLayerButton)
        addButton(deleteLayerButton)
        
        c1Node = Node()
        c1Node?.rect.x = 10
        c1Node?.rect.y = 10
        
        c2Node = Node()
        c2Node?.rect.x = 10
        c2Node?.rect.y = 10
        
        if currentLayerItem.layerType == .NoiseLayer {
            
            let noiseModeVar = NodeUISelector(c1Node!, variable: "noiseMode", title: "Noise Mode", items: ["None", "Noise 2D", "Noise 3D", "Image"], index: Float(currentLayerItem.layer!.noiseType.rawValue), shadows: false)
            c1Node!.uiItems.append(noiseModeVar)
            
            let blendModeVar = NodeUISelector(c1Node!, variable: "blendMode", title: "Blend Mode", items: ["Add", "Subtract"], index: Float(currentLayerItem.layer!.blendType.rawValue), shadows: false)
            c1Node!.uiItems.append(blendModeVar)
            
            c1Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                if variable == "noiseMode" {
                    self.currentLayerItem.layer!.noiseType = TerrainLayer.LayerNoiseType(rawValue: Int(newValue))!
                    self.terrainNeedsUpdate()
                    self.updateUI()
                } else
                if variable == "blendMode" {
                    self.currentLayerItem.layer!.blendType = TerrainLayer.LayerBlendType(rawValue: Int(newValue))!
                    self.terrainNeedsUpdate()
                    self.updateUI()
                }
                self.terrainNeedsUpdate(false)
            }
            
            c2Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                if variable == "noiseMode" {
                    self.currentLayerItem.layer!.noiseType = TerrainLayer.LayerNoiseType(rawValue: Int(newValue))!
                    self.terrainNeedsUpdate()
                    self.updateUI()
                }
                self.terrainNeedsUpdate(false)
                
                if variable.starts(with: "noise") || variable.starts(with: "image") {
                    if self.currentLayerItem.layer!.noiseType == .Image {
                        let fragment = self.currentLayerItem.layer!.imageFragment
                        fragment.values[variable] = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? globalApp!.currentEditor.undoComponentStart("Image Changed") : nil
                        fragment.values[variable] = newValue
                        if variable == "image" {
                            self.terrainNeedsUpdate()
                        }
                        if let undo = codeUndo { globalApp!.currentEditor.undoComponentEnd(undo) }
                    } else
                    if self.currentLayerItem.layer!.noiseType == .TwoD {
                        let fragment = self.currentLayerItem.layer!.noise2DFragment
                        fragment.values[variable] = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? globalApp!.currentEditor.undoComponentStart("Noise Changed") : nil
                        fragment.values[variable] = newValue
                        if variable == "noise2D" || variable == "noiseMix2D" {
                            self.terrainNeedsUpdate()
                        }
                        if let undo = codeUndo { globalApp!.currentEditor.undoComponentEnd(undo) }
                    } else
                    if self.currentLayerItem.layer!.noiseType == .ThreeD {
                        let fragment = self.currentLayerItem.layer!.noise3DFragment

                        fragment.values[variable] = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? globalApp!.currentEditor.undoComponentStart("Noise Changed") : nil
                        fragment.values[variable] = newValue
                        if variable == "noise3D" || variable == "noiseMix3D" {
                            self.terrainNeedsUpdate()
                        }
                        if let undo = codeUndo { globalApp!.currentEditor.undoComponentEnd(undo) }
                    }
                    return
                }
            }
            
            if currentLayerItem.layer!.noiseType == .TwoD {
                // To initiate the fragment in case its a virgin
                let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, globalApp!.developerEditor.codeEditor.codeContext.fontScale)
                let component = CodeComponent(.Dummy)
                ctx.cComponent = component
                component.globalCode = ""
                let _ = generateNoise2DFunction(ctx, currentLayerItem.layer!.noise2DFragment)
                c2Node!.uiItems.append(setupNoise2DUI(c2Node!, currentLayerItem.layer!.noise2DFragment))
            } else
            if currentLayerItem.layer!.noiseType == .ThreeD {
                // To initiate the fragment in case its a virgin
                let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, globalApp!.developerEditor.codeEditor.codeContext.fontScale)
                let component = CodeComponent(.Dummy)
                ctx.cComponent = component
                component.globalCode = ""
                let _ = generateNoise3DFunction(ctx, currentLayerItem.layer!.noise3DFragment)
                c2Node!.uiItems.append(setupNoise3DUI(c2Node!, currentLayerItem.layer!.noise3DFragment))
            } else
            if currentLayerItem.layer!.noiseType == .Image {
                // To initiate the fragment in case its a virgin
                let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, globalApp!.developerEditor.codeEditor.codeContext.fontScale)
                let component = CodeComponent(.Dummy)
                ctx.cComponent = component
                component.globalCode = ""
                let _ = generateImageFunction(ctx, currentLayerItem.layer!.imageFragment)
                c2Node!.uiItems.append(setupImageUI(c2Node!, currentLayerItem.layer!.imageFragment))
            }
        }
        
        c1Node?.setupUI(mmView: mmView)
        c2Node?.setupUI(mmView: mmView)
    }

    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        drawPreview(mmView: mmView, rect)
        
        let startY : Float = rect.bottom() - height

        mmView.drawBox.draw( x: rect.x, y: rect.bottom() - height + 0.5, width: rect.width + 0.5, height: height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1.0 ))
                
        layerListWidget.rect.x = rect.x + 5
        layerListWidget.rect.y = startY + 50
        layerListWidget.rect.width = 180
        layerListWidget.rect.height = height - 50
        layerListWidget.draw()
        
        //layerListWidget.drawRoundedBorder(backColor: SIMD4<Float>(0.145, 0.145, 0.145, 1.0), borderColor: SIMD4<Float>(0.286, 0.286, 0.286, 1.000))
        
        addLayerButton.rect.x = rect.x + 5
        addLayerButton.rect.y = startY + 5
        addLayerButton.rect.width = 80
        
        deleteLayerButton.rect.x = addLayerButton.rect.right() + 5
        deleteLayerButton.rect.y = startY + 5
        deleteLayerButton.rect.width = 80
        
        c1Node?.rect.x = layerListWidget.rect.right() + 20
        c1Node?.rect.y = startY + 5 - rect.y
        
        c2Node?.rect.x = layerListWidget.rect.right() + 220
        c2Node?.rect.y = startY + 5 - rect.y
        
        super.draw(xOffset: xOffset, yOffset: yOffset)
    }
    
    func getValue(_ location: SIMD2<Float>) -> Int8
    {
        var loc = location
        var value : Int8 = 0;
        
        loc.x += terrain.terrainSize / 2.0
        loc.y += terrain.terrainSize / 2.0
        
        let x : Int = Int(loc.x)
        let y : Int = Int(loc.y)

        let region = MTLRegionMake2D(min(Int(x), Int(terrain.terrainSize)-1), min(Int(y), Int(terrain.terrainSize)-1), 1, 1)

        var texArray = Array<Int8>(repeating: Int8(0), count: 2)
        texArray.withUnsafeMutableBytes { texArrayPtr in
            if let ptr = texArrayPtr.baseAddress {
                if let texture = terrain.getTexture() {
                    texture.getBytes(ptr, bytesPerRow: (MemoryLayout<Int8>.size * 2 * texture.width), from: region, mipmapLevel: 0)
                }
            }
        }
            
        value = texArray[0]
        return value
    }
    
    func setValue(_ location: SIMD2<Float>, value: Int8 = 1)
    {
        var loc = location
        
        loc.x += terrain.terrainSize / 2.0
        loc.y += terrain.terrainSize / 2.0
        
        let x : Int = Int(loc.x)
        let y : Int = Int(loc.y)

        let region = MTLRegionMake2D(min(Int(x), Int(terrain.terrainSize)-1), min(Int(y), Int(terrain.terrainSize)-1), 1, 1)

        var texArray = Array<Int8>(repeating: value, count: 2)
        texArray.withUnsafeMutableBytes { texArrayPtr in
            if let ptr = texArrayPtr.baseAddress {
                if let texture = terrain.getTexture() {
                    texture.replace(region: region, mipmapLevel: 0, withBytes: ptr, bytesPerRow: (MemoryLayout<Int8>.size * 2 * texture.width))
                }
            }
        }
    }
    
    /// Returns the XZ location of the mouse location
    func getHitLocationAt(_ event: MMMouseEvent) -> SIMD2<Float>?
    {
        let x : Float = event.x - rect.x
        let y : Float = event.y - rect.y
         
        // Selection
        if let texture = globalApp!.currentPipeline!.getTextureOfId("id") {
             
            if let convertTo = globalApp!.currentPipeline!.codeBuilder.compute.allocateTexture(width: Float(texture.width), height: Float(texture.height), output: true, pixelFormat: .rgba32Float) {
             
                globalApp!.currentPipeline!.codeBuilder.renderCopy(convertTo, texture, syncronize: true)
                 
                let region = MTLRegionMake2D(min(Int(x), convertTo.width-1), min(Int(y), convertTo.height-1), 1, 1)

                var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(repeating: 0), count: 1)
                texArray.withUnsafeMutableBytes { texArrayPtr in
                    if let ptr = texArrayPtr.baseAddress {
                        convertTo.getBytes(ptr, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * convertTo.width), from: region, mipmapLevel: 0)
                    }
                }
                let value = texArray[0]
                
                if value.w >= 0 {
                    let camera = getCameraValues(event)
                    let hit = camera.0 + normalize(camera.1) * value.y

                    return SIMD2<Float>(hit.x, hit.z)
                }
            }
        }
        return nil
    }
    
    func convertTexture(_ texture: MTLTexture) -> MTLTexture?
    {
        if let convertTo = globalApp!.currentPipeline!.codeBuilder.compute.allocateTexture(width: Float(texture.width), height: Float(texture.height), output: true, pixelFormat: .rgba32Float) {
         
            globalApp!.currentPipeline!.codeBuilder.renderCopy(convertTo, texture, syncronize: true)
            return convertTo
        }
        return nil
    }
    
    /// Returns the XZ location of the mouse location
    func getTextureValueAt(_ event: MMMouseEvent, texture: MTLTexture) -> SIMD4<Float>
    {
        let x : Float = event.x - rect.x
        let y : Float = event.y - rect.y

        let region = MTLRegionMake2D(min(Int(x), texture.width-1), min(Int(y), texture.height-1), 1, 1)

        var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(repeating: 0), count: 1)
        texArray.withUnsafeMutableBytes { texArrayPtr in
            if let ptr = texArrayPtr.baseAddress {
                texture.getBytes(ptr, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * texture.width), from: region, mipmapLevel: 0)
            }
        }
            
        return texArray[0]
    }
    
    /// Returns the origin and lookAt values of the camera
    func computeCameraTextures()
    {
        if let pipeline = globalApp!.currentPipeline as? Pipeline3D {
    
            originTexture = pipeline.checkTextureSize(rect.width, rect.height, nil, .rgba16Float)
            directionTexture = pipeline.checkTextureSize(rect.width, rect.height, nil, .rgba16Float)
            
            if let inst = pipeline.instanceMap["camera3D"] {
                
                pipeline.codeBuilder.render(inst, originTexture!, outTextures: [directionTexture!])
                
                originTexture = convertTexture(originTexture!)
                directionTexture = convertTexture(directionTexture!)
            }
        }
    }
    
    /// Returns the origin and lookAt values of the camera
    func getCameraValues(_ event: MMMouseEvent) -> (SIMD3<Float>, SIMD3<Float>)
    {
        let origin = getTextureValueAt(event, texture: originTexture!)
        let lookAt = getTextureValueAt(event, texture: directionTexture!)
            
        return (SIMD3<Float>(origin.x, origin.y, origin.z), SIMD3<Float>(lookAt.x, lookAt.y, lookAt.z))
    }
}
