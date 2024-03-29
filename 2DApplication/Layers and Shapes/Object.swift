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
    enum MaterialType {
        case Body, Border
    }
    
    enum AnimationMode : Int {
        case Loop, InverseLoop, GotoStart, GotoEnd
    }
    
    enum AnimationState : Int {
        case NotAnimating, AtStart, GoingForward, GoingBackward, AtEnd
    }
    
    enum PhysicsMode : Int {
        case Off, Static, Dynamic, CollisionOnly
    }
    
    var builderData             : [Float]? = []

    var shapes                  : [Shape]
    var bodyMaterials           : [Material]
    var borderMaterials         : [Material]
    var childObjects            : [Object]
    
    /// The timeline sequences for this object
    var animationMode           : AnimationMode = .Loop
    var animationState          : AnimationState = .NotAnimating
    
    var sequences               : [MMTlSequence]
    var currentSequence         : MMTlSequence? = nil
    /// Animation related, the current animation frame plus the max frame for the current sequence
    var frame                   : Float = 0
    var maxFrame                : Float = 0
    var animationScale          : Float = 1

    var disks                   : [Disk] = []
    var objectRect              : ObjectRect? = nil

    // Physics Body
    var body                    : Body? = nil
    
    // Profile points (if any)
    var profile                 : [SIMD4<Float>]? = nil
    
    var selectedShapes          : [UUID]
    var selectedBodyMaterials   : [UUID]
    var selectedBorderMaterials : [UUID]

    var pointConnections        : [ObjectPointConnection] = []
    
    // The render instance for this object, used for preview
    var instance                : BuilderInstance?
    
    // The fragment instance used by the Object Instances
    var fragmentInstance        : BuilderInstance? = nil
    
    /// If this object is an instance, this points to the original object
    var instanceOf              : Object? = nil
    
    /// The instance of this object used for preview play in Object view
    var playInstance            : Object? = nil
    
    private enum CodingKeys: String, CodingKey {
        case type
        case shapes
        case bodyMaterials
        case borderMaterials
        case childObjects
        case selectedShapes
        case selectedBodyMaterials
        case selectedBorderMaterials
        case sequences
        case pointConnections
        case subset
        case disks
        case objectRect
    }
    
    override init()
    {
        shapes = []
        bodyMaterials = []
        borderMaterials = []
        childObjects = []
        selectedShapes = []
        selectedBodyMaterials = []
        selectedBorderMaterials = []
        sequences = []
        
        super.init()
        
        properties["posX"] = 0
        properties["posY"] = 0
        properties["rotate"] = 0
        properties["border"] = 2
        properties["scaleX"] = 1
        properties["scaleY"] = 1
        
        subset = []
    }
    
    override func setup() {
        type = "Object"
        
        if properties["scaleX"] == nil {
            properties["scaleX"] = 1
            properties["scaleY"] = 1
        }

        maxDelegate = ObjectMaxDelegate()
        //minimumSize = Node.NodeWithPreviewSize
    }

    /// Creates an instance of the given object with the given instance properties
    init(instanceFor: Object, instanceUUID: UUID, instanceProperties: [String:Float])
    {
        self.shapes = instanceFor.shapes
        self.bodyMaterials = instanceFor.bodyMaterials
        self.borderMaterials = instanceFor.borderMaterials
        self.childObjects = instanceFor.childObjects
        self.sequences = instanceFor.sequences
        self.selectedShapes = []
        self.selectedBodyMaterials = []
        self.selectedBorderMaterials = []
        self.instanceOf = instanceFor
        
        super.init()

        terminals = instanceFor.terminals
        properties = instanceProperties
        self.type = instanceFor.type
        self.uuid = instanceUUID
        self.name = "Instance of " + instanceFor.name
        self.subset = instanceFor.subset
        self.disks = instanceFor.disks
        self.objectRect = instanceFor.objectRect
        self.profile = instanceFor.profile

        if properties["posX"] == nil {
            properties["posX"] = 0
            properties["posY"] = 0
            properties["rotate"] = 0
            properties["scaleX"] = 1
            properties["scaleY"] = 1
        }
        
        if properties["scaleX"] == nil {
            properties["scaleX"] = 1
            properties["scaleY"] = 1
        }
        
        properties["border"] = instanceFor.properties["border"]
        minimumSize = Node.NodeWithPreviewSize
        
        // --- Copy same values for reseting instances
        
        properties["copy_posX"] = properties["posX"]
        properties["copy_posY"] = properties["posY"]
        properties["copy_rotate"] = properties["rotate"]
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shapes = try container.decode([Shape].self, forKey: .shapes)
        bodyMaterials = try container.decode([Material].self, forKey: .bodyMaterials)
        borderMaterials = try container.decode([Material].self, forKey: .borderMaterials)
        childObjects = try container.decode([Object].self, forKey: .childObjects)
        selectedShapes = try container.decode([UUID].self, forKey: .selectedShapes)        
        selectedBodyMaterials = try container.decode([UUID].self, forKey: .selectedBodyMaterials)
        selectedBorderMaterials = try container.decode([UUID].self, forKey: .selectedBorderMaterials)
        sequences = try container.decode([MMTlSequence].self, forKey: .sequences)
        pointConnections = try container.decode([ObjectPointConnection].self, forKey: .pointConnections)
        disks = try container.decode([Disk].self, forKey: .disks)
        objectRect = try container.decodeIfPresent(ObjectRect.self, forKey: .objectRect)

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
        try container.encode(shapes, forKey: .shapes)
        try container.encode(bodyMaterials, forKey: .bodyMaterials)
        try container.encode(borderMaterials, forKey: .borderMaterials)
        try container.encode(childObjects, forKey: .childObjects)
        try container.encode(selectedBodyMaterials, forKey: .selectedBodyMaterials)
        try container.encode(selectedBorderMaterials, forKey: .selectedBorderMaterials)
        try container.encode(selectedShapes, forKey: .selectedShapes)
        try container.encode(sequences, forKey: .sequences)
        try container.encode(pointConnections, forKey: .pointConnections)
        try container.encode(disks, forKey: .disks)
        try container.encode(objectRect, forKey: .objectRect)

        let superdecoder = container.superEncoder()
        try super.encode(to: superdecoder)
    }
    
    /// Returns the physics mode for this object
    func getPhysicsMode() -> Object.PhysicsMode
    {
        var mode : PhysicsMode = .Off
        
        if properties["physicsMode"] != nil {
            mode = PhysicsMode(rawValue: Int(properties["physicsMode"]!))!
        }
        return mode
    }
    
    /// Sets the animation mode
    func setAnimationMode(_ mode: AnimationMode, scale: Float = 1)
    {
        animationMode = mode
        animationScale = scale
    }
    
    /// Sets the current sequence
    func setSequence(index: Int = 0, sequence: MMTlSequence?=nil, timeline: MMTimeline)
    {
        let seq = sequence != nil ? sequence : sequences[index]
        currentSequence = seq
        maxFrame = Float(timeline.getMaxFrame(sequence: currentSequence!))
    }
    
    /// Sets up the object instance for execution, only used in Object view play mode
    func setupExecution(nodeGraph: NodeGraph)
    {
        frame = 0

        playInstance = Object(instanceFor: self, instanceUUID: UUID(), instanceProperties: properties)
        updatePreview(nodeGraph: nodeGraph, hard: true)
    }
    
    /// Execute all bevavior outputs
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        let result : Result = .Success
        
        for tree in behaviorTrees! {
            _ = tree.execute(nodeGraph: nodeGraph, root: root, parent: self)
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
    
    /// Returns an array of the currently selected materials
    func getSelectedMaterials(_ type: MaterialType) -> [Material]
    {
        var result : [Material] = []
        
        if type == .Body {
            for material in bodyMaterials {
                if selectedBodyMaterials.contains( material.uuid ) {
                    result.append(material)
                }
            }
        } else {
            for material in borderMaterials {
                if selectedBorderMaterials.contains( material.uuid ) {
                    result.append(material)
                }
            }
        }
        
        return result
    }
    
    /// Returns the connections for the given point, 0 will contain the connection for which this point is the master (if any) and 1 will contain the connection for which this connection is the slave. A point can be the master of many points but can only be the slave of one.
    func getPointConnections(shape: Shape, index: Int) -> (ObjectPointConnection?, ObjectPointConnection?)
    {
        var result : (ObjectPointConnection?, ObjectPointConnection?) = (nil,nil)
        
        for pt in pointConnections {
            if pt.fromShape == shape.uuid && pt.fromIndex == index {
                result.0 = pt
            }
            if pt.toShapes[shape.uuid] != nil && pt.toShapes[shape.uuid]! == index {
                result.1 = pt
            }
        }
        return result
    }
    
    /// Removes the given slave point connection
    @discardableResult func removePointConnection(toShape: Shape, toIndex: Int) -> Bool
    {
        var success = false
        
        let conn = getPointConnections(shape: toShape, index: toIndex)
        if conn.1 != nil {
            let pt = conn.1!
            
            pt.toShapes.removeValue(forKey: toShape.uuid)
            success = true
        }
        return success
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
        
        if instance == nil || hard {
            instance = nil
            DispatchQueue.main.async {
                self.executeProperties(nodeGraph)
                self.instance = nodeGraph.builder.buildObjects(objects: self.playInstance != nil ? [self.playInstance!] : [self], camera: camera, renderMode: Object.getRenderMode(self))
                self.updatePreview(nodeGraph: nodeGraph)
                nodeGraph.mmView.update()
            }
            return
        }
        
        if instance != nil {
            nodeGraph.builder.render(width: size.x, height: size.y, instance: instance!, camera: camera, outTexture: previewTexture)
        }
    }
    
    /// Returns the Builder::RenderMode for the object
    static func getRenderMode(_ object: Object) -> Builder.RenderMode
    {
        var renderMode : Builder.RenderMode = .PBR
        
        if object.properties["renderMode"] != nil {
            let index : Float = object.properties["renderMode"]!
            if index == 0.0 {
                renderMode = .Color
            } else
            if index == 2.0 {
                renderMode = .Distance
            }
        }

        return renderMode
    }
}

