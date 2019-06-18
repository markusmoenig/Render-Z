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
    var name         : String
    var uuid         : UUID
    var objectUUID   : UUID
    var properties   : [String:Float]
    var instance     : Object? = nil
    
    private enum CodingKeys: String, CodingKey {
        case name
        case uuid
        case objectUUID
        case properties
    }
    
    init(name: String, objectUUID: UUID, properties: [String:Float])
    {
        self.name = name
        uuid = UUID()
        self.objectUUID = objectUUID
        self.properties = properties
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        objectUUID = try container.decode(UUID.self, forKey: .objectUUID)
        properties = try container.decode([String:Float].self, forKey: .properties)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
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
    
    var gameCamera      : Camera? = nil
    
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
        
        name = "New Layer"
        subset = []
    }
    
    override func setup()
    {
        type = "Layer"
        maxDelegate = LayerMaxDelegate()
        
        properties["renderMode"] = 1
        properties["renderSampling"] = 1
        
        //minimumSize = Node.NodeWithPreviewSize
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
        
        properties["renderMode"] = 1
        properties["renderSampling"] = 0.1
        executeProperties(nodeGraph)
        
        var camera = maxDelegate!.getCamera()!
        if nodeGraph.app == nil || nodeGraph.currentMaster!.type == "Scene" || nodeGraph.currentMaster!.type == "Game" {
            self.gameCamera = Camera()
            camera = self.gameCamera!
        } else {
            self.gameCamera = nil
        }
        
        builderInstance = nodeGraph.builder.buildObjects(objects: objects, camera: camera, preview: nodeGraph.app == nil ? false : false)
        physicsInstance = nodeGraph.physics.buildPhysics(objects: objects, builder: nodeGraph.builder, camera: camera)
    }
    
    /// Execute the layer
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        let result : Result = .Success
        
        for tree in behaviorTrees! {
            _ = tree.execute(nodeGraph: nodeGraph, root: root, parent: self)
        }
        
        return result
    }
    
    // Deallocate all object instances
    override func finishExecution() {
        for inst in objectInstances {
            inst.instance = nil
        }
        gameCamera = nil
    }
    
    override func updatePreview(nodeGraph: NodeGraph, hard: Bool = false)
    {
        let size = nodeGraph.previewSize
        if previewTexture == nil || Float(previewTexture!.width) != size.x || Float(previewTexture!.height) != size.y {
            previewTexture = nodeGraph.builder.compute!.allocateTexture(width: size.x, height: size.y, output: true)
        }
        
        let prevOffX = properties["prevOffX"]
        let prevOffY = properties["prevOffY"]
        let prevScale = properties["prevScale"]
        let camera = Camera(x: prevOffX != nil ? prevOffX! : 0, y: prevOffY != nil ? prevOffY! : 0, zoom: prevScale != nil ? prevScale! : 1)
        
        if builderInstance == nil || hard {
            DispatchQueue.main.async {
                self.executeProperties(nodeGraph)
                let instances = self.createInstances(nodeGraph: nodeGraph)
                for instance in instances {
                    instance.executeProperties(nodeGraph)
                }
                self.builderInstance = nodeGraph.builder.buildObjects(objects: instances, camera: camera, preview: false)
                self.updatePreview(nodeGraph: nodeGraph)
                nodeGraph.mmView.update()
            }
            return
        }
        
        if builderInstance != nil {
            builderInstance?.layerGlobals?.normalSampling = properties["renderSampling"]!
            nodeGraph.builder.render(width: size.x, height: size.y, instance: builderInstance!, camera: camera, outTexture: previewTexture)
        }
        
        if physicsInstance != nil {
            nodeGraph.physics.render(width: size.x, height: size.y, instance: physicsInstance!, builderInstance: builderInstance!, camera: camera)
        }
    }
    
    func updatePreviewExt(nodeGraph: NodeGraph, hard: Bool = false, properties: [String:Float])
    {
        let size = nodeGraph.previewSize
        if previewTexture == nil || Float(previewTexture!.width) != size.x || Float(previewTexture!.height) != size.y {
            previewTexture = nodeGraph.builder.compute!.allocateTexture(width: size.x, height: size.y, output: true)
        }
        
        let camera : Camera
        
        if self.gameCamera == nil {
            let prevOffX = properties["prevOffX"]
            let prevOffY = properties["prevOffY"]
            let prevScale = properties["prevScale"]
            camera = Camera(x: prevOffX != nil ? prevOffX! : 0, y: prevOffY != nil ? prevOffY! : 0, zoom: prevScale != nil ? prevScale! : 1)
        } else {
            camera = self.gameCamera!
        }
        
        if builderInstance == nil || hard {
            DispatchQueue.main.async {
                self.executeProperties(nodeGraph)
                let instances = self.createInstances(nodeGraph: nodeGraph)
                for instance in instances {
                    instance.executeProperties(nodeGraph)
                }
                self.builderInstance = nodeGraph.builder.buildObjects(objects: instances, camera: camera, preview: false)
                self.updatePreviewExt(nodeGraph: nodeGraph, hard: false, properties: properties)
                nodeGraph.mmView.update()
            }
            return
        }
        
        if builderInstance != nil {
            nodeGraph.builder.render(width: size.x, height: size.y, instance: builderInstance!, camera: camera, outTexture: previewTexture!)
        }
        
        if physicsInstance != nil {
            nodeGraph.physics.render(width: size.x, height: size.y, instance: physicsInstance!, builderInstance: builderInstance!, camera: camera)
        }
    }
}
