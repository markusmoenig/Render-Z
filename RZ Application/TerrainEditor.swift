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
    
    var currentLayerIndex   : Int = -1
    var currentMaterialIndex: Int = 0

    var originTexture       : MTLTexture? = nil
    var directionTexture    : MTLTexture? = nil
    var shapeIdTexture      : MTLTexture? = nil

    var addLayerButton      : MMButtonWidget!
    var deleteLayerButton   : MMButtonWidget!
    
    var addShapeButton      : MMButtonWidget!
    var deleteShapeButton   : MMButtonWidget!
    
    var addMaterialButton   : MMButtonWidget!
    var changeMaterialButton: MMButtonWidget!
    var deleteMaterialButton: MMButtonWidget!
    
    var currentShape        : CodeComponent? = nil
        
    let height              : Float = 200
    var propMap             : [String:CodeFragment] = [:]
    
    let fragment            : MMFragment
    var drawHighlightShape  : MTLRenderPipelineState?
    var shapeInstance       : CodeBuilderInstance!
    var shapeMoveStart      : SIMD2<Float> = SIMD2<Float>()
    
    var shapeLayoutChanged  : Bool = false
    
    var editTab             : MMTabButtonWidget
    
    var terrainUndo         : SceneGraphItemUndo? = nil
    
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
        
        editTab.addTab("Edit")
        editTab.addTab("Materials")
        
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
        
        addLayerButton = MMButtonWidget(mmView, skinToUse: borderlessSkin, text: "Add Layer", fixedWidth: buttonWidth)
        addLayerButton.clicked = { (event) in
            let layer = TerrainLayer()
            self.terrain.layers.append(layer)
            self.addLayerButton.removeState(.Checked)
            self.currentLayerIndex = self.terrain.layers.count - 1
            self.updateUI()
        }
        addLayerButton.rect.width = 100

        deleteLayerButton = MMButtonWidget(mmView, skinToUse: borderlessSkin, text: "Remove", fixedWidth: buttonWidth)
        deleteLayerButton.clicked = { (event) in
            
            self.terrain.layers.remove(at: self.currentLayerIndex)
            
            self.currentLayerIndex = self.currentLayerIndex - 1
            self.updateUI()
            
            self.terrainNeedsUpdate()
        
            self.deleteLayerButton.removeState(.Checked)
        }
        deleteLayerButton.rect.width = 80

        
        addShapeButton = MMButtonWidget(mmView, skinToUse: borderlessSkin, text: "Add Shape", fixedWidth: buttonWidth)
        addShapeButton.clicked = { (event) in
            globalApp!.libraryDialog.show(ids: ["SDF2D"], style: .Icon, cb: { (json) in
                if let comp = decodeComponentFromJSON(json) {
                    
                    let layer = self.terrain.layers[self.currentLayerIndex]
                    layer.shapes.append(comp)
                    
                    self.terrainNeedsUpdate()
                    self.addShapeButton.removeState(.Checked)
                    self.currentShape = comp
                    self.actionState = .MoveShape
                    
                    self.shapeMoveStart.x = 0
                    self.shapeMoveStart.y = 0

                    self.updateUI()
                }
            } )
        }
        addShapeButton.rect.width = 100

        deleteShapeButton = MMButtonWidget(mmView, skinToUse: borderlessSkin, text: "Delete", fixedWidth: buttonWidth)
        deleteShapeButton.clicked = { (event) in
            if let shape = self.currentShape {
                if self.currentLayerIndex >= 0 {
                    let layer = self.terrain.layers[self.currentLayerIndex]
                    
                    if let index = layer.shapes.firstIndex(of: shape) {
                        layer.shapes.remove(at: index)
                        
                        if layer.shapes.count > 0 {
                            self.currentShape = layer.shapes[0]
                        } else {
                            self.currentShape = nil
                        }
                        self.updateUI()
                        self.terrainNeedsUpdate(true)
                    }
                }
            }
            self.deleteShapeButton.removeState(.Checked)
        }
        deleteShapeButton.rect.width = 80
        
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
        shapeIdTexture = nil
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
        
        actionState = .None
        
        if isUIActive() == false {
            if currentLayerIndex == -1 {
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
            } else {
                // Noise Layer, see if we select a shape
                if currentLayerIndex >= 0 {
                    let layer = terrain.layers[currentLayerIndex]
                    
                    if layer.shapes.count > 0 {
                        let id = getShapeIdAt(event)
                        
                        if id >= 0.0 {
                            currentShape = layer.shapes[Int(id)]
                            actionState = .MoveShape
                            if let loc = getHitLocationAt(event), currentShape != nil {
                                shapeMoveStart.x = loc.x / terrain.terrainScale - currentShape!.values["_posX"]!
                                shapeMoveStart.y = loc.y / terrain.terrainScale + currentShape!.values["_posY"]!
                            } else {
                                shapeMoveStart = SIMD2<Float>(0, 0)
                            }
                            updateUI()
                        }
                    }
                }
            }
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
        } else
        if actionState == .MoveShape {
            if let loc = getHitLocationAt(event) {
                if let shape = currentShape {
                    shape.values["_posX"] = -(shapeMoveStart.x - loc.x / terrain.terrainScale)
                    shape.values["_posY"] = shapeMoveStart.y - loc.y / terrain.terrainScale
                }
            }
            mmView.update()
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
        
        if currentLayerIndex >= terrain.layers.count {
            currentLayerIndex = -1
        }
        
        if currentMaterialIndex >= terrain.materials.count {
            currentMaterialIndex = 0
        }
        
        if editTab.index == 0 {
            
            addButton(addLayerButton)
            addButton(deleteLayerButton)
            
            deleteLayerButton.isDisabled = currentLayerIndex == -1

            if currentLayerIndex >= 0 {
                addButton(addShapeButton)
                addButton(deleteShapeButton)
                deleteShapeButton.isDisabled = currentShape == nil
            }

            var layerItems = ["Paint Layer"]
            for (index, _) in terrain.layers.enumerated() {
                layerItems.append("Layer #" + String(index + 1))
            }
            
            let layerIndex : Float = currentLayerIndex == -1 ? 0.0 : Float(currentLayerIndex + 1)
            
            let layerSelector = NodeUISelector(c1Node!, variable: "layerSelector", title: "Layers", items: layerItems, index: layerIndex)
            layerSelector.titleShadows = true
            layerSelector.additionalSpacing = 10
            c1Node!.uiItems.append(layerSelector)

            if currentLayerIndex >= 0 {
                let layer = terrain.layers[currentLayerIndex]
                let noiseModeVar = NodeUISelector(c1Node!, variable: "noiseMode", title: "Noise Mode", items: ["None", "Noise 2D", "Noise 3D", "Image"], index: Float(layer.noiseType.rawValue), shadows: false)
                noiseModeVar.titleShadows = true
                c1Node!.uiItems.append(noiseModeVar)
                
                c1Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                    
                    if variable == "layerSelector" {
                        self.currentLayerIndex = Int(newValue - 1)
                        self.updateUI()
                        return
                    }
                    
                    if variable == "noiseMode" {
                        layer.noiseType = TerrainLayer.LayerNoiseType(rawValue: Int(newValue))!
                        self.terrainNeedsUpdate()
                        self.updateUI()
                    } else
                    if variable == "blendMode" {
                        layer.blendType = TerrainLayer.LayerBlendType(rawValue: Int(newValue))!
                        self.terrainNeedsUpdate()
                        self.updateUI()
                    }
                    
                    if variable.starts(with: "noise") || variable.starts(with: "image") {
                        if layer.noiseType == .Image {
                            let fragment = layer.imageFragment
                            fragment.values[variable] = oldValue
                            let codeUndo : CodeUndoComponent? = continous == false ? globalApp!.currentEditor.undoComponentStart("Image Changed") : nil
                            fragment.values[variable] = newValue
                            if variable == "image" {
                                self.terrainNeedsUpdate()
                            }
                            if let undo = codeUndo { globalApp!.currentEditor.undoComponentEnd(undo) }
                        } else
                        if layer.noiseType == .TwoD {
                            let fragment = layer.noise2DFragment
                            fragment.values[variable] = oldValue
                            let codeUndo : CodeUndoComponent? = continous == false ? globalApp!.currentEditor.undoComponentStart("Noise Changed") : nil
                            fragment.values[variable] = newValue
                            if variable == "noise2D" || variable == "noiseMix2D" {
                                self.terrainNeedsUpdate()
                            }
                            if let undo = codeUndo { globalApp!.currentEditor.undoComponentEnd(undo) }
                        } else
                        if layer.noiseType == .ThreeD {
                            let fragment = layer.noise3DFragment

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
                
                if layer.noiseType == .TwoD {
                    // To initiate the fragment in case its a virgin
                    let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, globalApp!.developerEditor.codeEditor.codeContext.fontScale)
                    let component = CodeComponent(.Dummy)
                    ctx.cComponent = component
                    component.globalCode = ""
                    let _ = generateNoise2DFunction(ctx, layer.noise2DFragment)
                    let noiseUI = setupNoise2DUI(c1Node!, layer.noise2DFragment)
                    noiseUI.titleShadows = true
                    c1Node!.uiItems.append(noiseUI)
                } else
                if layer.noiseType == .ThreeD {
                    // To initiate the fragment in case its a virgin
                    let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, globalApp!.developerEditor.codeEditor.codeContext.fontScale)
                    let component = CodeComponent(.Dummy)
                    ctx.cComponent = component
                    component.globalCode = ""
                    let _ = generateNoise3DFunction(ctx, layer.noise3DFragment)
                    let noiseUI = setupNoise3DUI(c1Node!, layer.noise3DFragment)
                    noiseUI.titleShadows = true
                    c1Node!.uiItems.append(noiseUI)
                } else
                if layer.noiseType == .Image {
                    // To initiate the fragment in case its a virgin
                    let ctx = CodeContext(globalApp!.mmView, nil, globalApp!.mmView.openSans, globalApp!.developerEditor.codeEditor.codeContext.fontScale)
                    let component = CodeComponent(.Dummy)
                    ctx.cComponent = component
                    component.globalCode = ""
                    let _ = generateImageFunction(ctx, layer.imageFragment)
                    let imageUI = setupImageUI(c1Node!, layer.imageFragment)
                    imageUI.titleShadows = true
                    c1Node!.uiItems.append(imageUI)
                }
                
                if layer.noiseType != .None {
                    let blendModeVar = NodeUISelector(c1Node!, variable: "blendMode", title: "Blend Mode", items: ["Add", "Subtract", "Max"], index: Float(layer.blendType.rawValue), shadows: false)
                    c1Node!.uiItems.append(blendModeVar)
                }
            } else {
                let terrainScaleVar = NodeUINumber(c1Node!, variable: "terrainScale", title: "Terrain Scale", range: SIMD2<Float>(0.5, 1), value: 1.0 - terrain.terrainScale, precision: Int(3))
                terrainScaleVar.titleShadows = true
                c1Node?.uiItems.append(terrainScaleVar)
                let terrainHeightScaleVar = NodeUINumber(c1Node!, variable: "terrainHeightScale", title: "Height Scale", range: SIMD2<Float>(0.1, 2), value: terrain.terrainHeightScale, precision: Int(3))
                terrainHeightScaleVar.titleShadows = true
                c1Node?.uiItems.append(terrainHeightScaleVar)
                c1Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                    
                    if variable == "layerSelector" {
                        self.currentLayerIndex = Int(newValue - 1)
                        self.updateUI()
                        return
                    }
                    
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
            
            // Right Side c2Node
            if currentLayerIndex >= 0 {
                let layer = terrain.layers[currentLayerIndex]
                
                if let shape = currentShape {
                    if layer.shapes.firstIndex(of: shape) == nil {
                        currentShape = nil
                    }
                }

                if let shape = currentShape {
                    
                    //let shapeBlendVar = NodeUISelector(c2Node!, variable: "shapesBlendMode", title: "Custome Height", items: ["Distance * Height", "Height"], index: Float(layer.shapesBlendType.rawValue), shadows: true)
                    //c2Node!.uiItems.append(shapeBlendVar)
                    
                    let factorVar = NodeUINumber(c2Node!, variable: "factor", title: "Height", range: SIMD2<Float>(-5, 5), value: layer.shapeFactor, precision: Int(3))
                    factorVar.titleShadows = true
                    factorVar.additionalSpacing = 20
                    c2Node?.uiItems.append(factorVar)
                
                    for (index,uuid) in shape.properties.enumerated() {
                        let rc = shape.getPropertyOfUUID(uuid)
                        if let frag = rc.0 {
                            propMap[frag.name] = rc.1!
                            let components = frag.evaluateComponents()
                            let data = extractValueFromFragment(rc.1!)
                                            
                            if components == 1 {
                                let numberVar = NodeUINumber(c2Node!, variable: frag.name, title: (index == 0 ?"Current Shape: " : "") + shape.artistPropertyNames[uuid]!, range: SIMD2<Float>(rc.1!.values["min"]!, rc.1!.values["max"]!), int: frag.typeName == "int", value: data.x, precision: Int(rc.1!.values["precision"]!))
                                numberVar.titleShadows = true
                                numberVar.autoAdjustMargin = true
                                c2Node!.uiItems.append(numberVar)
                            }
                        }
                    }
                }
                
                if currentShape != nil || layer.blendType == .Max {
                    
                    if let last = c2Node?.uiItems.last {
                        if last.additionalSpacing == 0 {
                            last.additionalSpacing = 20
                        }
                    }
                    
                    var materialItems = ["None"]
                    var materialIndex : Float = 0
                    
                    if let material = layer.material {
                        materialItems.append(material.name)
                        materialIndex = 1
                    } else {
                        materialItems.append("Material")
                    }
                    
                    let materialVar = NodeUISelector(c2Node!, variable: "material", title: "Material", items: materialItems, index: materialIndex, shadows: true)
                    c2Node!.uiItems.append(materialVar)
                }
                
                c2Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
                    
                    if variable == "material" {
                        if newValue == 0 {
                            layer.material = nil
                            
                            self.updateUI()
                            globalApp!.project.selected!.invalidateCompilerInfos()
                            self.terrainNeedsUpdate(true)
                        } else {
                            
                            DispatchQueue.main.async {
                                self.getMaterialFromLibrary({ (stageItem) -> () in
                                    layer.material = stageItem
                                    
                                    self.updateUI()
                                    globalApp!.project.selected!.invalidateCompilerInfos()
                                    self.terrainNeedsUpdate(true)
                                })
                            }
                        }
                        
                        return
                    }
                    
                    if variable == "shapesBlendMode" {
                        layer.shapesBlendType = TerrainLayer.ShapesBlendType(rawValue: Int(newValue))!
                        self.terrainNeedsUpdate(true)
                        return
                    }
                    
                    if variable == "factor" {
                        layer.shapeFactor = newValue
                        self.terrainNeedsUpdate(true)
                        return
                    }
                    
                    if let frag = self.propMap[variable] {
                        frag.values["value"] = oldValue
                        //let codeUndo : CodeUndoComponent? = continous == false ? self.editor.designEditor.undoStart("Value Changed") : nil
                        frag.values["value"] = newValue
                        self.terrainNeedsUpdate(false)
                        //self.addKey([variable:newValue])
                        //if let undo = codeUndo { self.editor.designEditor.undoEnd(undo) }
                    }
                }
            }
        } else {
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
        
        if currentLayerIndex >= 0 {
            let layer = terrain.layers[currentLayerIndex]
            if layer.shapes.isEmpty == false {
                generateShapeHighlightingState()
                drawShapeHighlight()
            }
        }
        
        editTab.rect.x = (rect.width - editTab.rect.width) / 2
        editTab.rect.y = rect.y + 15
        editTab.draw()
        
        if editTab.index == 0 {
            // Editing
            
            addLayerButton.rect.x = rect.x + 3
            addLayerButton.rect.y = rect.y + 40
            
            deleteLayerButton.rect.x = addLayerButton.rect.right() + 5
            deleteLayerButton.rect.y = addLayerButton.rect.y
            
            if currentLayerIndex >= 0 {
                addShapeButton.rect.x = rect.right() - 200
                addShapeButton.rect.y = addLayerButton.rect.y
                
                deleteShapeButton.rect.x = addShapeButton.rect.right() + 5
                deleteShapeButton.rect.y = addLayerButton.rect.y
            }
            
            c1Node?.rect.x = 10
            c1Node?.rect.y = addLayerButton.rect.bottom() + 10 - rect.y
            
            c2Node?.rect.x = rect.right() - 200 - rect.x
            c2Node?.rect.y = c1Node!.rect.y
        } else {
            // Materials
            
            addMaterialButton.rect.x = rect.x + 3
            addMaterialButton.rect.y = rect.y + 40
            
            changeMaterialButton.rect.x = addMaterialButton.rect.right() + 5
            changeMaterialButton.rect.y = addMaterialButton.rect.y
            
            deleteMaterialButton.rect.x = changeMaterialButton.rect.right() + 5
            deleteMaterialButton.rect.y = addMaterialButton.rect.y
            
            c1Node?.rect.x = 10
            c1Node?.rect.y = addLayerButton.rect.bottom() + 10 - rect.y
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
    
    /// Returns the
    func getShapeIdAt(_ event: MMMouseEvent) -> Float
    {
        let x : Float = event.x - rect.x
        let y : Float = event.y - rect.y
        
        let rc : Float = -1
         
        // Selection
        if let texture = shapeIdTexture {
             
            if let convertTo = globalApp!.currentPipeline!.codeBuilder.compute.allocateTexture(width: Float(texture.width), height: Float(texture.height), output: true, pixelFormat: .r32Float) {
             
                globalApp!.currentPipeline!.codeBuilder.renderCopy(convertTo, texture, syncronize: true)
                globalApp!.currentPipeline!.codeBuilder.waitUntilCompleted()

                let region = MTLRegionMake2D(min(Int(x), convertTo.width-1), min(Int(y), convertTo.height-1), 1, 1)

                var texArray = Array<Float>(repeating: Float(0), count: 1)
                texArray.withUnsafeMutableBytes { texArrayPtr in
                    if let ptr = texArrayPtr.baseAddress {
                        convertTo.getBytes(ptr, bytesPerRow: (MemoryLayout<Float>.size * convertTo.width), from: region, mipmapLevel: 0)
                    }
                }
                let value = texArray[0]
                return value
            }
        }
        return rc
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
            shapeIdTexture = pipeline.checkTextureSize(rect.width, rect.height, nil, .r16Float)

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
    
    func generateShapeHighlightingState()
    {
        var headerCode =
        """

        #define PI 3.1415926535897932384626422832795028841971

        float2 __translate(float2 p, float2 t)
        {
            return p - t;
        }

        float degrees(float radians)
        {
            return radians * 180.0 / PI;
        }

        float radians(float degrees)
        {
            return degrees * PI / 180.0;
        }

        float2 rotate(float2 pos, float angle)
        {
            float ca = cos(angle), sa = sin(angle);
            return pos * float2x2(ca, sa, -sa, ca);
        }

        float2 rotatePivot(float2 pos, float angle, float2 pivot)
        {
            float ca = cos(angle), sa = sin(angle);
            return pivot + (pos-pivot) * float2x2(ca, sa, -sa, ca);
        }

        """
        
        var code =
        """

        typedef struct
        {
            float currentId;
        } HIGHLIGHT_TERRAINSHAPE;

        fragment float4 highlightTerrainShape(RasterizerData in [[stage_in]],
                                        texture2d<half, access::read>  depthTexture [[texture(0)]],
                                        texture2d<half, access::read>  cameraOriginTexture [[texture(1)]],
                                        texture2d<half, access::read>  cameraDirectionTexture [[texture(2)]],
                                        texture2d<half, access::write> shapeIdTexture [[texture(3)]],
                                        constant HIGHLIGHT_TERRAINSHAPE *terrainData [[ buffer(4) ]],
                                        constant float4 *__data [[ buffer(5) ]])
        {
            float4 color = float4(0);
            float2 gid_ = float2(in.textureCoordinate.x, 1.0 - in.textureCoordinate.y) * float2(depthTexture.get_width(), depthTexture.get_height());
            uint2 gid = uint2(gid_);

            float outDistance = 1000000.0;

            float4 shape = float4(depthTexture.read(gid));

            float id = shape.w;
            float outShapeId = -1;

            float3 origin = float4(cameraOriginTexture.read(gid)).xyz;
            float3 dir = float4(cameraDirectionTexture.read(gid)).xyz;
            float3 position = origin + dir * shape.y;


            //if (id == data->id) color = float4(0.816, 0.345, 0.188, 0.8);
            //else color = float4(0);

            if (id == 0) {
                //color = float4(0.816, 0.345, 0.188, 0.8);

        """
        
        shapeInstance = CodeBuilderInstance()
        shapeInstance.data.append(SIMD4<Float>(0,0,0,0))

        if currentLayerIndex >= 0 {
            let layer = terrain.layers[currentLayerIndex]
            
            code +=
            """
            
                {
                    outDistance = 1000000.0;
                    float oldDistance = outDistance;
                    float3 position3 = position;
                    float2 position;


            """
            
            // Add the shapes
            var posX : Int = 0
            var posY : Int = 0
            var rotate : Int = 0
            
            for (index, shapeComponent) in layer.shapes.enumerated() {
                dryRunComponent(shapeComponent, shapeInstance.data.count)
                shapeInstance.collectProperties(shapeComponent)
                
                if let globalCode = shapeComponent.globalCode {
                    headerCode += globalCode
                }
                
                posX = shapeInstance.getTransformPropertyIndex(shapeComponent, "_posX")
                posY = shapeInstance.getTransformPropertyIndex(shapeComponent, "_posY")
                rotate = shapeInstance.getTransformPropertyIndex(shapeComponent, "_rotate")
                    
                code +=
                """
                        
                        position = __translate(position3.xz, float2(__data[\(posX)].x, -__data[\(posY)].x));
                        position = rotate( position, radians(360 - __data[\(rotate)].x) );

                """
                
                code += shapeComponent.code!
                code +=
                """

                    if (outDistance < oldDistance && outDistance < 0.0 ) {
                        outShapeId = \(index);
                    }
                
                    outDistance = min( outDistance, oldDistance );
                    oldDistance = outDistance;
                
                """

            }
            
            code +=
            """

                }

                if (outDistance <= 0.) {
                    if (terrainData->currentId == outShapeId)
                        color = float4(0.816, 0.345, 0.188, 0.8);
                    else
                        color = float4(0.816, 0.345, 0.188, 0.4);
                }
            
            """
        }
        
        code +=
        """

            }
        
            shapeIdTexture.write(half4(outShapeId), gid);
            
            return color;
        }

        """
        
        code = headerCode + code;
        
        let library = fragment.createLibraryFromSource(source: code)
        drawHighlightShape = fragment.createState(library: library, name: "highlightTerrainShape")
    }
    
    func drawShapeHighlight()
    {
        var currentId : Float = 0
        
        if currentLayerIndex >= 0 && currentShape != nil {
            let layer = terrain.layers[currentLayerIndex]
            if let index = layer.shapes.firstIndex(of: currentShape!) {
                currentId = Float(index)
            }
        }
        
        let settings: [Float] = [Float(currentId)];
        
        let renderEncoder = mmView.renderer.renderEncoder!
        
        let vertexBuffer = mmView.renderer.createVertexBuffer( MMRect( rect.x, rect.y, rect.width, rect.height, scale: mmView.scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmView.renderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentTexture(globalApp!.currentPipeline?.getTextureOfId("id"), index: 0)
        renderEncoder.setFragmentTexture(originTexture!, index: 1)
        renderEncoder.setFragmentTexture(directionTexture!, index: 2)
        renderEncoder.setFragmentTexture(shapeIdTexture!, index: 3)
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 4)

        globalApp!.currentPipeline?.codeBuilder.updateData(shapeInstance)
        renderEncoder.setFragmentBuffer(shapeInstance.buffer, offset: 0, index: 5)

        renderEncoder.setRenderPipelineState( drawHighlightShape! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
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
                if let comp = decodeComponentFromJSON(jsonComponent) {

                    let stageItem = StageItem(.ShapeStage, comp.libraryName)

                    stageItem.components[stageItem.defaultName] = comp

                    fillInDefaults(stageItem)
                    callback(stageItem)
                }
            } else {
                if let newStageItem = decodeStageItemFromJSON(jsonStageItem) {
                                        
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
}
