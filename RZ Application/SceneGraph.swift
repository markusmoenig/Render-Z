//
//  SceneGraph.swift
//  Shape-Z
//
//  Created by Markus Moenig on 1/2/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class SceneGraphSkin {
    
    //let normalInteriorColor     = SIMD4<Float>(0,0,0,0)
    let normalInteriorColor     = SIMD4<Float>(0.231, 0.231, 0.231, 1.000)
    let normalBorderColor       = SIMD4<Float>(0.5,0.5,0.5,1)
    let normalTextColor         = SIMD4<Float>(0.8,0.8,0.8,1)
    
    let tempRect                = MMRect()
    let fontScale               : Float
    let font                    : MMFont
    let lineHeight              : Float
        
    init(_ font: MMFont, fontScale: Float = 0.4) {
        self.font = font
        self.fontScale = fontScale
        self.lineHeight = font.getLineHeight(fontScale)
    }
}

class SceneGraphItem {
        
    enum SceneGraphItemType {
        case Stage, StageItem, ShapeItem, BooleanItem, EmptyShape, ShapesContainer
    }
    
    var itemType                : SceneGraphItemType
    
    let stage                   : Stage
    let stageItem               : StageItem?
    let component               : CodeComponent?
    let parentComponent         : CodeComponent?
    
    let rect                    : MMRect = MMRect()
    
    init(_ type: SceneGraphItemType, stage: Stage, stageItem: StageItem? = nil, component: CodeComponent? = nil, parentComponent: CodeComponent? = nil)
    {
        itemType = type
        self.stage = stage
        self.stageItem = stageItem
        self.component = component
        self.parentComponent = parentComponent
    }
}

class SceneGraphButton {
    
    let item                    : SceneGraphItem

    var rect                    : MMRect? = nil
    var cb                      : (() -> ())? = nil
    
    init(item: SceneGraphItem)
    {
        self.item = item
    }
}

class SceneGraph                : MMWidget
{
    enum SceneGraphState {
        case Closed, Open
    }
    
    var sceneGraphState         : SceneGraphState = .Closed
    var animating               : Bool = false
    
    var needsUpdate             : Bool = true
    
    var itemMap                 : [UUID:SceneGraphItem] = [:]
    var buttons                 : [SceneGraphButton] = []

    var graphX                  : Float = 100
    var graphY                  : Float = 200
    var graphZoom               : Float = 1

    var dispatched              : Bool = false
    
    var currentStage            : Stage? = nil
    var currentStageItem        : StageItem? = nil
    var currentComponent        : CodeComponent? = nil

    var currentUUID             : UUID? = nil
    
    var hoverButton             : SceneGraphButton? = nil
    var pressedButton           : SceneGraphButton? = nil

    var dragItem                : SceneGraphItem? = nil
    var mouseDownPos            : SIMD2<Float> = SIMD2<Float>(0,0)
    var mouseDownItemPos        : SIMD2<Float> = SIMD2<Float>(0,0)

    var currentWidth            : Float = 0
    var openWidth               : Float = 300

    var toolBarWidgets          : [MMWidget] = []

    var menuWidget              : MMMenuWidget
    
    var plusLabel               : MMTextLabel? = nil
    
    var toolBarButtonSkin       : MMSkinButton
    
    var zoomBuffer              : Float = 0
    
    var mouseIsDown             : Bool = false
    var clickWasConsumed        : Bool = false
    var isDraggingKnob          : Bool = false
    
    var knobRect                : MMRect = MMRect()

    //var map             : [MMRe]
    
