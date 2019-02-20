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
        case test
    }
    
    override func setupTerminals()
    {
        terminals = [
            Terminal(name: "Properties", connector: .Right, type: .Properties)
        ]
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Object Physics"
    }
}
