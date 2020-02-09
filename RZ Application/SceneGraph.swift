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
    let normalInteriorColor     = SIMD4<Float>(1,1,1,0.4)
    let normalBorderColor       = SIMD4<Float>(0.5,0.5,0.5,1)
    let normalTextColor         = SIMD4<Float>(0.8,0.8,0.8,1)
    
    let tempRect                = MMRect()
    let fontScale               : Float = 0.4
    let font                    : MMFont
    let lineHeight              : Float
    
    init(_ font: MMFont) {
        self.font = font
        self.lineHeight = font.getLineHeight(fontScale)
    }
}

class SceneGraphItem {
        
    enum SceneGraphItemType {
        case StageItem, ShapeItem, BooleanItem, EmptyShape
    }
    
    var itemType                : SceneGraphItemType
    
    let stageItem               : StageItem
    let component               : CodeComponent?
    let parentComponent         : CodeComponent?
    
    let rect                    : MMRect = MMRect()
    
    init(_ type: SceneGraphItemType, stageItem: StageItem, component: CodeComponent? = nil, parentComponent: CodeComponent? = nil)
    {
        itemType = type
        self.stageItem = stageItem
        self.component = component
        self.parentComponent = parentComponent
    }
}

class SceneGraph                : MMWidget
{
    var fragment                : MMFragment
    
    var textureWidget           : MMTextureWidget
    var scrollArea              : MMScrollArea
    
    var needsUpdate             : Bool = true
    var graphRect               : MMRect = MMRect()
    
    var itemMap                  : [UUID:SceneGraphItem] = [:]
    
    var graphX                  : Float = 100
    var graphY                  : Float = 100
    var graphZoom               : Float = 1

    var dispatched              : Bool = false
    
    var currentStageItem        : StageItem? = nil
    var currentComponent        : CodeComponent? = nil
    
    var menuWidget              : MMMenuWidget
    var menuUUID                : UUID? = nil

    //var map             : [MMRe]
    
    override init(_ view: MMView)
    {
        scrollArea = MMScrollArea(view, orientation: .Vertical)
        menuWidget = MMMenuWidget(view)

        fragment = MMFragment(view)
        fragment.allocateTexture(width: 10, height: 10)
        textureWidget = MMTextureWidget( view, texture: fragment.texture )
        
        super.init(view)
        
        zoom = view.scaleFactor
        textureWidget.zoom = zoom
    }
    
    func activate()
    {
        mmView.widgets.insert(menuWidget, at: 0)
    }
    
    func deactivate()
    {
        mmView.deregisterWidgets(widgets: menuWidget)
    }
     
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        #if os(iOS)
        // If there is a selected shape, don't scroll
        xGraph -= event.deltaX! * 2
        yGraph -= event.deltaY! * 2
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
    
    func setCurrent(stageItem: StageItem? = nil, component: CodeComponent? = nil)
    {
        currentStageItem = stageItem
        currentComponent = nil
        menuUUID = nil
        
        if let stageItem = stageItem {
            globalApp!.project.selected?.setSelected(stageItem)
            if let defaultComponent = stageItem.components[stageItem.defaultName] {
                globalApp!.currentEditor.setComponent(defaultComponent)
                //globalApp!.currentEditor.updateOnNextDraw(compile: false)
                currentComponent = defaultComponent
            }
            menuUUID = stageItem.uuid
        }
        
        if let component = component {
            globalApp!.currentEditor.setComponent(component)
            globalApp!.currentEditor.updateOnNextDraw(compile: true)
            currentComponent = component
            
            menuUUID = component.uuid
        }
        
        if let _ = menuUUID {
            activate()
        } else {
            deactivate()
        }
        
        needsUpdate = true
        mmView.update()
    }
    
    func setCurrent(component: CodeComponent? = nil)
    {
        currentComponent = component
        if let component = component {
            globalApp!.currentEditor.setComponent(component)
            globalApp!.currentEditor.updateOnNextDraw(compile: false)
        }
    }
    
    func clickAt(x: Float, y: Float) -> Bool
    {
        var consumed : Bool = false
        
        let realX : Float = (x - rect.x - graphX) / graphZoom
        let realY : Float = (y - rect.y - graphY) / graphZoom

        for (_,item) in itemMap {
            
            if item.rect.contains(realX, realY) {
                consumed = true
                
                if item.itemType == .EmptyShape {
                    getShape(item: item, replace: false)
                } else {
                    setCurrent(stageItem: item.stageItem, component: item.component)
                }
                break
            }
        }
        
        return consumed
    }
     
