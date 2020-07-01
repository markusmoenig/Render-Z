//
//  GroundEditor.swift
//  Render-Z
//
//  Created by Markus Moenig on 12/4/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class GroundItem {
        
    enum GroundItemType {
        case StageItem, CameraOrigin, CameraLookAt
    }

    var itemType                : GroundItemType
    let stageItem               : StageItem?
    let rect                    : MMRect = MMRect()
    
    var label                   : MMTextLabel?

    init(_ type: GroundItemType,_ stageItem: StageItem? = nil)
    {
        itemType = type
        self.stageItem = stageItem
    }
    
    func getComponent() -> CodeComponent?
    {
        if let item = stageItem {
            if let component = item.components[item.defaultName] {
                return component
            }
        }
        return nil
    }
}

class GroundEditor              : PropertiesWidget
{
    enum State {
        case Idle, DraggingItem, DraggingGrid, Gizmo
    }
    
    var state                   : State = .Idle
    
    var groundShaders           : GroundShaders
    var gizmo                   : GizmoCombo2D
    
    var offset                  = SIMD2<Float>(-5,0)
    var graphZoom               : Float = 1
    
    var mouseDownPos            = SIMD2<Float>(0,0)
    var mouseDownOffset         = SIMD2<Float>(0,0)

    var drawPatternState        : MTLRenderPipelineState?

    var itemMap                 : [UUID:GroundItem] = [:]
    var cameraOriginItem        : GroundItem? = nil
    var cameraLookAtItem        : GroundItem? = nil

    let normalInteriorColor     = SIMD4<Float>(0.231, 0.231, 0.231, 1.000)
    let normalBorderColor       = SIMD4<Float>(0.5,0.5,0.5,1)
    let normalTextColor         = SIMD4<Float>(0.8,0.8,0.8,1)
    let selectedBorderColor     = SIMD4<Float>(0.816, 0.396, 0.204, 1.000)
    
    var selectedItem            : GroundItem? = nil
    
    let gridSize                : Float = 80
    
    var initialValues           : [String:Float] = [:]
    var initialProperty         = SIMD3<Float>(0,0,0)
    
    var groundItem              : StageItem!
    
    var currentRegion           : StageItem? = nil
    var currentComponent        : CodeComponent? = nil
    
    var undoComponent           : CodeUndoComponent? = nil
    var undoStageItem           : SceneGraphItemUndo? = nil

    var addRegionButton         : MMButtonWidget!
    var deleteRegionButton      : MMButtonWidget!
    
    var addShapeButton          : MMButtonWidget!
    var deleteShapeButton       : MMButtonWidget!
    
    var mouseIsDown             : Bool = false

