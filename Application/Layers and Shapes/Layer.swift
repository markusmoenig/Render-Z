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
    var uuid         : UUID
    var objectUUID   : UUID
    var properties   : [String:Float]
    var instance     : Object? = nil
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case objectUUID
        case properties
    }
    
    init( objectUUID: UUID, properties: [String:Float])
    {
        uuid = UUID()
        self.objectUUID = objectUUID
        self.properties = properties
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        objectUUID = try container.decode(UUID.self, forKey: .objectUUID)
        properties = try container.decode([String:Float].self, forKey: .properties)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(uuid, forKey: .uuid)
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
    
    var builderInstance : BuilderInstance?
    var physicsInstance : PhysicsInstance?
        
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
        minimumSize = Node.NodeWithPreviewSize
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
        minimumSize = Node.NodeWithPreviewSize
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
    
    /// Creates the object instances contained in this layer
    @discardableResult func createInstances(nodeGraph: NodeGraph) -> [Object]
    {
        var objects : [Object] = []
        for inst in objectInstances {
            
            for node in nodeGraph.nodes {
                if node.uuid == inst.objectUUID {
                    inst.instance = Object(instanceFor: node as! Object, instanceUUID: inst.uuid, instanceProperties: inst.properties)
                    inst.instance!.maxDelegate = maxDelegate
                    objects.append(inst.instance!)
                }
            }
        }
        return objects
    }
    
    /// Sets up the object instances for execution
    func setupExecution(nodeGraph: NodeGraph)
    {
        let objects = createInstances(nodeGraph: nodeGraph)
        for object in objects {
            object.executeProperties(nodeGraph)
        }
        executeProperties(nodeGraph)
        
        builderInstance = nodeGraph.builder.buildObjects(objects: objects, camera: maxDelegate!.getCamera()!, preview: true)
        physicsInstance = nodeGraph.physics.buildPhysics(objects: objects, camera: maxDelegate!.getCamera()!)
    }
    
    /// Execute the layer
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        var result : Result = .Success
        
        /*
        for object in objectInstances {
            
            let instance = object.instance!
            
            let physicsMode = instance.properties["physicsMode"]
            if physicsMode != nil && physicsMode! == 2 {
                instance.properties["posY"]! += 0.3
            }
            print(instance.name, object.instance!.properties["posY"]!)
        }*/
        
        /// Execute behavior outputs
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
    
    override func updatePreview(nodeGraph: NodeGraph, hard: Bool = false)
    {
        let width : Float = 200
        let height : Float = 130
        
        if previewTexture == nil {
            previewTexture = nodeGraph.builder.compute!.allocateTexture(width: width, height: height, output: true)
        }
        
        let prevOffX = properties["prevOffX"]
        let prevOffY = properties["prevOffY"]
        let prevScale = properties["prevScale"]
        let camera = Camera(x: prevOffX != nil ? prevOffX! : 0, y: prevOffY != nil ? prevOffY! : 0, zoom: prevScale != nil ? prevScale! : 1)
        
        if builderInstance == nil || hard {
            builderInstance = nodeGraph.builder.buildObjects(objects: createInstances(nodeGraph: nodeGraph), camera: camera, preview: true)
        }
        
        if physicsInstance != nil {
            nodeGraph.physics.render(width: width, height: height, instance: physicsInstance!, camera: camera)
        }
        
        if builderInstance != nil {
            nodeGraph.builder.render(width: width, height: height, instance: builderInstance!, camera: camera, outTexture: previewTexture)
        }
    }
}