    override init(_ view: MMView)
    {
        menuWidget = MMMenuWidget(view, type: .Hidden)
        
        toolBarButtonSkin = MMSkinButton()
        toolBarButtonSkin.margin = MMMargin( 4, 4, 4, 4 )
        toolBarButtonSkin.borderSize = 0
        toolBarButtonSkin.height = view.skin.Button.height - 5
        toolBarButtonSkin.fontScale = 0.44
        toolBarButtonSkin.round = 20
        
        super.init(view)
        
        zoom = view.scaleFactor

        menuWidget.setItems([
            MMMenuItem(text: "Add Object", cb: { () in
                getStringDialog(view: self.mmView, title: "New Object", message: "Object name", defaultValue: "New Object", cb: { (value) -> Void in
                    if let scene = globalApp!.project.selected {
                        
                        let shapeStage = scene.getStage(.ShapeStage)
                        let objectItem = shapeStage.createChild(value)
                        
                        objectItem.values["_graphX"]! = (self.mouseDownPos.x - self.rect.x - self.graphX) * self.graphZoom
                        objectItem.values["_graphY"]! = (self.mouseDownPos.y - self.rect.y - self.graphY) * self.graphZoom

                        globalApp!.sceneGraph.setCurrent(stage: shapeStage, stageItem: objectItem)
                    }
                } )
            })
        ])
    }
    
    func activate()
    {
        for w in toolBarWidgets {
            mmView.widgets.insert(w, at: 0)
        }
        mmView.widgets.insert(menuWidget, at: 0)
    }
    
