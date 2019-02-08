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
    var undoButton      : MMButtonWidget!
    var redoButton      : MMButtonWidget!
    
    var shapesButton    : MMButtonWidget!
    var materialsButton : MMButtonWidget!
    var timelineButton  : MMButtonWidget!
    
    var app             : App

    init( _ view: MMView, app: App )
    {
        self.app = app
        super.init( view, type: .Top )
        
        var borderlessSkin = MMSkinButton()
        borderlessSkin.margin = MMMargin( 4, 4, 4, 4 )
        borderlessSkin.borderSize = 0
        borderlessSkin.height = 30

        undoButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "Undo" )
        undoButton.isDisabled = true
        undoButton.clicked = { (event) -> Void in
            self.undoButton.removeState(.Checked)
            view.undoManager?.undo()
        }
        
        redoButton = MMButtonWidget( mmView, skinToUse: borderlessSkin, text: "Redo" )
        redoButton.isDisabled = true
        redoButton.clicked = { (event) -> Void in
            self.redoButton.removeState(.Checked)
            view.undoManager?.redo()
        }
        
        shapesButton = MMButtonWidget( mmView, text: "Shapes" )
        shapesButton.clicked = { (event) -> Void in
            app.leftRegion?.setMode(.Shapes)
            self.materialsButton.removeState(.Checked)
        }
        
        materialsButton = MMButtonWidget( mmView, text: "Materials" )
        materialsButton.clicked = { (event) -> Void in
            app.leftRegion?.setMode(.Materials)
            self.shapesButton.removeState(.Checked)
            
            /*
            /// Testing
            
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
            }*/
            
        }
        
        timelineButton = MMButtonWidget( mmView, text: "Timeline" )
        timelineButton.clicked = { (event) -> Void in
            app.bottomRegion?.switchMode()
        }
        
        layoutH( startX: 10, startY: 8, spacing: 10, widgets: undoButton, redoButton )
        layoutH( startX: 10, startY: 4 + 44, spacing: 10, widgets: shapesButton, materialsButton, timelineButton )

        registerWidgets( widgets: undoButton, redoButton, shapesButton, materialsButton, timelineButton )
    }
    
    override func build()
    {
        layoutHFromRight( startX: rect.x + rect.width - 10, startY: 4 + 44, spacing: 10, widgets: timelineButton )
        
        mmView.drawBox.draw( x: 1, y: 0, width: mmView.renderer.width - 1, height: 44, round: 0, borderSize: 1, fillColor : float4(0.153, 0.153, 0.153, 1.000), borderColor: float4( 0.051, 0.051, 0.051, 1 ) )
        mmView.drawBoxGradient.draw( x: 1, y: 0, width: mmView.renderer.width - 1, height: 44, round: 0, borderSize: 1, uv1: float2( 0, 0 ), uv2: float2( 0, 1 ), gradientColor1 : float4(0.275, 0.275, 0.275, 1.000), gradientColor2 : float4(0.153, 0.153, 0.153, 1.000), borderColor: float4( 0.051, 0.051, 0.051, 1 ) )
        
        mmView.drawBoxGradient.draw( x: 1, y: 44, width: mmView.renderer.width-1, height: 48, round: 0, borderSize: 1, uv1: float2( 0, 0 ), uv2: float2( 0, 1 ), gradientColor1 : float4( 0.082, 0.082, 0.082, 1), gradientColor2 : float4( 0.169, 0.173, 0.169, 1), borderColor: float4( 0.051, 0.051, 0.051, 1 ) )
        rect.height = 48 + 44

        undoButton.isDisabled = !mmView.window!.undoManager!.canUndo
        undoButton.draw()
                
        redoButton.isDisabled = !mmView.window!.undoManager!.canRedo
        redoButton.draw()
        
        #if os(OSX)
            mmView.window!.isDocumentEdited = !undoButton.isDisabled
        #endif

        shapesButton.draw()
        materialsButton.draw()
        timelineButton.draw()

//        mmView.drawText.drawText( mmView.openSans!, text: "Punk is not dead", x: 200, y: 200, scale: 0.5)
//        mmView.drawSphere.draw( x: 200, y: 100, radius: 20, borderSize: 2, fillColor: vector_float4( 0.5, 0.5, 0.5, 1 ), borderColor: vector_float4( 1 ) )
    }
}
