//
//  BehaviorLeaves.swift
//  Shape-Z
//
//  Created by Markus Moenig on 22.04.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class KeyDown : Node
{
    override init()
    {
        super.init()
        
        name = "Key Down"
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
        
        type = "Key Down"
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

