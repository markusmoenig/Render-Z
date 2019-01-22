//
//  Object.swift
//  Shape-Z
//
//  Created by Markus Moenig on 21/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class Object : Codable
{
    var shapes          : [Shape]
    var shapeIdCounter  : Int
    
    var childObjects    : [Object]
    
    var name            : String = ""
    
    var id              : Int
    var active          : Bool
    
    var selectedShapes  : [Int]
    
    private enum CodingKeys: String, CodingKey {
        case shapes
        case childObjects
        case shapeIdCounter
        case active
        case id
        case selectedShapes
        case name
    }
    
    init()
    {
        shapes = []
        childObjects = []
        selectedShapes = []
        shapeIdCounter = 0
        id = -1
        active = true
    }
    
    func addShape(_ shape: Shape)
    {
        shapes.append( shape )
        shape.id = shapeIdCounter
        shapeIdCounter += 1
    }
}