    override init(_ view : MMView)
    {
        let function = view.renderer.defaultLibrary.makeFunction( name: "nodeGridPattern" )
        drawPatternState = view.renderer.createNewPipelineState( function! )
        
        groundShaders = GroundShaders(view)
        gizmo = GizmoCombo2D(view)
        
        super.init(view)
        
        // Custom gizmo cb
        gizmo.customUpdateCB = { () in
            self.groundShaders.updateRegionPreview()
            globalApp!.currentEditor.updateOnNextDraw(compile: false)
            self.mmView.update()
        }
        
        // Custom camera
        gizmo.customCameraCB = { (name)->(Float) in
            var rc : Float = 0
            
            if name == "scale" {
                rc = 1/self.graphZoom
            } else
            if name == "cameraX" {
                rc = -self.offset.x * self.gridSize * self.graphZoom
            } else
            if name == "cameraY" {
                rc = self.offset.y * self.gridSize * self.graphZoom
            }
            
            return rc
        }
        
        groundShaders.groundEditor = self
        addRegionButton = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Add Region", fixedWidth: buttonWidth)
        addRegionButton.clicked = { (event) in
            globalApp!.libraryDialog.show(ids: ["SDF2D"], style: .Icon, cb: { (json) in
                if let comp = decodeComponentFromJSON(json) {
                    
                    let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
                    
                    let undo = globalApp!.currentEditor.undoStageItemStart(self.groundItem, "Add Region")

                    let newRegion = shapeStage.createChild("Region #" + String(self.getRegions().count+1), parent: self.groundItem)
                    
                    //let regionComponent = CodeComponent(.RegionProfile3D, "Region")
                    //regionComponent.createDefaultFunction(.RegionProfile3D)
                    
                    newRegion.components[newRegion.defaultName] = globalApp!.libraryDialog.getItem(ofId: "RegionProfile3D", withName: "Default")
                    
                    newRegion.componentLists["shapes2D"] = [comp]
                    self.setCurrentRegion(newRegion, comp)
                    
                    placeChild(modeId: "3D", parent: self.groundItem, child: newRegion, stepSize: 50, radius: 120)
                    
                    globalApp!.developerEditor.codeEditor.markStageItemInvalid(self.groundItem)
                    
                    self.groundShaders.buildRegionPreview()
                    
                    globalApp!.currentEditor.undoStageItemEnd(self.groundItem, undo)
                    self.updateUI()
                    
                    self.addRegionButton.removeState(.Checked)
                }
            } )
        }
        
        deleteRegionButton = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Delete", fixedWidth: buttonWidth)
        deleteRegionButton.clicked = { (event) in
                                        
            let undo = globalApp!.currentEditor.undoStageItemStart(self.groundItem, "Delete Region")
            
            if let index = self.groundItem.children.firstIndex(of: self.currentRegion!) {
                self.groundItem.children.remove(at: index)
            }
            self.currentRegion = nil
            self.currentComponent = nil
                                
            globalApp!.developerEditor.codeEditor.markStageItemInvalid(self.groundItem)
            
            globalApp!.currentEditor.undoStageItemEnd(self.groundItem, undo)
            
            let regions = self.getRegions()
            if let region = regions.first {
                self.setCurrentRegion(region)
            }
            
            self.updateUI()
            self.groundShaders.buildRegionPreview()
            self.deleteRegionButton.removeState(.Checked)
        }
        
        addShapeButton = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Add Shape", fixedWidth: buttonWidth)
        addShapeButton.clicked = { (event) in
            globalApp!.libraryDialog.show(ids: ["SDF2D"], style: .Icon, cb: { (json) in
                if let comp = decodeComponentFromJSON(json) {
                                        
                    let undo = globalApp!.currentEditor.undoStageItemStart(self.groundItem, "Add Region Shape")
                    
                    self.currentRegion!.componentLists["shapes2D"]!.append(comp)
                    self.setCurrentRegion(self.currentRegion!, comp)
                                        
                    globalApp!.developerEditor.codeEditor.markStageItemInvalid(self.groundItem)
                    
                    self.groundShaders.buildRegionPreview()
                    
                    globalApp!.currentEditor.undoStageItemEnd(self.groundItem, undo)
                    self.updateUI()
                    
                    self.addShapeButton.removeState(.Checked)
                }
            } )
        }
        
        deleteShapeButton = MMButtonWidget(mmView, skinToUse: smallButtonSkin, text: "Delete", fixedWidth: buttonWidth)
        deleteShapeButton.clicked = { (event) in
                                        
            let undo = globalApp!.currentEditor.undoStageItemStart(self.groundItem, "Delete Region Shape")
            
            if let index = self.currentRegion!.componentLists["shapes2D"]!.firstIndex(of: self.currentComponent!) {
                self.currentRegion!.componentLists["shapes2D"]!.remove(at: index)
            }
            self.currentComponent = nil
                                
            globalApp!.developerEditor.codeEditor.markStageItemInvalid(self.groundItem)
            self.groundShaders.buildRegionPreview()
            
            globalApp!.currentEditor.undoStageItemEnd(self.groundItem, undo)
            self.updateUI()
            
            self.deleteShapeButton.removeState(.Checked)
        }

        buttonWidth = 120
    }
    
    func translate(_ x: Float, _ z: Float) -> SIMD2<Float>
    {
        var res = SIMD2<Float>(0,0)
        
        res.x = rect.width / 2
        res.y = rect.height / 2
        
        res.x += x * gridSize * graphZoom
        res.y += z * gridSize * graphZoom
        
        res.x += offset.x * gridSize * graphZoom
        res.y += offset.y * gridSize * graphZoom

        return res
    }
    