    func deactivate()
    {
        for w in toolBarWidgets {
            mmView.deregisterWidget(w)
        }
        mmView.deregisterWidget(menuWidget)
    }
     
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        #if os(iOS)
        // If there is a selected shape, don't scroll
        graphX += event.deltaX! * 2
        graphY += event.deltaY! * 2
        #elseif os(OSX)
        if mmView.commandIsDown && event.deltaY! != 0 {
            graphZoom += event.deltaY! * 0.003
            graphZoom = max(0.2, graphZoom)
            graphZoom = min(1, graphZoom)
        } else {
            graphX -= event.deltaX! * 2
            graphY -= event.deltaY! * 2
        }
        #endif
        if !dispatched {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.mmView.unlockFramerate()
                self.dispatched = false
            }
            dispatched = true
        }
        
        if mmView.maxFramerateLocks == 0 {
            mmView.lockFramerate()
        }
    }
    
    override func pinchGesture(_ scale: Float,_ firstTouch: Bool)
    {
        if firstTouch == true {
            zoomBuffer = graphZoom
        }
         
        graphZoom = max(0.2, zoomBuffer * scale)
        graphZoom = min(1, graphZoom)
        mmView.update()
    }
    
    func setCurrent(stage: Stage, stageItem: StageItem? = nil, component: CodeComponent? = nil)
    {
        currentStage = stage
        currentStageItem = stageItem
        currentComponent = nil
        currentUUID = nil
        
        currentUUID = stage.uuid

        if let stageItem = stageItem {
            globalApp!.project.selected?.setSelected(stageItem)
            if let defaultComponent = stageItem.components[stageItem.defaultName] {
                globalApp!.currentEditor.setComponent(defaultComponent)
                //globalApp!.currentEditor.updateOnNextDraw(compile: false)
                currentComponent = defaultComponent
            } else {
                globalApp!.currentEditor.setComponent(CodeComponent())
            }
            currentUUID = stageItem.uuid
        }
        
        if let component = component {
            globalApp!.currentEditor.setComponent(component)
            globalApp!.currentEditor.updateOnNextDraw(compile: true)
            currentComponent = component
            
            currentUUID = component.uuid
        } else
        if currentComponent == nil {
            globalApp!.currentEditor.setComponent(CodeComponent())
        }
        
        needsUpdate = true
        mmView.update()
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        dragItem = nil
        mouseIsDown = true
        clickWasConsumed = false
        
        // Clicked on the knob
        if knobRect.contains(event.x, event.y) {
            isDraggingKnob = true
            mouseDownPos.x = event.x
            mouseDownPos.y = event.y
            mouseDownItemPos.x = currentWidth
            mmView.mouseTrackWidget = self
            return
        }
        
        #if os(iOS)
        for b in buttons {
            if b.rect!.contains(event.x, event.y) {
                hoverButton = b
                break
            }
        }
        #endif

        if let hoverButton = hoverButton {
            pressedButton = hoverButton
            return
        }
        
        mouseDownPos.x = event.x
        mouseDownPos.y = event.y
                
        mouseDownItemPos.x = graphX
        mouseDownItemPos.y = graphY

        if globalApp!.sceneGraph.clickAt(x: event.x, y: event.y) {
            clickWasConsumed = true
            if let uuid = currentUUID {
                dragItem = itemMap[uuid]
                
                if let drag = dragItem {

                    if let stageItem = drag.stageItem, drag.itemType == .ShapesContainer {
                        mouseDownItemPos.x = stageItem.values["_graphShapesX"]!
                        mouseDownItemPos.y = stageItem.values["_graphShapesY"]!
                    } else
                    if let stageItem = drag.stageItem {
                        mouseDownItemPos.x = stageItem.values["_graphX"]!
                        mouseDownItemPos.y = stageItem.values["_graphY"]!
                    } else {
                        mouseDownItemPos.x = drag.stage.values["_graphX"]!
                        mouseDownItemPos.y = drag.stage.values["_graphY"]!
                    }
                    
                    mmView.mouseTrackWidget = self
                }
            }
        } else {
            
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        hoverButton = nil

        if let drag = dragItem {

            if let stageItem = drag.stageItem, drag.itemType == .ShapesContainer {
                stageItem.values["_graphShapesX"]! = mouseDownItemPos.x + (event.x - mouseDownPos.x) / graphZoom
                stageItem.values["_graphShapesY"]! = mouseDownItemPos.y + (event.y - mouseDownPos.y) / graphZoom
            } else
            if let stageItem = drag.stageItem {
                stageItem.values["_graphX"]! = mouseDownItemPos.x + (event.x - mouseDownPos.x) / graphZoom
                stageItem.values["_graphY"]! = mouseDownItemPos.y + (event.y - mouseDownPos.y) / graphZoom
            } else {
                drag.stage.values["_graphX"]! = mouseDownItemPos.x + (event.x - mouseDownPos.x) / graphZoom
                drag.stage.values["_graphY"]! = mouseDownItemPos.y + (event.y - mouseDownPos.y) / graphZoom
                
                //print(drag.stage.values["_graphX"]!, drag.stage.values["_graphY"]! )
            }
            needsUpdate = true
            mmView.update()
        } else {
            
            for b in buttons {
                if b.rect!.contains(event.x, event.y) {
                    hoverButton = b
                    break
                }
            }
            
            if isDraggingKnob {
                currentWidth = min(max(mouseDownItemPos.x + (mouseDownPos.x - event.x), 300), 900)
                openWidth = currentWidth
                globalApp!.rightRegion!.rect.width = currentWidth
                mmView.update()
            } else
            if mouseIsDown && clickWasConsumed == false && pressedButton == nil {
                graphX = mouseDownItemPos.x + (event.x - mouseDownPos.x) / graphZoom
                graphY = mouseDownItemPos.y + (event.y - mouseDownPos.y) / graphZoom
                mmView.update()
            }
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if let pressedButton = pressedButton {
            pressedButton.cb!()
        } else
        if clickWasConsumed == false {
            // Check for showing menu
            
            if menuWidget.states.contains(.Opened) == false && distance(mouseDownPos, SIMD2<Float>(event.x, event.y)) < 5 {
                menuWidget.rect.x = event.x
                menuWidget.rect.y = event.y
                menuWidget.activateHidden()
            }
        }
        
        dragItem = nil
        if menuWidget.states.contains(.Opened) == false {
            mmView.mouseTrackWidget = nil
        }
        mouseIsDown = false
        pressedButton = nil
        isDraggingKnob = false
    }
    
    /// Click at the given position
    func clickAt(x: Float, y: Float) -> Bool
    {
        let realX       : Float = (x - rect.x)
        let realY       : Float = (y - rect.y)
        var contUUID    : UUID? = nil
        var consumed    : Bool = false
        
        for (uuid,item) in itemMap {
            if item.rect.contains(realX, realY) {
                
                if item.itemType == .ShapesContainer {
                    contUUID = uuid
                    continue
                }
                
                setCurrent(stage: item.stage, stageItem: item.stageItem, component: item.component)
                consumed = true
                break
            }
        }
        
        if let uuid = contUUID, consumed == false {
            currentUUID = uuid
            consumed = true
        }
        
        return consumed
    }
    
    /// Switches between open and close states
    func switchState() {
        if animating { return }
        let rightRegion = globalApp!.rightRegion!
        
        if sceneGraphState == .Open {
            globalApp!.mmView.startAnimate( startValue: rightRegion.rect.width, endValue: 0, duration: 500, cb: { (value,finished) in
                self.currentWidth = value
                if finished {
                    self.animating = false
                    self.sceneGraphState = .Closed
                    
                    self.mmView.deregisterWidget(self)
                    self.deactivate()
                    globalApp!.topRegion?.graphButton.removeState(.Checked)
                }
                globalApp!.currentEditor.updateOnNextDraw(compile: false)
            } )
            animating = true
        } else if rightRegion.rect.height != openWidth {
            
            globalApp!.mmView.startAnimate( startValue: rightRegion.rect.width, endValue: openWidth, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                    self.sceneGraphState = .Open
                    self.activate()
                    self.mmView.registerWidget(self)
                    globalApp!.topRegion?.graphButton.addState(.Checked)
                }
                self.currentWidth = value
                globalApp!.currentEditor.updateOnNextDraw(compile: false)
            } )
            animating = true
        }
    }
     
    override func update()
    {
        buildToolbar(uuid: currentUUID)
        needsUpdate = false
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        if needsUpdate {
            update()
        }

        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1))
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: 30, round: 0, fillColor : SIMD4<Float>(0.165, 0.169, 0.173, 1.000) )
        mmView.drawBox.draw( x: rect.x, y: rect.y + 30, width: rect.width, height: 1, round: 0, fillColor : SIMD4<Float>(0, 0, 0, 1) )
        
        var left: Float = 5
        for w in toolBarWidgets {
            w.rect.x = rect.x + left
            w.rect.y = rect.y + 2
            w.draw()
            //mmView.drawBox.draw( x: w.rect.x, y: w.rect.y, width: w.rect.width, height: w.rect.height, round: 0, borderSize: 1.5, fillColor: SIMD4<Float>(1,1,1,1), borderColor: SIMD4<Float>(1,1,1,1))//skin.borderColor)
            left += w.rect.width + 5
        }
        
        if let scene = globalApp!.project.selected {
            mmView.renderer.setClipRect(MMRect(rect.x, rect.y + 31, rect.width, rect.height - 31))
            parse(scene: scene)
            if menuWidget.states.contains(.Opened) {
                menuWidget.draw()
            }
            mmView.renderer.setClipRect()
        }
        
        let halfKnobWidth : Float = 6
        knobRect.x = rect.x - halfKnobWidth
        knobRect.y = rect.y + rect.height / 2 - halfKnobWidth * 2
        knobRect.width = halfKnobWidth * 3
        knobRect.height = halfKnobWidth * 4

        if isDraggingKnob == false {
            mmView.drawBox.draw( x: knobRect.x, y: knobRect.y, width: knobRect.width - halfKnobWidth, height: knobRect.height, round: 6, fillColor : SIMD4<Float>( 0, 0, 0, 1))
        } else {
            mmView.drawBox.draw( x: knobRect.x, y: knobRect.y, width: knobRect.width - halfKnobWidth, height: knobRect.height, round: 6, fillColor : SIMD4<Float>( 0.5, 0.5, 0.5, 1))

        }
    }
    
    /// Replaces the shape for the given scene graph item
    func getShape(item: SceneGraphItem, replace: Bool)
    {
        // Empty Shape
        globalApp!.libraryDialog.show(id: "SDF" + getCurrentModeId(), cb: { (json) in
            if let comp = decodeComponentFromJSON(json) {
                let undo = globalApp!.currentEditor.undoStageItemStart(replace == false ? "Add Shape" : "Replace Shape")

                comp.uuid = UUID()
                comp.selected = nil

                globalApp!.currentEditor.setComponent(comp)
                globalApp!.currentEditor.updateOnNextDraw(compile: true)
                setDefaultComponentValues(comp)
                
                if replace == false {
                    // Add it
                    comp.subComponent = nil
                    if let current = self.currentStageItem {
                        current.componentLists["shapes" + getCurrentModeId()]?.append(comp)
                    }
                } else {
                    // Replace it
                    comp.uuid = item.component!.uuid
                    globalApp!.project.selected!.updateComponent(comp)
                }
                
                if comp.subComponent == nil {
                    if let bComp = decodeComponentFromJSON(defaultBoolean) {
                        //CodeComponent(.Boolean)
                        //bComp.createDefaultFunction(.Boolean)
                        bComp.uuid = UUID()
                        bComp.selected = nil
                        comp.subComponent = bComp
                    }
                }
                
                globalApp!.currentEditor.undoStageItemEnd(undo)
                self.setCurrent(stage: item.stage, stageItem: item.stageItem, component: comp)
            }
        })
    }
    
    ///Build the menu
    func buildToolbar(uuid: UUID?)
    {
        deactivate()
        toolBarWidgets = []

        if let uuid = uuid {
            if let item = itemMap[uuid] {
                if item.itemType == .Stage && item.stage.stageType == .PreStage {
                    var borderlessSkin = MMSkinButton()
                    borderlessSkin.margin = MMMargin( 4, 4, 4, 4 )
                    borderlessSkin.borderSize = 0
                    borderlessSkin.height = mmView.skin.Button.height - 5
                    borderlessSkin.fontScale = 0.44
                    borderlessSkin.round = 24
                    
                    let tabButton = MMTabButtonWidget(mmView, skinToUse: borderlessSkin)

                    tabButton.addTab("2D")
                    tabButton.addTab("3D")
                    
                    if globalApp!.currentSceneMode == .ThreeD {
                        tabButton.currentTab = tabButton.items[1]
                    }
                    
                    tabButton.clicked = { (event) -> Void in
                        if tabButton.index == 0 {
                            globalApp!.currentSceneMode = .TwoD
                            if let scene = globalApp!.project.selected {
                                scene.setSelected(item.stage.getChildren()[0])
                            }
                            item.stage.label = nil
                        } else
                        if tabButton.index == 1 {
                            globalApp!.currentSceneMode = .ThreeD
                            if let scene = globalApp!.project.selected {
                                scene.setSelected(item.stage.getChildren()[0])
                            }
                            item.stage.label = nil
                        }
                    }
                    
                    toolBarWidgets.append(tabButton)
                } else
                if item.itemType == .ShapeItem {
                    
                    let button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Change")
                    button.clicked = { (event) in
                        self.getShape(item: item, replace: true)
                    }
                    toolBarWidgets.append(button)
                } else
                if item.itemType == .BooleanItem {
                    
                    let button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Change")
                    button.clicked = { (event) in
                        globalApp!.libraryDialog.show(id: "Boolean", cb: { (json) in
                            if let comp = decodeComponentFromJSON(json) {
                                let undo = globalApp!.currentEditor.undoStageItemStart("Change Boolean")
                                
                                comp.uuid = UUID()
                                comp.selected = nil
                                globalApp!.currentEditor.setComponent(comp)
                                globalApp!.currentEditor.updateOnNextDraw(compile: true)
                                
                                if let parent = item.parentComponent {
                                    parent.subComponent = comp
                                    globalApp!.project.selected!.updateComponent(parent)
                                }
                                                            
                                globalApp!.currentEditor.undoStageItemEnd(undo)
                                self.setCurrent(stage: item.stage, stageItem: item.stageItem, component: comp)
                            }
                        })
                    }
                    toolBarWidgets.append(button)
                }
            }
        }
        
        activate()

        /*
        var items : [MMMenuItem] = []
        if let item = itemMap[uuid] {
            
            if item.itemType == .ShapeItem {
                
                items.append(MMMenuItem(text: "Change", cb: { () in
                    self.getShape(item: item, replace: true)
                }))
                
                items.append(MMMenuItem(text: "Delete", cb: { () in
                    
                }))
            } else
            if item.itemType == .BooleanItem {
                
                items.append(MMMenuItem(text: "Change", cb: { () in
                    globalApp!.libraryDialog.show(id: "Boolean", cb: { (json) in
                        if let comp = decodeComponentFromJSON(json) {
                            let undo = globalApp!.currentEditor.undoStageItemStart("Change Boolean")
                            
                            comp.uuid = UUID()
                            comp.selected = nil
                            globalApp!.currentEditor.setComponent(comp)
                            globalApp!.currentEditor.updateOnNextDraw(compile: true)
                            
                            if let parent = item.parentComponent {
                                parent.subComponent = comp
                                globalApp!.project.selected!.updateComponent(parent)
                            }
                                                        
                            globalApp!.currentEditor.undoStageItemEnd(undo)
                            self.setCurrent(stageItem: item.stageItem, component: comp)
                        }
                    })
                }))

            }
        }
        
        menuWidget.setItems(items)
        */
    }
    
    /// Draws a line between two circles
    func drawLineBetweenCircles(_ b: SceneGraphItem,_ a: SceneGraphItem,_ skin: SceneGraphSkin)
    {
        
        mmView.drawLine.draw(sx: rect.x + b.rect.x + b.rect.width / 2, sy: rect.y + b.rect.y + b.rect.height / 2, ex: rect.x + a.rect.x + a.rect.width / 2, ey: rect.y + a.rect.y + a.rect.height / 2, radius: 1, fillColor: skin.normalBorderColor)
        /*
         
        let aMid = SIMD2<Float>(a.rect.x + a.rect.width / 2, a.rect.y + a.rect.height / 2)
        let bMid = SIMD2<Float>(b.rect.x + b.rect.width / 2, b.rect.y + b.rect.height / 2)
         
        let deltaX : Float = bMid.x - aMid.x
        let deltaY : Float = bMid.y - aMid.y
        let L : Float = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        let radiusA : Float = a.rect.width / 2 / L
        let radiusB : Float = b.rect.width / 2 / L

        mmView.drawLine.draw(sx: rect.x + bMid.x - deltaX * radiusB - 1, sy: rect.y + bMid.y - deltaY * radiusB - 1, ex: rect.x + aMid.x + deltaX * radiusA - 1, ey: rect.y + aMid.y + deltaY * radiusA - 1, radius: 1, fillColor: skin.normalBorderColor)*/
    }
    
    /// Creates a button with a "+" text and draws it
    func drawPlusButton(item: SceneGraphItem, rect: MMRect, cb: @escaping ()->(), skin: SceneGraphSkin)
    {
        let button = SceneGraphButton(item: item)
        button.rect = rect
        button.cb = cb
        
        if plusLabel == nil || plusLabel!.scale != skin.fontScale {
            plusLabel = MMTextLabel(mmView, font: mmView.openSans, text: "+", scale: skin.fontScale, color: skin.normalTextColor)
        }
        plusLabel!.drawCentered(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        
        buttons.append(button)
    }
    
    /// Parses and draws the scene graph
    func parse(scene: Scene)
    {
        itemMap = [:]
        buttons = []
        
        let skin : SceneGraphSkin = SceneGraphSkin(mmView.openSans, fontScale: 0.4 * graphZoom)
        
        // Draw World
        var stage = scene.getStage(.PreStage)
        
        if stage.label == nil || stage.label!.scale != skin.fontScale {
            stage.label = MMTextLabel(mmView, font: mmView.openSans, text: stage.name + " " + getCurrentModeId(), scale: skin.fontScale, color: skin.normalTextColor)
        }
        let diameter : Float = stage.label!.rect.width + 10 * graphZoom

        let x = (graphX + stage.values["_graphX"]!) * graphZoom - diameter / 2
        let y = (graphY + stage.values["_graphY"]!) * graphZoom - diameter / 2
        
        let worldItem = SceneGraphItem(.Stage, stage: stage)
        worldItem.rect.set(x, y, diameter, diameter)
        itemMap[stage.uuid] = worldItem
        
        let childs = stage.getChildren()
        for childItem in childs {

            if childItem.label == nil || childItem.label!.scale != skin.fontScale {
                childItem.label = MMTextLabel(mmView, font: mmView.openSans, text: childItem.name, scale: skin.fontScale, color: skin.normalTextColor)
            }
            let diameter : Float = childItem.label!.rect.width + 10 * graphZoom

            let cX = x + childItem.values["_graphX"]! * graphZoom - diameter / 2
            let cY = y + childItem.values["_graphY"]! * graphZoom - diameter / 2

            let comp = childItem.components[childItem.defaultName]!
            let item = SceneGraphItem(.StageItem, stage: stage, stageItem: childItem, component: comp)
            item.rect.set(cX, cY, diameter, diameter)
            itemMap[comp.uuid] = item
            
            drawLineBetweenCircles(worldItem, item, skin)

            mmView.drawSphere.draw(x: rect.x + cX, y: rect.y + cY, radius: diameter / 2, borderSize: 1, fillColor: childItem === currentStageItem ? skin.normalBorderColor : skin.normalInteriorColor, borderColor: skin.normalBorderColor)
            
            childItem.label!.rect.x = rect.x + cX + (diameter - childItem.label!.rect.width) / 2
            childItem.label!.rect.y = rect.y + cY + (diameter - skin.lineHeight) / 2
            childItem.label!.draw()
        }
        
        mmView.drawSphere.draw(x: rect.x + x, y: rect.y + y, radius: diameter / 2, borderSize: 1, fillColor: stage === currentStage ? skin.normalBorderColor : skin.normalInteriorColor, borderColor: skin.normalBorderColor)
        
        stage.label!.rect.x = rect.x + x + (diameter - stage.label!.rect.width) / 2
        stage.label!.rect.y = rect.y + y + (diameter - skin.lineHeight) / 2
        stage.label!.draw()

        // Draw Objects
        stage = scene.getStage(.ShapeStage)
        let objects = stage.getChildren()
        for o in objects {

            if o.label == nil || o.label!.scale != skin.fontScale {
                o.label = MMTextLabel(mmView, font: mmView.openSans, text: o.name, scale: skin.fontScale, color: skin.normalTextColor)
            }
            let diameter : Float = o.label!.rect.width + 10 * graphZoom
            
            let x = (graphX + o.values["_graphX"]!) * graphZoom - diameter / 2
            let y = (graphY + o.values["_graphY"]!) * graphZoom - diameter / 2
            
            let item = SceneGraphItem(.StageItem, stage: stage, stageItem: o)
            item.rect.set(x, y, diameter, diameter)
            itemMap[o.uuid] = item
            
            drawShapesBox(parent: item, skin: skin)

            mmView.drawSphere.draw(x: rect.x + x, y: rect.y + y, radius: diameter / zoom, borderSize: 1, fillColor: o === currentStageItem ? skin.normalBorderColor : skin.normalInteriorColor, borderColor: skin.normalBorderColor)
            
            o.label!.rect.x = rect.x + x + (diameter - o.label!.rect.width) / 2
            o.label!.rect.y = rect.y + y + (diameter - skin.lineHeight) / 2
            o.label!.draw()
        }
    }
    
    func drawShapesBox(parent: SceneGraphItem, skin: SceneGraphSkin)
    {
        let spacing     : Float = 22 * graphZoom
        let itemSize    : Float = 70 * graphZoom
        let totalWidth  : Float = 140 * graphZoom
        let headerHeight: Float = 20 * graphZoom
        var top         : Float = headerHeight + 7.5 * graphZoom
        
        let stageItem   = parent.stageItem!
        
        let x           : Float = parent.rect.x + stageItem.values["_graphShapesX"]! * graphZoom
        let y           : Float = parent.rect.y + stageItem.values["_graphShapesY"]! * graphZoom

        if let list = parent.stageItem!.getComponentList("shapes") {
            
            let amount : Float = Float(list.count)
            let height : Float = amount * itemSize + max(amount - 1, 0) * spacing + headerHeight + 15 * graphZoom
            
            let shapesContainer = SceneGraphItem(.ShapesContainer, stage: parent.stage, stageItem: stageItem)
            shapesContainer.rect.set(x, y, totalWidth, height)
            itemMap[UUID()] = shapesContainer
            
            mmView.drawLine.draw(sx: rect.x + parent.rect.x + parent.rect.width / 2, sy: rect.y + parent.rect.y + parent.rect.height / 2, ex: rect.x + x + totalWidth / 2, ey: rect.y + y + height / 2, radius: 1, fillColor: skin.normalBorderColor)
            
            mmView.drawBox.draw(x: rect.x + x, y: rect.y + y, width: totalWidth, height: height, round: 12, borderSize: 1, fillColor: skin.normalInteriorColor, borderColor: skin.normalBorderColor)
            
            drawPlusButton(item: shapesContainer, rect: MMRect(rect.x + x, rect.y + y, headerHeight, headerHeight), cb: { () in
                self.getShape(item: shapesContainer, replace: false)
            }, skin: skin)
            
            //mmView.drawBox.draw(x: x + drawXOffset(), y: y + drawYOffset(), width: totalWidth, height: headerHeight, round: 0, borderSize: 0, fillColor: skin.normalBorderColor, borderColor: skin.normalInteriorColor, fragment: fragment)
            
            skin.font.getTextRect(text: "Shapes", scale: skin.fontScale, rectToUse: skin.tempRect)
            mmView.drawText.drawText(skin.font, text: "Shapes", x: rect.x + x + (totalWidth - skin.tempRect.width) / 2, y: rect.y + y + 4, scale: skin.fontScale, color: skin.normalTextColor)
    
            for (index, comp) in list.enumerated() {
            
                let item = SceneGraphItem(.ShapeItem, stage: parent.stage, stageItem: stageItem, component: comp)
                item.rect.set(x, y + top, totalWidth, itemSize)
                itemMap[comp.uuid] = item
                
                if comp === currentComponent {
                    mmView.drawBox.draw( x: rect.x + item.rect.x, y: rect.y + item.rect.y, width: totalWidth, height: itemSize, round: 0, borderSize: 0, fillColor: SIMD4<Float>(0.4,0.4,0.4,1), borderColor: skin.normalBorderColor)
                }
                
                if let thumb = globalApp!.thumbnail.request(comp.libraryName + " :: SDF" + getCurrentModeId(), comp) {
                    mmView.drawTexture.draw(thumb, x: rect.x + item.rect.x + (totalWidth - 200 / 3 * graphZoom) / 2, y: rect.y + item.rect.y, zoom: 3 / graphZoom)
                }
            
                top += itemSize
                if let sub = comp.subComponent, index < list.count - 1 {
                    let subItem = SceneGraphItem(.BooleanItem, stage: parent.stage, stageItem: stageItem, component: sub, parentComponent: comp)
                    subItem.rect.set(x, y + top, totalWidth, spacing)
                    itemMap[sub.uuid] = subItem

                    if sub === currentComponent {
                        mmView.drawBox.draw( x: rect.x + subItem.rect.x, y: rect.y + subItem.rect.y, width: totalWidth, height: spacing, round: 0, borderSize: 0, fillColor: SIMD4<Float>(0.4,0.4,0.4,1), borderColor: skin.normalBorderColor)
                    }
                    
                    skin.font.getTextRect(text: sub.libraryName, scale: skin.fontScale, rectToUse: skin.tempRect)
                    mmView.drawText.drawText(skin.font, text: sub.libraryName, x: rect.x + x + (totalWidth - skin.tempRect.width) / 2, y: rect.y + y + top + 2, scale: skin.fontScale, color: skin.normalTextColor)
                }
                top += spacing
            }
        }
    }
}

