//
//  TerrainEditor.swift
//  Shape-Z
//
//  Created by Markus Moenig on 13/5/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class TerrainEditor         : PropertiesWidget
{
    enum ActionState : Int {
        case None, PaintHeight, MoveShape
    }
    
    var actionState         : ActionState = .None

    var terrain             : Terrain!
    
    var mouseIsDown         : Bool = false
    var mouseDownPos        : SIMD2<Float> = SIMD2<Float>()
    
    var currentMaterialIndex: Int = 0

    var originTexture       : MTLTexture? = nil
    var directionTexture    : MTLTexture? = nil

    var addMaterialButton   : MMButtonWidget!
    var changeMaterialButton: MMButtonWidget!
    var deleteMaterialButton: MMButtonWidget!
    
    let height              : Float = 200
    var propMap             : [String:CodeFragment] = [:]
    
    let fragment            : MMFragment

    var editTab             : MMTabButtonWidget
    
    var terrainUndo         : SceneGraphItemUndo? = nil
    
    var brushModeVar        : NodeUISelector!
    
    override required init(_ view: MMView)
    {
        fragment = MMFragment(view)
        
        var tabSkin = MMSkinButton()
        tabSkin.margin = MMMargin( 14, 4, 14, 4 )
        tabSkin.borderSize = 0
        tabSkin.height = view.skin.Button.height - 1
        tabSkin.fontScale = 0.44
        tabSkin.round = 28
        
        editTab = MMTabButtonWidget(view, skinToUse: tabSkin)
        
        editTab.addTab("Heightmap")
        editTab.addTab("Materials")
        editTab.addTab("Noise")

        super.init(view)
        
        editTab.clicked = { (event) in
            self.updateUI()
        }
        
        var borderlessSkin = MMSkinButton()
        borderlessSkin.margin = MMMargin( 7, 4, 7, 4 )
        borderlessSkin.borderSize = 0
        borderlessSkin.height = view.skin.Button.height - 10
        borderlessSkin.fontScale = 0.36
        borderlessSkin.round = 18
         
        // Materials
        addMaterialButton = MMButtonWidget(mmView, skinToUse: borderlessSkin, text: "Add", fixedWidth: buttonWidth)
        addMaterialButton.clicked = { (event) in
            self.getMaterialFromLibrary({ (stageItem) -> () in
                self.terrain.materials.append(stageItem)
                self.currentMaterialIndex += 1
                self.updateUI()
                self.terrainNeedsUpdate(true)
            })
        }
        addMaterialButton.rect.width = 80
        
        changeMaterialButton = MMButtonWidget(mmView, skinToUse: borderlessSkin, text: "Change", fixedWidth: buttonWidth)
        changeMaterialButton.clicked = { (event) in
            self.getMaterialFromLibrary({ (stageItem) -> () in
                self.terrain.materials [self.currentMaterialIndex] = stageItem
                self.updateUI()
                self.terrainNeedsUpdate(true)
            })
        }
        changeMaterialButton.rect.width = 80
        
        deleteMaterialButton = MMButtonWidget(mmView, skinToUse: borderlessSkin, text: "Delete", fixedWidth: buttonWidth)
        deleteMaterialButton.clicked = { (event) in
        }
        deleteMaterialButton.rect.width = 80
    }
    
    func activate()
    {
        mmView.registerPriorityWidgets(widgets: self, editTab)
        computeCameraTextures()
    }
    
    func deactivate()
    {
        clear()
        mmView.deregisterWidgets(widgets: editTab, self)
        originTexture = nil
        directionTexture = nil
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
        
        actionState = .None
        
        if isUIActive() == false {
            // Paint Terrain
            if let loc = getHitLocationAt(event) {
                terrainUndoStart(name: "Terrain Paint")
                
                let val = getValue(loc)
                setValue(loc, value: Int8(val + 1))

                globalApp!.currentPipeline?.setMinimalPreview(true)
                globalApp!.currentEditor.updateOnNextDraw(compile: false)
                
                actionState = .PaintHeight
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
                
                if brushModeVar.index == 0 {
                    setValue(loc, value: Int8(val + 1))
                } else {
                    setValue(loc, value: Int8(val - 1))
                }

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
        
        if actionState == .PaintHeight {
            globalApp!.currentPipeline?.setMinimalPreview()
            terrainUndoEnd()
        } else
        if actionState == .MoveShape {
            globalApp!.currentEditor.render()
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
    
    func terrainUndoStart(name: String)
    {
        terrainUndo = SceneGraphItemUndo(name)
        if let current = terrain {
            let encodedData = try? JSONEncoder().encode(current)
            if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
                terrainUndo!.originalData = encodedObjectJsonString
            }
        }
    }
    
    func terrainUndoEnd()
    {
        if let undo = terrainUndo {
            let encodedData = try? JSONEncoder().encode(terrain)
            if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8) {
                undo.processedData = encodedObjectJsonString
            }

            func terrainChanged(_ oldState: String, _ newState: String)
            {
                globalApp!.mmView.undoManager!.registerUndo(withTarget: self) { target in
                    if let jsonData = oldState.data(using: .utf8)
                    {
                        if let terrain =  try? JSONDecoder().decode(Terrain.self, from: jsonData) {
                            let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
                            shapeStage.terrain = terrain
                            self.setTerrain(terrain)
                            self.terrainNeedsUpdate(true)
                        }
                    }
                    
                    terrainChanged(newState, oldState)
                }
                globalApp!.mmView.undoManager!.setActionName(undo.name)
            }
            terrainChanged(undo.originalData, undo.processedData)
            
        }
        terrainUndo = nil
    }
    
    func setTerrain(_ terrain: Terrain)
    {
        self.terrain = terrain
        
        updateUI()
    }
    
    func updateUI()
    {
        propMap = [:]

        clear()
        
        c1Node = Node()
        c1Node?.rect.x = 10
        c1Node?.rect.y = 10
        
        c2Node = Node()
        c2Node?.rect.x = 10
        c2Node?.rect.y = 10
        
        c3Node = Node()
        c3Node?.rect.x = 10
        c3Node?.rect.y = 10
        
        if currentMaterialIndex >= terrain.materials.count {
            currentMaterialIndex = 0
        }
        
        if editTab.index == 0 {
                
            let terrainScaleVar = NodeUINumber(c1Node!, variable: "terrainScale", title: "Terrain Scale", range: SIMD2<Float>(0.5, 1), value: 1.0 - terrain.terrainScale, precision: Int(3))
            terrainScaleVar.titleShadows = true
            c1Node?.uiItems.append(terrainScaleVar)
            
            let terrainHeightScaleVar = NodeUINumber(c1Node!, variable: "terrainHeightScale", title: "Height Scale", range: SIMD2<Float>(0.1, 2), value: terrain.terrainHeightScale, precision: Int(3))
            terrainHeightScaleVar.titleShadows = true
            c1Node?.uiItems.append(terrainHeightScaleVar)
            
            brushModeVar = NodeUISelector(c1Node!, variable: "brushMode", title: "Brush Mode", items: ["Add", "Subtract"], index: 0, shadows: true)
            c1Node!.uiItems.append(brushModeVar)
            
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
        } else
        if editTab.index == 1
        {
            // Material Mode
            
            addButton(addMaterialButton)
            addButton(changeMaterialButton)
            addButton(deleteMaterialButton)
            
            var materialItems : [String] = []
            for material in terrain.materials {
                materialItems.append(material.name)
            }
                        
            let materialSelector = NodeUISelector(c1Node!, variable: "materialSelector", title: "Materials", items: materialItems, index: Float(currentMaterialIndex))
            materialSelector.titleShadows = true
            materialSelector.additionalSpacing = 10
            c1Node!.uiItems.append(materialSelector)
            
            let currentMaterial = terrain.materials[currentMaterialIndex]
            
            let topSlopeVar = NodeUINumber(c1Node!, variable: "maxSlope", title: "Max Slope", range: SIMD2<Float>(0, 1), value: currentMaterial.values["maxSlope"]!, precision: Int(3))
            topSlopeVar.titleShadows = true
            c1Node?.uiItems.append(topSlopeVar)
            
            let minSlopeVar = NodeUINumber(c1Node!, variable: "minSlope", title: "Min Slope", range: SIMD2<Float>(0, 1), value: currentMaterial.values["minSlope"]!, precision: Int(3))
            minSlopeVar.titleShadows = true
            c1Node?.uiItems.append(minSlopeVar)
            
            c1Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                if variable == "materialSelector" {
                    self.currentMaterialIndex = Int(newValue)
                    self.updateUI()
                    self.terrainNeedsUpdate(true)
                    return
                }
                
                currentMaterial.values[variable] = newValue
                self.terrainNeedsUpdate(true)
            }
        } else
        if editTab.index == 2 {
        
            let noiseModeVar = NodeUISelector(c1Node!, variable: "noiseMode", title: "Noise Mode", items: ["None", "Noise 2D", "Noise 3D", "Image"], index: Float(terrain.noiseType.rawValue), shadows: false)
            noiseModeVar.titleShadows = true
            c1Node!.uiItems.append(noiseModeVar)
            
            if terrain.noiseType == .TwoD {
                // To initiate the fragment in case its a virgin
                let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, globalApp!.developerEditor.codeEditor.codeContext.fontScale)
                let component = CodeComponent(.Dummy)
                ctx.cComponent = component
                component.globalCode = ""
                let _ = generateNoise2DFunction(ctx, terrain.noise2DFragment)
                let noiseUI = setupNoise2DUI(c1Node!, terrain.noise2DFragment)
                noiseUI.titleShadows = true
                c1Node!.uiItems.append(noiseUI)
            } else
            if terrain.noiseType == .ThreeD {
                // To initiate the fragment in case its a virgin
                let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, globalApp!.developerEditor.codeEditor.codeContext.fontScale)
                let component = CodeComponent(.Dummy)
                ctx.cComponent = component
                component.globalCode = ""
                let _ = generateNoise3DFunction(ctx, terrain.noise3DFragment)
                let noiseUI = setupNoise3DUI(c1Node!, terrain.noise3DFragment)
                noiseUI.titleShadows = true
                c1Node!.uiItems.append(noiseUI)
            } else
            if terrain.noiseType == .Image {
                // To initiate the fragment in case its a virgin
                let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, globalApp!.developerEditor.codeEditor.codeContext.fontScale)
                let component = CodeComponent(.Dummy)
                ctx.cComponent = component
                component.globalCode = ""
                let _ = generateImageFunction(ctx, terrain.imageFragment)
                let imageUI = setupImageUI(c1Node!, terrain.imageFragment)
                imageUI.titleShadows = true
                c1Node!.uiItems.append(imageUI)
            }
            
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
                
                if variable == "noiseMode" {
                    self.terrain.noiseType = Terrain.TerrainNoiseType(rawValue: Int(newValue))!
                    self.terrainNeedsUpdate()
                    self.updateUI()
                }
                
                if variable.starts(with: "noise") || variable.starts(with: "image") {
                    if self.terrain.noiseType == .Image {
                        let fragment = self.terrain.imageFragment
                        fragment.values[variable] = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? globalApp!.currentEditor.undoComponentStart("Image Changed") : nil
                        fragment.values[variable] = newValue
                        if variable == "imageIndex" {
                            self.terrainNeedsUpdate()
                        }
                        if let undo = codeUndo { globalApp!.currentEditor.undoComponentEnd(undo) }
                    } else
                    if self.terrain.noiseType == .TwoD {
                        let fragment = self.terrain.noise2DFragment
                        fragment.values[variable] = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? globalApp!.currentEditor.undoComponentStart("Noise Changed") : nil
                        fragment.values[variable] = newValue
                        if variable == "noise2D" || variable == "noiseMix2D" {
                            self.terrainNeedsUpdate()
                        }
                        if let undo = codeUndo { globalApp!.currentEditor.undoComponentEnd(undo) }
                    } else
                    if self.terrain.noiseType == .ThreeD {
                        let fragment = self.terrain.noise3DFragment

                        fragment.values[variable] = oldValue
                        let codeUndo : CodeUndoComponent? = continous == false ? globalApp!.currentEditor.undoComponentStart("Noise Changed") : nil
                        fragment.values[variable] = newValue
                        if variable == "noise3D" || variable == "noiseMix3D" {
                            self.terrainNeedsUpdate()
                        }
                        if let undo = codeUndo { globalApp!.currentEditor.undoComponentEnd(undo) }
                    }
                }
                self.terrainNeedsUpdate(false)
            }
        }
        
        // Raymarcher in Node 3
        
        if let raymarcher = terrain.rayMarcher {
            for (index,uuid) in raymarcher.properties.enumerated() {
                let rc = raymarcher.getPropertyOfUUID(uuid)
                if let frag = rc.0 {
                    propMap[frag.name] = rc.1!
                    let components = frag.evaluateComponents()
                    let data = extractValueFromFragment(rc.1!)
                                    
                    if components == 1 {
                        let numberVar = NodeUINumber(c3Node!, variable: frag.name, title: (index == 0 ? "Raymarcher: " : "") + raymarcher.artistPropertyNames[uuid]!, range: SIMD2<Float>(rc.1!.values["min"]!, rc.1!.values["max"]!), int: frag.typeName == "int", value: data.x, precision: Int(rc.1!.values["precision"]!))
                        numberVar.titleShadows = true
                        numberVar.autoAdjustMargin = true
                        c3Node!.uiItems.append(numberVar)
                    }
                }
            }
            
            c3Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                if let frag = self.propMap[variable] {
                    frag.values["value"] = oldValue
                    //let codeUndo : CodeUndoComponent? = continous == false ? self.editor.designEditor.undoStart("Value Changed") : nil
                    frag.values["value"] = newValue
                    self.terrainNeedsUpdate(false)
                    //self.addKey([variable:newValue])
                    //if let undo = codeUndo { self.editor.designEditor.undoEnd(undo) }
                    self.terrainNeedsUpdate(false)
                }
            }
        }
                
        c1Node?.setupUI(mmView: mmView)
        c2Node?.setupUI(mmView: mmView)
        c3Node?.setupUI(mmView: mmView)
    }

    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        drawPreview(mmView: mmView, rect)
        
        if originTexture!.width != Int(rect.width) || originTexture!.height != Int(rect.height) {
            computeCameraTextures()
        }
        
        editTab.rect.x = (rect.width - editTab.rect.width) / 2
        editTab.rect.y = rect.y + 15
        editTab.draw()
        
        if editTab.index == 0 {
            // Heightmap
            
            c1Node?.rect.x = 10
            c1Node?.rect.y = rect.y + 60 + 10 - rect.y
            
            c2Node?.rect.x = rect.right() - 200 - rect.x
            c2Node?.rect.y = c1Node!.rect.y
        } else
        if editTab.index == 1
        {
            // Materials
            
            addMaterialButton.rect.x = rect.x + 3
            addMaterialButton.rect.y = rect.y + 40
            
            changeMaterialButton.rect.x = addMaterialButton.rect.right() + 5
            changeMaterialButton.rect.y = addMaterialButton.rect.y
            
            deleteMaterialButton.rect.x = changeMaterialButton.rect.right() + 5
            deleteMaterialButton.rect.y = addMaterialButton.rect.y
            
            c1Node?.rect.x = 10
            c1Node?.rect.y = rect.y + 60 + 10 - rect.y
        } else {
            // Noise
            
            c1Node?.rect.x = 10
            c1Node?.rect.y = rect.y + 60 + 10 - rect.y
        }
        
        c3Node?.rect.x = rect.right() - 200 - rect.x
        c3Node?.rect.y = rect.bottom() - 188
        
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
        if let texture = globalApp!.currentPipeline!.getTextureOfId("shape") {
             
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
                convertTo.setPurgeableState(.empty)
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
        if let pipeline = globalApp!.currentPipeline as? Pipeline3DRT {
    
            originTexture = pipeline.checkTextureSize(rect.width, rect.height, originTexture, .rgba16Float)
            directionTexture = pipeline.checkTextureSize(rect.width, rect.height, directionTexture, .rgba16Float)

            let scene = globalApp!.project.selected!
            let preStage = scene.getStage(.PreStage)
            let result = getFirstItemOfType(preStage.getChildren(), .Camera3D)
            let cameraComponent = result.1!
            
            let instance = globalApp!.codeBuilder.build(cameraComponent, camera: cameraComponent)
            
            pipeline.codeBuilder.render(instance, originTexture!, outTextures: [directionTexture!])
            pipeline.codeBuilder.waitUntilCompleted()

            originTexture = convertTexture(originTexture!)
            directionTexture = convertTexture(directionTexture!)
        }
    }
    
    /// Returns the origin and lookAt values of the camera
    func getCameraValues(_ event: MMMouseEvent) -> (SIMD3<Float>, SIMD3<Float>)
    {
        let origin = getTextureValueAt(event, texture: originTexture!)
        let lookAt = getTextureValueAt(event, texture: directionTexture!)
            
        return (SIMD3<Float>(origin.x, origin.y, origin.z), SIMD3<Float>(lookAt.x, lookAt.y, lookAt.z))
    }
    
    /// Get a material from the library
    func getMaterialFromLibrary(_ callback: @escaping (StageItem)->())
    {
        func fillInDefaults(_ stageItem: StageItem)
        {
            stageItem.values["maxSlope"] = 1
            stageItem.values["minSlope"] = 0
        }
        
        globalApp!.libraryDialog.showMaterials(cb: { (jsonComponent, jsonStageItem) in
            if jsonComponent.count > 0 {
                if let comp = decodeComponentAndProcess(jsonComponent) {
 
                    let stageItem = StageItem(.ShapeStage, comp.libraryName)

                    stageItem.components[stageItem.defaultName] = comp

                    fillInDefaults(stageItem)
                    callback(stageItem)
                }
            } else {
                if let newStageItem = decodeStageItemAndProcess(jsonStageItem) {
                                        
                    let stageItem = StageItem(.ShapeStage)

                    stageItem.components[stageItem.defaultName] = newStageItem.components[stageItem.defaultName]
                    stageItem.components[stageItem.defaultName]!.uuid = UUID()
                    
                    stageItem.componentLists["patterns"] = newStageItem.componentLists["patterns"]
                    
                    stageItem.components[stageItem.defaultName]!.libraryName = newStageItem.name

                    stageItem.libraryCategory = newStageItem.libraryCategory
                    stageItem.libraryDescription = newStageItem.libraryDescription
                    stageItem.libraryAuthor = newStageItem.libraryAuthor
                    
                    stageItem.name = newStageItem.name
                    stageItem.label = nil
                    
                    fillInDefaults(stageItem)
                    callback(stageItem)
                }
            }
        })
    }
    
    /// Get a object from the library
    func getObjectFromLibrary(_ callback: @escaping (StageItem)->())
    {
        globalApp!.libraryDialog.showObjects(cb: { (jsonStageItem) in
            if let stageItem = decodeStageItemFromJSON(jsonStageItem) {
                                    
                stageItem.uuid = UUID()
                callback(stageItem)
            }
        })
    }
}
