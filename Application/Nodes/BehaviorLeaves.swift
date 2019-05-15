//
//  BehaviorLeaves.swift
//  Shape-Z
//
//  Created by Markus Moenig on 22.04.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

/// OSX: Key Is Down
class KeyDown : Node
{
    override init()
    {
        super.init()
        
        name = "Key Down"
    }
    
    override func setup()
    {
        type = "Key Down"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupTerminals()
    {
        terminals = [
            Terminal(name: "In", connector: .Top, brand: .Behavior, node: self)
        ]
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIKeyDown(self, variable: "keyCode", title: "Key")
        ]
        
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Return Success if the selected key is currently down
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        #if os(OSX)
        let index = nodeGraph.app!.mmView.keysDown.firstIndex{$0 == properties["keyCode"]!}
        
        if index != nil {
            playResult = .Success
        }
        #endif
        
        return playResult!
    }
}

/// Clicked in Layer Area
class ClickInLayerArea : Node
{
    override init()
    {
        super.init()
        
        name = "Click In Layer Area"
        uiConnections.append(UINodeConnection(.LayerArea))
    }
    
    override func setup()
    {
        type = "Click In Layer Area"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupTerminals()
    {
        terminals = [
            Terminal(name: "In", connector: .Top, brand: .Behavior, node: self)
        ]
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIMasterPicker(self, variable: "master", title: "Layer", connection:  uiConnections[0]),
            NodeUILayerAreaPicker(self, variable: "layerArea", title: "Area", connection:  uiConnections[0]),
        ]
        
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Return Success if the selected key is currently down
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        
        if uiConnections[0].masterNode == nil || uiConnections[0].target == nil { return playResult! }
        
        if let layer = uiConnections[0].masterNode as? Layer {
            if let area = uiConnections[0].target as? LayerArea {
                if area.areaObject == nil || area.areaObject!.shapes.count == 0 { return playResult! }
                let screen = nodeGraph.mmScreen!
                let camera = createNodeCamera(layer)
                
                if let mouse = screen.tranformToCamera(screen.mousePos, camera) {
                    //print("mouse", area.name, mouse.x, mouse.y)
                    
                    let object = area.areaObject!
                    let shape = object.shapes[0]
                    
                    func rotateCW(_ pos : float2, angle: Float) -> float2
                    {
                        let ca : Float = cos(angle), sa = sin(angle)
                        return pos * float2x2(float2(ca, -sa), float2(sa, ca))
                    }
                    
                    var uv = float2(mouse.x, -mouse.y)
                    
                    uv -= float2(object.properties["posX"]!, object.properties["posY"]!)
                    uv /= float2(object.properties["scaleX"]!, object.properties["scaleY"]!)
                    
                    uv = rotateCW(uv, angle: object.properties["rotate"]! * Float.pi / 180 );

                    var d : float2 = simd_abs( uv ) - float2(shape.properties[shape.widthProperty]!, shape.properties[shape.heightProperty]!)
                    let dist : Float = simd_length(max(d,float2(repeating: 0))) + min(max(d.x,d.y),0.0)

                    //print(name, object.properties["posX"]!, object.properties["posY"]!, dist)
                    if dist < 0 {
                        playResult = .Success
                    }
                }
                
                
            }
        }
        return playResult!
    }
}

