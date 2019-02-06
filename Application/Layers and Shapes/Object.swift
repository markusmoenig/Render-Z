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
    var properties      : [String: Float]

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
        case properties
    }
    
    init()
    {
        shapes = []
        childObjects = []
        properties = [:]
        selectedShapes = []
        sequences = []
        active = true
        
        properties["posX"] = 0
        properties["posY"] = 0
        properties["scaleX"] = 1
        properties["scaleY"] = 1
        properties["rotate"] = 0
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
    
    /// Returns an array of the currently selected shapes
    func getSelectedShapes() -> [Shape]
    {
        var result : [Shape] = []
        
        for shape in shapes {
            if selectedShapes.contains( shape.uuid ) {
                result.append(shape)
            }
        }

        return result
    }
}
