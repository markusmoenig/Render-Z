//
//  Scene.swift
//  Shape-Z
//
//  Created by Markus Moenig on 22/4/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class Scene : Node
{
    var layers         : [UUID] = []
    var selectedLayers : [UUID] = []

    private enum CodingKeys: String, CodingKey {
        case type
        case selectedLayers
        case layers
    }
    
    override init()
    {
        super.init()
        
        name = "Scene"
        subset = []
    }
    
    override func setup()
    {
        type = "Scene"
        maxDelegate = SceneMaxDelegate()
        //minimumSize = Node.NodeWithPreviewSize
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        selectedLayers = try container.decode([UUID].self, forKey: .selectedLayers)
        layers = try container.decode([UUID].self, forKey: .layers)

        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(selectedLayers, forKey: .selectedLayers)
        try container.encode(layers, forKey: .layers)

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
