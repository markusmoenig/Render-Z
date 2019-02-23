//
//  Behavior.swift
//  Shape-Z
//
//  Created by Markus Moenig on 23.02.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class Sequence : Node
{
    override init()
    {
        super.init()
        
        name = "Sequence"
        type = "Sequence"
        
        minimumSize = float2(240, 70)
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
    override func execute(nodeGraph: NodeGraph, root: Node, parent: Node) -> Result
    {
        var result : Result = .Failure
        for terminal in terminals {
            
            if terminal.connector == .Bottom {
                for conn in terminal.connections {
                    let toTerminal = conn.toTerminal!
                    result = toTerminal.node!.execute(nodeGraph: nodeGraph, root: root, parent: self)
                    if result == .Failure {
                        return .Failure
                    }
                }
            }
        }
        
        return result
    }
}

class Selector : Node
{
    override init()
    {
        super.init()
        
        name = "Selector"
        type = "Selector"
        
        minimumSize = float2(240, 70)
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
    override func execute(nodeGraph: NodeGraph, root: Node, parent: Node) -> Result
    {
        var result : Result = .Failure
        for terminal in terminals {
            
            if terminal.connector == .Bottom {
                for conn in terminal.connections {
                    let toTerminal = conn.toTerminal!
                    result = toTerminal.node!.execute(nodeGraph: nodeGraph, root: root, parent: self)
                    if result == .Success {
                        return .Success
                    }
                }
            }
        }
        
        return result
    }
}
