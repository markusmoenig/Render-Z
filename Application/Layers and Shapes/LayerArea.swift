//
//  ObjectProfile.swift
//  Shape-Z
//
//  Created by Markus Moenig on 26/4/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class LayerArea : Node
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
        type = "Layer Area"
        brand = .Property
        
        //minimumSize = Node.NodeWithPreviewSize
        maxDelegate = LayerAreaMaxDelegate()
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
            NodeUIDropDown(self, variable: "status", title: "Status", items: ["Enabled", "Disabled"], index: 0)
        ]
        super.setupUI(mmView: mmView)
    }
    
    /// Apply the control points to the objects profile array
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        playResult = .Success
        
        if properties["status"] != nil && properties["status"]! == 0 {
            if let _ = root.objectRoot {
            }
        }
        return playResult!
    }
}
