//
//  App.swift
//  Framework
//
//  Created by Markus Moenig on 9/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class App
{
    var mmView          : MMView
    var leftRegion      : LeftRegion?
    var topRegion       : TopRegion?
    var rightRegion     : RightRegion?
    var bottomRegion    : BottomRegion?
    var editorRegion    : EditorRegion?
    
    var nodeGraph       : NodeGraph
    
    var changed         : Bool = false
    
    let gizmo           : Gizmo
    let closeButton     : MMButtonWidget!
    
    let builder         : Builder

    init(_ view : MMView )
    {
        mmView = view
    
//        layerManager = LayerManager()
        nodeGraph = NodeGraph()
        
        // --- Reusable buttons
        
        // Close Button
        let state = mmView.drawCustomState.createState(source:
            """

            float sdLine( float2 uv, float2 pa, float2 pb, float r) {
                float2 o = uv-pa;
                float2 l = pb-pa;
                float h = clamp( dot(o,l)/dot(l,l), 0.0, 1.0 );
                return -(r-distance(o,l*h));
            }

            fragment float4 drawCloseButton(RasterizerData in [[stage_in]],
                                           constant MM_CUSTOMSTATE_DATA *data [[ buffer(0) ]] )
            {
                float2 uv = in.textureCoordinate * data->size;
                uv -= data->size / 2;

                float dist = sdLine( uv, float2( data->size.x / 2, data->size.y / 2 ), float2( -data->size.x / 2, -data->size.y / 2 ), 2 );
                dist = min( dist, sdLine( uv, float2( -data->size.x / 2, data->size.y / 2 ), float2( data->size.x/2, -data->size.y/2 ), 2 ) );

                float4 col = float4( 1, 1, 1, m4mFillMask( dist ) );
                return col;
            }
            """, name: "drawCloseButton")
        
        closeButton = MMButtonWidget(mmView, customState: state)
        // ---
                
        /*
        let json = nodeGraph.encodeJSON()
        
        if let jsonData = json.data(using: .utf8)
        {
            print( json )

            if let graph =  try? JSONDecoder().decode(NodeGraph.self, from: jsonData) {
                print( "yes" )
                print( graph.encodeJSON() )
            }
        }*/
        
        gizmo = Gizmo(view)
        builder = Builder()
        
        nodeGraph.setup(app: self)

        topRegion = TopRegion( mmView, app: self )
        leftRegion = LeftRegion( mmView, app: self )
        rightRegion = RightRegion( mmView, app: self )
        bottomRegion = BottomRegion( mmView, app: self )
        editorRegion = EditorRegion( mmView, app: self )
        
        mmView.leftRegion = leftRegion
        mmView.topRegion = topRegion
        mmView.rightRegion = rightRegion
        mmView.bottomRegion = bottomRegion
        mmView.editorRegion = editorRegion

        nodeGraph.activate()
        
        setChanged()
    }

    func setChanged()
    {
        changed = true
        nodeGraph.maximizedNode?.maxDelegate?.setChanged()
    }
}

class AppUndo : UndoManager
{
    
}


