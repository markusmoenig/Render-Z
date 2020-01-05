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
        
        rect.width = 0
    }
    
    override func build()
    {
        rect.width = 0
    }
}
