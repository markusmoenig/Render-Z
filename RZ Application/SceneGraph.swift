//
//  SceneGraph.swift
//  Shape-Z
//
//  Created by Markus Moenig on 1/2/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class SceneGraph        : MMWidget
{
    var fragment        : MMFragment
    
    var textureWidget   : MMTextureWidget
    var scrollArea      : MMScrollArea
    
    var needsUpdate     : Bool = true
    var graphRect       : MMRect = MMRect()
    
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
     
    override func mouseUp(_ event: MMMouseEvent)
    {
    }
     
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        /*
         var prevScale = codeContext.fontScale
         
         #if os(OSX)
         if mmView.commandIsDown && event.deltaY! != 0 {
             prevScale += event.deltaY! * 0.01
             prevScale = max(0.2, prevScale)
             prevScale = min(2, prevScale)
             
             codeContext.fontScale = prevScale
             editor.updateOnNextDraw(compile: false)
         } else {
             scrollArea.mouseScrolled(event)
             scrollArea.checkOffset(widget: textureWidget, area: rect)
         }
         #endif*/
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
            fragment.allocateTexture(width: graphRect.width * zoom, height: graphRect.height * zoom)
        }
        textureWidget.setTexture(fragment.texture)
                 
        if fragment.encoderStart()
        {
            parse(scene: globalApp!.project.selected!)
            fragment.encodeEnd()
        }
        needsUpdate = false
    }
     
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        if needsUpdate {
            update()
        }

        mmView.drawTexture.draw(fragment.texture, x: rect.x + (rect.width - graphRect.width) / 2, y: rect.y + (rect.height - graphRect.height) / 2, zoom: zoom)
    }
    
    func checkDimensions(_ x: Float,_ y: Float,_ width: Float,_ height: Float)
    {
        if x < graphRect.x {
            graphRect.x = x
        }
        if y < graphRect.y {
            graphRect.y = y
        }
        if width > graphRect.width {
            graphRect.width = width
        }
        if height > graphRect.height {
            graphRect.height = height
        }
    }
    
    func drawXOffset() -> Float
    {
        if graphRect.x < 0 { return abs(graphRect.x) }
        return 0
    }
    
    func drawYOffset() -> Float
    {
        if graphRect.y < 0 { return abs(graphRect.y) }
        return 0
    }
    
    func parse(scene: Scene, draw: Bool = true)
    {
        graphRect.clear()
        
        let normalInteriorColor = SIMD4<Float>(0,0,0,0)
        let normalBorderColor = SIMD4<Float>(0.5,0.5,0.5,1)
        let normalTextColor = SIMD4<Float>(0.5,0.5,0.5,1)

        let tempRect = MMRect()
        let fontScale : Float = 0.4
        let font = mmView.openSans!
        let lineHeight : Float = font.getLineHeight(fontScale)
        
        let stage = scene.getStage(.ShapeStage)
        let objects = stage.getChildren()
        for o in objects {
            var x = o.values["graphX"]!
            var y = o.values["graphY"]!
            
            font.getTextRect(text: o.name, scale: fontScale, rectToUse: tempRect)

            let radius : Float = tempRect.width + 10
            
            x -= radius / 2
            y -= radius / 2
            checkDimensions(x, y, radius, radius)
            
            if draw {
                mmView.drawText.drawText(font, text: o.name, x: x + drawXOffset() + (radius - tempRect.width) / 2, y: y + drawYOffset() + (radius - lineHeight) / 2, scale: fontScale, color: normalTextColor, fragment: fragment)
                
                mmView.drawSphere.draw(x: x + drawXOffset(), y: y + drawYOffset(), radius: radius / zoom, borderSize: 2, fillColor: normalInteriorColor, borderColor: normalBorderColor, fragment: fragment)

                drawShapesBox(stageItem: o, x: x + radius + 40, y: y - 40, draw: draw)
            }
        }
        
        if graphRect.width == 0 { graphRect.width = 1 }
        if graphRect.height == 0 { graphRect.height = 1 }
        
        //print("parse Result", graphRect.x, graphRect.y, graphRect.width, graphRect.height)
    }
    
    func drawShapesBox(stageItem: StageItem, x: Float, y: Float, draw: Bool = true)
    {
        if let list = stageItem.getComponentList("shapes") {
            for c in list {
                
            }
        }
    }
}

