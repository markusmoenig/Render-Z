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
        helpUrl = "https://moenig.atlassian.net/wiki/spaces/SHAPEZ/pages/9207837/Area"
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

class SceneDirLight : Node
{
    override init()
    {
        super.init()
        name = "Directional Light"
    }
    
    override func setup()
    {
        type = "Scene Directional Light"
        brand = .Property
        
        helpUrl = "https://moenig.atlassian.net/wiki/spaces/SHAPEZ/pages/19791995/Collision+Properties"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUINumber(self, variable: "position", title: "X", range: float2(-4000,4000), value: 10),
            NodeUINumber(self, variable: "y", title: "Y", range: float2(-4000,4000), value: 0),
            NodeUINumber(self, variable: "height", title: "Height", range: float2(0,200), value: 100),
            NodeUINumber(self, variable: "power", title: "Power", range: float2(0,100), value: 3.15),
            //NodeUIAngle(self, variable: "collisionVelocity", title: "Collision Velocity", value: 0),
            //NodeUIAngle(self, variable: "collisionNormal", title: "Collision Normal", value: 0)
        ]
        
        super.setupUI(mmView: mmView)
    }
    
    override func setupTerminals()
    {
        terminals = [
            //Terminal(name: "collisionVelocity", connector: .Right, brand: .Float2Variable, node: self),
            //Terminal(name: "collisionNormal", connector: .Right, brand: .Float2Variable, node: self)
        ]
    }
    
    override func updateUIState(mmView: MMView)
    {
        super.updateUIState(mmView: mmView)
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
    
    /// A UI Variable changed
    override func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false, noUndo: Bool = false)
    {
        if let scene = nodeGraph?.getMasterForNode(self) as? Scene {
            scene.updateStatus = .NeedsHardUpdate
            //if scene.builderInstance?.scene == nil {
            //    scene.updateStatus = .NeedsHardUpdate
            //} else {
            //    scene.updateStatus = .NeedsUpdate
            //}
            nodeGraph?.mmView.update()
        }

        if noUndo == false {
            super.variableChanged(variable: variable, oldValue: oldValue, newValue: newValue, continuous: continuous)
        }
    }
    
    override func executeReadBinding(_ nodeGraph: NodeGraph, _ terminal: Terminal)
    {
    }
    
    override func executeWriteBinding(_ nodeGraph: NodeGraph, _ terminal: Terminal)
    {
    }
    
    /// Execute Object physic properties
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) ->    Result
    {
        if let scene = root.sceneRoot {
            let numberOfLights : Int = Int(scene.properties["numberOfLights"]!)

            scene.properties["light_\(numberOfLights)_posX"] = properties["position"]!
            scene.properties["light_\(numberOfLights)_posY"] = properties["y"]!
            scene.properties["light_\(numberOfLights)_posZ"] = properties["height"]!

            scene.properties["light_\(numberOfLights)_power"] = properties["power"]!
            scene.properties["light_\(numberOfLights)_type"] = 1

            scene.properties["numberOfLights"] = Float(numberOfLights + 1)
        }
        return .Success
    }
}

class SceneSphericalLight : Node
{
    override init()
    {
        super.init()
        name = "Spherical Light"
    }
    
    override func setup()
    {
        type = "Scene Spherical Light"
        brand = .Property
        
        helpUrl = "https://moenig.atlassian.net/wiki/spaces/SHAPEZ/pages/19791995/Collision+Properties"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUINumber(self, variable: "position", title: "X", range: float2(-4000,4000), value: 10),
            NodeUINumber(self, variable: "y", title: "Y", range: float2(-4000,4000), value: 0),
            NodeUINumber(self, variable: "height", title: "Height", range: float2(0,200), value: 100),
            NodeUINumber(self, variable: "power", title: "Power", range: float2(0,100), value: 3.15),
            NodeUINumber(self, variable: "radius", title: "radius", range: float2(0,100), value: 10),
            //NodeUIAngle(self, variable: "collisionVelocity", title: "Collision Velocity", value: 0),
            //NodeUIAngle(self, variable: "collisionNormal", title: "Collision Normal", value: 0)
        ]
        
        super.setupUI(mmView: mmView)
    }
    
    override func setupTerminals()
    {
        terminals = [
            //Terminal(name: "collisionVelocity", connector: .Right, brand: .Float2Variable, node: self),
            //Terminal(name: "collisionNormal", connector: .Right, brand: .Float2Variable, node: self)
        ]
    }
    
    override func updateUIState(mmView: MMView)
    {
        super.updateUIState(mmView: mmView)
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
    
    /// A UI Variable changed
    override func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false, noUndo: Bool = false)
    {
        if let scene = nodeGraph?.getMasterForNode(self) as? Scene {
            scene.updateStatus = .NeedsHardUpdate
            //if scene.builderInstance?.scene == nil {
            //    scene.updateStatus = .NeedsHardUpdate
            //} else {
            //    scene.updateStatus = .NeedsUpdate
            //}
            nodeGraph?.mmView.update()
        }

        if noUndo == false {
            super.variableChanged(variable: variable, oldValue: oldValue, newValue: newValue, continuous: continuous)
        }
    }
    
    override func executeReadBinding(_ nodeGraph: NodeGraph, _ terminal: Terminal)
    {
    }
    
    override func executeWriteBinding(_ nodeGraph: NodeGraph, _ terminal: Terminal)
    {
    }
    
    /// Execute Object physic properties
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) ->    Result
    {
        if let scene = root.sceneRoot {
            let numberOfLights : Int = Int(scene.properties["numberOfLights"]!)

            scene.properties["light_\(numberOfLights)_posX"] = properties["position"]!
            scene.properties["light_\(numberOfLights)_posY"] = properties["y"]!
            scene.properties["light_\(numberOfLights)_posZ"] = properties["height"]!

            scene.properties["light_\(numberOfLights)_radius"] = properties["radius"]!
            scene.properties["light_\(numberOfLights)_power"] = properties["power"]!
            scene.properties["light_\(numberOfLights)_type"] = 0

            scene.properties["numberOfLights"] = Float(numberOfLights + 1)
        }
        return .Success
    }
}
