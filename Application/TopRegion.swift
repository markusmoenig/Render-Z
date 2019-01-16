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
    var app             : App

    init( _ view: MMView, app: App )
    {
        self.app = app
        super.init( view, type: .Top )
        
        shapesButton = MMButtonWidget( mmView, skinToUse: mmView.skin.toolBarButton, text: "Shapes" )
        shapesButton.clickedCB = { (x,y) -> Void in
            print( "shapesButton clicked" )
            app.leftRegion?.setMode(.Shapes)
            self.materialsButton.removeState(.Checked)
        }
        
        materialsButton = MMButtonWidget( mmView, skinToUse: mmView.skin.toolBarButton, text: "Materials" )
        materialsButton.clickedCB = { (x,y) -> Void in
            print( "materialsButton clicked" )
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
                    //And here you get the Supermarket object back
                    if let layerM = try? JSONDecoder().decode(LayerManager.self, from: jsonData)
                    {
                        //let shape = layerM.layers[0].shapes[0]// as! MM2DBox
                        //print( layerM.layers[0].shapes[0].globalCode() )
                    
                        layerM.currentLayer = layerM.layers[0]
                        app.layerManager = layerM
                        app.editorRegion?.result = nil
                    }
                }
            }
            */
            
        }
        
        layoutH( startX: 10, startY: 4, spacing: 10, widgets: shapesButton, materialsButton )
        
        registerWidgets( widgets: shapesButton, materialsButton )
    }
    
    override func build()
    {
        mmView.drawCubeGradient.draw( x: 0, y: 0, width: mmView.renderer.width, height: 48, round: 0, borderSize: 1, uv1: vector_float2( 0, 0 ), uv2: vector_float2( 0, 1 ), gradientColor1 : float4( 0.082, 0.082, 0.082, 1), gradientColor2 : float4( 0.169, 0.173, 0.169, 1), borderColor: vector_float4( 0.051, 0.051, 0.051, 1 ) )
        rect.height = 48
        
        shapesButton.draw()
        materialsButton.draw()

//        mmView.drawText.drawText( mmView.openSans!, text: "Punk is not dead", x: 200, y: 200, scale: 0.5)
//        mmView.drawSphere.draw( x: 200, y: 100, radius: 20, borderSize: 2, fillColor: vector_float4( 0.5, 0.5, 0.5, 1 ), borderColor: vector_float4( 1 ) )
    }
}
