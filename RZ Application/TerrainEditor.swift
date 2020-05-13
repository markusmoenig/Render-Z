//
//  TerrainEditor.swift
//  Shape-Z
//
//  Created by Markus Moenig on 13/5/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class TerrainEditor   : MMWidget
{
    var terrain       : Terrain!
    
    override required init(_ view: MMView)
    {
        super.init(view)
    }
    
    func activate()
    {
        //mmView.registerWidgets(widgets: codeList, codeEditor, codeProperties, showButton, liveButton, navButton)
    }
    
    func deactivate()
    {
        //mmView.deregisterWidgets(widgets: codeList, codeEditor, codeProperties, showButton, liveButton, navButton)
    }
    
    func setTerrain(_ terrain: Terrain)
    {
        self.terrain = terrain
    }

    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        
    }
}
