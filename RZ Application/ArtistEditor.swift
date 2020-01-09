//
//  ArtistEditor.swift
//  Render-Z
//
//  Created by Markus Moenig on 05/01/20.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class ArtistEditor      : Editor
{
    let mmView          : MMView!
    
    let designEditor    : DesignEditor

    var sceneList       : SceneList

    required init(_ view: MMView,_ sceneList: SceneList)
    {
        mmView = view
        self.sceneList = sceneList

        designEditor = DesignEditor(view)

        super.init()
        
        designEditor.editor = self
    }
    
    override func activate()
    {
        mmView.registerWidgets(widgets: sceneList)
    }
    
    override func deactivate()
    {
        mmView.deregisterWidgets(widgets: sceneList)
    }
    
    override func setComponent(_ component: CodeComponent)
    {
        designEditor.designComponent = component
        updateOnNextDraw()
        mmView.update()
    }
    
    override func updateOnNextDraw(compile: Bool = true)
    {
        designEditor.needsUpdate = true
        designEditor.designChanged = compile
        mmView.update()
    }
    
    override func drawRegion(_ region: MMRegion)
    {
        if region.type == .Top {

        } else
        if region.type == .Left {
            sceneList.rect.copy(region.rect)
            sceneList.draw()
        } else
        if region.type == .Editor {
            designEditor.rect.copy(region.rect)
            designEditor.draw()
        } else
        if region.type == .Bottom {
            region.rect.y = globalApp!.mmView.renderer.cHeight
        }
    }
}
