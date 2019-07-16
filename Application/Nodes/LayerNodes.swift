//
//  LayerNodes.swift
//  Shape-Z
//
//  Created by Markus Moenig on 17.05.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class LayerArea : Node
{
    var areaObject  : Object? = nil
    
    private enum CodingKeys: String, CodingKey {
        case type
        case areaObject
    }
    
    override init()
    {
        super.init()
        
        areaObject = Object()
        name = "Area"
    }
    
    override func setup()
    {
        type = "Layer Area"
        brand = .Property
        
        //minimumSize = Node.NodeWithPreviewSize
        maxDelegate = LayerAreaMaxDelegate()
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        areaObject = try container.decode(Object?.self, forKey: .areaObject)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(areaObject, forKey: .areaObject)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIDropDown(self, variable: "status", title: "Status", items: ["Enabled", "Disabled"], index: 0)
        ]
        super.setupUI(mmView: mmView)
    }
    
    /// Apply the control points to the objects profile array
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Success
        
        //if properties["status"] != nil && properties["status"]! == 0 {
        //    if let _ = root.objectRoot {
        //    }
        //}
        return playResult!
    }
}

class LayerGravity : Node
{
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override init()
    {
        super.init()
        
        name = "Gravity"
    }
    
    override func setup()
    {
        type = "Layer Gravity"
        brand = .Property
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
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
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIAngle(self, variable: "orientation", title: "", value: 90),
            NodeUINumber(self, variable: "angle", title: "Angle", range: float2(0,360), value: 90),
            NodeUINumber(self, variable: "strength", title: "Strength", range: float2(0,10), value: 5)
        ]
        
        uiItems[1].linkedTo = uiItems[0]
        uiItems[0].linkedTo = uiItems[1]
 
        super.setupUI(mmView: mmView)
    }
    
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Success
        
        let angle = properties["angle"]!
        let strength = properties["strength"]!
        let dir = float2(cos((360-angle) * Float.pi/180) * strength * 10, sin((360-angle) * Float.pi/180) * strength * 10)
        
        if let layer = root.layerRoot {
            
            layer.properties["physicsGravityX"] = dir.x
            layer.properties["physicsGravityY"] = dir.y

            return .Success
        }
        
        return playResult!
    }
}

class LayerRender : Node
{
    override init()
    {
        super.init()
        name = "Render Properties"
    }
    
    override func setup()
    {
        type = "Layer Render"
        brand = .Property
        
        //helpUrl = "https://moenig.atlassian.net/wiki/spaces/SHAPEZ/overview"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIDropDown(self, variable: "renderMode", title: "Mode", items: ["Off", "PBR"], index: 1),
            NodeUINumber(self, variable: "renderSampling", title: "Sampling", range: float2(0.1, 20), value: 0.1)
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
    
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) ->    Result
    {
        if let layer = root.layerRoot {
            layer.properties["renderMode"] = properties["renderMode"]!
            layer.properties["renderSampling"] = properties["renderSampling"]!

            return .Success
        }
        return .Failure
    }
    
    override func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false, noUndo: Bool = false)
    {
        if variable == "renderSampling" {
            if let master = nodeGraph?.currentMaster as? Layer {
                master.properties["renderSampling"] = properties["renderSampling"]!

                master.updatePreview(nodeGraph: nodeGraph!)
                nodeGraph?.mmView.update()
            }
        }
        if noUndo == false {
            super.variableChanged(variable: variable, oldValue: oldValue, newValue: newValue, continuous: continuous)
        }
    }
}

class LayerDirLight : Node
{
    var areaObject  : Object? = nil
    
    private enum CodingKeys: String, CodingKey {
        case type
        case areaObject
    }
    
    override init()
    {
        super.init()
        
        areaObject = Object()
        name = "Directional Light"
    }
    
    override func setup()
    {
        type = "Layer Dir Light"
        brand = .Property
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        areaObject = try container.decode(Object?.self, forKey: .areaObject)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(areaObject, forKey: .areaObject)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIDropDown(self, variable: "status", title: "Status", items: ["Enabled", "Disabled"], index: 0)
        ]
        super.setupUI(mmView: mmView)
    }
    
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Success
        
        if properties["status"] != nil && properties["status"]! == 0 {
            if let _ = root.objectRoot {
            }
        }
        return playResult!
    }
}
