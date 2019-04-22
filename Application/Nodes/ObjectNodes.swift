//
//  Nodes.swift
//  Shape-Z
//
//  Created by Markus Moenig on 20.02.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class ObjectPhysics : Node
{
    override init()
    {
        super.init()
        
        name = "Physics Properties"
        type = "Object Physics"
        brand = .Property
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIDropDown(self, variable: "physicsMode", title: "Mode", items: ["Off", "Static", "On"], index: 1),
            NodeUINumber(self, variable: "physicsMass", title: "Mass", range: float2(0, 50), value: 1),
            NodeUINumber(self, variable: "physicsRestitution", title: "Restitution", range: float2(0, 1), value: 0.2)
        ]
        
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
//        test = try container.decode(Float.self, forKey: .test)

        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Object Physics"
        brand = .Property
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Execute Object physic properties
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) ->    Result
    {
        if let object = root.objectRoot {
            let value = properties["physicsMode"]!
            object.properties["physicsMode"] = value
            object.properties["physicsMass"] = properties["physicsMass"]!
            object.properties["physicsRestitution"] = properties["physicsRestitution"]!

            return .Success
        }
        return .Failure
    }
}

class ObjectAnimation : Node
{
    override init()
    {
        super.init()
        
        name = "Animation"
        type = "Object Animation"
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
            NodeUIAnimationPicker(self, variable: "animation", title: "Animation"),
            NodeUIDropDown(self, variable: "animationMode", title: "Mode", items: ["Loop", "Inverse Loop", "Goto Start", "Goto End"], index: 0),
            NodeUINumber(self, variable: "scale", title: "Scale", range: float2(0, 5), value: 1)
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Object Animation"
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
        
        if let object = root.objectRoot {
            let animPicker = uiItems[0] as! NodeUIAnimationPicker
            let mode = uiItems[1] as! NodeUIDropDown
            let scale = uiItems[2] as! NodeUINumber

            object.setSequence(index: Int(animPicker.index), timeline: nodeGraph.app!.timeline)
            object.setAnimationMode(Object.AnimationMode(rawValue: Int(mode.index))!, scale: scale.value)
            //print("AnimationPicker", Int(animPicker.index), Int(mode.index))
            playResult = .Success
        }
        
        return playResult!
    }
}
