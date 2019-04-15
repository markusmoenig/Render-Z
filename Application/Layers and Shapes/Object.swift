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
    
    var shapes          : [Shape]
    var bodyMaterials   : [Material]
    var borderMaterials : [Material]
    var childObjects    : [Object]
    
    /// The timeline sequences for this object
    var sequences       : [MMTlSequence]
    var currentSequence : MMTlSequence? = nil
    
    var selectedShapes  : [UUID]
    var selectedBodyMaterials: [UUID]
    var selectedBorderMaterials: [UUID]

    var pointConnections: [ObjectPointConnection] = []
    
    /// The render instance for this object, used for preview
    var instance        : BuilderInstance?
    
    /// If this object is an instance, this uuid is the uuid of the original object
    var instanceOf      : UUID? = nil
    
    /// The instance of this object used for preview play in Object view
    var playInstance    : Object? = nil
    var playFrame       : Int = 0
        
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
        
        type = "Object"
        
        properties["posX"] = 0
        properties["posY"] = 0
        properties["rotate"] = 0
        properties["border"] = 2
        
        maxDelegate = ObjectMaxDelegate()
        minimumSize = Node.NodeWithPreviewSize
        
        subset = []
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
        self.instanceOf = instanceFor.uuid
        
        super.init()

        terminals = instanceFor.terminals
        properties = instanceProperties
        self.type = instanceFor.type
        self.uuid = instanceUUID
        self.name = "Instance of " + instanceFor.name
        self.subset = instanceFor.subset

        if properties["posX"] == nil {
            properties["posX"] = 0
            properties["posY"] = 0
            properties["rotate"] = 0
            properties["border"] = 2
        }
        minimumSize = Node.NodeWithPreviewSize
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
        try container.encode(bodyMaterials, forKey: .bodyMaterials)
        try container.encode(borderMaterials, forKey: .borderMaterials)
        try container.encode(childObjects, forKey: .childObjects)
        try container.encode(selectedBodyMaterials, forKey: .selectedBodyMaterials)
        try container.encode(selectedBorderMaterials, forKey: .selectedBorderMaterials)
        try container.encode(selectedShapes, forKey: .selectedShapes)
        try container.encode(sequences, forKey: .sequences)
        try container.encode(pointConnections, forKey: .pointConnections)

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
    
    /// Sets up the object instance for execution, only used in Object view play mode
    func setupExecution(nodeGraph: NodeGraph)
    {
        //nodeGraph.app!.timeline.currentFrame = 0
        playFrame = 0

        playInstance = Object(instanceFor: self, instanceUUID: UUID(), instanceProperties: properties)
        updatePreview(nodeGraph: nodeGraph, hard: true)
    }
    
    /// Execute all bevavior outputs
    override func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        var result : Result = .Success
        
        //let timeline = nodeGraph.app!.timeline
        
        //timeline.transformProperties(sequence: playInstance!.currentSequence, uuid: uuid, properties: properties, frame: timeline.currentFrame) -> [String:Float]
        
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
            instance = nodeGraph.builder.buildObjects(objects: playInstance != nil ? [self] : [self], camera: camera, preview: true)
        }
        
        if instance != nil {
            nodeGraph.builder.render(width: size.x, height: size.y, instance: instance!, camera: camera, outTexture: previewTexture, frame: playFrame)
            playFrame += 1
            print(playFrame)
        }
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
