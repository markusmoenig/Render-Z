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

    var compute         : MMCompute
    var kernelState     : MTLComputePipelineState?
    
    var shapeSelector   : ShapeSelector
    var textureWidget   : MMTextureWidget
    var scrollArea      : MMScrollArea

    init( _ view: MMView, app: App )
    {
        self.app = app
        mode = .Closed
        
        compute = MMCompute()
        compute.allocateTexture(width: 200, height: 1000)
//        textureWidget = MMTextureWidget( view, texture: compute.texture )
        kernelState = compute.createState(name: "cubeGradient")

        shapeSelector = ShapeSelector(width : 200)
        textureWidget = MMTextureWidget( view, texture: shapeSelector.compute!.texture )

        scrollArea = MMScrollArea(view, orientation:.Vertical)
        
        super.init( view, type: .Left )

        scrollArea.clickedCB = { (x,y) -> Void in
            print( "scrollArea clicked", x - self.rect.x, y - self.rect.y )
            self.shapeSelector.selectAt(x - self.rect.x, y - self.rect.y)
        }
        
        view.registerWidget(scrollArea, region:self)
    }
    
    func setMode(_ mode: LeftRegionMode )
    {
        if self.mode == mode && mode != .Closed {
            startAnimation( 0, startValue: rect.width, finishedCB: {
                print( "Closed" )
                self.mode = .Closed
                self.app.topRegion!.shapesButton.removeState( .Checked )
                self.app.topRegion!.materialsButton.removeState( .Checked )
            } )

        } else if rect.width != 200 {
            startAnimation( 200, finishedCB: { print( "Opened" ) } )
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
            mmView.drawCube.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0,  fillColor : float4( 0.125, 0.125, 0.125, 1), borderColor: vector_float4( 0, 0, 0, 1 ) )
            scrollArea.build(widget: textureWidget, area: rect, xOffset:(rect.width - 200))
        } else {
            rect.width = 0
        }
    }
}
