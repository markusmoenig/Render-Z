//
//  LeftRegion.swift
//  Framework
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class LeftRegion: MMRegion
{
    enum LeftRegionMode
    {
        case Closed, Shapes, Materials
    }
    
    var mode            : LeftRegionMode
    var app             : App
    
    var shapeSelector   : ShapeSelector
    var textureWidget   : MMTextureWidget
    var scrollArea      : ShapeScrollArea
    var animating       : Bool = false

    init( _ view: MMView, app: App )
    {
        self.app = app
        mode = .Shapes

        shapeSelector = ShapeSelector(view, width : 200)
        textureWidget = MMTextureWidget( view, texture: shapeSelector.compute!.texture )

        scrollArea = ShapeScrollArea(view, app: app)
        
        super.init( view, type: .Left )
        
        rect.width = 200
        self.app.topRegion!.shapesButton.addState( .Checked )

        view.registerWidget(scrollArea, region:self)
    }
    
    func setMode(_ mode: LeftRegionMode )
    {
        if animating { return }
        if self.mode == mode && mode != .Closed {
            mmView.startAnimate( startValue: rect.width, endValue: 0, duration: 500, cb: { (value,finished) in
                self.rect.width = value
                if finished {
                    self.animating = false
                    self.mode = .Closed
                    self.app.topRegion!.shapesButton.removeState( .Checked )
                    self.app.topRegion!.materialsButton.removeState( .Checked )
                }
            } )
            animating = true
        } else if rect.width != 200 {
            
            mmView.startAnimate( startValue: rect.width, endValue: 200, duration: 500, cb: { (value,finished) in
                if finished {
                    self.animating = false
                }
                self.rect.width = value
            } )
            animating = true
        }
        self.mode = mode
    }
    
    /*
    func renderShapesTexture()
    {
        let width = Float(compute.texture.width)
        let height = Float(compute.texture.height)
        let round : Float = 20
        let borderSize : Float = 10
        let gradientColor1 : float4 = float4( 0, 0, 0, 1)
        let gradientColor2 : float4 = float4( 1, 1, 1, 1)
        let borderColor : float4 = float4( 0.5, 0.5, 0.5, 1)
        
        let settings: [Float] = [
            width, height,
            round, borderSize,
            0, 0,
            0, 1,
            gradientColor1.x, gradientColor1.y, gradientColor1.z, gradientColor1.w,
            gradientColor2.x, gradientColor2.y, gradientColor2.z, gradientColor2.w,
            borderColor.x, borderColor.y, borderColor.z, borderColor.w
        ];
        
        let buffer = mmView.renderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
        compute.run( kernelState, inBuffer: buffer )
    }*/
    
    override func build()
    {
        if mode != .Closed {
            super.build()
            mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: vector_float4( 0, 0, 0, 1 ) )
            scrollArea.build(widget: textureWidget, area: rect, xOffset:(rect.width - 200))
        } else {
            rect.width = 0
        }
    }
}

/// The scroll area for the shapes
class ShapeScrollArea: MMScrollArea
{
    var app                 : App
    var mouseDownPos        : float2
    var mouseIsDown         : Bool = false
    
    var dragSource          : ShapeSelectorDrag? = nil
    var shapeAtMouse        : Shape?

    init(_ view: MMView, app: App)
    {
        self.app = app
        mouseDownPos = float2()
        super.init(view, orientation:.Vertical)
    }
    
    override func mouseDown(_ event: MMMouseEvent) {
        mouseDownPos.x = event.x - rect.x
        mouseDownPos.y = event.y - rect.y
        mouseIsDown = true
        shapeAtMouse = app.leftRegion!.shapeSelector.selectAt(mouseDownPos.x,mouseDownPos.y)
    }
    
    override func mouseMoved(_ event: MMMouseEvent) {
        if mouseIsDown && dragSource == nil {
            dragSource = app.leftRegion!.shapeSelector.createDragSource(mouseDownPos.x,mouseDownPos.y)
            dragSource?.sourceWidget = self
            mmView.dragStarted(source: dragSource!)
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent) {
        mouseIsDown = false
    }
    
    override func dragTerminated() {
        dragSource = nil
        mmView.unlockFramerate()
    }
}
