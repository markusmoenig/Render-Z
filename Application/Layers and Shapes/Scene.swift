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
    
    var outputTextures : [MTLTexture] = []
    var runningInRoot  : BehaviorTreeRoot? = nil
    var runBy          : UUID? = nil
    
    var layerObjects   : [Layer]? = nil
    var platformSize   : float2? = nil

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
        layerObjects = []
        for layerUUID in layers {
            for node in nodeGraph.nodes {
                if layerUUID == node.uuid {
                    let layer = node as! Layer
                    layerObjects!.append(layer)
                }
            }
        }
        platformSize = getPlatformSize(nodeGraph: nodeGraph)
    }
    
    override func finishExecution() {
        layerObjects = nil
        platformSize = nil
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
    
    /// Returns the platform size (if any) for the current platform
    func getPlatformSize(nodeGraph: NodeGraph) -> float2?
    {
        var size : float2? = nil
        
        #if os(OSX)
        if let osx = nodeGraph.getNodeOfType("Platform OSX") as? GamePlatformOSX {
            size = osx.getScreenSize()
        }
        #elseif os(iOS)
        
        #endif
        return size
    }
    
    /// Process a layer
    func processLayer(nodeGraph: NodeGraph, layer: Layer)
    {
        layer.builderInstance?.layerGlobals?.position.x = properties[layer.uuid.uuidString + "_posX" ]!
        layer.builderInstance?.layerGlobals?.position.y = properties[layer.uuid.uuidString + "_posY" ]!
        
        layer.builderInstance?.layerGlobals?.limiterSize.x = properties[layer.uuid.uuidString + "_width" ]!
        layer.builderInstance?.layerGlobals?.limiterSize.y = properties[layer.uuid.uuidString + "_height" ]!
        
        if nodeGraph.app != nil {
            layer.updatePreviewExt(nodeGraph: nodeGraph, hard: false, properties: properties)
        } else {
            let width = properties[layer.uuid.uuidString + "_width" ]!
            let height = properties[layer.uuid.uuidString + "_height" ]!
            layer.gameCamera!.zoom = min(nodeGraph.previewSize.x / width, nodeGraph.previewSize.y / height)
            
            layer.updatePreviewExt(nodeGraph: nodeGraph, hard: false, properties: properties)
        }
        outputTextures.append(layer.previewTexture!)
    }
    
    override func updatePreview(nodeGraph: NodeGraph, hard: Bool = false)
    {
        outputTextures = []
        if let objects = layerObjects {
            for layer in objects {
                processLayer(nodeGraph: nodeGraph, layer: layer)
            }
        } else {
            for layerUUID in layers {
                for node in nodeGraph.nodes {
                    if layerUUID == node.uuid {
                        let layer = node as! Layer
                        
                        processLayer(nodeGraph: nodeGraph, layer: layer)
                    }
                }
            }
        }
    }
}
