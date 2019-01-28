//
//  TopRegion.swift
//  Framework
//
//  Created by Markus Moenig on 04.01.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class TopRegion: MMRegion
{
    var shapesButton    : MMButtonWidget!
    var materialsButton : MMButtonWidget!
    var timelineButton  : MMButtonWidget!
    
    var app             : App

    init( _ view: MMView, app: App )
    {
        self.app = app
        super.init( view, type: .Top )
        
        shapesButton = MMButtonWidget( mmView, text: "Shapes" )
        shapesButton.clickedCB = { (x,y) -> Void in
            app.leftRegion?.setMode(.Shapes)
            self.materialsButton.removeState(.Checked)
        }
        
        materialsButton = MMButtonWidget( mmView, text: "Materials" )
        materialsButton.clickedCB = { (x,y) -> Void in
            app.leftRegion?.setMode(.Materials)
            self.shapesButton.removeState(.Checked)
            
            
            /// Testing
            /*
            let layerManager = app.layerManager
            
            /// Encoding
            
            let encodedData = try? JSONEncoder().encode(layerManager)
            if let encodedObjectJsonString = String(data: encodedData!, encoding: .utf8)
            {
                print(encodedObjectJsonString)
                
                /// Decoding

                
                if let jsonData = encodedObjectJsonString.data(using: .utf8)
                {
                    if let layerM = try? JSONDecoder().decode(LayerManager.self, from: jsonData)
                    {
                        //let shape = layerM.layers[0].shapes[0]// as! MM2DBox
                        //print( layerM.layers[0].shapes[0].globalCode() )
                    
//                        layerM.currentLayer = layerM.layers[0]
//                        layerM.currentLayer.currentObject = layerM.currentLayer.objects[0]

                        app.layerManager = layerM
                        app.editorRegion?.result = nil
                        
                        app.layerManager.layers[0].layerManager = layerM
                        
                        layerM.app = app
                    }
                }
            }
            */
        }
        
        timelineButton = MMButtonWidget( mmView, text: "Timeline" )
        timelineButton.clickedCB = { (x,y) -> Void in
            app.bottomRegion?.switchMode()
        }
        
        layoutH( startX: 10, startY: 4, spacing: 10, widgets: shapesButton, materialsButton, timelineButton )

        registerWidgets( widgets: shapesButton, materialsButton, timelineButton )
    }
    
    override func build()
    {
        layoutHFromRight( startX: rect.x + rect.width - 10, startY: 4, spacing: 10, widgets: timelineButton )
        
        mmView.drawBoxGradient.draw( x: 0, y: 0, width: mmView.renderer.width, height: 48, round: 0, borderSize: 1, uv1: vector_float2( 0, 0 ), uv2: vector_float2( 0, 1 ), gradientColor1 : float4( 0.082, 0.082, 0.082, 1), gradientColor2 : float4( 0.169, 0.173, 0.169, 1), borderColor: vector_float4( 0.051, 0.051, 0.051, 1 ) )
        rect.height = 48
        
        shapesButton.draw()
        materialsButton.draw()
        timelineButton.draw()

//        mmView.drawText.drawText( mmView.openSans!, text: "Punk is not dead", x: 200, y: 200, scale: 0.5)
//        mmView.drawSphere.draw( x: 200, y: 100, radius: 20, borderSize: 2, fillColor: vector_float4( 0.5, 0.5, 0.5, 1 ), borderColor: vector_float4( 1 ) )
    }
}