    func activate()
    {
        clear()
        updateUI()
    }
    
    func deactivate()
    {
        clear()
        currentComponent = nil
        currentRegion = nil
    }
    
    func setGroundItem(stageItem: StageItem)
    {
        groundItem = stageItem

        cameraOriginItem = nil
        cameraLookAtItem = nil
        itemMap = [:]
        
        self.currentRegion = nil
        self.currentComponent = nil

        for c in groundItem.children {
            if c.components[c.defaultName]!.componentType == .RegionProfile3D {
                self.setCurrentRegion(c, c.componentLists["shapes2D"]!.first!)
            }
        }
        
        activate()
        self.groundShaders.buildRegionPreview()
    }
    
    func setCurrentRegion(_ region: StageItem,_ component: CodeComponent? = nil)
    {
        currentRegion = region
        currentComponent = component
        if let component = component {
            gizmo.setComponent(component)
        }        
    }
    
    func updateUI()
    {
        clear()
        
        addButton(addRegionButton)
        addButton(deleteRegionButton)

        addButton(addShapeButton)
        addButton(deleteShapeButton)

        c1Node = Node()
        c1Node?.rect.x = 10
        c1Node?.rect.y = 10
        
        var regions : [String] = []
        var regionIndex : Float = 0
        var cIndex : Float = 0
        var isDisabled = true
        
        for c in groundItem.children {
            if c.components[c.defaultName]!.componentType == .RegionProfile3D {
                regions.append(c.name)
                if c === currentRegion {
                    regionIndex = cIndex
                }
                cIndex += 1
                isDisabled = false
            }
        }
                
        if regions.count == 0 {
            regions.append("None")
        }
        
        let regionSelector = NodeUISelector(c1Node!, variable: "regionSelector", title: "Current Region", items:regions, index: regionIndex, shadows: true)
        regionSelector.isDisabled = isDisabled
        c1Node?.uiItems.append(regionSelector)
        
        c1Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
            if variable == "regionSelector" {
                let regions = self.getRegions()
                let region = regions[Int(newValue)]
                self.setCurrentRegion(region)
                self.groundShaders.buildRegionPreview()
                self.mmView.update()
            }
        }
        
        c1Node?.setupUI(mmView: mmView)
        
        // c2Node, Plane Height Editor
        
