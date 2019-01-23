//
//  ObjectEditorWidget.swift
//  Shape-Z
//
//  Created by Markus Moenig on 22/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit


class ObjectEditorWidget : MMWidget
{
    var app             : App
    var margin          : Float = 2

    init(_ view: MMView, app: App)
    {
        self.app = app
        super.init(view)
    }
    
    func draw(layer: Layer, object: Object)
    {
        // Background
        mmView.drawBox.draw( x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 0, borderSize: 1,  fillColor : float4( 0.145, 0.145, 0.145, 1), borderColor: vector_float4( 0, 0, 0, 1 ) )
        
        //
        
        let rootObject = layer.getCurrentRootObject()!
        let color = layer.currentId == rootObject.id ? mmView.skin.Widget.selectionColor : float4( 1 )
        let borderSize : Float = layer.currentId == rootObject.id ? 0 : 4

        mmView.drawBox.draw( x: rect.x + margin, y: rect.y + margin, width: rect.width - 2 * margin, height: rect.height - 2 * margin, round: 6, borderSize: borderSize,  fillColor : color, borderColor: vector_float4( 1 ) )
    }
}
