//
//  LayerNodes.swift
//  Shape-Z
//
//  Created by Markus Moenig on 7.06.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class SceneArea : Node
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
        type = "Scene Area"
        brand = .Property
        
        //minimumSize = Node.NodeWithPreviewSize
        maxDelegate = SceneAreaMaxDelegate()
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
            NodeUISelector(self, variable: "status", title: "Status", items: ["Enabled", "Disabled"], index: 0)
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

class SceneGravity : Node
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
        type = "Scene Gravity"
        brand = .Property
        
        helpUrl = "https://moenig.atlassian.net/wiki/spaces/SHAPEZ/pages/9142364/Gravity"
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
            NodeUINumber(self, variable: "angle", title: "Direction", range: float2(0,360), value: 90),
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
        
        if let layer = root.sceneRoot {
            
            layer.properties["physicsGravityX"] = dir.x
            layer.properties["physicsGravityY"] = dir.y
            
            return .Success
        }
        
        return playResult!
    }
}

class SceneRender : Node
{
    override init()
    {
        super.init()
        name = "Render Properties"
    }
    
    override func setup()
    {
        type = "Scene Render"
        brand = .Property
        
        //helpUrl = "https://moenig.atlassian.net/wiki/spaces/SHAPEZ/overview"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUISelector(self, variable: "renderMode", title: "Mode", items: ["Off", "PBR"], index: 1),
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
        if let scene = root.sceneRoot {
            scene.properties["renderMode"] = properties["renderMode"]!
            scene.properties["renderSampling"] = properties["renderSampling"]!
            
            return .Success
        }
        return .Failure
    }
    
    override func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false, noUndo: Bool = false)
    {
        if variable == "renderSampling" {
            if let master = nodeGraph?.currentMaster as? Scene {
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

class SceneDirLight : Node
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
        type = "Scene Dir Light"
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
            NodeUISelector(self, variable: "status", title: "Status", items: ["Enabled", "Disabled"], index: 0)
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

class SceneFinished : Node
{
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override init()
    {
        super.init()
        
        name = "Finished"
    }
    
    override func setup()
    {
        type = "Scene Finished"
        brand = .Function
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
    
    override func setupTerminals()
    {
        terminals = [
            Terminal(name: "In", connector: .Top, brand: .Behavior, node: self),
        ]
    }
    
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Success
        
        if let scene = root.sceneRoot {
            if scene.runningInRoot != nil && scene.runBy != nil {
                scene.runningInRoot!.hasRun.append(scene.runBy!)
            }
            //if nodeGraph.playNode != nil && scene.uuid == nodeGraph.playNode!.uuid {
            else
            {
                nodeGraph.stopPreview()
            }
        }

        return playResult!
    }
}
