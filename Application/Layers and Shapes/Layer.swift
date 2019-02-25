//
//  Layer.swift
//  Shape-Z
//
//  Created by Markus Moenig on 24/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class Layer : Node
{
    var objectRefs      : [UUID]

    /// The timeline sequences for this object
    var sequences       : [MMTlSequence]
    var currentSequence : MMTlSequence? = nil
    
    var selectedObjects : [UUID]
    
    var instance        : BuilderInstance?
        
    private enum CodingKeys: String, CodingKey {
        case objectRefs
        case selectedObjects
        case sequences
    }
    
    override init()
    {
        objectRefs = []
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
        objectRefs = try container.decode([UUID].self, forKey: .objectRefs)
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
        try container.encode(objectRefs, forKey: .objectRefs)
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
    }
}