        /*
        c2Node = Node()
        
        let planeHeightVar = NodeUINumber(c2Node!, variable: "planeHeight", title: "Plane Offset", range: SIMD2<Float>(-20, 20), value: 0, precision: 2)
        planeHeightVar.titleShadows = true
        c2Node?.uiItems.append(planeHeightVar)
        c2Node?.floatChangedCB = { (variable, oldValue, newValue, continous, noUndo)->() in
        }
        
        c2Node?.setupUI(mmView: mmView)
        */
    }
    
    func getRegions() -> [StageItem]
    {
        var list : [StageItem] = []
        for c in groundItem.children {
            if c.components[c.defaultName]!.componentType == .RegionProfile3D {
                list.append(c)
            }
        }
        return list
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
        
        mouseIsDown = true
        
        state = .Idle
        selectedItem = nil

        if currentComponent != nil {
            gizmo.rect.copy(rect)
            gizmo.mouseDown(event)
            
            if gizmo.hoverState != .Inactive {
                undoStageItem = globalApp!.currentEditor.undoStageItemStart(groundItem, "Region Transform")
                state = .Gizmo
                return
            }
        }

        for (_,item) in itemMap {
            if item.rect.contains(event.x - rect.x, event.y - rect.y) {
                selectedItem = item
                mmView.update()
                state = .DraggingItem
                if item.itemType == .CameraLookAt {
                    globalApp!.currentPipeline?.setMinimalPreview(true)
                    if let property = getCameraProperty("lookAt") {
                        initialProperty = property
                    }
                } else
                if item.itemType == .CameraOrigin {
                    globalApp!.currentPipeline?.setMinimalPreview(true)
                    if let property = getCameraProperty("origin") {
                        initialProperty = property
                    }
                }
                break
            }
        }
        
        if state == .Idle && currentRegion != nil {
            groundShaders.selectComponentAt(event: event)
        }
        
        if state == .Idle {
            super.mouseDown(event)
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if currentComponent != nil {
            gizmo.rect.copy(rect)
            gizmo.mouseMoved(event)
            
            if gizmo.hoverState != .Inactive {
                return
            }
        }
        
        if mouseIsDown && state == .Idle {
            if distance(mouseDownPos, SIMD2<Float>(event.x, event.y)) > 2 {
                state = .DraggingGrid
                mouseDownOffset.x = offset.x
                mouseDownOffset.y = offset.y
            }
        }
                
        if state == .DraggingGrid {
            offset.x = mouseDownOffset.x - (mouseDownPos.x - event.x) / gridSize / graphZoom
            offset.y = mouseDownOffset.y - (mouseDownPos.y - event.y) / gridSize / graphZoom
            groundShaders.updateRegionPreview()
            mmView.update()
        }

        if state == .DraggingItem {
            if selectedItem!.itemType == .CameraOrigin {
                
                let x : Float = initialProperty.x - (mouseDownPos.x - event.x) / gridSize / graphZoom
                let z : Float = initialProperty.z - (mouseDownPos.y - event.y) / gridSize / graphZoom
                let properties : [String:Float] = [
                    "origin_x" : x,
                    "origin_z" : z,
                ]
                if let component = selectedItem?.getComponent() {
                    if undoComponent == nil {
                        undoComponent = globalApp!.currentEditor.undoComponentStart(component, "Camera Change")
                    }
                    if processProperties(component, properties) == false {
                        insertValueToCameraProperty("origin", SIMD3<Float>(x, initialProperty.y, z))
                    }
                }
            } else
            if selectedItem!.itemType == .CameraLookAt {
                
                let x : Float = initialProperty.x - (mouseDownPos.x - event.x) / gridSize / graphZoom
                let z : Float = initialProperty.z - (mouseDownPos.y - event.y) / gridSize / graphZoom
                let properties : [String:Float] = [
                    "lookAt_x" : x,
                    "lookAt_z" : z,
                ]
                if let component = selectedItem?.getComponent() {
                    if undoComponent == nil {
                        undoComponent = globalApp!.currentEditor.undoComponentStart(component, "Camera Change")
                    }
                    if processProperties(component, properties) == false {
                        insertValueToCameraProperty("lookAt", SIMD3<Float>(x, initialProperty.y, z))
                    }
                }
            }
        }
        
        if state == .Idle {
            super.mouseMoved(event)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if currentComponent != nil {
            gizmo.rect.copy(rect)
            gizmo.mouseUp(event)
        }
        
        if state == .DraggingItem {
            globalApp!.currentPipeline?.setMinimalPreview(false)
        }
        
        if undoComponent != nil && undoComponent!.undoComponent != nil {
            globalApp!.currentEditor.undoComponentEnd(undoComponent!.undoComponent!, undoComponent!)
            undoComponent = nil
        }
        
        if undoStageItem != nil {
            globalApp!.currentEditor.undoStageItemEnd(groundItem!, undoStageItem!)
            undoStageItem = nil
        }
        
        if state == .Idle {
            super.mouseUp(event)
        }
        
        state = .Idle
        mouseIsDown = false
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        var prevScale = graphZoom
        
        #if os(OSX)
        if event.deltaY! != 0 {
            prevScale += event.deltaY! * 0.05
            prevScale = max(0.1, prevScale)
            prevScale = min(20, prevScale)
            
            graphZoom = prevScale
            groundShaders.updateRegionPreview()
            mmView.update()
        }
        #endif
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        let shapeStage = globalApp!.project.selected!.getStage(.ShapeStage)
        
        let itemZoom : Float = 0.7
        let fontScale : Float = 0.4 * itemZoom
        let itemHeight : Float = 30 * itemZoom
        
        func drawItem(_ item: GroundItem,_ name: String,_ pos: SIMD2<Float>)
        {
            if item.label == nil || item.label!.scale != fontScale {
                item.label = MMTextLabel(mmView, font: mmView.openSans, text: name, scale: fontScale, color: normalTextColor)
            }
            
            let width : Float = item.label!.rect.width + 20 * itemZoom
            item.rect.set(pos.x - width / 2, pos.y - itemHeight / 2, width, itemHeight)

            let selected = selectedItem === item
            mmView.drawBox.draw(x: rect.x + item.rect.x /*+ item.rect.width / 2*/, y: rect.y + item.rect.y/* + item.rect.height / 2*/, width: item.rect.width, height: item.rect.height, round: 6, borderSize: 1, fillColor: normalInteriorColor, borderColor: selected ? selectedBorderColor : normalBorderColor)
            
            item.label!.rect.x = rect.x + pos.x - width / 2 + 10 * itemZoom
            item.label!.rect.y = rect.y + pos.y - 9 * itemZoom
            item.label!.draw()
        }
        
        mmView.renderer.setClipRect(rect)
        
        // Grid
        let settings: [Float] = [
            rect.width, rect.height,
            gridSize * graphZoom, gridSize * graphZoom,
            offset.x * graphZoom * gridSize, -offset.y * graphZoom * gridSize,
            ];
        
        let renderEncoder = mmView.renderer.renderEncoder!
        
        let vertexBuffer = mmView.renderer.createVertexBuffer( MMRect( rect.x, rect.y, rect.width, rect.height, scale: mmView.scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmView.renderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState( drawPatternState! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
                
        // Objects
        for child in shapeStage.getChildren() {
            if let component = child.components[child.defaultName] {
                if component.componentType == .Ground3D {
                    continue
                }
            
                let transformed = getTransformedComponentValues(component)
                let x = transformed["_posX"]!
                let z = transformed["_posZ"]!
            
                let pos = translate(x,z)
                
                if itemMap[child.uuid] == nil {
                    itemMap[child.uuid] = GroundItem(.StageItem, child)
                }
                let item = itemMap[child.uuid]!
                
                drawItem(item, child.name, pos)
            }
        }
        
        var cameraComponent : CodeComponent? = nil
        var cameraStageItem : StageItem? = nil

        let preStage = globalApp!.project.selected!.getStage(.PreStage)
        let preStageChildren = preStage.getChildren()
        for stageItem in preStageChildren {
            if let c = stageItem.components[stageItem.defaultName] {
                if c.componentType == .Camera2D || c.componentType == .Camera3D {
                    cameraComponent = c
                    cameraStageItem = stageItem
                    break
                }
            }
        }
        
        if let camera = cameraComponent {
            // Origin
            let origin = getTransformedComponentProperty(camera, "origin")
            let originPos = translate(origin.x, origin.z)
            // LookAt
            let lookAt = getTransformedComponentProperty(camera, "lookAt")
            let lookAtPos = translate(lookAt.x, lookAt.z)
            
            if cameraOriginItem == nil {
                cameraOriginItem = GroundItem(.CameraOrigin, cameraStageItem!)
            }
            if cameraLookAtItem == nil {
                cameraLookAtItem = GroundItem(.CameraLookAt, cameraStageItem!)
            }
            
            itemMap[UUID()] = cameraOriginItem
            itemMap[UUID()] = cameraLookAtItem

            mmView.drawLine.drawDotted(sx: rect.x + cameraOriginItem!.rect.x + cameraOriginItem!.rect.width / 2, sy: rect.y + cameraOriginItem!.rect.y +  cameraOriginItem!.rect.height / 2, ex: rect.x + cameraLookAtItem!.rect.x + cameraLookAtItem!.rect.width / 2, ey: rect.y + cameraLookAtItem!.rect.y + cameraLookAtItem!.rect.height / 2, radius: 1.5, fillColor: normalBorderColor)

            drawItem(cameraOriginItem!, "Origin", originPos)
            drawItem(cameraLookAtItem!, "Look At", lookAtPos)
        }
                
        if groundShaders.lastPreviewWidth != rect.width || groundShaders.lastPreviewHeight != rect.height {
            groundShaders.updateRegionPreview()
        }
        
        // UI
        if let texture = globalApp!.currentPipeline!.finalTexture {
            let width : Float = Float(texture.width) / 3
            let height : Float = Float(texture.height) / 3
            
            // Preview
            let previewRect = MMRect(rect)
            previewRect.width -= width
            mmView.renderer.setClipRect(previewRect)
            groundShaders.drawPreview()
            mmView.renderer.setClipRect()
            
            // c1Node
            let uiStartX = rect.right() - width
            let uiStartY = rect.y + height

            mmView.drawBox.draw(x: uiStartX, y: uiStartY, width: width, height: rect.height - height, round: 0, borderSize: 0, fillColor: SIMD4<Float>(1,1,1,0.2))
            
            addRegionButton.rect.x = uiStartX + 10
            addRegionButton.rect.y = uiStartY + 10
            addRegionButton.rect.width = buttonWidth

            deleteRegionButton.rect.x = uiStartX + 10 + buttonWidth + 10
            deleteRegionButton.rect.y = uiStartY + 10
            deleteRegionButton.rect.width = buttonWidth
            deleteRegionButton.isDisabled = currentRegion == nil
            
            if let c1Node = c1Node {
                c1Node.rect.x = uiStartX + 10
                c1Node.rect.y = deleteRegionButton.rect.bottom() + 10 - rect.y
            }
            
            /*
            // c2Node
            uiStartX = rect.x + 10
            uiStartY = rect.bottom() - 20
            
            if let c2Node = c2Node {
                c2Node.rect.x = uiStartX
                c2Node.rect.y = uiStartY
            }*/
            
            // --- Shape Buttons
            addShapeButton.rect.x = uiStartX - 20 - buttonWidth * 2
            addShapeButton.rect.y = rect.bottom() - 40
            addShapeButton.rect.width = buttonWidth
            addShapeButton.isDisabled = currentRegion == nil

            deleteShapeButton.rect.x = addShapeButton.rect.right() + 10
            deleteShapeButton.rect.y = addShapeButton.rect.y
            deleteShapeButton.rect.width = buttonWidth
            deleteShapeButton.isDisabled = (currentRegion == nil || currentComponent == nil)
        }
        
        super.draw(xOffset: xOffset, yOffset: yOffset)
        
        if currentComponent != nil {
            gizmo.rect.copy(rect)
            gizmo.draw()
        }
        
        mmView.renderer.setClipRect()
    }
    
    func getCameraProperty(_ name: String) -> SIMD3<Float>?
    {
        if let camera = cameraOriginItem {
            if let cameraItem = camera.stageItem {
                if let component = cameraItem.components[cameraItem.defaultName] {
                
                    for uuid in component.properties {
                        let rc = component.getPropertyOfUUID(uuid)
                        if let frag = rc.0 {
                            if frag.name == name {
                                 return extractValueFromFragment3(rc.1!)
                            }
                        }
                    }
                }
            }
        }
        
        return nil
    }
    
    func insertValueToCameraProperty(_ name: String,_ value: SIMD3<Float>)
    {
        if let camera = cameraOriginItem {
            if let cameraItem = camera.stageItem {
                if let component = cameraItem.components[cameraItem.defaultName] {
                
                    for uuid in component.properties {
                        let rc = component.getPropertyOfUUID(uuid)
                        if let frag = rc.0 {
                            if frag.name == name {
                                insertValueToFragment3(rc.1!, value)
                            }
                        }
                    }
                }
            }
        }
    }
    
    func processProperties(_ component: CodeComponent,_ properties: [String:Float]) -> Bool
    {
        let timeline = globalApp!.artistEditor.timeline
        
        if timeline.isRecording {
            timeline.addKeyProperties(sequence: component.sequence, uuid: component.uuid, properties: properties)
            return true
        }
        globalApp!.currentEditor.updateOnNextDraw(compile: false)
        return false
    }
}