/// A tree item
class ObjectTreeItem
{
    var object          : Object
    
    var childItems      : [ObjectTreeItem]
    var parentItem      : ObjectTreeItem?
    
    var rect            : MMRect = MMRect()
    
    init(_ obj: Object, parent: ObjectTreeItem?)
    {
        object = obj
        parentItem = parent
        childItems = []
        
        for child in obj.childObjects {
            let item = ObjectTreeItem(child, parent: self)
            childItems.append(item)
        }
    }
}

/// Builds an object tree for the given root object
class ObjectTree : ObjectTreeItem
{
    var flat            : [ObjectTreeItem]
    var rows            : [[ObjectTreeItem]]
    
    init(_ root: Object)
    {
        flat = []
        rows = []
        super.init(root, parent: nil)
        
        // --- Build Flat Hierarchy
        flat.append(self as ObjectTreeItem)
        
        func parseItem(_ item: ObjectTreeItem)
        {
            flat.append(item)
            for childItem in item.childItems {
                parseItem(childItem)
            }
        }
        
        for item in childItems {
            parseItem(item)
        }
        
        // --- Build Row Hierarchy
        func parseRow(_ items:[ObjectTreeItem]) -> [ObjectTreeItem]
        {
            var row : [ObjectTreeItem] = []
            for item in items {
                for child in item.childItems {
                    row.append(child)
                }
            }
            return row
        }
        rows.append([self as ObjectTreeItem])
        //        rows.append(childItems)
        
        var row = parseRow([self as ObjectTreeItem])
        while row.count > 0 {
            rows.append(row)
            row = parseRow(row)
        }
    }
}

