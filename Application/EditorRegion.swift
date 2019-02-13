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
    var widget                  : EditorWidget!
    
    var result                  : MTLTexture?
    
    init( _ view: MMView, app: App )
    {
        self.app = app

        super.init( view, type: .Editor )
        
        widget = EditorWidget(view, editorRegion: self, app: app)
        registerWidgets( widgets: widget! )
    }
    
    override func build()
    {
        if app.nodeGraph.maximizedNode == nil {
            app.nodeGraph.drawRegion(self)
        } else {
            app.nodeGraph.maximizedNode?.maxDelegate?.drawRegion(self)
        }
        
        widget.rect.copy(rect)
    }
    
    func compute()
    {
        result = app.layerManager.render(width: rect.width, height: rect.height)
    }
}
