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

    var sceneList         : SceneList

    required init(_ view: MMView,_ sceneList: SceneList)
    {
        mmView = view
        self.sceneList = sceneList

        super.init()
    }
    
    override func activate()
    {
        mmView.registerWidgets(widgets: sceneList)
    }
    
    override func deactivate()
    {
        mmView.deregisterWidgets(widgets: sceneList)
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

        } else
        if region.type == .Bottom {
        }
    }
}
