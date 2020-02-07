//
//  SceneGraph.swift
//  Shape-Z
//
//  Created by Markus Moenig on 1/2/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class SceneGraphSkin {
    
    let normalInteriorColor     = SIMD4<Float>(0,0,0,0)
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
    let subComponent            : CodeComponent?
    
    let rect                    : MMRect = MMRect()
    
    init(_ type: SceneGraphItemType, stageItem: StageItem, component: CodeComponent? = nil, subComponent: CodeComponent? = nil)
    {
        itemType = type
        self.stageItem = stageItem
        self.component = component
        self.subComponent = subComponent
    }
}

class SceneGraph                : MMWidget
{
    var fragment                : MMFragment
    
    var textureWidget           : MMTextureWidget
    var scrollArea              : MMScrollArea
    
    var needsUpdate             : Bool = true
    var graphRect               : MMRect = MMRect()
    
    var items                   : [SceneGraphItem] = []
    
    var graphX                  : Float = 100
    var graphY                  : Float = 100
    var graphZoom               : Float = 1

    var dispatched              : Bool = false

    //var map             : [MMRe]
    
    override init(_ view: MMView)
    {
        scrollArea = MMScrollArea(view, orientation: .Vertical)

        fragment = MMFragment(view)
        fragment.allocateTexture(width: 10, height: 10)
        textureWidget = MMTextureWidget( view, texture: fragment.texture )
        
        super.init(view)
        
        zoom = view.scaleFactor
        textureWidget.zoom = zoom
    }
    
    override func mouseLeave(_ event: MMMouseEvent)
    {
    }
     
    override func mouseMoved(_ event: MMMouseEvent)
    {
    }
     
    override func mouseDown(_ event: MMMouseEvent)
    {
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
    
    func clickAt(x: Float, y: Float) -> Bool
    {
        var consumed : Bool = false
        
        //print( graphRect.x, graphRect.y)
        let realX : Float = (x - rect.x - graphX) * graphZoom + graphRect.x
        let realY : Float = (y - rect.y - graphY) * graphZoom + graphRect.y

        print(1, realX, realY)

        for item in items {
            print(2, item.rect.x, item.rect.y)

            if item.rect.contains(realX, realY) {
                consumed = true
                print("yeah")
                break
            }
        }
        
        return consumed
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
     
    override func update()
    {
        parse(scene: globalApp!.project.selected!, draw: false)
        if fragment.width != graphRect.width * zoom || fragment.height != graphRect.height * zoom {
            fragment.allocateTexture(width: graphRect.width * zoom, height: graphRect.height * zoom, mipMaps: true)
        }
        textureWidget.setTexture(fragment.texture)
                 
        if fragment.encoderStart()
        {
            parse(scene: globalApp!.project.selected!)
            
            fragment.encodeEnd()
        }
        
        if let blitEncoder = fragment.commandBuffer!.makeBlitCommandEncoder() {
            blitEncoder.generateMipmaps(for: fragment.texture)
            blitEncoder.endEncoding()
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
        mmView.renderer.setClipRect()
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
        items = []
        let skin : SceneGraphSkin = SceneGraphSkin(mmView.openSans)
        
        let stage = scene.getStage(.ShapeStage)
        let objects = stage.getChildren()
        for o in objects {
            var x = o.values["graphX"]!
            var y = o.values["graphY"]!
            
            skin.font.getTextRect(text: o.name, scale: skin.fontScale, rectToUse: skin.tempRect)

            let radius : Float = skin.tempRect.width + 10
            
            x -= radius / 2
            y -= radius / 2
            checkDimensions(x, y, radius, radius)
            
            let item = SceneGraphItem(.StageItem, stageItem: o)
            item.rect.set(x, y, radius, radius)
            items.append(item)
            
            if draw {
                mmView.drawText.drawText(skin.font, text: o.name, x: x + drawXOffset() + (radius - skin.tempRect.width) / 2, y: y + drawYOffset() + (radius - skin.lineHeight) / 2, scale: skin.fontScale, color: skin.normalTextColor, fragment: fragment)
                
                mmView.drawSphere.draw(x: x + drawXOffset(), y: y + drawYOffset(), radius: radius / zoom, borderSize: 2, fillColor: skin.normalInteriorColor, borderColor: skin.normalBorderColor, fragment: fragment)
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
        let totalWidth  : Float = 160
        let headerHeight: Float = 20
        var top         : Float = 20 + 10
        
        if let list = stageItem.getComponentList("shapes") {
            
            let amount : Float = Float(list.count) + 1
            let height : Float = amount * itemSize + (amount - 1) * spacing + headerHeight + 20
            
            checkDimensions(x, y, totalWidth, height)

            if draw {
                mmView.drawBox.draw(x: x + drawXOffset(), y: y + drawYOffset(), width: totalWidth, height: height, round: 12, borderSize: 2, fillColor: skin.normalInteriorColor, borderColor: skin.normalBorderColor, fragment: fragment)
                
                //mmView.drawBox.draw(x: x + drawXOffset(), y: y + drawYOffset(), width: totalWidth, height: headerHeight, round: 0, borderSize: 0, fillColor: skin.normalBorderColor, borderColor: skin.normalInteriorColor, fragment: fragment)
                
                skin.font.getTextRect(text: "Shapes", scale: skin.fontScale, rectToUse: skin.tempRect)
                mmView.drawText.drawText(skin.font, text: "Shapes", x: x + drawXOffset() + (totalWidth - skin.tempRect.width) / 2, y: y + drawYOffset() + 2, scale: skin.fontScale, color: skin.normalTextColor, fragment: fragment)
        
                for comp in list {
                
                    let item = SceneGraphItem(.ShapeItem, stageItem: stageItem, component: comp)
                    item.rect.set(x, top, totalWidth, itemSize)
                    items.append(item)
                    
                    if let thumb = globalApp!.thumbnail.request(comp.libraryName + " :: SDF2D", comp) {
                        mmView.drawTexture.draw(thumb, x: x + drawXOffset() + (160 - 200 / 3) / 2, y: top, zoom: 3, fragment: fragment)
                    }
                
                    top += itemSize + spacing
                }
            
                // Empty
                //if list.count > 0 {
                //    top -= spacing
                //}
                let item = SceneGraphItem(.EmptyShape, stageItem: stageItem)
                item.rect.set(x + (totalWidth - itemSize) / 2, y + top, itemSize, itemSize)
                items.append(item)
                
                mmView.drawBox.draw(x: x + drawXOffset() + (totalWidth - itemSize) / 2, y: y + drawYOffset() + top, width: itemSize, height: itemSize, round: 0, borderSize: 2, fillColor: skin.normalInteriorColor, borderColor: skin.normalBorderColor, fragment: fragment)
            }
        }
    }
}

