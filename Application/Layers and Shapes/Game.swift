//
//  Game.swift
//  Shape-Z
//
//  Created by Markus Moenig on 22/4/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class Game : Node
{
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override init()
    {
        super.init()
        
        type = "Game"
        name = "Game"
        
        minimumSize = Node.NodeWithPreviewSize
        
        subset = []
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Game"
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)

        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Sets up the object instances for execution
    func setupExecution(nodeGraph: NodeGraph)
    {
    }
    
    /// Execute the layer
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        let result : Result = .Success
        
        for tree in behaviorTrees! {
            _ = tree.execute(nodeGraph: nodeGraph, root: root, parent: self)
        }
        
        return result
    }
    
    override func updatePreview(nodeGraph: NodeGraph, hard: Bool = false)
    {
    }
}
