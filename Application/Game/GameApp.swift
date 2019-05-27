//
//  App.swift
//  Framework
//
//  Created by Markus Moenig on 9/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class GameApp
{
    var mmView          : MMView
    var gameRegion      : GameRegion?
    
    var nodeGraph       : NodeGraph
    
    let closeButton     : MMButtonWidget!
    
    let camera          : Camera!
    let timeline        : MMTimeline!
    
    let mmFile          : MMFile!
    
    #if os(OSX)
    var viewController  : NSViewController?
    var playController  : NSWindowController?
    #else
    var viewController  : ViewController?
    #endif
    
    init(_ view : MMView )
    {
        mmView = view
        mmFile = MMFile( view )
            
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
        
        camera = Camera()
        timeline = MMTimeline(view)
        
        gameRegion = GameRegion( mmView, app: self )
        
        mmView.editorRegion = gameRegion
    }
    
    func load(_ json: String)
    {
        if let jsonData = json.data(using: .utf8) {

            if let graph =  try? JSONDecoder().decode(NodeGraph.self, from: jsonData) {
        
                nodeGraph = graph        
            }
        }
    }
}


