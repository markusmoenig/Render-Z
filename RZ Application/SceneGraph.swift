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
    let normalInteriorColor     = SIMD4<Float>(1,1,1,0.1)
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
        case Stage, StageItem, ShapeItem, BooleanItem, EmptyShape
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

class SceneGraph                : MMWidget
{
    enum SceneGraphState {
        case Closed, Open
    }
    
    var sceneGraphState         : SceneGraphState = .Closed
    var animating               : Bool = false
    
    var needsUpdate             : Bool = true
    
    var itemMap                 : [UUID:SceneGraphItem] = [:]
    
    var graphX                  : Float = 100
    var graphY                  : Float = 200
    var graphZoom               : Float = 1

    var dispatched              : Bool = false
    
    var currentStage            : Stage? = nil
    var currentStageItem        : StageItem? = nil
    var currentComponent        : CodeComponent? = nil
    
    var currentUUID             : UUID? = nil
    
    var dragItem                : SceneGraphItem? = nil
    var mouseDownPos            : SIMD2<Float> = SIMD2<Float>(0,0)
    var mouseDownItemPos        : SIMD2<Float> = SIMD2<Float>(0,0)

    var currentWidth            : Float = 0
    var openWidth               : Float = 300

    var toolBarWidgets          : [MMWidget] = []

    var addMenuWidget           : MMMenuWidget
    
    //var map             : [MMRe]
    
