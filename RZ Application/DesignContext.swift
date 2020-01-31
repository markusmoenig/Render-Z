//
//  DesignContext.swift
//  Shape-Z
//
//  Created by Markus Moenig on 29/01/20.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class DesignContext : MMWidget
{
    var mouseIsDown         : Bool = false
    var mouseDownPos        : SIMD2<Float> = SIMD2<Float>()
    
    override init(_ view: MMView)
    {
        super.init(view)

    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
        
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
    }
    
    //override func mouseLeave(_ event: MMMouseEvent) {
    //    hoverItem = nil
    //}
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
    }
}
