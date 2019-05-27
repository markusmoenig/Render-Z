//
//  GameRegion.swift
//  Framework
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class GameRegion: MMRegion
{
    var app                     : GameApp
    var widget                  : GameWidget!
        
    init( _ view: MMView, app: GameApp )
    {
        self.app = app

        super.init( view, type: .Editor )
        
        widget = GameWidget(view, gameRegion: self, app: app)
        registerWidgets( widgets: widget! )
    }
    
    override func build()
    {
        widget.rect.copy(rect)
        
        mmView.drawBox.draw( x: 1, y: 0, width: mmView.renderer.width - 20, height: 44, round: 10, borderSize: 1, fillColor : float4(1, 1, 1, 1.000), borderColor: float4( 0.051, 0.051, 0.051, 1 ) )
    }
}
