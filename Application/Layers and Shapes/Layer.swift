//
//  Layer.swift
//  Shape-Z
//
//  Created by Markus Moenig on 24/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class ObjectInstance : Codable
{
    var objectUUID   : UUID
    var properties   : [String:Float]
    var instance     : Object? = nil
    
    private enum CodingKeys: String, CodingKey {
        case objectUUID
        case properties
    }
    
    init( uuid: UUID, properties: [String:Float])
    {
        objectUUID = uuid
        self.properties = properties
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        objectUUID = try container.decode(UUID.self, forKey: .objectUUID)
        properties = try container.decode([String:Float].self, forKey: .properties)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(objectUUID, forKey: .objectUUID)
        try container.encode(properties, forKey: .properties)
    }
}

class Layer : Node
{
    var objectInstances : [ObjectInstance]

    /// The timeline sequences for this object
    var sequences       : [MMTlSequence]
    var currentSequence : MMTlSequence? = nil
    
    var selectedObjects : [UUID]
    
    var instance        : BuilderInstance?
        
    private enum CodingKeys: String, CodingKey {
        case type
        case objectInstances
        case selectedObjects
        case sequences
    }
    
    override init()
    {
        objectInstances = []
        selectedObjects = []
        sequences = []
        
        super.init()
        
        type = "Layer"
        name = "New Layer"
        
        maxDelegate = LayerMaxDelegate()
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        objectInstances = try container.decode([ObjectInstance].self, forKey: .objectInstances)
        selectedObjects = try container.decode([UUID].self, forKey: .selectedObjects)
        sequences = try container.decode([MMTlSequence].self, forKey: .sequences)

        if sequences.count > 0 {
            currentSequence = sequences[0]
        }
        
        let superDecoder = try container.superDecoder()
        try super.init(from: superDecoder)
        
        type = "Layer"
        maxDelegate = LayerMaxDelegate()
    }
    
    override func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(type, forKey: .type)
        try container.encode(objectInstances, forKey: .objectInstances)
        try container.encode(selectedObjects, forKey: .selectedObjects)
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
    
    /*
    /// Returns the current object which is the first object in the selectedObjects array
    func getCurrentObject() -> Object?
    {
        if selectedObjects.isEmpty { return nil }
        
        for object in objectRefs {
            if object.uuid == selectedObjects[0] {
                return object
            }
        }
        
        return nil
    }
    
    /// Returns an array of the currently selected objects
    func getSelectedObjects() -> [Shape]
    {
        var result : [Object] = []
        
        for object in objectRefs {
            if selectedObjects.contains( object.uuid ) {
                result.append(object)
            }
        }

        return result
    }*/
    
    override func updatePreview(app: App)
    {
        if previewTexture == nil {
            previewTexture = app.builder.compute!.allocateTexture(width: 250, height: 160, output: true)
        }
        if instance != nil {
            app.builder.render(width: 250, height: 160, instance: instance!, camera: app.camera, timeline: app.timeline, outTexture: previewTexture)
        }
    }
}
