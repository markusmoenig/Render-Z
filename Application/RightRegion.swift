//
//  RightRegion.swift
//  Framework
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class RightRegion: MMRegion
{
    var app             : App
    
    init( _ view: MMView, app: App )
    {
        self.app = app
        super.init( view, type: .Right )
    }
    
    override func build()
    {
        rect.width = 200
        rect.x = mmView.renderer.cWidth - rect.width
        mmView.drawCube.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 2,  fillColor : float4( 0.706, 0.416, 0.431, 1), borderColor: vector_float4( 0, 0, 0, 1 ) )
    }
}
