//
//  Shapes.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class MM2DShape : Codable
{
    var name        : String
    var properties  : [String: Float]
    var id          : Int
    
    private enum CodingKeys: String, CodingKey {
        case name
        case properties
        case id
    }
    
    required init()
    {
        self.id = -1
        properties = [:]
        name = "New Shape"
        properties["posX"] = 0
        properties["posY"] = 0
    }
    
    func create(uvName: String) -> String
    {
        return ""
    }
    
    func globalCode() -> String
    {
        return ""
    }
    
    func instance() -> MM2DShape
    {
        return MM2DShape()
    }
}

class MM2DBox : MM2DShape
{
    required init()
    {
        super.init()
        properties["width"] = 1
        properties["height"] = 1
        name = "Box"
    }
    
    required init(from: Decoder)
    {
        super.init()
    }
    
    override func create(uvName: String) -> String
    {
        let width = properties["width"]
        let height = properties["height"]

        return "sdBox( \(uvName), float2( \(width ?? 1), \(height ?? 1) ) )"
    }
    
    override func globalCode() -> String {
        let code =
        """
            float sdBox( float2 p, float2 b )
            {
                float2 d = abs(p)-b;
                return length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
            }
        """
        return code;
    }
    
    override func instance() -> MM2DShape
    {
        return MM2DBox()
    }
}

class MM2DDisk : MM2DShape
{
    required init()
    {
        super.init()
        properties["radius"] = 1
        name = "Disk"
    }
    
    required init(from: Decoder)
    {
        super.init()
    }
    
    override func create(uvName: String) -> String
    {
        let radius = properties["radius"]
        return "length(\(uvName)) - \(radius ?? 1)"
    }
    
    override func instance() -> MM2DShape
    {
        return MM2DDisk()
    }
}
