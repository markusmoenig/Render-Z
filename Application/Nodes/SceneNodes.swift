//
//  LayerNodes.swift
//  Shape-Z
//
//  Created by Markus Moenig on 7.06.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

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
        }
        return playResult!
    }
}