    override init(_ view: MMView)
    {
        addMenuWidget = MMMenuWidget(view, type: .LabelMenu)
        addMenuWidget.setText("Add", 0.45)
        
        super.init(view)
        
        zoom = view.scaleFactor

        addMenuWidget.setItems([
            MMMenuItem(text: "Object", cb: { () in
                getStringDialog(view: self.mmView, title: "New Object", message: "Object name", defaultValue: "New Object", cb: { (value) -> Void in
                    if let scene = globalApp!.project.selected {
                        
                        let shapeStage = scene.getStage(.ShapeStage)
                        let objectItem = shapeStage.createChild(value)
                        
                        objectItem.values["_graphX"]! += 100

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
        mmView.widgets.insert(addMenuWidget, at: 0)
    }
    
    func deactivate()
    {
        for w in toolBarWidgets {
            mmView.deregisterWidget(w)
        }
        mmView.deregisterWidget(addMenuWidget)
    }
     
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        #if os(iOS)
        // If there is a selected shape, don't scroll
        graphX -= event.deltaX! * 2
        graphY -= event.deltaY! * 2
        #elseif os(OSX)
        if mmView.commandIsDown && event.deltaY! != 0 {
            graphZoom += event.deltaY! * 0.003
            graphZoom = max(0.3, graphZoom)
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
        /*
         if firstTouch == true {
             let realScale : Float = codeContext.fontScale
             pinchBuffer = realScale
         }
         
         codeContext.fontScale = max(0.2, pinchBuffer * scale)
         codeContext.fontScale = min(2, codeContext.fontScale)
         
         editor.updateOnNextDraw(compile: false)*/
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
        globalApp!.sceneGraph.clickAt(x: event.x, y: event.y)
        if let uuid = currentUUID {
            dragItem = itemMap[uuid]
            
            mouseDownPos.x = event.x
            mouseDownPos.y = event.y
            
            if let drag = dragItem {

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
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if let drag = dragItem {

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
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        dragItem = nil
        mmView.mouseTrackWidget = nil
    }
    
    func clickAt(x: Float, y: Float)
    {
        let realX : Float = (x - rect.x)
        let realY : Float = (y - rect.y)

        for (_,item) in itemMap {
            if item.rect.contains(realX, realY) {
                if item.itemType == .EmptyShape {
                    getShape(item: item, replace: false)
                } else {
                    setCurrent(stage: item.stage, stageItem: item.stageItem, component: item.component)
                }
                break
            }
        }
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
            w.rect.y = rect.y + 4
            w.draw()
            left += w.rect.width
        }
        
        addMenuWidget.rect.x = rect.right() - addMenuWidget.rect.width - 5
        addMenuWidget.rect.y = rect.y + 4
        addMenuWidget.draw()
        
        if let scene = globalApp!.project.selected {
            mmView.renderer.setClipRect(MMRect(rect.x, rect.y + 30, rect.width, rect.height - 30))
            parse(scene: scene)
            mmView.renderer.setClipRect()
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
        let aMid = SIMD2<Float>(a.rect.x + a.rect.width / 2, a.rect.y + a.rect.height / 2)
        let bMid = SIMD2<Float>(b.rect.x + b.rect.width / 2, b.rect.y + b.rect.height / 2)
        
        let deltaX : Float = bMid.x - aMid.x
        let deltaY : Float = bMid.y - aMid.y
        let L : Float = sqrt(deltaX * deltaX + deltaY * deltaY)
        
        let radiusA : Float = a.rect.width / 2 / L
        let radiusB : Float = b.rect.width / 2 / L

        mmView.drawLine.draw(sx: rect.x + bMid.x - deltaX * radiusB - 1, sy: rect.y + bMid.y - deltaY * radiusB - 1, ex: rect.x + aMid.x + deltaX * radiusA - 1, ey: rect.y + aMid.y + deltaY * radiusA - 1, radius: 1, fillColor: skin.normalBorderColor)
    }
    
    func parse(scene: Scene)
    {
        itemMap = [:]
        let skin : SceneGraphSkin = SceneGraphSkin(mmView.openSans, fontScale: 0.4 * graphZoom)
        
        // Draw World
        var stage = scene.getStage(.PreStage)
        
        let name = stage.name + " " + getCurrentModeId()
        skin.font.getTextRect(text: name, scale: skin.fontScale, rectToUse: skin.tempRect)
        let diameter : Float = skin.tempRect.width + 10 * graphZoom

        let x = (graphX + stage.values["_graphX"]!) * graphZoom - diameter / 2
        let y = (graphY + stage.values["_graphY"]!) * graphZoom - diameter / 2
        
        let worldItem = SceneGraphItem(.StageItem, stage: stage)
        worldItem.rect.set(x, y, diameter, diameter)
        itemMap[stage.uuid] = worldItem
        
        mmView.drawSphere.draw(x: rect.x + x, y: rect.y + y, radius: diameter / 2, borderSize: 1, fillColor: stage === currentStage ? skin.normalBorderColor : skin.normalInteriorColor, borderColor: skin.normalBorderColor)
            
        mmView.drawText.drawText(skin.font, text: name, x: rect.x + x + (diameter - skin.tempRect.width) / 2, y: rect.y + y + (diameter - skin.lineHeight) / 2, scale: skin.fontScale, color: skin.normalTextColor)
        
        let childs = stage.getChildren()
        for childItem in childs {
            
            skin.font.getTextRect(text: childItem.name, scale: skin.fontScale, rectToUse: skin.tempRect)
            let diameter : Float = skin.tempRect.width + 10 * graphZoom

            let cX = x + childItem.values["_graphX"]! * graphZoom - diameter / 2
            let cY = y + childItem.values["_graphY"]! * graphZoom - diameter / 2

            let comp = childItem.components[childItem.defaultName]!
            let item = SceneGraphItem(.StageItem, stage: stage, stageItem: childItem, component: comp)
            item.rect.set(cX, cY, diameter, diameter)
            itemMap[comp.uuid] = item
            
            mmView.drawSphere.draw(x: rect.x + cX, y: rect.y + cY, radius: diameter / 2, borderSize: 1, fillColor: childItem === currentStageItem ? skin.normalBorderColor : skin.normalInteriorColor, borderColor: skin.normalBorderColor)
            
            mmView.drawText.drawText(skin.font, text: childItem.name, x: rect.x + cX + (diameter - skin.tempRect.width) / 2, y: rect.y + cY + (diameter - skin.lineHeight) / 2, scale: skin.fontScale, color: skin.normalTextColor)
            
            drawLineBetweenCircles(worldItem, item, skin)
        }
        
        // Draw Objects
        stage = scene.getStage(.ShapeStage)
        let objects = stage.getChildren()
        for o in objects {
            
            skin.font.getTextRect(text: o.name, scale: skin.fontScale, rectToUse: skin.tempRect)
            let diameter : Float = skin.tempRect.width + 10 * graphZoom
            
            let x = (graphX + o.values["_graphX"]!) * graphZoom - diameter / 2
            let y = (graphY + o.values["_graphY"]!) * graphZoom - diameter / 2
            
            let item = SceneGraphItem(.StageItem, stage: stage, stageItem: o)
            item.rect.set(x, y, diameter, diameter)
            itemMap[o.uuid] = item
            
            mmView.drawSphere.draw(x: rect.x + x, y: rect.y + y, radius: diameter / zoom, borderSize: 1, fillColor: o === currentStageItem ? skin.normalBorderColor : skin.normalInteriorColor, borderColor: skin.normalBorderColor)
            
            mmView.drawText.drawText(skin.font, text: o.name, x: rect.x + x + (diameter - skin.tempRect.width) / 2, y: rect.y + y + (diameter - skin.lineHeight) / 2, scale: skin.fontScale, color: skin.normalTextColor)
            
            drawShapesBox(stage: stage, stageItem: o, x: x + diameter + 40, y: y - 40, skin: skin)
        }
    }
    
    func drawShapesBox(stage: Stage, stageItem: StageItem, x: Float, y: Float, skin: SceneGraphSkin)
    {
        let spacing     : Float = 22 * graphZoom
        let itemSize    : Float = 70 * graphZoom
        let totalWidth  : Float = 140 * graphZoom
        let headerHeight: Float = 20 * graphZoom
        var top         : Float = headerHeight + 7.5 * graphZoom
        
        if let list = stageItem.getComponentList("shapes") {
            
            let amount : Float = Float(list.count) + 1
            let height : Float = amount * itemSize + (amount - 1) * spacing + headerHeight + 15 * graphZoom
            
            mmView.drawBox.draw(x: rect.x + x, y: rect.y + y, width: totalWidth, height: height, round: 12, borderSize: 2, fillColor: skin.normalInteriorColor, borderColor: skin.normalBorderColor)
            
            //mmView.drawBox.draw(x: x + drawXOffset(), y: y + drawYOffset(), width: totalWidth, height: headerHeight, round: 0, borderSize: 0, fillColor: skin.normalBorderColor, borderColor: skin.normalInteriorColor, fragment: fragment)
            
            skin.font.getTextRect(text: "Shapes", scale: skin.fontScale, rectToUse: skin.tempRect)
            mmView.drawText.drawText(skin.font, text: "Shapes", x: rect.x + x + (totalWidth - skin.tempRect.width) / 2, y: rect.y + y + 4, scale: skin.fontScale, color: skin.normalTextColor)
    
            for (index, comp) in list.enumerated() {
            
                let item = SceneGraphItem(.ShapeItem, stage: stage, stageItem: stageItem, component: comp)
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
                    let subItem = SceneGraphItem(.BooleanItem, stage: stage, stageItem: stageItem, component: sub, parentComponent: comp)
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
        
            // Empty
//                if list.count > 0 {
//                    top -= spacing
//                }
            let item = SceneGraphItem(.EmptyShape, stage: stage, stageItem: stageItem)
            item.rect.set(x + (totalWidth - itemSize) / 2, y + top, itemSize, itemSize)
            itemMap[UUID()] = item
            
            mmView.drawBox.draw(x: rect.x + item.rect.x, y: rect.y + item.rect.y, width: itemSize, height: itemSize, round: 0, borderSize: 1, fillColor: skin.normalInteriorColor, borderColor: skin.normalBorderColor)
        }
    }
}

