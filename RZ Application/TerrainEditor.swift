//
//  TerrainEditor.swift
//  Shape-Z
//
//  Created by Markus Moenig on 13/5/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class LayerListItem : MMListWidgetItem
{
    enum LayerType : Int {
        case PaintLayer, NoiseLayer
    }
    
    var name         : String
    var uuid         : UUID
    var color        : SIMD4<Float>? = SIMD4<Float>(0.282, 0.282, 0.282, 1)
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
    
    var layerListWidget     : MMListWidget
    var layerItems          : [LayerListItem] = []

    var currentLayerItem    : LayerListItem!

    var originTexture       : MTLTexture? = nil
    var directionTexture    : MTLTexture? = nil
    
    var cameraButton        : MMButtonWidget!
    var topDownButton       : MMButtonWidget!
    
    var addLayerButton      : MMButtonWidget!
    var deleteLayerButton   : MMButtonWidget!
    
    var addRegionButton     : MMButtonWidget!
    var deleteRegionButton  : MMButtonWidget!
    
    var topDownIsActive     : Bool = false
    
    let height              : Float = 200
    
    var orthoCamera         : CodeComponent? = nil
    
    var layerListNeedsUpdate: Bool = false

    override required init(_ view: MMView)
    {
        layerListWidget = MMListWidget(view)
        
        super.init(view)
        
        cameraButton = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Camera", fixedWidth: buttonWidth)
        cameraButton.clicked = { (event) in
            self.topDownButton.removeState(.Checked)
            self.deinstallTopDownView()
            self.topDownIsActive = false
            self.computeCameraTextures()
        }
        
        topDownButton = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Top Down", fixedWidth: buttonWidth)
        topDownButton.clicked = { (event) in
            self.cameraButton.removeState(.Checked)
            self.installTopDownView()
            self.topDownIsActive = true
            self.computeCameraTextures()
        }
        
        var borderlessSkin = MMSkinButton()
        borderlessSkin.margin = MMMargin( 14, 4, 14, 4 )
        borderlessSkin.borderSize = 0
        borderlessSkin.height = view.skin.Button.height - 1
        borderlessSkin.fontScale = 0.4
        borderlessSkin.round = 28
        
        addLayerButton = MMButtonWidget(mmView, skinToUse: borderlessSkin, text: "Add", fixedWidth: buttonWidth)
        addLayerButton.clicked = { (event) in
            let layer = TerrainLayer()
            let item = LayerListItem("Noise Layer #" + String(self.layerItems.count), UUID(), .NoiseLayer, layer: layer)
            self.layerItems.insert(item, at: 0)
            self.terrain.layers.insert(layer, at: 0)
            self.addLayerButton.removeState(.Checked)
            self.setLayerItem(item)
        }
        
        deleteLayerButton = MMButtonWidget(mmView, skinToUse: borderlessSkin, text: "Delete", fixedWidth: buttonWidth)
        deleteLayerButton.clicked = { (event) in
            if let index = self.terrain.layers.firstIndex(of: self.currentLayerItem.layer!) {
                self.layerItems.remove(at: index)
                self.terrain.layers.remove(at: index)
                self.setLayerItem(self.layerItems.last!)
                self.terrainNeedsUpdate()
            }
            self.deleteLayerButton.removeState(.Checked)
        }
        
        
        addRegionButton = MMButtonWidget(mmView, skinToUse: borderlessSkin, text: "Add Shape", fixedWidth: buttonWidth)
        addRegionButton.clicked = { (event) in
            globalApp!.libraryDialog.show(ids: ["SDF2D"], style: .Icon, cb: { (json) in
                if let comp = decodeComponentFromJSON(json) {
                    
                    self.currentLayerItem.layer!.shapes.append(comp)
                    
                    self.terrainNeedsUpdate()
                    self.addRegionButton.removeState(.Checked)
                }
            } )
        }
        
        deleteRegionButton = MMButtonWidget(mmView, skinToUse: borderlessSkin, text: "Delete", fixedWidth: buttonWidth)
        deleteRegionButton.clicked = { (event) in

        }
    }
    
    func activate()
    {
        mmView.registerPriorityWidgets(widgets: self)

        if topDownIsActive {
            cameraButton.removeState(.Checked)
            topDownButton.addState(.Checked)
            installTopDownView()
        } else {
            topDownButton.removeState(.Checked)
            cameraButton.addState(.Checked)
        }
        
        computeCameraTextures()
    }
    
    func deactivate()
    {
        clear()
        mmView.deregisterWidgets(widgets: self)
        originTexture = nil
        directionTexture = nil
        
        if topDownIsActive {
            self.deinstallTopDownView()
            terrainNeedsUpdate()
        }
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
                
                //layerListWidget.build(items: layerItems, fixedWidth: layerListWidget.rect.width)
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
                setValue(loc, value: Int8(val - 1))

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

        deleteLayerButton.isDisabled = currentLayerItem.layerType == .PaintLayer
        mmView.update()
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
        
        addButton(cameraButton)
        addButton(topDownButton)
        
        addButton(addLayerButton)
        addButton(deleteLayerButton)
        
        if currentLayerItem.layerType == .NoiseLayer {
            addButton(addRegionButton)
            addButton(deleteRegionButton)
        }
        
        c1Node = Node()
        c1Node?.rect.x = 10
        c1Node?.rect.y = 10
        
        c2Node = Node()
        c2Node?.rect.x = 10
        c2Node?.rect.y = 10
        
        if currentLayerItem.layerType == .NoiseLayer {
            
            let noiseModeVar = NodeUISelector(c1Node!, variable: "noiseMode", title: "Noise Mode", items: ["None", "Noise 2D", "Noise 3D", "Image"], index: Float(currentLayerItem.layer!.noiseType.rawValue), shadows: false)
            c1Node!.uiItems.append(noiseModeVar)
            
            let blendModeVar = NodeUISelector(c1Node!, variable: "blendMode", title: "Blend Mode", items: ["Add", "Subtract", "Max"], index: Float(currentLayerItem.layer!.blendType.rawValue), shadows: false)
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
        } else {
            let terrainScaleVar = NodeUINumber(c1Node!, variable: "terrainScale", title: "Terrain Scale", range: SIMD2<Float>(0.5, 1), value: 1.0 - terrain.terrainScale, precision: Int(3))
            c1Node?.uiItems.append(terrainScaleVar)
            let terrainHeightScaleVar = NodeUINumber(c1Node!, variable: "terrainHeightScale", title: "Height Scale", range: SIMD2<Float>(0.1, 2), value: terrain.terrainHeightScale, precision: Int(3))
            c1Node?.uiItems.append(terrainHeightScaleVar)
            c1Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                if variable == "terrainScale" {
                    self.terrain.terrainScale = max(1.0 - newValue, 0.001)
                    self.terrainNeedsUpdate()
                }
                if variable == "terrainHeightScale" {
                    self.terrain.terrainHeightScale = newValue
                    self.terrainNeedsUpdate()
                }
                self.terrainNeedsUpdate(false)
            }
        }
                
        c1Node?.setupUI(mmView: mmView)
        c2Node?.setupUI(mmView: mmView)
    }

    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        drawPreview(mmView: mmView, rect)
        
        //if layerListNeedsUpdate {
            layerListWidget.build(items: layerItems, fixedWidth: layerListWidget.rect.width)