    override func update()
    {
        parse(scene: globalApp!.project.selected!, draw: false)
        if fragment.width != graphRect.width * zoom || fragment.height != graphRect.height * zoom {
            fragment.allocateTexture(width: graphRect.width * zoom, height: graphRect.height * zoom, mipMaps: true)
        }
        textureWidget.setTexture(fragment.texture)
                 
        if fragment.encoderStart() {
            parse(scene: globalApp!.project.selected!)
            fragment.encodeEnd()
        }
        
        if let blitEncoder = fragment.commandBuffer!.makeBlitCommandEncoder() {
            blitEncoder.generateMipmaps(for: fragment.texture)
            blitEncoder.endEncoding()
        }
        
        if let uuid = menuUUID {
            buildMenu(uuid: uuid)
        }
        
        needsUpdate = false
    }
     
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        if needsUpdate {
            update()
        }

        mmView.renderer.setClipRect(rect)
        mmView.drawTexture.draw(fragment.texture, x: rect.x + graphX, y: rect.y + graphY, zoom: zoom / graphZoom)
        
        if let uuid = menuUUID {
            if let item = itemMap[uuid]{
                
                menuWidget.rect.x = rect.x + item.rect.x * graphZoom + graphX// / graphZoom
                menuWidget.rect.y = rect.y + item.rect.y * graphZoom + graphY// / graphZoom
                menuWidget.rect.width = 24 * graphZoom //30
                menuWidget.rect.height = 22 * graphZoom //28
                menuWidget.draw()
            }
        }
        
