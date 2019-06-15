//
//  Behavior.swift
//  Shape-Z
//
//  Created by Markus Moenig on 23.02.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class BehaviorTree : Node
{
    override init()
    {
        super.init()
        
        name = "Behavior Tree"
        type = "Behavior Tree"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupTerminals()
    {
        terminals = [
            Terminal(name: "Behavior", connector: .Bottom, brand: .Behavior, node: self)
        ]
    }
    
    override func setupUI(mmView: MMView)
    {
        uiItems = [
            NodeUIDropDown(self, variable: "status", title: "Execute", items: ["Always", "On Demand"], index: 0),
            NodeUINumber(self, variable: "treeScale", title: "Scale", range: float2(0, 1), value: 1)
        ]
        super.setupUI(mmView: mmView)
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Behavior Tree"
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    override func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false)
    {
        if variable == "treeScale" {
            properties[variable] = newValue
            uiItems[0].mmView.update()
        }
    }
    
    /// Execute the attached behavior nodes
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Success
        for terminal in terminals {
            
            if terminal.connector == .Bottom {
                for conn in terminal.connections {
                    let toTerminal = conn.toTerminal!
                    playResult = toTerminal.node!.execute(nodeGraph: nodeGraph, root: root, parent: self)
                }
            }
        }
        
        return playResult!
    }
}


class Sequence : Node
{
    override init()
    {
        super.init()
        
        name = "Sequence"
        type = "Sequence"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupTerminals()
    {
        terminals = [
            Terminal(name: "In", connector: .Top, brand: .Behavior, node: self),

            Terminal(name: "Behavior1", connector: .Bottom, brand: .Behavior, node: self),
            Terminal(name: "Behavior2", connector: .Bottom, brand: .Behavior, node: self),
            Terminal(name: "Behavior3", connector: .Bottom, brand: .Behavior, node: self),
            Terminal(name: "Behavior4", connector: .Bottom, brand: .Behavior, node: self),
            Terminal(name: "Behavior5", connector: .Bottom, brand: .Behavior, node: self)
        ]
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
//        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Sequence"
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Return Success if all behavior outputs succeeded
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Success
        for terminal in terminals {
            
            if terminal.connector == .Bottom {
                for conn in terminal.connections {
                    let toTerminal = conn.toTerminal!
                    playResult = toTerminal.node!.execute(nodeGraph: nodeGraph, root: root, parent: self)
                    if playResult == .Failure {
                        return .Failure
                    }
                    if playResult == .Running {
                        return .Success
                    }
                }
            }
        }
        
        return playResult!
    }
}

class Selector : Node
{
    override init()
    {
        super.init()
        
        name = "Selector"
        type = "Selector"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupTerminals()
    {
        terminals = [
            Terminal(name: "In", connector: .Top, brand: .Behavior, node: self),
            
            Terminal(name: "Behavior1", connector: .Bottom, brand: .Behavior, node: self),
            Terminal(name: "Behavior2", connector: .Bottom, brand: .Behavior, node: self),
            Terminal(name: "Behavior3", connector: .Bottom, brand: .Behavior, node: self),
            Terminal(name: "Behavior4", connector: .Bottom, brand: .Behavior, node: self),
            Terminal(name: "Behavior5", connector: .Bottom, brand: .Behavior, node: self)
        ]
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Selector"
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Return Success if the first encountered behavior output succeeded
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Failure
        for terminal in terminals {
            
            if terminal.connector == .Bottom {
                for conn in terminal.connections {
                    let toTerminal = conn.toTerminal!
                    playResult = toTerminal.node!.execute(nodeGraph: nodeGraph, root: root, parent: self)
                    if playResult == .Success {
                        return .Success
                    }
                    if playResult == .Running {
                        return .Success
                    }
                }
            }
        }
        
        return playResult!
    }
}

class Inverter : Node
{
    override init()
    {
        super.init()
        
        name = "Inverter"
        type = "Inverter"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override func setupTerminals()
    {
        terminals = [
            Terminal(name: "In", connector: .Top, brand: .Behavior, node: self),
            
            Terminal(name: "Behavior", connector: .Bottom, brand: .Behavior, node: self)
        ]
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        //        test = try container.decode(Float.self, forKey: .test)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Inverter"
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        
        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Return Success if all behavior outputs succeeded
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Success
        for terminal in terminals {
            
            if terminal.connector == .Bottom {
                for conn in terminal.connections {
                    let toTerminal = conn.toTerminal!
                    playResult = toTerminal.node!.execute(nodeGraph: nodeGraph, root: root, parent: self)
                    if playResult == .Failure {
                        playResult = .Success
                    } else
                    if playResult == .Success {
                        playResult = .Failure
                    }
                }
            }
        }
        
        return playResult!
    }
}

class Restart : Node
{
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override init()
    {
        super.init()
        
        name = "Restart"
    }
    
    override func setup()
    {
        type = "Restart"
        brand = .Behavior
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
        
        root.hasRun = []
        return playResult!
    }
}