/// Stores a connection between two points in different shapes
class ObjectPointConnection : Codable
{
    var fromShape   : UUID
    var fromIndex   : Int
    
    var toShapes    : [UUID:Int] = [:]
    
    // Builder can store values here for rendering speedup
    var valueX      : Float = 0
    var valueY      : Float = 0

    private enum CodingKeys: String, CodingKey {
        case fromShape
        case fromIndex
        case toShapes
    }
    
    init(fromShape: UUID, fromIndex: Int, toShape: UUID, toIndex: Int)
    {
        self.fromShape = fromShape
        self.fromIndex = fromIndex
        
        toShapes[toShape] = toIndex
    }
}

/// Stores a disk which make up the body of an object for physics and shading
class Disk : Codable
{
    var xPos            : Float
    var yPos            : Float
    var distance        : Float
    
    private enum CodingKeys: String, CodingKey {
        case xPos
        case yPos
        case distance
    }
    
    init(_ xPos: Float,_ yPos: Float,_ distance: Float)
    {
        self.xPos = xPos
        self.yPos = yPos
        self.distance = distance
    }
}

/// Stores the rect of the object
class ObjectRect : Codable
{
    var xPos            : Float
    var yPos            : Float
    var width           : Float
    var height          : Float
    var scale           : Float

    private enum CodingKeys: String, CodingKey {
        case xPos
        case yPos
        case width
        case height
        case scale
    }
    
    init(_ xPos: Float,_ yPos: Float,_ width: Float,_ height: Float,_ scale: Float)
    {
        self.xPos = xPos
        self.yPos = yPos
        self.width = width
        self.height = height
        self.scale = scale
    }
}