        mmView.renderer.setClipRect()
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
                self.setCurrent(stageItem: item.stageItem, component: comp)
            }
        })
    }
    
    ///Build the menu
    func buildMenu(uuid: UUID)
    {
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
    }
    
    /// Increases the scene graph rect by the given rect if necessary
    func checkDimensions(_ x: Float,_ y: Float,_ width: Float,_ height: Float)
    {
        if x < graphRect.x {
            graphRect.x = x
        }
        if y < graphRect.y {
            graphRect.y = y
        }
        if width + x > graphRect.right() {
            graphRect.width = width + x
        }
        if height - y > graphRect.bottom() {
            graphRect.height = height - y
        }
    }
    
    /// Adjusts the x offset
    func drawXOffset() -> Float
    {
        if graphRect.x < 0 { return abs(graphRect.x) }
        return 0
    }
    
    /// Adjusts the y offset
    func drawYOffset() -> Float
    {
        if graphRect.y < 0 { return abs(graphRect.y) }
        return 0
    }
    
    func parse(scene: Scene, draw: Bool = true)
    {
        graphRect.clear()
        itemMap = [:]
        let skin : SceneGraphSkin = SceneGraphSkin(mmView.openSans)
        
        let stage = scene.getStage(.ShapeStage)
        let objects = stage.getChildren()
        for o in objects {
            var x = o.values["_graphX"]!
            var y = o.values["_graphY"]!
            
            skin.font.getTextRect(text: o.name, scale: skin.fontScale, rectToUse: skin.tempRect)

            let radius : Float = skin.tempRect.width + 10
            
            x -= radius / 2
            y -= radius / 2
            checkDimensions(x, y, radius, radius)
            
            let item = SceneGraphItem(.StageItem, stageItem: o)
            item.rect.set(x + drawXOffset(), y + drawYOffset(), radius, radius)
            itemMap[o.uuid] = item
            
            if draw {
                mmView.drawSphere.draw(x: x + drawXOffset(), y: y + drawYOffset(), radius: radius / zoom, borderSize: 2, fillColor: o === currentStageItem ? skin.normalBorderColor : skin.normalInteriorColor, borderColor: skin.normalBorderColor, fragment: fragment)
                
                mmView.drawText.drawText(skin.font, text: o.name, x: x + drawXOffset() + (radius - skin.tempRect.width) / 2, y: y + drawYOffset() + (radius - skin.lineHeight) / 2, scale: skin.fontScale, color: skin.normalTextColor, fragment: fragment)
            }
            drawShapesBox(stageItem: o, x: x + radius + 40, y: y - 40, draw: draw, skin: skin)
        }
        
        if graphRect.width == 0 { graphRect.width = 1 }
        if graphRect.height == 0 { graphRect.height = 1 }
        
        graphRect.width += 50
        graphRect.height += 50
        
        //if graphRect.x < 0 { graphRect.width += -graphRect.x }
        //if graphRect.y < 0 { graphRect.height += -graphRect.y }

        //print("parse Result", graphRect.x, graphRect.y, graphRect.width, graphRect.height)
    }
    
    func drawShapesBox(stageItem: StageItem, x: Float, y: Float, draw: Bool = true, skin: SceneGraphSkin)
    {
        let spacing     : Float = 22
        let itemSize    : Float = 70
        let totalWidth  : Float = 140
        let headerHeight: Float = 20
        var top         : Float = 20 + 7.5
        
        if let list = stageItem.getComponentList("shapes") {
            
            let amount : Float = Float(list.count) + 1
            let height : Float = amount * itemSize + (amount - 1) * spacing + headerHeight + 15
            
            checkDimensions(x, y, totalWidth, height)

            if draw {
                mmView.drawBox.draw(x: x + drawXOffset(), y: y + drawYOffset(), width: totalWidth, height: height, round: 12, borderSize: 2, fillColor: skin.normalInteriorColor, borderColor: skin.normalBorderColor, fragment: fragment)
                
                //mmView.drawBox.draw(x: x + drawXOffset(), y: y + drawYOffset(), width: totalWidth, height: headerHeight, round: 0, borderSize: 0, fillColor: skin.normalBorderColor, borderColor: skin.normalInteriorColor, fragment: fragment)
                
                skin.font.getTextRect(text: "Shapes", scale: skin.fontScale, rectToUse: skin.tempRect)
                mmView.drawText.drawText(skin.font, text: "Shapes", x: x + drawXOffset() + (totalWidth - skin.tempRect.width) / 2, y: y + drawYOffset() + 4, scale: skin.fontScale, color: skin.normalTextColor, fragment: fragment)
        
                for (index, comp) in list.enumerated() {
                
                    let item = SceneGraphItem(.ShapeItem, stageItem: stageItem, component: comp)
                    item.rect.set(x + drawXOffset(), y + top + drawYOffset(), totalWidth, itemSize)
                    itemMap[comp.uuid] = item
                    
                    if comp === currentComponent {
                        mmView.drawBox.draw( x: item.rect.x, y: item.rect.y, width: totalWidth, height: itemSize, round: 0, borderSize: 0, fillColor: SIMD4<Float>(0.4,0.4,0.4,1), borderColor: skin.normalBorderColor, fragment: fragment)
                    }
                    
                    if let thumb = globalApp!.thumbnail.request(comp.libraryName + " :: SDF" + getCurrentModeId(), comp) {
                        mmView.drawTexture.draw(thumb, x: item.rect.x + (totalWidth - 200 / 3) / 2, y: item.rect.y, zoom: 3, fragment: fragment)
                    }
                
                    top += itemSize
                    if let sub = comp.subComponent, index < list.count - 1 {
                        let subItem = SceneGraphItem(.BooleanItem, stageItem: stageItem, component: sub, parentComponent: comp)
                        subItem.rect.set(x + drawXOffset(), y + top + drawYOffset(), totalWidth, spacing)
                        itemMap[sub.uuid] = subItem

                        if sub === currentComponent {
                            mmView.drawBox.draw( x: subItem.rect.x, y: subItem.rect.y, width: totalWidth, height: spacing, round: 0, borderSize: 0, fillColor: SIMD4<Float>(0.4,0.4,0.4,1), borderColor: skin.normalBorderColor, fragment: fragment)
                        }
                        
                        skin.font.getTextRect(text: sub.libraryName, scale: skin.fontScale, rectToUse: skin.tempRect)
                        mmView.drawText.drawText(skin.font, text: sub.libraryName, x: x + drawXOffset() + (totalWidth - skin.tempRect.width) / 2, y: y + top + drawYOffset() + 2, scale: skin.fontScale, color: skin.normalTextColor, fragment: fragment)
                    }
                    top += spacing
                }
            
                // Empty
//                if list.count > 0 {
//                    top -= spacing
//                }
                let item = SceneGraphItem(.EmptyShape, stageItem: stageItem)
                item.rect.set(x + drawXOffset() + (totalWidth - itemSize) / 2, y + drawYOffset() + top, itemSize, itemSize)
                itemMap[UUID()] = item
                
                mmView.drawBox.draw(x: item.rect.x, y: item.rect.y, width: itemSize, height: itemSize, round: 0, borderSize: 2, fillColor: skin.normalInteriorColor, borderColor: skin.normalBorderColor, fragment: fragment)
            }
        }
    }
}

