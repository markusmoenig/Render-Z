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
        rect.height = 160
        app.editor.drawRegion(self)
    }
}
