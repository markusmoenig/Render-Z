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
    var childObjects    : [Object]
    
    /// The timeline sequences for this object
    var sequences       : [MMTlSequence]

    var name            : String = ""
    
    var uuid            : UUID = UUID()
    var active          : Bool
    
    var selectedShapes  : [UUID]
        
    private enum CodingKeys: String, CodingKey {
        case shapes
        case childObjects
        case active
        case uuid
        case selectedShapes
        case name
        case sequences
    }
    
    init()
    {
        shapes = []
        childObjects = []
        selectedShapes = []
        sequences = []
        active = true
    }
    
    @discardableResult func addShape(_ shape: Shape) -> Shape
    {
        shapes.append( shape )
        
        return shape
    }
    
    /// Returns the current shape which is the first shape in the selectedShapes array
    func getCurrentShape() -> Shape?
    {
        if selectedShapes.isEmpty { return nil }
        
        for shape in shapes {
            if shape.uuid == selectedShapes[0] {
                return shape
            }
        }
        
        return nil
    }
}
