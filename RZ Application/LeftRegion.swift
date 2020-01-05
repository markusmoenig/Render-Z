//
//  LeftRegion.swift
//  Framework
//
//  Created by Markus Moenig on 26/12/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class LeftRegion: MMRegion
{
    var app             : App
    
    init( _ view: MMView, app: App )
    {
        self.app = app
        super.init( view, type: .Left )
        
        rect.width = 200
    }

    override func build()
    {
        app.currentEditor.drawRegion(self)
    }
}
