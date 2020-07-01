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
        
        self.properties["opacity"] = 1
        self.properties["active"] = 1
        self.properties["z-index"] = 0
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        objectUUID = try container.decode(UUID.self, forKey: .objectUUID)
        properties = try container.decode([String:Float].self, forKey: .properties)
        
        if properties["opacity"] == nil {
            properties["opacity"] = 1.0
            properties["active"] = 1.0
            properties["z-index"] = 0.0
        }
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

class Scene : Node
{
    enum UpdateStatus {
        case Valid, NeedsUpdate, NeedsHardUpdate
    }
    
    enum PreviewStatus {
        case Valid, NeedsUpdate, InProgress
    }
    
    var updateStatus    : UpdateStatus = .NeedsHardUpdate
    var previewStatus   : PreviewStatus = .NeedsUpdate

    var objectInstances : [ObjectInstance]

    /// The timeline sequences for this object
    var sequences       : [MMTlSequence]
    var currentSequence : MMTlSequence? = nil
    
    var selectedObjects : [UUID]
    
    var gameCamera      : Camera? = nil
    var platformSize    : SIMD2<Float>? = nil

    var builderInstance : BuilderInstance?
    var physicsInstance : PhysicsInstance?
    
    var runningInRoot   : BehaviorTreeRoot? = nil
    var runBy           : UUID? = nil
        
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
        
        name = "New Scene"
        subset = []
    }
    
    override func setup()
    {
        type = "Scene"
        maxDelegate = SceneMaxDelegate()
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
    
    /// Sets up the scene instances for execution
    func setupExecution(nodeGraph: NodeGraph)
    {
        properties["numberOfLights"] = 0
        let objects = createInstances(nodeGraph: nodeGraph)

        executeProperties(nodeGraph)
        for object in objects {
            object.executeProperties(nodeGraph)

            let physicsMode = object.getPhysicsMode()
            if physicsMode == .Static || physicsMode == .Dynamic {
                object.body = Body(object, self)
            }
        }
                
        var camera = maxDelegate!.getCamera()!
        if nodeGraph.app == nil /*|| nodeGraph.currentMaster!.type == "Scene"*/ || nodeGraph.currentMaster!.type == "Game" {
            self.gameCamera = Camera()
            camera = self.gameCamera!
        } else {
            self.gameCamera = nil
        }
        
        //builderInstance = nodeGraph.builder.buildObjects(objects: objects, camera: camera)
        builderInstance = nodeGraph.sceneRenderer.setup(nodeGraph: nodeGraph, instances: objects, scene: self)
        physicsInstance = nodeGraph.physics.buildPhysics(objects: objects, builder: nodeGraph.builder, camera: camera)
        
        platformSize = nodeGraph.getPlatformSize()
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
        physicsInstance = nil
    }
    
    /// Creates a preview of the scene inside the preview texture (which is otherwise unused)
    func createIconPreview(nodeGraph: NodeGraph, size: SIMD2<Float>)
    {
        if previewTexture == nil || Float(previewTexture!.width) != size.x || Float(previewTexture!.height) != size.y {
            previewTexture = nodeGraph.sceneRenderer.fragment.allocateTexture(width: size.x, height: size.y, output: true)
        }

        let camera = Camera()
        let platformSize = nodeGraph.getPlatformSize()

        let width = platformSize.x
        let height = platformSize.y
        
        let xFactor : Float = nodeGraph.previewSize.x / width
        let yFactor : Float = nodeGraph.previewSize.y / height
        let factor : Float = min(xFactor, yFactor)
        camera.zoom = factor
        
        /*
        let prevOffX = properties["prevOffX"]
        let prevOffY = properties["prevOffY"]
        let prevScale = properties["prevScale"]
        let camera = Camera(x: prevOffX != nil ? prevOffX! : 0, y: prevOffY != nil ? prevOffY! : 0, zoom: prevScale != nil ? prevScale! : 1)
        */
        
        previewStatus = .InProgress
        
        //self.executeProperties(nodeGraph)
        let instances = self.createInstances(nodeGraph: nodeGraph)
        for instance in instances {
            instance.executeProperties(nodeGraph)
        }
        
        DispatchQueue.main.async {
            let builderInstance = nodeGraph.sceneRenderer.setup(nodeGraph: nodeGraph, instances: instances)
            nodeGraph.sceneRenderer.render(width: size.x, height: size.y, camera: camera, instance: builderInstance!, outTexture: self.previewTexture!)
            self.previewStatus = .Valid
            nodeGraph.mmView.update()
        }
    }
    
    override func updatePreview(nodeGraph: NodeGraph, hard: Bool = false)
    {
        let size = nodeGraph.previewSize
        //if previewTexture == nil || Float(previewTexture!.width) != size.x || Float(previewTexture!.height) != size.y {
        //    previewTexture = nodeGraph.sceneRenderer.fragment.allocateTexture(width: size.x, height: size.y, output: true)
        //}
        
        let camera : Camera
        
        if self.gameCamera == nil {
            let prevOffX = properties["prevOffX"]
            let prevOffY = properties["prevOffY"]
            let prevScale = properties["prevScale"]
            camera = Camera(x: prevOffX != nil ? prevOffX! : 0, y: prevOffY != nil ? prevOffY! : 0, zoom: prevScale != nil ? prevScale! : 1)
        } else {
            camera = self.gameCamera!

            let width = platformSize!.x
            let height = platformSize!.y

            let xFactor : Float = nodeGraph.previewSize.x / width
            let yFactor : Float = nodeGraph.previewSize.y / height
            let factor : Float = min(xFactor, yFactor)
            
            gameCamera!.zoom = factor
        }
        
        if builderInstance == nil || hard {
            DispatchQueue.main.async {
                self.properties["numberOfLights"] = 0
                self.executeProperties(nodeGraph)
                let instances = self.createInstances(nodeGraph: nodeGraph)
                for instance in instances {
                    instance.executeProperties(nodeGraph)
                }
                //self.builderInstance = nodeGraph.builder.buildObjects(objects: instances, camera: camera)
                self.builderInstance = nodeGraph.sceneRenderer.setup(nodeGraph: nodeGraph, instances: instances, scene: self)
                self.updatePreview(nodeGraph: nodeGraph)
                nodeGraph.mmView.update()
            }
            return
        }
        
        if physicsInstance != nil {
            nodeGraph.physics.render(width: size.x, height: size.y, instance: physicsInstance!, builderInstance: builderInstance!, camera: camera)
        }
        
        if builderInstance != nil {
            nodeGraph.sceneRenderer.render(width: size.x, height: size.y, camera: camera, instance: self.builderInstance!)
        }
        
        if physicsInstance != nil {
            nodeGraph.physics.step(instance: physicsInstance!)
        }
        
        updateStatus = .Valid
    }
}
