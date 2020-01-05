//
//  CodeList.swift
//  Shape-Z
//
//  Created by Markus Moenig on 1/1/20.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class CodeList : MMWidget
{
    var sceneList         : SceneList
    var fragList          : CodeFragList

    init(_ view: MMView,_ sceneList: SceneList)
    {        
        self.sceneList = sceneList
        fragList = CodeFragList(view)

        super.init(view)
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 0, fillColor : SIMD4<Float>( 0.145, 0.145, 0.145, 1), borderColor: SIMD4<Float>( 0, 0, 0, 1 ) )
        
        sceneList.draw()
        fragList.draw()
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {

    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {

    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
    }
}
