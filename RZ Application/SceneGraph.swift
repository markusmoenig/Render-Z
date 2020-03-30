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
    
    let selectedBorderColor     = SIMD4<Float>(0.816, 0.396, 0.204, 1.000)

    let normalTerminalColor     = SIMD4<Float>(0.5,0.5,0.5,1)
    let selectedTerminalColor   = SIMD4<Float>(0.816, 0.396, 0.204, 1.000)

    let tempRect                = MMRect()
    let fontScale               : Float
    let font                    : MMFont
    let lineHeight              : Float
    let itemHeight              : Float = 30
    let margin                  : Float = 20
    
    let tSize                   : Float = 15
    let tHalfSize               : Float = 15 / 2

    init(_ font: MMFont, fontScale: Float = 0.4) {
        self.font = font
        self.fontScale = fontScale
        self.lineHeight = font.getLineHeight(fontScale)
    }
}

class SceneGraphItem {
        
    enum SceneGraphItemType {
        case Stage, StageItem, ShapesContainer, ShapeItem, BooleanItem, VariableContainer, VariableItem, DomainContainer, DomainItem, ModifierContainer, ModifierItem
    }
    
    var itemType                : SceneGraphItemType
    
    let stage                   : Stage
    let stageItem               : StageItem?
    let component               : CodeComponent?
    let parentComponent         : CodeComponent?
    
    let rect                    : MMRect = MMRect()
    var navRect                 : MMRect? = nil

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
    var navItems                : [SceneGraphItem] = []

    var graphX                  : Float = 70
    var graphY                  : Float = 250
    var graphZoom               : Float = 0.62

    var dispatched              : Bool = false
    
    var currentStage            : Stage? = nil
    var currentStageItem        : StageItem? = nil
    var currentComponent        : CodeComponent? = nil

    var currentUUID             : UUID? = nil
    
    var hoverButton             : SceneGraphButton? = nil
    var pressedButton           : SceneGraphButton? = nil

    var dragItem                : SceneGraphItem? = nil
    var mousePos                : SIMD2<Float> = SIMD2<Float>(0,0)
    var mouseDownPos            : SIMD2<Float> = SIMD2<Float>(0,0)
    var mouseDownItemPos        : SIMD2<Float> = SIMD2<Float>(0,0)

    var currentWidth            : Float = 0
    var openWidth               : Float = 300

    var toolBarWidgets          : [MMWidget] = []
    let toolBarHeight           : Float = 30

    var menuWidget              : MMMenuWidget
    
    var plusLabel               : MMTextLabel? = nil
    
    var toolBarButtonSkin       : MMSkinButton
    
    var zoomBuffer              : Float = 0
    
    var mouseIsDown             : Bool = false
    var clickWasConsumed        : Bool = false
    //var isDraggingKnob          : Bool = false
    
    //var knobRect                : MMRect = MMRect()
    var navRect                 : MMRect = MMRect()
    var visNavRect              : MMRect = MMRect()
    
    var dragVisNav              : Bool = false

    var selectedVariable        : SceneGraphItem? = nil
    
    var labels                  : [UUID:MMTextLabel] = [:]
    
    // The list of the property terminal locations
    var terminals               : [(CodeComponent, UUID?, String?, Float, Float)] = []
    
    var selectedTerminal        : (CodeComponent, UUID?, String?, Float, Float)? = nil
    var possibleConnTerminal    : (CodeComponent, UUID?, String?, Float, Float)? = nil
    var connectingTerminals     : Bool = false
    
    //var map             : [MMRe]
    
