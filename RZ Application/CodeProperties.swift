//
//  CodeProperties.swift
//  Render-Z
//
//  Created by Markus Moenig on 30/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class CodeProperties    : MMWidget
{
    override init(_ view: MMView)
    {
        super.init(view)
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1) )
    }
}
