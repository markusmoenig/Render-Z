//
//  EditorRegion.swift
//  Framework
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class EditorRegion: MMRegion
{
    var app                     : App
        
    init( _ view: MMView, app: App )
    {
        self.app = app

        super.init( view, type: .Editor )
    }
    
    override func build()
    {
        app.currentEditor.drawRegion(self)
    }
}
