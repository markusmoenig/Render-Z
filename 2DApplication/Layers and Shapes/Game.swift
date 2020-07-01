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
    var currentScene        : Scene? = nil
    
    private enum CodingKeys: String, CodingKey {
        case type
    }
    
    override init()
    {
        super.init()
        
        name = "Game"
        subset = []
    }
    
    override func setup()
    {
        type = "Game"
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
    
    func setupExecution(nodeGraph: NodeGraph)
    {
        currentScene = nil
    }
    
    
    override func finishExecution() {
        currentScene = nil
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