    override init(_ view: MMView)
    {
        menuWidget = MMMenuWidget(view, type: .Hidden)
        
        toolBarButtonSkin = MMSkinButton()
        toolBarButtonSkin.margin = MMMargin( 8, 4, 8, 4 )
        toolBarButtonSkin.borderSize = 0
        toolBarButtonSkin.height = view.skin.Button.height - 5
        toolBarButtonSkin.fontScale = 0.40
        toolBarButtonSkin.round = 20
        
        super.init(view)
        
        zoom = view.scaleFactor

        menuWidget.setItems([
            MMMenuItem(text: "Add Object", cb: { () in
                //getStringDialog(view: self.mmView, title: "New Object", message: "Object name", defaultValue: "New Object", cb: { (value) -> Void in
                    if let scene = globalApp!.project.selected {
                        
                        let shapeStage = scene.getStage(.ShapeStage)
                        
                        let undo = globalApp!.currentEditor.undoStageStart(shapeStage, "Add Object")
                        let objectItem = shapeStage.createChild("New Object")//value)
                        
                        objectItem.values["_graphX"]! = (self.mouseDownPos.x - self.rect.x) / self.graphZoom - self.graphX
                        objectItem.values["_graphY"]! = (self.mouseDownPos.y - self.rect.y) / self.graphZoom - self.graphY

                        globalApp!.sceneGraph.setCurrent(stage: shapeStage, stageItem: objectItem)
                        globalApp!.currentEditor.undoStageEnd(shapeStage, undo)
                    }
                //} )
            }),
            MMMenuItem(text: "Add Point Light", cb: { () in
                //getStringDialog(view: self.mmView, title: "New Light", message: "Light name", defaultValue: "Light", cb: { (value) -> Void in
                    if let scene = globalApp!.project.selected {
                        
                        let lightStage = scene.getStage(.LightStage)
                        
                        let undo = globalApp!.currentEditor.undoStageStart(lightStage, "Add Object")
                        let lightItem = lightStage.createChild("Point Light")
                        
                        lightItem.values["_graphX"]! = (self.mouseDownPos.x - self.rect.x) / self.graphZoom - self.graphX
                        lightItem.values["_graphY"]! = (self.mouseDownPos.y - self.rect.y) / self.graphZoom - self.graphY

                        globalApp!.sceneGraph.setCurrent(stage: lightStage, stageItem: lightItem)
                        globalApp!.currentEditor.updateOnNextDraw(compile: true)
                        globalApp!.currentEditor.undoStageEnd(lightStage, undo)
                    }
                //} )
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
        globalApp!.artistEditor.designEditor.blockRendering = true

        if let stageItem = stageItem {
            globalApp!.project.selected?.setSelected(stageItem)
            if component == nil {
                if let defaultComponent = stageItem.components[stageItem.defaultName] {
                    globalApp!.currentEditor.setComponent(defaultComponent)
                    if globalApp!.currentEditor === globalApp!.developerEditor {
                        globalApp!.currentEditor.updateOnNextDraw(compile: false)
                    }
                    currentComponent = defaultComponent
                } else {
                    globalApp!.currentEditor.setComponent(CodeComponent(.Dummy))
                }
            }
            currentUUID = stageItem.uuid
        }
        
        if let component = component {
            globalApp!.currentEditor.setComponent(component)
            if globalApp!.currentEditor === globalApp!.developerEditor {
                globalApp!.currentEditor.updateOnNextDraw(compile: false)
            }
            currentComponent = component
            
            currentUUID = component.uuid
        } else
        if currentComponent == nil {
            globalApp!.currentEditor.setComponent(CodeComponent())
        }
        
        globalApp!.artistEditor.designEditor.blockRendering = false
        needsUpdate = true
        mmView.update()
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        dragItem = nil
        mouseIsDown = true
        clickWasConsumed = false
        selectedVariable = nil
        
        // Clicked on the knob
        /*
        if knobRect.contains(event.x, event.y) {
            isDraggingKnob = true
            mouseDownPos.x = event.x
            mouseDownPos.y = event.y
            mouseDownItemPos.x = currentWidth
            mmView.mouseTrackWidget = self
            return
        }*/
        
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
        
        selectedTerminal = nil
        // Terminal click ?
        for t in terminals {
            if event.x >= t.3 && event.y >= t.4 && event.x <= t.3 + 15 * graphZoom && event.y <= t.4 + 15 * graphZoom {
                selectedTerminal = t
                connectingTerminals = true
                mmView.update()
                break
            }
        }

        if globalApp!.sceneGraph.clickAt(x: event.x, y: event.y) {
            clickWasConsumed = true
            if let uuid = currentUUID {
                dragItem = itemMap[uuid]
                
                if let drag = dragItem {

                    if let stageItem = drag.stageItem, drag.itemType == .ShapesContainer {
                        mouseDownItemPos.x = stageItem.values["_graphShapesX"]!
                        mouseDownItemPos.y = stageItem.values["_graphShapesY"]!
                    } else
                    if let stageItem = drag.stageItem, drag.itemType == .DomainContainer {
                        mouseDownItemPos.x = stageItem.values["_graphDomainX"]!
                        mouseDownItemPos.y = stageItem.values["_graphDomainY"]!
                    } else
                    if let stageItem = drag.stageItem, drag.itemType == .ModifierContainer {
                        mouseDownItemPos.x = stageItem.values["_graphModifierX"]!
                        mouseDownItemPos.y = stageItem.values["_graphModifierY"]!
                    } else
                    if drag.component != nil && drag.component!.componentType == .Pattern {
                        mouseDownItemPos.x = drag.component!.values["_graphX"]!
                        mouseDownItemPos.y = drag.component!.values["_graphY"]!
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
            // Want to drag the nav ?
            if navRect.contains(event.x, event.y) && visNavRect.contains(event.x, event.y) {
                mouseDownPos.x = event.x
                mouseDownPos.y = event.y
                mouseDownItemPos.x = graphX
                mouseDownItemPos.y = graphY
                dragVisNav = true
                mmView.mouseTrackWidget = self
            }
        }
        
        // Prevent dragging for selected variable items
        if let drag = selectedVariable {
            if drag.itemType == .VariableItem {
                dragItem = nil
                mmView.mouseTrackWidget = nil
            }
        }
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        mousePos.x = event.x
        mousePos.y = event.y
        
        // Dragging the navigator
        if dragVisNav == true {
            graphX = mouseDownItemPos.x + (mouseDownPos.x - event.x) / graphZoom
            graphY = mouseDownItemPos.y + (mouseDownPos.y - event.y) / graphZoom
            mmView.update()
            return
        }
        
        // Connecting Terminals ?
        if connectingTerminals == true && selectedTerminal != nil {
            possibleConnTerminal = nil
            for t in terminals {
                if event.x >= t.3 && event.y >= t.4 && event.x <= t.3 + 15 * graphZoom && event.y <= t.4 + 15 * graphZoom {
                    if t.0 !== selectedTerminal!.0 {
                        
                        var propertyTerminal : (CodeComponent, UUID?, String?, Float, Float)? = nil
                        var outTerminal : (CodeComponent, UUID?, String?, Float, Float)? = nil
                        
                        if (selectedTerminal!.1 != nil && t.1 == nil) {
                            propertyTerminal = selectedTerminal
                            outTerminal = t
                        } else
                        if (selectedTerminal!.1 == nil && t.1 != nil) {
                            propertyTerminal = t
                            outTerminal = selectedTerminal
                        }
                        
                        if propertyTerminal != nil {
                                                        
                            let propertyType = propertyTerminal!.0.getPropertyOfUUID(propertyTerminal!.1!).0!.typeName
                            var canConnect = false
                                                        
                            if outTerminal!.2 == "color" && propertyType == "float4" {
                                canConnect = true
                            } else
                            if propertyType == "float" {
                                canConnect = true
                            }
                            
                            if canConnect {
                                possibleConnTerminal = t
                                mousePos.x = t.3 + 7.5 * graphZoom
                                mousePos.y = t.4 + 7.5 * graphZoom
                                break
                            }
                        }
                    }
                }
            }
            mmView.update()
            return
        }
        
        hoverButton = nil
        
        if let varItem = selectedVariable, mmView.dragSource == nil {
            if distance(mouseDownPos, SIMD2<Float>(event.x, event.y)) > 5 {
                // VARIABLE, START A DRAG OPERATION WITH A CODE FRAGMENT
                //CodeFragment(.VariableDefinition, "float", "", [.Selectable, .Dragable, .Monitorable], ["float"], "float" )
                if let comp = varItem.component {
                    dryRunComponent(comp)
                    var variable : CodeFragment? = nil
                    for uuid in comp.properties {
                        if let p = comp.getPropertyOfUUID(uuid).0 {
                            if p.values["variable"] == 1 {
                                variable = p
                                break
                            }
                        }
                    }
                    if let variable = variable {
                        let frag = CodeFragment(.VariableReference, variable.typeName, variable.name, [.Selectable, .Dragable, .Monitorable], [variable.typeName], variable.typeName )
                        frag.referseTo = nil
                        frag.name = varItem.stageItem!.name + "." + variable.name
                        frag.values["variable"] = 1
                        
                        // Create Drag Item
                        var drag = SourceListDrag()
                        drag.id = "SourceFragmentItem"
                        drag.name = variable.name
                        
                        drag.pWidgetOffset!.x = (event.x - rect.x) - varItem.rect.x
                        drag.pWidgetOffset!.y = (event.y - rect.y) - varItem.rect.y
                        
                        drag.codeFragment = frag
                                                        
                        let texture = globalApp!.developerEditor.codeList.listWidget.createGenericThumbnail(variable.name, 140 * graphZoom)
                        drag.previewWidget = MMTextureWidget(mmView, texture: texture)
                        drag.previewWidget!.zoom = 2
                        
                        drag.sourceWidget = globalApp!.developerEditor.codeEditor
                        mmView.dragStarted(source: drag)
                        
                        selectedVariable = nil
                    }
                }
            }
        }

        if let drag = dragItem {

            if let stageItem = drag.stageItem, drag.itemType == .ShapesContainer {
                stageItem.values["_graphShapesX"]! = mouseDownItemPos.x + (event.x - mouseDownPos.x) / graphZoom
                stageItem.values["_graphShapesY"]! = mouseDownItemPos.y + (event.y - mouseDownPos.y) / graphZoom
            } else
                if let stageItem = drag.stageItem, drag.itemType == .DomainContainer {
                stageItem.values["_graphDomainX"]! = mouseDownItemPos.x + (event.x - mouseDownPos.x) / graphZoom
                stageItem.values["_graphDomainY"]! = mouseDownItemPos.y + (event.y - mouseDownPos.y) / graphZoom
            } else
            if let stageItem = drag.stageItem, drag.itemType == .ModifierContainer {
                stageItem.values["_graphModifierX"]! = mouseDownItemPos.x + (event.x - mouseDownPos.x) / graphZoom
                stageItem.values["_graphModifierY"]! = mouseDownItemPos.y + (event.y - mouseDownPos.y) / graphZoom
            } else
            if drag.component != nil && drag.component!.componentType == .Pattern {
                drag.component!.values["_graphX"]! = mouseDownItemPos.x + (event.x - mouseDownPos.x) / graphZoom
                drag.component!.values["_graphY"]! = mouseDownItemPos.y + (event.y - mouseDownPos.y) / graphZoom
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
            /*
            if isDraggingKnob {
                currentWidth = min(max(mouseDownItemPos.x + (mouseDownPos.x - event.x), 300), 900)
                openWidth = currentWidth
                mmView.update()
            } else*/
            if mouseIsDown && clickWasConsumed == false && pressedButton == nil {
                graphX = mouseDownItemPos.x + (event.x - mouseDownPos.x) / graphZoom
                graphY = mouseDownItemPos.y + (event.y - mouseDownPos.y) / graphZoom
                mmView.update()
            }
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if let varItem = selectedVariable {
            if distance(mouseDownPos, SIMD2<Float>(event.x, event.y)) < 10 {
                setCurrent(stage: varItem.stage, stageItem: varItem.stageItem, component: varItem.component)
            }
        }
        
        if let pressedButton = pressedButton {
            pressedButton.cb!()
        } else
        if clickWasConsumed == false {
            // Check for showing menu
            
            if menuWidget.states.contains(.Opened) == false && distance(mouseDownPos, SIMD2<Float>(event.x, event.y)) < 5 {                
                if event.y - rect.y > toolBarHeight {
                    menuWidget.rect.x = event.x
                    menuWidget.rect.y = event.y
                    menuWidget.activateHidden()
                }
            }
        }
        
        dragItem = nil
        if menuWidget.states.contains(.Opened) == false {
            mmView.mouseTrackWidget = nil
        }
        
        // Connect terminals ?
        if connectingTerminals && selectedTerminal != nil && possibleConnTerminal != nil {
            var propertyTerminal : (CodeComponent, UUID?, String?, Float, Float)? = nil
            var outTerminal : (CodeComponent, UUID?, String?, Float, Float)? = nil
            
            if (selectedTerminal!.1 != nil && possibleConnTerminal!.1 == nil) {
                propertyTerminal = selectedTerminal
                outTerminal = possibleConnTerminal
            } else
            if (selectedTerminal!.1 == nil && possibleConnTerminal!.1 != nil) {
                propertyTerminal = possibleConnTerminal
                outTerminal = selectedTerminal
            }
            
            if let propT = propertyTerminal {
                let comp = propT.0
                if comp.connections[propT.1!] == nil {
                    comp.connections[propT.1!] = []
                }
                comp.connections[propT.1!]!.append(CodeConnection(outTerminal!.0.uuid, outTerminal!.2!))
            }
        }
        
        mouseIsDown = false
        pressedButton = nil
        hoverButton = nil
        //isDraggingKnob = false
        selectedVariable = nil
        dragVisNav = false
        
        connectingTerminals = false
        possibleConnTerminal = nil
    }
    
    /// Click at the given position
    func clickAt(x: Float, y: Float) -> Bool
    {
        let realX       : Float = (x - rect.x)
        let realY       : Float = (y - rect.y)
        var contUUID    : UUID? = nil
        var consumed    : Bool = false
        
        for (uuid,item) in itemMap {
            if item.rect.contains(realX, realY) || (item.navRect != nil && item.navRect!.contains(x, y)) {
                
                if item.itemType == .ShapesContainer || item.itemType == .VariableContainer || item.itemType == .DomainContainer || item.itemType == .ModifierContainer {
                    contUUID = uuid
                    continue
                }
                
                if item.itemType != .VariableItem {
                    setCurrent(stage: item.stage, stageItem: item.stageItem, component: item.component)
                } else {
                    selectedVariable = item
                }
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
            globalApp!.currentPipeline!.setMinimalPreview(true)
            globalApp!.mmView.startAnimate( startValue: rightRegion.rect.width, endValue: 0, duration: 500, cb: { (value,finished) in
                self.currentWidth = value
                if finished {
                    self.animating = false
                    self.sceneGraphState = .Closed
                    
                    self.mmView.deregisterWidget(self)
                    self.deactivate()
                    globalApp!.topRegion?.graphButton.removeState(.Checked)
                    globalApp!.currentPipeline!.setMinimalPreview()
                }
            } )
            animating = true
        } else if rightRegion.rect.height != openWidth {
            globalApp!.currentPipeline!.setMinimalPreview(true)
            globalApp!.mmView.startAnimate( startValue: rightRegion.rect.width, endValue: openWidth, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                    self.sceneGraphState = .Open
                    self.activate()
                    self.mmView.registerWidget(self)
                    globalApp!.topRegion?.graphButton.addState(.Checked)
                    globalApp!.currentPipeline!.setMinimalPreview()
                }
                self.currentWidth = value
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
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1))
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: toolBarHeight, round: 0, fillColor : SIMD4<Float>(0.165, 0.169, 0.173, 1.000) )
        mmView.drawBox.draw( x: rect.x, y: rect.y + toolBarHeight, width: rect.width, height: 1, round: 0, fillColor : SIMD4<Float>(0, 0, 0, 1) )
        
        var left: Float = 5
        for w in toolBarWidgets {
            w.rect.x = rect.x + left
            w.rect.y = rect.y + 2
            w.draw()
            //mmView.drawBox.draw( x: w.rect.x, y: w.rect.y, width: w.rect.width, height: w.rect.height, round: 0, borderSize: 1.5, fillColor: SIMD4<Float>(1,1,1,1), borderColor: SIMD4<Float>(1,1,1,1))//skin.borderColor)
            left += w.rect.width + 5
        }
        
        let skin : SceneGraphSkin = SceneGraphSkin(mmView.openSans, fontScale: 0.4 * graphZoom)
        
        if let scene = globalApp!.project.selected {
            mmView.renderer.setClipRect(MMRect(rect.x, rect.y + toolBarHeight + 1, rect.width - 1, rect.height - toolBarHeight - 1))
            parse(scene: scene, skin: skin)
            if menuWidget.states.contains(.Opened) {
                menuWidget.draw()
            }
            mmView.renderer.setClipRect()
        }
        
        /*
        let halfKnobWidth : Float = 6
        knobRect.x = rect.x - halfKnobWidth
        knobRect.y = rect.y + rect.height / 2 - halfKnobWidth * 2
        knobRect.width = halfKnobWidth * 3
        knobRect.height = halfKnobWidth * 4

        if isDraggingKnob == false {
            mmView.drawBox.draw( x: knobRect.x, y: knobRect.y, width: knobRect.width - halfKnobWidth, height: knobRect.height, round: 6, fillColor : SIMD4<Float>( 0, 0, 0, 1))
        } else {
            mmView.drawBox.draw( x: knobRect.x, y: knobRect.y, width: knobRect.width - halfKnobWidth, height: knobRect.height, round: 6, fillColor : SIMD4<Float>( 0.5, 0.5, 0.5, 1))
        }*/
        
        // Build the toolbar
        if needsUpdate {
            update()
        }
        
        // Build the navigator
        navRect.width = 200 / 2
        navRect.height = 160 / 2
        navRect.x = rect.right() - navRect.width
        navRect.y = rect.bottom() - navRect.height
        
        mmView.renderer.setClipRect(MMRect(navRect.x, navRect.y, navRect.width - 1, navRect.height))

        mmView.drawBox.draw( x: navRect.x, y: navRect.y, width: navRect.width, height: navRect.height, round: 0, borderSize: 1, fillColor : SIMD4<Float>(0.165, 0.169, 0.173, 1.000), borderColor: SIMD4<Float>(0, 0, 0, 1) )
        
        // Find the min / max values of the items
        
        var minX : Float = 10000
        var minY : Float = 10000
        var maxX : Float = -10000
        var maxY : Float = -10000

        for n in navItems {
        //for (_, n) in itemMap {
            if n.navRect == nil { n.navRect = MMRect() }
            if n.rect.x < minX { minX = n.rect.x }
            if n.rect.y < minY { minY = n.rect.y }
            if n.rect.right() > maxX { maxX = n.rect.right() }
            if n.rect.bottom() > maxY { maxY = n.rect.bottom() }
        }
                
        let border : Float = 10
        
        let ratioX : Float =  (navRect.width - border*2) / (maxX - minX)
        let ratioY : Float =  (navRect.height - border*2) / (maxY - minY)
                
        for n in navItems {
        //for (_, n) in itemMap {
            
            n.navRect!.x = border + navRect.x + (n.rect.x - minX) * ratioX
            n.navRect!.y = border + navRect.y + (n.rect.y - minY) * ratioY
            n.navRect!.width = n.rect.width * ratioX
            n.navRect!.height = n.rect.height * ratioY
            
            var selected : Bool = n.stage === currentStage
            if selected {
                if ( n.stageItem !== currentStageItem) {
                    selected = false
                }
            }

            mmView.drawBox.draw( x:n.navRect!.x, y: n.navRect!.y, width: n.navRect!.width, height: n.navRect!.height, round: 0, borderSize: 1, fillColor: skin.normalInteriorColor, borderColor: selected ? skin.selectedBorderColor : skin.normalBorderColor)
        }
                        
        visNavRect.x = navRect.x + border - minX * ratioX + openWidth - rect.width
        visNavRect.y = navRect.y + border - minY * ratioY + toolBarHeight * ratioY
        visNavRect.width = rect.width * ratioX
        visNavRect.height = rect.height * ratioY - toolBarHeight * ratioY
        
        mmView.drawBox.draw( x: visNavRect.x, y: visNavRect.y, width: visNavRect.width, height: visNavRect.height, round: 6, fillColor : SIMD4<Float>(1, 1, 1, 0.1) )
        mmView.renderer.setClipRect()
        
        // Connecting Terminals ?
        if connectingTerminals == true && selectedTerminal != nil {
            mmView.drawLine.draw(sx: selectedTerminal!.3 + 7.5 * graphZoom, sy: selectedTerminal!.4 + 7.5 * graphZoom, ex: mousePos.x, ey: mousePos.y, radius: 1, fillColor: skin.normalTerminalColor)
        }
    }
    
    /// Replaces the shape for the given scene graph item
    func getShape(item: SceneGraphItem, replace: Bool)
    {
        // Empty Shape
        globalApp!.libraryDialog.show(ids: ["SDF" + getCurrentModeId()], style: .Icon, cb: { (json) in
            if let comp = decodeComponentFromJSON(json) {
                let undo = globalApp!.currentEditor.undoStageItemStart(replace == false ? "Add Shape" : "Replace Shape")

                comp.uuid = UUID()
                comp.selected = nil

                globalApp!.currentEditor.setComponent(comp)
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
                globalApp!.currentEditor.updateOnNextDraw(compile: true)
            }
        })
    }
    
    /// Adds a modifier or domain item to the list
    func addItem(_ item: SceneGraphItem, name: String, listId: String)
    {
        globalApp!.libraryDialog.show(ids: [name + getCurrentModeId()], cb: { (json) in
            if let comp = decodeComponentFromJSON(json) {
                let undo = globalApp!.currentEditor.undoStageItemStart("Add " + name)
                
                comp.uuid = UUID()
                comp.selected = nil
                
                globalApp!.currentEditor.setComponent(comp)

                if let current = item.stageItem {
                    current.componentLists[listId]?.append(comp)
                }
                
                globalApp!.currentEditor.undoStageItemEnd(undo)
                self.setCurrent(stage: item.stage, stageItem: item.stageItem, component: comp)
                globalApp!.currentEditor.updateOnNextDraw(compile: true)
            }
        })
    }
    
    /// Clear the toolbar
    func clearToolbar()
    {
        deactivate()
        toolBarWidgets = []
    }
    
    // Build the menu
    func buildToolbar(uuid: UUID?)
    {
        deactivate()
        toolBarWidgets = []
        
        func buildChangeComponent(_ item: SceneGraphItem, name: String, id: String)
        {
            let button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Change " + name)
            button.clicked = { (event) in
                globalApp!.libraryDialog.show(ids: [id], cb: { (json) in
                    if let comp = decodeComponentFromJSON(json) {
                        let undo = globalApp!.currentEditor.undoStageItemStart("Change " + name)
                        
                        //comp.uuid = UUID()
                        comp.selected = nil
                        
                        comp.uuid = item.component!.uuid
                        globalApp!.currentEditor.setComponent(comp)
                        globalApp!.project.selected!.updateComponent(comp)

                        globalApp!.currentEditor.undoStageItemEnd(undo)
                        self.setCurrent(stage: item.stage, stageItem: item.stageItem, component: comp)
                        globalApp!.currentEditor.updateOnNextDraw(compile: true)
                        
                        if let stageItem = item.stageItem {
                            if comp.componentType == .Material3D {
                                stageItem.name = comp.libraryName
                                stageItem.label = nil
                            }
                        }
                    }
                })
            }
            toolBarWidgets.append(button)
        }
        
        if let uuid = uuid {
            if let item = itemMap[uuid] {
                if item.itemType == .Stage && item.stage.stageType == .PreStage {
                    // PreStage: 2D / 3D Switch
                    
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
                            globalApp!.currentPipeline = globalApp!.pipeline2D
                            if let scene = globalApp!.project.selected {
                                scene.setSelected(item.stage.getChildren()[0])
                            }
                            item.stage.label = nil
                        } else
                        if tabButton.index == 1 {
                            globalApp!.currentSceneMode = .ThreeD
                            globalApp!.currentPipeline = globalApp!.pipeline3D
                            if let scene = globalApp!.project.selected {
                                scene.setSelected(item.stage.getChildren()[0])
                            }
                            item.stage.label = nil
                        }
                        globalApp!.project.selected!.sceneMode = globalApp!.currentSceneMode
                        globalApp!.currentEditor.updateOnNextDraw(compile: true)
                    }
                    
                    toolBarWidgets.append(tabButton)
                } else
                if item.itemType == .Stage && item.stage.stageType == .VariablePool {
                    // Variable Stage
                    
                    let button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Add Variable Pool")
                    button.clicked = { (event) in
                        getStringDialog(view: self.mmView, title: "Variable Pool", message: "Pool name", defaultValue: "Variables", cb: { (value) -> Void in
                            
                            let variablePool = StageItem(.VariablePool, value)
                            variablePool.componentLists["variables"] = []

                            if globalApp!.currentSceneMode == .ThreeD {
                                item.stage.children3D.append(variablePool)
                            } else {
                                item.stage.children2D.append(variablePool)
                            }
                            placeChild(modeId: getCurrentModeId(), parent: item.stage, child: variablePool, stepSize: 90, radius: 150)
                            self.mmView.update()
                        } )
                    }
                    toolBarWidgets.append(button)
                } else
                if item.itemType == .StageItem && item.stage.stageType == .VariablePool {
                    // Variable Stage
                    
                    var button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Rename Pool")
                    button.isDisabled = item.stageItem!.name == "Sun"
                    button.clicked = { (event) -> Void in
                        getStringDialog(view: self.mmView, title: "Rename Variable Pool", message: "Pool name", defaultValue: "Variables", cb: { (value) -> Void in
                            let undo = globalApp!.currentEditor.undoStageItemStart("Rename Variable Pool")
                            item.stageItem!.name = value
                            globalApp!.currentEditor.undoStageItemEnd(undo)
                            self.mmView.update()
                        } )
                    }
                    toolBarWidgets.append(button)
                    
                    button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Remove")
                    button.isDisabled = item.stageItem!.name == "Sun"
                    button.clicked = { (event) -> Void in
                        if globalApp!.currentSceneMode == .ThreeD {
                            let index = item.stage.children3D.firstIndex(of: item.stageItem!)
                            if let index = index {
                                item.stage.children3D.remove(at: index)
                            }
                        } else {
                            let index = item.stage.children2D.firstIndex(of: item.stageItem!)
                            if let index = index {
                                item.stage.children2D.remove(at: index)
                            }
                        }
                    }
                    toolBarWidgets.append(button)
                } else
                if item.itemType == .StageItem && item.stage.stageType == .LightStage {
                    // Light
                    
                    var button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Rename Light")
                    button.clicked = { (event) -> Void in
                        getStringDialog(view: self.mmView, title: "Rename Light", message: "Light name", defaultValue: item.stageItem!.name, cb: { (value) -> Void in
                            let undo = globalApp!.currentEditor.undoStageItemStart("Rename Light")
                            item.stageItem!.name = value
                            globalApp!.currentEditor.undoStageItemEnd(undo)
                            self.mmView.update()
                        } )
                    }
                    toolBarWidgets.append(button)
                    
                    button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Remove")
                    button.clicked = { (event) -> Void in
                        if globalApp!.currentSceneMode == .ThreeD {
                            let index = item.stage.children3D.firstIndex(of: item.stageItem!)
                            if let index = index {
                                item.stage.children3D.remove(at: index)
                            }
                        } else {
                            let index = item.stage.children2D.firstIndex(of: item.stageItem!)
                            if let index = index {
                                item.stage.children2D.remove(at: index)
                            }
                        }
                        globalApp!.currentEditor.updateOnNextDraw(compile: true)
                    }
                    toolBarWidgets.append(button)
                } else
                if item.itemType == .ShapeItem {
                    
                    let button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Change Shape")
                    button.clicked = { (event) in
                        self.getShape(item: item, replace: true)
                    }
                    toolBarWidgets.append(button)
                    
                    let deleteButton = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Remove")
                    deleteButton.clicked = { (event) in
                        let id = "shapes" + getCurrentModeId()
                        
                        if let index = item.stageItem!.componentLists[id]!.firstIndex(of: item.component!) {
                            let undo = globalApp!.currentEditor.undoStageItemStart("Remove Shape")
                            item.stageItem!.componentLists[id]!.remove(at: index)
                            globalApp!.currentEditor.undoStageItemEnd(undo)
                            globalApp!.currentEditor.updateOnNextDraw(compile: true)
                        }
                    }
                    toolBarWidgets.append(deleteButton)
                } else
                if item.itemType == .BooleanItem {
                    let button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Change Boolean")
                    button.clicked = { (event) in
                        globalApp!.libraryDialog.show(ids: ["Boolean"], cb: { (json) in
                            if let comp = decodeComponentFromJSON(json) {
                                let undo = globalApp!.currentEditor.undoStageItemStart("Change Boolean")
                                                                
                                comp.uuid = UUID()
                                comp.selected = nil
                                globalApp!.currentEditor.setComponent(comp)
                                
                                if let parent = item.parentComponent {
                                    parent.subComponent = comp
                                    globalApp!.project.selected!.updateComponent(parent)
                                }
                                                            
                                globalApp!.currentEditor.undoStageItemEnd(undo)
                                self.setCurrent(stage: item.stage, stageItem: item.stageItem, component: comp)
                                globalApp!.currentEditor.updateOnNextDraw(compile: true)
                            }
                        })
                    }
                    toolBarWidgets.append(button)
                } else
                // Renderer
                if let comp = item.component, comp.componentType == .Render2D || comp.componentType == .Render3D {
                    
                    let button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Change Renderer")
                    button.clicked = { (event) in
                        globalApp!.libraryDialog.show(ids: [comp.componentType == .Render2D ? "Render2D" : "Render3D"], cb: { (json) in
                            if let comp = decodeComponentFromJSON(json) {
                                let undo = globalApp!.currentEditor.undoStageItemStart("Change Renderer")
                                
                                comp.uuid = UUID()
                                comp.selected = nil
                                globalApp!.currentEditor.setComponent(comp)
                                
                                comp.uuid = item.component!.uuid
                                globalApp!.project.selected!.updateComponent(comp)
                                                            
                                globalApp!.currentEditor.undoStageItemEnd(undo)
                                self.setCurrent(stage: item.stage, stageItem: item.stageItem, component: comp)
                                globalApp!.currentEditor.updateOnNextDraw(compile: true)
                            }
                        })
                    }
                    toolBarWidgets.append(button)
                } else
                if item.itemType == .StageItem && item.stageItem!.stageItemType == .ShapeStage {
                    let button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Add Child")
                    button.clicked = { (event) in
                        //getStringDialog(view: self.mmView, title: "Child Object", message: "Object name", defaultValue: "Child Object", cb: { (value) -> Void in
                            if let scene = globalApp!.project.selected {
                                
                                let shapeStage = scene.getStage(.ShapeStage)
                                let objectItem = shapeStage.createChild(/*value*/"Child Object", parent: item.stageItem!)
                                
                                objectItem.values["_graphX"]! = objectItem.values["_graphX"]!
                                objectItem.values["_graphY"]! = objectItem.values["_graphY"]! + 270

                                globalApp!.sceneGraph.setCurrent(stage: shapeStage, stageItem: objectItem)
                            }
                        //} )
                    }
                    toolBarWidgets.append(button)
                    
                    let renameButton = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Rename")
                    renameButton.clicked = { (event) -> Void in
                        getStringDialog(view: self.mmView, title: "Rename Object", message: "Object name", defaultValue: item.stageItem!.name, cb: { (value) -> Void in
                            let undo = globalApp!.currentEditor.undoStageItemStart("Rename Object")
                            item.stageItem!.name = value
                            item.stageItem!.label = nil
                            globalApp!.currentEditor.undoStageItemEnd(undo)
                            self.mmView.update()
                        } )
                        renameButton.removeState(.Checked)
                    }
                    toolBarWidgets.append(renameButton)
                    
                    let removeButton = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Remove")
                    removeButton.clicked = { (event) in
                        
                        if let scene = globalApp!.project.selected {
                            let shapeStage = scene.getStage(.ShapeStage)
                            let parent = shapeStage.getParentOfStageItem(item.stageItem!)
                            if parent.1 == nil {
                                let undo = globalApp!.currentEditor.undoStageStart(shapeStage, "Remove Object")
                                if let index = shapeStage.children2D.firstIndex(of: item.stageItem!) {
                                    shapeStage.children2D.remove(at: index)
                                } else
                                if let index = shapeStage.children3D.firstIndex(of: item.stageItem!) {
                                    shapeStage.children3D.remove(at: index)
                                }
                                globalApp!.currentEditor.undoStageEnd(shapeStage, undo)
                            } else
                            if let p = parent.1 {
                                let undo = globalApp!.currentEditor.undoStageItemStart(p, "Remove Child Object")
                                if let index = p.children.firstIndex(of: item.stageItem!) {
                                    p.children.remove(at: index)
                                }
                                globalApp!.currentEditor.undoStageItemEnd(p, undo)
                            }
                            self.clearToolbar()
                        }
                        globalApp!.currentEditor.updateOnNextDraw(compile: true)
                        removeButton.removeState(.Checked)
                    }
                    toolBarWidgets.append(removeButton)
                } else
                if let comp = item.component {
                    if comp.componentType == .RayMarch3D {
                        buildChangeComponent(item, name: "RayMarcher", id: "RayMarch3D")
                    } else
                    if comp.componentType == .Normal3D {
                        buildChangeComponent(item, name: "Normal", id: "Normal3D")
                    } else
                    if comp.componentType == .SkyDome {
                        buildChangeComponent(item, name: "Sky Dome", id: "SkyDome")
                    } else
                    if comp.componentType == .Shadows3D {
                        buildChangeComponent(item, name: "Shadows", id: "Shadows3D")
                    } else
                    if comp.componentType == .Domain3D {
                        buildChangeComponent(item, name: "Domain", id: "Domain3D")
                        
                        let deleteButton = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Remove")
                        deleteButton.clicked = { (event) in
                            let id = "domain" + getCurrentModeId()
                            
                            if let index = item.stageItem!.componentLists[id]!.firstIndex(of: item.component!) {
                                let undo = globalApp!.currentEditor.undoStageItemStart("Remove Domain")
                                item.stageItem!.componentLists[id]!.remove(at: index)
                                globalApp!.currentEditor.undoStageItemEnd(undo)
                                globalApp!.currentEditor.updateOnNextDraw(compile: true)
                            }
                        }
                        toolBarWidgets.append(deleteButton)
                    } else
                    if comp.componentType == .Modifier3D {
                        buildChangeComponent(item, name: "Modifier", id: "Modifier3D")
                        
                        let deleteButton = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Remove")
                        deleteButton.clicked = { (event) in
                            let id = "modifier" + getCurrentModeId()
                            
                            if let index = item.stageItem!.componentLists[id]!.firstIndex(of: item.component!) {
                                let undo = globalApp!.currentEditor.undoStageItemStart("Remove Modifier")
                                item.stageItem!.componentLists[id]!.remove(at: index)
                                globalApp!.currentEditor.undoStageItemEnd(undo)
                                globalApp!.currentEditor.updateOnNextDraw(compile: true)
                            }
                        }
                        toolBarWidgets.append(deleteButton)
                    } else
                    if comp.componentType == .Material3D {
                        buildChangeComponent(item, name: "Material", id: "Material3D")
                        
                        let addPatternButton = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Add Pattern")
                        addPatternButton.clicked = { (event) in
                            if let stageItem = item.stageItem {
                                let comp = CodeComponent(.Pattern, "Pattern")
                                comp.createDefaultFunction(.Pattern)
                                comp.values["_graphX"] = 100
                                comp.values["_graphY"] = 100

                                if stageItem.componentLists["patterns"] == nil { stageItem.componentLists["patterns"] = [] }
                                
                                stageItem.componentLists["patterns"]?.append(comp)
                            }
                            addPatternButton.removeState(.Checked)
                        }
                        toolBarWidgets.append(addPatternButton)
                    } else
                    if comp.componentType == .Variable {
                        
                        var button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Rename Variable")
                        button.isDisabled = item.stageItem!.name == "Sun"
                        button.clicked = { (event) -> Void in
                            if let frag = getVariable(from: comp) {
                                getStringDialog(view: self.mmView, title: "Rename Variable", message: "Variable name", defaultValue: frag.name, cb: { (value) -> Void in
                                    let undo = globalApp!.currentEditor.undoComponentStart("Rename Variable")
                                    frag.name = value
                                    comp.libraryName = value
                                    globalApp!.project.selected!.updateComponent(comp)
                                    globalApp!.currentEditor.setComponent(comp)
                                    globalApp!.currentEditor.undoComponentEnd(undo)
                                    self.mmView.update()
                                } )
                            }
                        }
                        toolBarWidgets.append(button)
                        
                        button = MMButtonWidget(mmView, skinToUse: toolBarButtonSkin, text: "Remove")
                        button.isDisabled = item.stageItem!.name == "Sun"
                        button.clicked = { (event) in
                            if let index = item.stageItem!.componentLists["variables"]!.firstIndex(of: item.component!) {
                                let undo = globalApp!.currentEditor.undoStageItemStart("Remove Variable")
                                item.stageItem!.componentLists["variables"]!.remove(at: index)
                                globalApp!.currentEditor.undoStageItemEnd(undo)
                            }
                        }
                        toolBarWidgets.append(button)
                    }
                }
            }
        }
        
        activate()
        mmView.update()
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
        
        if plusLabel == nil || plusLabel!.scale != skin.fontScale + 0.1 {
            plusLabel = MMTextLabel(mmView, font: mmView.openSans, text: "+", scale: skin.fontScale + 0.1, color: skin.normalTextColor)
        }
        plusLabel!.rect.x = rect.x
        plusLabel!.rect.y = rect.y
        plusLabel!.draw()

        //plusLabel!.drawCentered(x: rect.x, y: rect.y, width: rect.width, height: rect.height)
        
        buttons.append(button)
    }
    
    /// Parses and draws the scene graph
    func parse(scene: Scene, skin: SceneGraphSkin)
    {
        itemMap = [:]
        navItems = []
        buttons = []
        terminals = []

        // Draw World
        var stage = scene.getStage(.PreStage)
        
        if stage.label == nil || stage.label!.scale != skin.fontScale {
            stage.label = MMTextLabel(mmView, font: mmView.openSans, text: stage.name + " " + getCurrentModeId(), scale: skin.fontScale, color: skin.normalTextColor)
        }
        var diameter : Float = stage.label!.rect.width + skin.margin * graphZoom

        var x : Float = (graphX + stage.values["_graphX"]!) * graphZoom - diameter / 2
        var y : Float = (graphY + stage.values["_graphY"]!) * graphZoom - diameter / 2
        
        let worldItem = SceneGraphItem(.Stage, stage: stage)
        worldItem.rect.set(x, y, diameter, skin.itemHeight * graphZoom)
        itemMap[stage.uuid] = worldItem
        navItems.append(worldItem)
        
        var childs = stage.getChildren()
        for childItem in childs {
            if childItem.label == nil || childItem.label!.scale != skin.fontScale {
                childItem.label = MMTextLabel(mmView, font: mmView.openSans, text: childItem.name, scale: skin.fontScale, color: skin.normalTextColor)
            }
            let diameter : Float = childItem.label!.rect.width + skin.margin * graphZoom

            let cX = x + childItem.values["_graphX"]! * graphZoom - diameter / 2
            let cY = y + childItem.values["_graphY"]! * graphZoom - diameter / 2

            let comp = childItem.components[childItem.defaultName]!
            let item = SceneGraphItem(.StageItem, stage: stage, stageItem: childItem, component: comp)
            item.rect.set(cX, cY, diameter, skin.itemHeight * graphZoom)
            itemMap[comp.uuid] = item

            drawItem(item, selected: childItem === currentStageItem , parent: worldItem, skin: skin)
        }
        drawItem(worldItem, selected: stage === currentStage, skin: skin)

        // Draw Objects
        stage = scene.getStage(.ShapeStage)
        let objects = stage.getChildren()
        for o in objects {
            drawObject(stage: stage, o: o, skin: skin)
        }
        
        // Draw Lights
        stage = scene.getStage(.LightStage)
        childs = stage.getChildren()
        for childItem in childs {
            
            if childItem.label == nil || childItem.label!.scale != skin.fontScale {
                childItem.label = MMTextLabel(mmView, font: mmView.openSans, text: childItem.name, scale: skin.fontScale, color: skin.normalTextColor)
            }
            let diameter : Float = childItem.label!.rect.width + skin.margin * graphZoom

            let cX = graphX * graphZoom + childItem.values["_graphX"]! * graphZoom - diameter / 2
            let cY = graphY * graphZoom + childItem.values["_graphY"]! * graphZoom - diameter / 2

            let comp = childItem.components[childItem.defaultName]!
            let item = SceneGraphItem(.StageItem, stage: stage, stageItem: childItem, component: comp)
            item.rect.set(cX, cY, diameter, skin.itemHeight * graphZoom)
            itemMap[comp.uuid] = item
            
            drawItem(item, selected: childItem === currentStageItem , parent: nil, skin: skin)
        }
        
        // Draw Render Stage
        stage = scene.getStage(.RenderStage)
        
        if stage.label == nil || stage.label!.scale != skin.fontScale {
            stage.label = MMTextLabel(mmView, font: mmView.openSans, text: stage.name, scale: skin.fontScale, color: skin.normalTextColor)
        }
        diameter = stage.label!.rect.width + skin.margin * graphZoom

        x = (graphX + stage.values["_graphX"]!) * graphZoom - diameter / 2
        y = (graphY + stage.values["_graphY"]!) * graphZoom - diameter / 2
        
        let renderStageItem = stage.getChildren()[0]
        let renderComponent = renderStageItem.components[renderStageItem.defaultName]!
        let renderItem = SceneGraphItem(.Stage, stage: stage, component: renderComponent)
        renderItem.rect.set(x, y, diameter, skin.itemHeight * graphZoom)
        itemMap[renderComponent.uuid] = renderItem
        navItems.append(renderItem)

        childs = stage.getChildren()
        for childItem in childs {
            
            if childItem.name == "Color" { continue }

            if childItem.label == nil || childItem.label!.scale != skin.fontScale {
                childItem.label = MMTextLabel(mmView, font: mmView.openSans, text: childItem.name, scale: skin.fontScale, color: skin.normalTextColor)
            }
            let diameter : Float = childItem.label!.rect.width + skin.margin * graphZoom

            let cX = x + childItem.values["_graphX"]! * graphZoom - diameter / 2
            let cY = y + childItem.values["_graphY"]! * graphZoom - diameter / 2

            let comp = childItem.components[childItem.defaultName]!
            let item = SceneGraphItem(.StageItem, stage: stage, stageItem: childItem, component: comp)
            item.rect.set(cX, cY, diameter, skin.itemHeight * graphZoom)
            itemMap[comp.uuid] = item
            
            drawItem(item, selected: childItem === currentStageItem , parent: renderItem, skin: skin)
        }
        drawItem(renderItem, selected: stage === currentStage, skin: skin)

        // Draw Variable Pool
        stage = scene.getStage(.VariablePool)
        
        if stage.label == nil || stage.label!.scale != skin.fontScale {
            stage.label = MMTextLabel(mmView, font: mmView.openSans, text: stage.name, scale: skin.fontScale, color: skin.normalTextColor)
        }
        diameter = stage.label!.rect.width + skin.margin * graphZoom

        x = (graphX + stage.values["_graphX"]!) * graphZoom - diameter / 2
        y = (graphY + stage.values["_graphY"]!) * graphZoom - diameter / 2
        
        let variableItem = SceneGraphItem(.Stage, stage: stage)
        variableItem.rect.set(x, y, diameter, skin.itemHeight * graphZoom)
        itemMap[stage.uuid] = variableItem
        navItems.append(variableItem)

        childs = stage.getChildren()
        for childItem in childs {

            if childItem.label == nil || childItem.label!.scale != skin.fontScale {
                childItem.label = MMTextLabel(mmView, font: mmView.openSans, text: childItem.name, scale: skin.fontScale, color: skin.normalTextColor)
            }
            let diameter : Float = childItem.label!.rect.width + skin.margin * graphZoom

            let cX = x + childItem.values["_graphX"]! * graphZoom - diameter / 2
            let cY = y + childItem.values["_graphY"]! * graphZoom - diameter / 2

            let item = SceneGraphItem(.StageItem, stage: stage, stageItem: childItem)
            item.rect.set(cX, cY, diameter, skin.itemHeight * graphZoom)
            itemMap[childItem.uuid] = item
            
            drawLineBetweenCircles(variableItem, item, skin)

            drawVariablesPool(parent: item, skin: skin)
        }
        drawItem(variableItem, selected: stage === currentStage, skin: skin)
    }
    
    // Returns a label for the given UUID
    func getLabel(_ uuid: UUID,_ text: String, skin: SceneGraphSkin) -> MMTextLabel
    {
        var label = labels[uuid]
        if label == nil || label!.scale != skin.fontScale {
            label = MMTextLabel(mmView, font: mmView.openSans, text: text, scale: skin.fontScale, color: skin.normalTextColor)
        }
        return label!
    }
    
    // drawItem
    func drawItem(_ item: SceneGraphItem, selected: Bool, parent: SceneGraphItem? = nil, skin: SceneGraphSkin)
    {
        if let parent = parent {
            drawLineBetweenCircles(parent, item, skin)
        }
        
        var label : MMTextLabel
        
        if let stageItem = item.stageItem {
            if stageItem.label == nil || stageItem.label!.scale != skin.fontScale {
                stageItem.label = MMTextLabel(mmView, font: mmView.openSans, text: stageItem.name, scale: skin.fontScale, color: skin.normalTextColor)
            }
            label = stageItem.label!
        } else {
            if item.stage.label == nil || item.stage.label!.scale != skin.fontScale {
                item.stage.label = MMTextLabel(mmView, font: mmView.openSans, text: item.stage.name, scale: skin.fontScale, color: skin.normalTextColor)
            }
            label = item.stage.label!
        }
        
        var hasProperties = false
        
        if let stageItem = item.stageItem {
            let defaultComponent = stageItem.components[stageItem.defaultName]
            let potentialComponent = defaultComponent != nil && defaultComponent!.componentType == .Material3D && item.component != nil ? item.component : defaultComponent
            if let component = potentialComponent, component.componentType == .Material3D || component.componentType == .Pattern {
                
                // Material, draw all the patterns
                if let patterns = stageItem.componentLists["patterns"], item.component!.componentType == .Material3D {
                    for p in patterns {
                        let pItem = SceneGraphItem(.StageItem, stage: item.stage, stageItem: stageItem, component: p)
                        pItem.rect.set(item.rect.x + p.values["_graphX"]! * graphZoom, item.rect.y + p.values["_graphY"]! * graphZoom, item.rect.width, item.rect.height)
                        itemMap[p.uuid] = pItem
                        drawItem(pItem, selected: p === currentComponent, skin: skin)
                    }
                }
                
                if component.properties.count > 0 || component.componentType == .Pattern {
                    
                    hasProperties = true
                    item.rect.width = 140 * graphZoom
                    var y = item.rect.y + item.rect.height + 16 * graphZoom
                    let yBackup = y
                    
                    let itemHeight : Float = 28 * graphZoom
                    
                    let itemCount : Float = component.componentType == .Pattern ? Float(max(2, component.properties.count)) : Float(component.properties.count)

                    item.rect.height += itemCount * itemHeight + 20 * graphZoom
                    mmView.drawBox.draw(x: rect.x + item.rect.x, y: rect.y + item.rect.y, width: item.rect.width, height: item.rect.height, round: 12 * graphZoom, borderSize: 1, fillColor: skin.normalInteriorColor, borderColor: selected ? skin.selectedBorderColor : skin.normalBorderColor)
                    
                    if component.componentType == .Pattern {
                        label = getLabel(component.uuid, component.libraryName, skin: skin)
                    }
                    label.rect.x = rect.x + item.rect.x + 10 * graphZoom
                    label.rect.y = rect.y + item.rect.y + 10 * graphZoom
                    label.draw()
                    
                    mmView.drawLine.draw(sx: rect.x + item.rect.x + 4 * graphZoom, sy: rect.y + item.rect.y + 32 * graphZoom, ex: rect.x + item.rect.x + item.rect.width - 8 * graphZoom, ey: rect.y + item.rect.y + 32 * graphZoom, radius: 0.6, fillColor: skin.normalBorderColor)
                                  
                    // Draw the right sided property terminals
                    for uuid in component.properties {
                        let name = component.artistPropertyNames[uuid]!
                        let label = getLabel(uuid, name, skin: skin)
                        
                        let frag = component.getPropertyOfUUID(uuid)
                        label.rect.x = rect.x + item.rect.right() - label.rect.width - 15 * graphZoom
                        label.rect.y = rect.y + y
                        label.draw()
                        
                        let tX : Float = rect.x + item.rect.right() - 7.5 * graphZoom
                        let tY : Float = rect.y + y + 1.5 * graphZoom

                        terminals.append((component, uuid, nil, tX, tY))
                        
                        var pColor = skin.normalInteriorColor
                        if let selectedTerminal = selectedTerminal {
                            if selectedTerminal.0 === component && selectedTerminal.1 == uuid {
                                pColor = skin.normalTerminalColor
                            }
                        }
                        if let terminal = possibleConnTerminal {
                            if terminal.0 === component && terminal.1 == uuid {
                                pColor = skin.normalTerminalColor
                            }
                        }

                        if frag.0!.typeName == "float4" {
                            mmView.drawBox.draw(x: tX, y: tY, width: 15 * graphZoom, height: 15 * graphZoom, round: 0, borderSize: 1, fillColor: pColor, borderColor: selected ? skin.selectedBorderColor : skin.normalBorderColor)
                        } else {
                            mmView.drawSphere.draw(x: tX, y: tY, radius: 7.5 * graphZoom, borderSize: 1, fillColor: pColor, borderColor: selected ? skin.selectedBorderColor : skin.normalBorderColor)
                        }
                        
                        // Draw the property terminal connections
                        if let connections = component.connections[uuid] {
                            for conn in connections {
                                for t in terminals {
                                    if t.0.uuid == conn.componentUUID && t.2 == conn.outName {
                                        mmView.drawLine.draw(sx: tX + 7.5 * graphZoom, sy: tY + 7.5 * graphZoom, ex: t.3 + 7.5 * graphZoom, ey: t.4 + 7.5 * graphZoom, radius: 1, fillColor: skin.normalTerminalColor)
                                    }
                                }
                            }
                        }
                        
                        y += itemHeight
                    }
                    
                    // Draw the left sided pattern terminals (color, mask, id)
                    if component.componentType == .Pattern {
                        y = yBackup
                        
                        func getInteriorColor(_ name: String) -> SIMD4<Float>
                        {
                            var pColor = skin.normalInteriorColor
                            if let selectedTerminal = selectedTerminal {
                                if selectedTerminal.0 === component && selectedTerminal.2 == name {
                                    pColor = skin.normalTerminalColor
                                }
                            }
                            if let terminal = possibleConnTerminal {
                                if terminal.0 === component && terminal.2 == name {
                                    pColor = skin.normalTerminalColor
                                }
                            }
                            return pColor
                        }
                        
                        let tX : Float = rect.x + item.rect.x - 7.5 * graphZoom
                        var tY : Float = rect.y + y + 1.5 * graphZoom

                        terminals.append((component, nil, "color", tX, tY))
                        var pColor = getInteriorColor("color")
                        
                        mmView.drawBox.draw(x: tX, y: tY, width: 15 * graphZoom, height: 15 * graphZoom, round: 0, borderSize: 1, fillColor: pColor, borderColor: selected ? skin.selectedBorderColor : skin.normalBorderColor)
                        
                        tY += itemHeight
                        terminals.append((component, nil, "mask", tX, tY))

                        pColor = getInteriorColor("mask")
                        mmView.drawSphere.draw(x: tX, y: tY, radius: 7.5 * graphZoom, borderSize: 1, fillColor: pColor, borderColor: selected ? skin.selectedBorderColor : skin.normalBorderColor)
                    }
                }
            }
        }
        
        if hasProperties == false {
            mmView.drawBox.draw(x: rect.x + item.rect.x, y: rect.y + item.rect.y, width: item.rect.width, height: item.rect.height, round: 12 * graphZoom, borderSize: 1, fillColor: skin.normalInteriorColor, borderColor: selected ? skin.selectedBorderColor : skin.normalBorderColor)
        }

        //mmView.drawSphere.draw(x: rect.x + item.rect.x, y: rect.y + item.rect.y, radius: item.rect.width / 2, borderSize: 1.5, fillColor: skin.normalInteriorColor, borderColor: selected ? skin.selectedBorderColor : skin.normalBorderColor)
        
        if hasProperties == false {
            label.rect.x = rect.x + item.rect.x + (item.rect.width - label.rect.width) / 2
            label.rect.y = rect.y + item.rect.y + (item.rect.height - skin.lineHeight) / 2
            label.draw()
        }
    }
    
    /// Draws an object hierarchy
    func drawObject(stage: Stage, o: StageItem, parent: SceneGraphItem? = nil, skin: SceneGraphSkin)
    {
        if o.label == nil || o.label!.scale != skin.fontScale {
            let name : String = o.name
            /*
            if let def = o.components[o.defaultName] {
                if def.componentType == .Ground3D {
                    name += ": " + def.libraryName
                }
            }*/
            o.label = MMTextLabel(mmView, font: mmView.openSans, text: name, scale: skin.fontScale, color: skin.normalTextColor)
        }
        let diameter : Float = o.label!.rect.width + skin.margin * graphZoom
        
        let x       : Float
        let y       : Float
        
        if let parent = parent {
            x = parent.rect.x + o.values["_graphX"]! * graphZoom
            y = parent.rect.y + o.values["_graphY"]! * graphZoom
        } else {
            x = (graphX + o.values["_graphX"]!) * graphZoom - diameter / 2
            y = (graphY + o.values["_graphY"]!) * graphZoom - diameter / 2
        }
        
        var uuid : UUID = o.uuid

        var component : CodeComponent? = nil
        if let comp = o.components[o.defaultName] {
            if comp.componentType == .Material3D || comp.componentType == .UVMAP3D {
                component = comp
                uuid = comp.uuid
            }
        }
        
        let item = SceneGraphItem(.StageItem, stage: stage, stageItem: o, component: component)
        item.rect.set(x, y, diameter, skin.itemHeight * graphZoom)
        itemMap[uuid] = item
        if parent == nil {
            navItems.append(item)
        }
        
        if let p = parent {
            drawLineBetweenCircles(item, p, skin)
        }
        
        drawShapesBox(parent: item, skin: skin)
        drawItemList(parent: item, listId: "domain" + getCurrentModeId(), graphId: "_graphDomain", name: "Domain", containerId: .DomainContainer, itemId: .DomainItem, skin: skin)
        drawItemList(parent: item, listId: "modifier" + getCurrentModeId(), graphId: "_graphModifier", name: "Modifier", containerId: .ModifierContainer, itemId: .ModifierItem, skin: skin)
        
        for c in o.children {
            drawObject(stage: stage, o: c, parent: item, skin: skin)
        }
        
        /*
        mmView.drawSphere.draw(x: rect.x + x, y: rect.y + y, radius: diameter / zoom, borderSize: 1, fillColor: o === currentStageItem ? skin.normalBorderColor : skin.normalInteriorColor, borderColor: skin.normalBorderColor)
        o.label!.rect.x = rect.x + x + (diameter - o.label!.rect.width) / 2
        o.label!.rect.y = rect.y + y + (diameter - skin.lineHeight) / 2
        o.label!.draw() */
        
        drawItem(item, selected: o === currentStageItem, parent: nil, skin: skin)

    }
    
    func drawShapesBox(parent: SceneGraphItem, skin: SceneGraphSkin)
    {
        let spacing     : Float = 22 * graphZoom
        let itemSize    : Float = 70 * graphZoom
        let totalWidth  : Float = 140 * graphZoom
        let headerHeight: Float = 30 * graphZoom
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
            
            mmView.drawLine.draw(sx: rect.x + parent.rect.x + parent.rect.width / 2, sy: rect.y + parent.rect.y + parent.rect.height / 2, ex: rect.x + x + totalWidth / 2, ey: rect.y + y + headerHeight / 2, radius: 1, fillColor: skin.normalBorderColor)
            
            mmView.drawBox.draw(x: rect.x + x, y: rect.y + y, width: totalWidth, height: height, round: 12, borderSize: 1, fillColor: skin.normalInteriorColor, borderColor: skin.normalBorderColor)
            
            drawPlusButton(item: shapesContainer, rect: MMRect(rect.x + x + totalWidth - (plusLabel != nil ? plusLabel!.rect.width : 0) - 10 * graphZoom, rect.y + y + 4 * graphZoom, headerHeight, headerHeight), cb: { () in
                self.getShape(item: shapesContainer, replace: false)
            }, skin: skin)
            
            skin.font.getTextRect(text: "Shapes", scale: skin.fontScale, rectToUse: skin.tempRect)
            mmView.drawText.drawText(skin.font, text: "Shapes", x: rect.x + x + 10 * graphZoom, y: rect.y + y + 7 * graphZoom, scale: skin.fontScale, color: skin.normalTextColor)
            
            mmView.drawLine.draw(sx: rect.x + x + 4 * graphZoom, sy: rect.y + y + headerHeight, ex: rect.x + x + totalWidth - 8 * graphZoom, ey: rect.y + y + headerHeight, radius: 0.6, fillColor: skin.normalBorderColor)
    
            for (index, comp) in list.enumerated() {
                let item = SceneGraphItem(.ShapeItem, stage: parent.stage, stageItem: stageItem, component: comp)
                item.rect.set(x, y + top, totalWidth, itemSize)
                itemMap[comp.uuid] = item
                
                if comp === currentComponent {
                    mmView.drawBox.draw( x: rect.x + item.rect.x + 1, y: rect.y + item.rect.y, width: totalWidth - 2, height: itemSize, round: 0, fillColor: skin.selectedBorderColor)
                }
                
                if let thumb = globalApp!.thumbnail.request(comp.libraryName + " :: SDF" + getCurrentModeId()) {
                    mmView.drawTexture.draw(thumb, x: rect.x + item.rect.x + (totalWidth - 200 / 3 * graphZoom) / 2, y: rect.y + item.rect.y, zoom: 3 / graphZoom)
                }
            
                top += itemSize
                // Take the subComponent of the NEXT item as the boolean
                if index < list.count - 1 {
                    let next = list[index+1]
                    if let sub = next.subComponent {
                        let subItem = SceneGraphItem(.BooleanItem, stage: parent.stage, stageItem: stageItem, component: sub, parentComponent: next)
                        subItem.rect.set(x, y + top, totalWidth, spacing)
                        itemMap[sub.uuid] = subItem

                        if sub === currentComponent {
                            mmView.drawBox.draw( x: rect.x + subItem.rect.x, y: rect.y + subItem.rect.y, width: totalWidth, height: spacing, round: 0, borderSize: 0, fillColor: SIMD4<Float>(0.4,0.4,0.4,1), borderColor: skin.normalBorderColor)
                        }
                        
                        skin.font.getTextRect(text: sub.libraryName, scale: skin.fontScale, rectToUse: skin.tempRect)
                        mmView.drawText.drawText(skin.font, text: sub.libraryName, x: rect.x + x + (totalWidth - skin.tempRect.width) / 2, y: rect.y + y + top + 2, scale: skin.fontScale, color: skin.normalTextColor)
                    }
                }
                top += spacing
            }
        }
    }
    
    func drawVariablesPool(parent: SceneGraphItem, skin: SceneGraphSkin)
    {
        let itemSize    : Float = 35 * graphZoom
        let totalWidth  : Float = 140 * graphZoom
        let headerHeight: Float = 30 * graphZoom
        var top         : Float = headerHeight + 7.5 * graphZoom
        
        let stageItem   = parent.stageItem!
        
        let x           : Float = parent.rect.x
        let y           : Float = parent.rect.y

        if let list = parent.stageItem!.componentLists["variables"] {
            
            let amount : Float = Float(list.count)
            let height : Float = amount * itemSize + headerHeight + 15 * graphZoom
            
            let variableContainer = SceneGraphItem(.VariableContainer, stage: parent.stage, stageItem: stageItem)
            variableContainer.rect.set(x, y, totalWidth, height)
            itemMap[UUID()] = variableContainer
            
            mmView.drawBox.draw(x: rect.x + x, y: rect.y + y, width: totalWidth, height: height, round: 12, borderSize: 1, fillColor: skin.normalInteriorColor, borderColor: skin.normalBorderColor)
            
            if parent.stageItem!.name != "Sun" {
                drawPlusButton(item: variableContainer, rect: MMRect(rect.x + x + totalWidth - (plusLabel != nil ? plusLabel!.rect.width : 0) - 10 * graphZoom, rect.y + y + 4 * graphZoom, headerHeight, headerHeight), cb: { () in
                        getStringDialog(view: self.mmView, title: "New Variable", message: "Variable name", defaultValue: "New Variable", cb: { (variableName) -> Void in
                                getStringDialog(view: self.mmView, title: "Variable Type", message: "Type", defaultValue: "float4", cb: { (variableType) -> Void in
                                    let validTypes = ["float", "float2", "float3", "float4", "int"]
                                    if validTypes.contains(variableType) {
                                        let varComponent = CodeComponent(.Variable, variableName)
                                        varComponent.createVariableFunction(variableName, variableType, variableName)
                                        stageItem.componentLists["variables"]!.append(varComponent)
                                        self.mmView.update()
                                    }
                            } )
                    } )
                }, skin: skin)
            }
            
            skin.font.getTextRect(text: parent.stageItem!.name, scale: skin.fontScale, rectToUse: skin.tempRect)
            
            mmView.drawText.drawText(skin.font, text: parent.stageItem!.name, x: rect.x + x + 10 * graphZoom, y: rect.y + y + 7 * graphZoom, scale: skin.fontScale, color: skin.normalTextColor)
            
            mmView.drawLine.draw(sx: rect.x + x + 4 * graphZoom, sy: rect.y + y + headerHeight, ex: rect.x + x + totalWidth - 8 * graphZoom, ey: rect.y + y + headerHeight, radius: 0.6, fillColor: skin.normalBorderColor)

            for comp in list {
                
                let item = SceneGraphItem(.VariableItem, stage: parent.stage, stageItem: stageItem, component: comp)
                item.rect.set(x, y + top, totalWidth, itemSize)
                itemMap[comp.uuid] = item
                
                if comp === currentComponent {
                    mmView.drawBox.draw( x: rect.x + item.rect.x + 1, y: rect.y + item.rect.y, width: totalWidth - 2, height: itemSize, round: 0, fillColor: skin.selectedBorderColor)
                }
                
                if stageItem.componentLabels[comp.libraryName] == nil || stageItem.componentLabels[comp.libraryName]!.scale != skin.fontScale {
                    stageItem.componentLabels[comp.libraryName] = MMTextLabel(mmView, font: mmView.openSans, text: comp.libraryName, scale: skin.fontScale, color: skin.normalTextColor)
                }
                if let label = stageItem.componentLabels[comp.libraryName] {
                    label.rect.x = rect.x + item.rect.x + 10// + (totalWidth - label.rect.width) / 2
                    label.rect.y = rect.y + item.rect.y + (itemSize - skin.lineHeight) / 2
                    label.draw()
                }
                top += itemSize
            }
        }
    }
    
    func drawItemList(parent: SceneGraphItem, listId: String, graphId: String, name: String, containerId: SceneGraphItem.SceneGraphItemType, itemId: SceneGraphItem.SceneGraphItemType, skin: SceneGraphSkin)
    {
        let itemSize    : Float = 35 * graphZoom
        let totalWidth  : Float = 140 * graphZoom
        let headerHeight: Float = 30 * graphZoom
        var top         : Float = headerHeight + 7.5 * graphZoom
        
        let stageItem   = parent.stageItem!
        
        if stageItem.values["\(graphId)X"] == nil {
            stageItem.values["\(graphId)X"] = 0
        }
        
        if stageItem.values["\(graphId)Y"] == nil {
            stageItem.values["\(graphId)Y"] = 0
        }

        let x           : Float = parent.rect.x + stageItem.values["\(graphId)X"]! * graphZoom
        let y           : Float = parent.rect.y + stageItem.values["\(graphId)Y"]! * graphZoom

        if let list = parent.stageItem!.componentLists[listId] {
            
            let amount : Float = Float(list.count)
            let height : Float = amount * itemSize + headerHeight + 15 * graphZoom
            
            let container = SceneGraphItem(containerId, stage: parent.stage, stageItem: stageItem)
            container.rect.set(x, y, totalWidth, height)
            itemMap[UUID()] = container
            
            mmView.drawLine.draw(sx: rect.x + parent.rect.x + parent.rect.width / 2, sy: rect.y + parent.rect.y + parent.rect.height / 2, ex: rect.x + x + totalWidth / 2, ey: rect.y + y + headerHeight / 2, radius: 1, fillColor: skin.normalBorderColor)
            
            mmView.drawBox.draw(x: rect.x + x, y: rect.y + y, width: totalWidth, height: height, round: 12, borderSize: 1, fillColor: skin.normalInteriorColor, borderColor: skin.normalBorderColor)
            
            drawPlusButton(item: container, rect: MMRect(rect.x + x + totalWidth - (plusLabel != nil ? plusLabel!.rect.width : 0) - 10 * graphZoom, rect.y + y + 4 * graphZoom, headerHeight, headerHeight), cb: { () in
                self.addItem(container, name: name, listId: listId)
            }, skin: skin)
            
            skin.font.getTextRect(text: name, scale: skin.fontScale, rectToUse: skin.tempRect)
            
            mmView.drawText.drawText(skin.font, text: name, x: rect.x + x + 10 * graphZoom, y: rect.y + y + 7 * graphZoom, scale: skin.fontScale, color: skin.normalTextColor)
            
            mmView.drawLine.draw(sx: rect.x + x + 4 * graphZoom, sy: rect.y + y + headerHeight, ex: rect.x + x + totalWidth - 8 * graphZoom, ey: rect.y + y + headerHeight, radius: 0.6, fillColor: skin.normalBorderColor)

            for comp in list {
                
                let item = SceneGraphItem(itemId, stage: parent.stage, stageItem: stageItem, component: comp)
                item.rect.set(x, y + top, totalWidth, itemSize)
                itemMap[comp.uuid] = item
                
                if comp === currentComponent {
                    mmView.drawBox.draw( x: rect.x + item.rect.x + 1, y: rect.y + item.rect.y, width: totalWidth - 2, height: itemSize, round: 0, fillColor: skin.selectedBorderColor)
                }
                
                if stageItem.componentLabels[comp.libraryName] == nil || stageItem.componentLabels[comp.libraryName]!.scale != skin.fontScale {
                    stageItem.componentLabels[comp.libraryName] = MMTextLabel(mmView, font: mmView.openSans, text: comp.libraryName, scale: skin.fontScale, color: skin.normalTextColor)
                }
                if let label = stageItem.componentLabels[comp.libraryName] {
                    label.rect.x = rect.x + item.rect.x + (totalWidth - label.rect.width) / 2
                    label.rect.y = rect.y + item.rect.y + (itemSize - skin.lineHeight) / 2
                    label.draw()
                }
                top += itemSize
            }
        }
    }
}