//            layerListNeedsUpdate = false
        //}
        
        let startY : Float = rect.bottom() - height

        mmView.drawBox.draw( x: rect.x, y: rect.bottom() - height + 0.5, width: rect.width + 0.5, height: height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1.0 ))
                
        layerListWidget.rect.x = rect.x + 8
        layerListWidget.rect.y = startY + 45
        layerListWidget.rect.width = 180
        layerListWidget.rect.height = height - 53
        layerListWidget.draw()
        
        layerListWidget.drawRoundedBorder(backColor: SIMD4<Float>(0.145, 0.145, 0.145, 1.0), borderColor:  SIMD4<Float>(0.286, 0.286, 0.286, 1.000))
        
        cameraButton.rect.x = rect.x + 5
        cameraButton.rect.y = rect.y + 5
        cameraButton.rect.width = buttonWidth
        
        topDownButton.rect.x = cameraButton.rect.right() + 5
        topDownButton.rect.y = rect.y + 5
        topDownButton.rect.width = buttonWidth
        
        addLayerButton.rect.x = rect.x + 10
        addLayerButton.rect.y = startY + 10
        addLayerButton.rect.width = 80
        
        deleteLayerButton.rect.x = addLayerButton.rect.right() + 5
        deleteLayerButton.rect.y = startY + 10
        deleteLayerButton.rect.width = 80
        
        if currentLayerItem.layerType == .NoiseLayer {
            addRegionButton.rect.x = rect.x + 5
            addRegionButton.rect.y = startY - addLayerButton.rect.height - 5
            
            deleteRegionButton.rect.x = addRegionButton.rect.right() + 5
            deleteRegionButton.rect.y = addRegionButton.rect.y
        }
        
        c1Node?.rect.x = layerListWidget.rect.right() + 30
        c1Node?.rect.y = startY + 20 - rect.y
        
        c2Node?.rect.x = layerListWidget.rect.right() + 220
        c2Node?.rect.y = startY + 20 - rect.y
        
        super.draw(xOffset: xOffset, yOffset: yOffset)
    }
    
    func getValue(_ location: SIMD2<Float>) -> Int8
    {
        var loc = location
        var value : Int8 = 0;
        
        loc.x += terrain.terrainSize / terrain.terrainScale / 2.0 * terrain.terrainScale
        loc.y += terrain.terrainSize / terrain.terrainScale / 2.0 * terrain.terrainScale
        
        let x : Int = Int(loc.x)
        let y : Int = Int(loc.y)
                
        if x >= 0 && x < Int(terrain.terrainSize) && y >= 0 && y < Int(terrain.terrainSize) {
            let region = MTLRegionMake2D(min(Int(x), Int(terrain.terrainSize)-1), min(Int(y), Int(terrain.terrainSize)-1), 1, 1)
            var texArray = Array<Int8>(repeating: Int8(0), count: 1)
            texArray.withUnsafeMutableBytes { texArrayPtr in
                if let ptr = texArrayPtr.baseAddress {
                    if let texture = terrain.getTexture() {
                        texture.getBytes(ptr, bytesPerRow: (MemoryLayout<Int8>.size * texture.width), from: region, mipmapLevel: 0)
                    }
                }
            }
            value = texArray[0]
        }
        
        return value
    }
    
    func setValue(_ location: SIMD2<Float>, value: Int8 = 1)
    {
        var loc = location
        
        loc.x += terrain.terrainSize / terrain.terrainScale / 2.0 * terrain.terrainScale
        loc.y += terrain.terrainSize / terrain.terrainScale / 2.0 * terrain.terrainScale
        
        let x : Int = Int(loc.x)
        let y : Int = Int(loc.y)

        if x >= 0 && x < Int(terrain.terrainSize) && y >= 0 && y < Int(terrain.terrainSize) {
            let region = MTLRegionMake2D(min(Int(x), Int(terrain.terrainSize)-1), min(Int(y), Int(terrain.terrainSize)-1), 1, 1)
            var texArray = Array<Int8>(repeating: value, count: 1)
            texArray.withUnsafeMutableBytes { texArrayPtr in
                if let ptr = texArrayPtr.baseAddress {
                    if let texture = terrain.getTexture() {
                        texture.replace(region: region, mipmapLevel: 0, withBytes: ptr, bytesPerRow: (MemoryLayout<Int8>.size * texture.width))
                    }
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
                globalApp!.currentPipeline!.codeBuilder.waitUntilCompleted()

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

                    return SIMD2<Float>(hit.x * terrain.terrainScale, hit.z * terrain.terrainScale)
                }
            }
        }
        return nil
    }
    
    func convertTexture(_ texture: MTLTexture) -> MTLTexture?
    {
        if let convertTo = globalApp!.currentPipeline!.codeBuilder.compute.allocateTexture(width: Float(texture.width), height: Float(texture.height), output: true, pixelFormat: .rgba32Float) {
         
            globalApp!.currentPipeline!.codeBuilder.renderCopy(convertTo, texture, syncronize: true)
            globalApp!.currentPipeline!.codeBuilder.waitUntilCompleted()

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
                pipeline.codeBuilder.waitUntilCompleted()

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
    
    /// Installs a StageItem with an orthographic camera for the top down view
    func installTopDownView()
    {
        if orthoCamera == nil {
            if let ortho = globalApp!.libraryDialog.getItem(ofId: "Camera3D", withName: "Orthographic Camera") {
                setPropertyValue3(component: ortho, name: "origin", value: SIMD3<Float>(0,2,0))
                setPropertyValue3(component: ortho, name: "lookAt", value: SIMD3<Float>(-0.05,0,0))
                setPropertyValue1(component: ortho, name: "fov", value: 160)

                orthoCamera = ortho
            }
        }
        
        if orthoCamera != nil {
            globalApp!.globalCamera = orthoCamera
            
            let preStage = globalApp!.project.selected!.getStage(.PreStage)
            let result = getFirstItemOfType(preStage.getChildren(), .Camera3D)
            if let stageItem = result.0 {
                stageItem.builderInstance = nil
            }
            terrainNeedsUpdate()
        }
    }
    
    func deinstallTopDownView()
    {
        globalApp!.globalCamera = nil

        let preStage = globalApp!.project.selected!.getStage(.PreStage)
        let result = getFirstItemOfType(preStage.getChildren(), .Camera3D)
        if let stageItem = result.0 {
            stageItem.builderInstance = nil
        }
        terrainNeedsUpdate()
    }
}
