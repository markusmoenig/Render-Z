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
    var test        : Float = 0
    
    override init()
    {
        super.init()
        
        name = "Object Physics"
        type = "Object Physics"
    }
    
    private enum CodingKeys: String, CodingKey {
        case type
        case test
    }
    
    override func setupTerminals()
    {
        terminals = [
            Terminal(name: "Properties", connector: .Right, brand: .Properties, node: self)
        ]
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        test = try container.decode(Float.self, forKey: .test)

        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Object Physics"
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(test, forKey: .test)
        try container.encode(type, forKey: .type)

        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
}
