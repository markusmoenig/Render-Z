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
        if app.nodeGraph.maximizedNode == nil {
            app.nodeGraph.drawRegion(self)
        } else {
            app.nodeGraph.maximizedNode?.maxDelegate?.drawRegion(self)
        }
    }
}
