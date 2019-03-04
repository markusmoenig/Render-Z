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

    /// The timeline sequences for this object
    var sequences       : [MMTlSequence]
    var currentSequence : MMTlSequence? = nil
    
    var selectedShapes  : [UUID]
    
    /// The render instance for this object, used for preview
    var instance        : BuilderInstance?
    
    /// If this object is an instance, this uuid is the uuid of the original object
    var instanceOf      : UUID? = nil
        
    private enum CodingKeys: String, CodingKey {
        case type
        case shapes
        case childObjects
        case selectedShapes
        case sequences
    }
    
    override init()
    {
        shapes = []
        childObjects = []
        selectedShapes = []
        sequences = []
        
        super.init()
        
        type = "Object"
        
        properties["posX"] = 0
        properties["posY"] = 0
        properties["rotate"] = 0
        
        maxDelegate = ObjectMaxDelegate()
        minimumSize = Node.NodeWithPreviewSize
    }

    /// Creates an instance of the given object with the given instance properties
    init(instanceFor: Object, instanceUUID: UUID, instanceProperties: [String:Float])
    {
        self.shapes = instanceFor.shapes
        self.childObjects = instanceFor.childObjects
        self.sequences = instanceFor.sequences
        self.selectedShapes = []
        self.instanceOf = instanceFor.uuid
        
        super.init()

        properties = instanceProperties
        self.type = instanceFor.type
        self.uuid = instanceUUID

        if properties["posX"] == nil {
            properties["posX"] = 0
            properties["posY"] = 0
            properties["rotate"] = 0
        }
        minimumSize = Node.NodeWithPreviewSize
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shapes = try container.decode([Shape].self, forKey: .shapes)
        childObjects = try container.decode([Object].self, forKey: .childObjects)
        selectedShapes = try container.decode([UUID].self, forKey: .selectedShapes)        
        sequences = try container.decode([MMTlSequence].self, forKey: .sequences)

        if sequences.count > 0 {
            currentSequence = sequences[0]
        }
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Object"
        maxDelegate = ObjectMaxDelegate()
        minimumSize = Node.NodeWithPreviewSize
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(shapes, forKey: .shapes)
        try container.encode(childObjects, forKey: .childObjects)
        try container.encode(selectedShapes, forKey: .selectedShapes)
        try container.encode(sequences, forKey: .sequences)

        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Add the terminals
    override func setupTerminals()
    {
        terminals = [
            Terminal(name: "Properties", connector: .Left, brand: .Properties, node: self),
//            Terminal(name: "Out", connector: .Right, brand: .Object, node: self),
            Terminal(name: "Behavior1", connector: .Bottom, brand: .Behavior, node: self),
            Terminal(name: "Behavior2", connector: .Bottom, brand: .Behavior, node: self),
            Terminal(name: "Behavior3", connector: .Bottom, brand: .Behavior, node: self)
        ]
    }
    
    /// Execute all bevavior outputs
    override func execute(nodeGraph: NodeGraph, root: Node, parent: Node) -> Result
    {
        var result : Result = .Success
        for terminal in terminals {
            
            if terminal.connector == .Bottom {
                for conn in terminal.connections {
                    let toTerminal = conn.toTerminal!
                    result = toTerminal.node!.execute(nodeGraph: nodeGraph, root: root, parent: self)
                }
            }
        }
        
        return result
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
    
    override func updatePreview(app: App, hard: Bool = false)
    {
        let width : Float = 200
        let height : Float = 130

        if previewTexture == nil {
            previewTexture = app.builder.compute!.allocateTexture(width: width, height: height, output: true)
        }
        
        if instance == nil || hard {
            instance = app.builder.buildObjects(objects: [self], camera: app.camera, timeline: app.timeline, preview: true)
        }
        
        if instance != nil {
            app.builder.render(width: width, height: height, instance: instance!, camera: app.camera, timeline: app.timeline, outTexture: previewTexture)
        }
    }
}
