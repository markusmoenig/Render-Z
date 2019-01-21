//
//  BottomRegion.swift
//  Framework
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class BottomRegion: MMRegion
{
    var app             : App
    
    init( _ view: MMView, app: App )
    {
        self.app = app
        super.init( view, type: .Bottom )
    }
    
    override func build()
    {
        rect.height = 150
        rect.y = mmView.renderer.cHeight - rect.height
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 2,  fillColor : float4( 0.192, 0.573, 0.478, 1), borderColor: vector_float4( 0, 0, 0, 1 ) )
    }
}
