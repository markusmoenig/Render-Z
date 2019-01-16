//
//  Shape.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class Shape : Codable
{
    var name            : String
    var properties      : [String: Float]
    var id              : Int
    
    var globalCode      : String = ""
    var distanceCode    : String = ""

    private enum CodingKeys: String, CodingKey {
        case name
        case properties
        case id
        case globalCode
        case distanceCode
    }
    
    required init()
    {
        id = -1
        properties = [:]
        name = "Unknown Shape"
        
        properties["posX"] = 0
        properties["posY"] = 0
    }
    
    func createDistanceCode( uvName: String ) -> String
    {
        var code = distanceCode
        code = code.replacingOccurrences(of: "__uv__", with: String(uvName))
        
        for (name,value) in properties {
            code = code.replacingOccurrences(of: "__" + name + "__", with: String(value))
        }        
        return code
    }
}
