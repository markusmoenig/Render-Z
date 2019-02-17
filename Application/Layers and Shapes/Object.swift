//
//  Object.swift
//  Shape-Z
//
//  Created by Markus Moenig on 21/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class Object : Node
{
    var shapes          : [Shape]
    var childObjects    : [Object]
    var properties      : [String: Float]

    /// The timeline sequences for this object
    var sequences       : [MMTlSequence]
    var currentSequence : MMTlSequence? = nil
    
    var selectedShapes  : [UUID]
    
    var instance        : BuilderInstance?
        
    private enum CodingKeys: String, CodingKey {
        case type
        case shapes
        case childObjects
        case selectedShapes
        case sequences
        case properties
    }
    
    override init()
    {
        shapes = []
        childObjects = []
        properties = [:]
        selectedShapes = []
        sequences = []
        
        properties["posX"] = 0
        properties["posY"] = 0
        properties["rotate"] = 0
        
        super.init()
        
        type = "Object"
        maxDelegate = ObjectMaxDelegate()
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shapes = try container.decode([Shape].self, forKey: .shapes)
        childObjects = try container.decode([Object].self, forKey: .shapes)
        properties = try container.decode([String: Float].self, forKey: .properties)
        selectedShapes = try container.decode([UUID].self, forKey: .selectedShapes)
        sequences = try container.decode([MMTlSequence].self, forKey: .sequences)

        if sequences.count > 0 {
            currentSequence = sequences[0]
        }
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Object"
        maxDelegate = ObjectMaxDelegate()
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(shapes, forKey: .shapes)
        try container.encode(childObjects, forKey: .childObjects)
        try container.encode(properties, forKey: .properties)
        try container.encode(selectedShapes, forKey: .selectedShapes)
        try container.encode(sequences, forKey: .sequences)

        //let superdecoder = container.superEncoder()
        //try super.encode(to: superdecoder)
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
    
    override func updatePreview(app: App)
    {
        if previewTexture == nil {
            previewTexture = app.builder.compute!.allocateTexture(width: 130, height: 100, output: true)
        }
        app.builder.render(width: 130, height: 100, instance: instance!, camera: maxDelegate!.getCamera()!, timeline: maxDelegate!.getTimeline()!, outTexture: previewTexture)
    }
}
