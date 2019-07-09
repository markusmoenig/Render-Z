//
//  Node.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

//

class Node : Codable, Equatable
{
    enum Brand {
        case Property, Behavior, Function, Arithmetic
    }

    enum Result {
        case Success, Failure, Running, Unused
    }
    
    var brand           : Brand = .Behavior
    var type            : String = ""
    var properties      : [String: Float]

    var name            : String = ""
    var uuid            : UUID = UUID()
    
    var xPos            : Float = 50
    var yPos            : Float = 50

    var rect            : MMRect = MMRect()
    
    var maxDelegate     : NodeMaxDelegate?
    
    var label           : MMTextLabel?
    var menu            : MMMenuWidget?
    
    var data            : NODE_DATA = NODE_DATA()
    var buffer          : MTLBuffer? = nil
    
    var previewTexture  : MTLTexture?
    
    var terminals       : [Terminal] = []
    
    var uiItems         : [NodeUI] = []
    var uiConnections   : [UINodeConnection] = []

    var minimumSize     : float2 = float2()
    var uiArea          : MMRect = MMRect()
    var uiMaxTitleSize  : float2 = float2()
    var uiMaxWidth      : Float = 0

    // The subset of nodes and camera for master nodes
    var subset          : [UUID]? = nil
    var camera          : Camera? = nil
    
    // Used only for master nodes during playback
    var behaviorTrees   : [BehaviorTree]? = nil
    var behaviorRoot    : BehaviorTreeRoot? = nil
    
    // Set for behavior nodes to allow for tree scaling
    var behaviorTree    : BehaviorTree? = nil

    var playResult      : Result? = nil
    var helpUrl         : String? = nil

    var nodeGraph       : NodeGraph? = nil
    
    /// Static sizes
    static var NodeWithPreviewSize : float2 = float2(260,220)
    static var NodeMinimumSize     : float2 = float2(240,75)

    private enum CodingKeys: String, CodingKey {
        case name
        case type
        case properties
        case uuid
        case xPos
        case yPos
        case terminals
        case subset
        case uiConnections
        case camera
    }
    
    init()
    {
        properties = [:]
        minimumSize = Node.NodeMinimumSize
        setup()
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        properties = try container.decode([String: Float].self, forKey: .properties)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        xPos = try container.decode(Float.self, forKey: .xPos)
        yPos = try container.decode(Float.self, forKey: .yPos)
        terminals = try container.decode([Terminal].self, forKey: .terminals)
        subset = try container.decode([UUID]?.self, forKey: .subset)
        uiConnections = try container.decode([UINodeConnection].self, forKey: .uiConnections)
        camera = try container.decodeIfPresent(Camera.self, forKey: .camera)

        for terminal in terminals {
            terminal.node = self
        }
        
        minimumSize = Node.NodeMinimumSize
        setup()
    }

    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(properties, forKey: .properties)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(xPos, forKey: .xPos)
        try container.encode(yPos, forKey: .yPos)
        try container.encode(terminals, forKey: .terminals)
        try container.encode(subset, forKey: .subset)
        try container.encode(uiConnections, forKey: .uiConnections)
        try container.encode(camera, forKey: .camera)
    }
    
    static func ==(lhs:Node, rhs:Node) -> Bool { // Implement Equatable
        return lhs.uuid == rhs.uuid
    }
    
    func onConnect(myTerminal: Terminal, toTerminal: Terminal)
    {
    }
    
    func onDisconnect(myTerminal: Terminal, toTerminal: Terminal)
    {
    }
    
    func execute(nodeGraph: NodeGraph, root: BehaviorTreeRoot, parent: Node) -> Result
    {
        return .Success
    }
    
    func finishExecution()
    {
    }
    
    /// Sets up the node terminals
    func setupTerminals()
    {
    }
    
    /// Setup the UI of the node
    func setupUI(mmView: MMView)
    {
        computeUIArea(mmView: mmView)
    }
    
    /// Update the UI elements of the node
    func updateUI(mmView: MMView)
    {
        for item in uiItems {
            item.update()
        }
        updateUIState()
    }
    
    /// Update the UI State
    func updateUIState()
    {
    }
    
    /// Setup
    func setup()
    {
    }
    
    /// Recomputes the UI area of the node
    func computeUIArea(mmView: MMView)
    {
        uiArea.width = 0; uiArea.height = 0;
        uiMaxTitleSize.x = 0; uiMaxTitleSize.y = 0
        uiMaxWidth = 0
        
        for item in uiItems {
            item.calcSize(mmView: mmView)
            
            uiArea.width = max(uiArea.width, item.rect.width)
            uiArea.height += item.rect.height
            uiMaxTitleSize.x = max(uiMaxTitleSize.x, item.titleLabel!.rect.width)
            uiMaxTitleSize.y = max(uiMaxTitleSize.y, item.titleLabel!.rect.height)
            uiMaxWidth = max(uiMaxWidth, item.rect.width -  item.titleLabel!.rect.width)
        }
        uiMaxTitleSize.x += NodeUI.titleMargin.width()
        uiMaxTitleSize.y += NodeUI.titleMargin.height()
        
        uiArea.width = uiMaxTitleSize.x + uiMaxWidth
        uiArea.height += 6
        
        uiMaxWidth -= NodeUI.titleMargin.width() + NodeUI.titleSpacing
        
        updateUIState()
    }
    
    /// A UI Variable changed
    func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false, noUndo: Bool = false)
    {
        func applyProperties(_ variable: String,_ old: Float,_ new: Float)
        {
            nodeGraph!.mmView.undoManager!.registerUndo(withTarget: self) { target in
                self.properties[variable] = new
                
                //print("change", variable, "to", new)
                applyProperties(variable, new, old)
                //self.setupUI(mmView: self.nodeGraph!.mmView)
                self.updateUI(mmView: self.nodeGraph!.mmView)
                self.variableChanged(variable: variable, oldValue: old, newValue: new, continuous: false, noUndo: true)
            }
        }
        
        if continuous == false {
            applyProperties(variable, newValue, oldValue)
        }
        self.updateUIState()
    }
    
    /// Executes the connected properties
    func executeProperties(_ nodeGraph: NodeGraph)
    {
        let propertyNodes = nodeGraph.getPropertyNodes(for: self)
        
        for node in propertyNodes {
            _ = node.execute(nodeGraph: nodeGraph, root: BehaviorTreeRoot(self), parent: self)
        }
    }
    
    /// Update the preview of the node
    func updatePreview(nodeGraph: NodeGraph, hard: Bool = false)
    {
    }
    
    /// Create a live preview if supported
    func livePreview(nodeGraph: NodeGraph, rect: MMRect)
    {
    }
}

/// Connects UI items to nodes of other objects, layers, etc

class UINodeConnection: Codable
{
    enum ConnectionType: Int, Codable {
        case Object, ObjectInstance, Animation, ValueVariable, DirectionVariable, LayerArea, Scene
    }
    
    var connectionType      : ConnectionType = .ValueVariable
    
    var connectedMaster     : UUID? = nil
    var connectedTo         : UUID? = nil
    
    var masterNode          : Node? = nil
    var target              : Any? = nil
    var targetName          : String? = nil

    var nodeGraph           : NodeGraph? = nil
    
    var uiMasterPicker      : NodeUIMasterPicker? = nil
    var uiPicker            : NodeUIDropDown? = nil
    var uiTarget            : NodeUIDropTarget? = nil

    private enum CodingKeys: String, CodingKey {
        case connectionType
        case connectedMaster
        case connectedTo
    }
    
    init(_ connectionType: ConnectionType)
    {
        self.connectionType = connectionType
        self.connectedMaster = nil
        self.connectedTo = nil
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        connectionType = try container.decode(ConnectionType.self, forKey: .connectionType)
        connectedMaster = try container.decode(UUID?.self, forKey: .connectedMaster)
        connectedTo = try container.decode(UUID?.self, forKey: .connectedTo)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(connectionType, forKey: .connectionType)
        try container.encode(connectedMaster, forKey: .connectedMaster)
        try container.encode(connectedTo, forKey: .connectedTo)
    }
}

/// Terminal class, connects nodes
class Terminal : Codable
{
    enum Connector : Int, Codable {
        case Left, Top, Right, Bottom
    }
    
    enum Brand : Int, Codable {
        case All, Properties, Object, Layer, Material, Behavior
    }
    
    var name            : String = ""
    var connector       : Connector = .Left
    var brand           : Brand = .All
    var uuid            : UUID!

    var connections     : [Connection] = []
    
    var node            : Node? = nil

    private enum CodingKeys: String, CodingKey {
        case name
        case connector
        case brand
        case uuid
        case connections
    }
    
    init(name: String? = nil, uuid: UUID? = nil, connector: Terminal.Connector? = nil, brand: Terminal.Brand? = nil, node: Node)
    {
        self.name = name != nil ? name! : ""
        self.uuid = uuid != nil ? uuid! : UUID()
        self.connector = connector != nil ? connector! : .Left
        self.brand = brand != nil ? brand! : .All
        self.node = node
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        connector = try container.decode(Connector.self, forKey: .connector)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        brand = try container.decode(Brand.self, forKey: .brand)
        connections = try container.decode([Connection].self, forKey: .connections)
        
        for connection in connections {
            connection.terminal = self
        }
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(connector, forKey: .connector)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(brand, forKey: .brand)
        try container.encode(connections, forKey: .connections)
    }
}

/// Connection between two terminals
class Connection : Codable
{
    var uuid            : UUID!
    var terminal        : Terminal?
    
    /// UUID of the Terminal this connection is connected to
    var toTerminalUUID  : UUID!
    /// UUID of the Connection this connection is connected to
    var toUUID          : UUID!
    var toTerminal      : Terminal? = nil
    
    private enum CodingKeys: String, CodingKey {
        case uuid
        case toTerminalUUID
        case toUUID
    }
    
    init(from: Terminal, to: Terminal)
    {
        uuid = UUID()
        self.terminal = from
        
        toTerminalUUID = to.uuid
        toTerminal = to
    }
}

/// Handles the maximized UI of a node
class NodeMaxDelegate
{
    func activate(_ app: App)
    {
    }
    
    func deactivate()
    {
    }
    
    func setChanged()
    {
    }
    
    func drawRegion(_ region: MMRegion)
    {
    }
    
    func keyDown(_ event: MMKeyEvent)
    {
    }
    
    func keyUp(_ event: MMKeyEvent)
    {
    }

    func mouseDown(_ event: MMMouseEvent)
    {
    }
    
    func mouseUp(_ event: MMMouseEvent)
    {
    }
    
    func mouseMoved(_ event: MMMouseEvent)
    {
    }
    
    func mouseScrolled(_ event: MMMouseEvent)
    {
    }
    
    func pinchGesture(_ scale: Float)
    {
    }
    
    func update(_ hard: Bool = false, updateLists: Bool = false)
    {
    }
    
    func getCamera() -> Camera?
    {
        return nil
    }
    
    func getTimeline() -> MMTimeline?
    {
        return nil
    }
}

/// A class describing the root node of a behavior tree
class BehaviorTreeRoot
{
    var rootNode        : Node
    var objectRoot      : Object? = nil
    var layerRoot       : Layer? = nil
    var sceneRoot       : Scene? = nil
    
    var runningNode     : Node? = nil

    /// List of Running capable nodes which have already been run, gets reset each time the tree is run
    var hasRun          : [UUID] = []
    
    init(_ node : Node)
    {
        rootNode = node
        objectRoot = node as? Object
        layerRoot = node as? Layer
        sceneRoot = node as? Scene
    }
}

// --- Helper for heterogeneous node arrays
// --- Taken from https://medium.com/@kewindannerfjordremeczki/swift-4-0-decodable-heterogeneous-collections-ecc0e6b468cf

protocol NodeClassFamily: Decodable {
    static var discriminator: NodeDiscriminator { get }
    
    func getType() -> AnyObject.Type
}

enum NodeDiscriminator: String, CodingKey {
    case type = "type"
}

/// The NodeFamily enum describes the node types
enum NodeFamily: String, NodeClassFamily {
    case object = "Object"
    case objectPhysics = "Object Physics"
    case setObjectPhysics = "Set Object Physics"
    //case objectProfile = "3D Profile"
    case objectAnimation = "Object Animation"
    case objectAnimationState = "Object Animation State"
    case objectApplyForce = "Object Apply Force"
    case objectApplyDirectionalForce = "Object Apply Directional Force"
    case objectCollisionAny = "Object Collision (Any)"
    case objectTouchLayerArea = "Object Touch Layer Area"
    case objectReset = "Object Reset"
    case sceneFinished = "Scene Finished"
    case gamePlatformOSX = "Platform OSX"
    case gamePlatformIPAD = "Platform IPAD"
    case gamePlayScene = "Game Play Scene"
    case behaviorTree = "Behavior Tree"
    case sequence = "Sequence"
    case selector = "Selector"
    case inverter = "Inverter"
    case restart = "Restart"
    case layer = "Layer"
    case layerArea = "Layer Area"
    case layerRender = "Layer Render"
    case clickInLayerArea = "Click In Layer Area"
    case keyDown = "Key Down"
    case scene = "Scene"
    case game = "Game"
    case valueVariable = "Value Variable"
    case directionVariable = "Direction Variable"
    case addValueVariable = "Add Value Variable"
    case subtractValueVariable = "Subtract Value Variable"
    case resetValueVariable = "Reset Value Variable"
    case testValueVariable = "Test Value Variable"

    static var discriminator: NodeDiscriminator = .type
    
    func getType() -> AnyObject.Type
    {
        switch self
        {
            case .object:
                return Object.self
            case .objectPhysics:
                return ObjectPhysics.self
            case .setObjectPhysics:
                return SetObjectPhysics.self
            //case .objectProfile:
            //    return ObjectProfile.self
            case .objectAnimation:
                return ObjectAnimation.self
            case .objectAnimationState:
                return ObjectAnimationState.self
            case .objectApplyForce:
                return ObjectApplyForce.self
            case .objectApplyDirectionalForce:
                return ObjectApplyDirectionalForce.self
            case .objectCollisionAny:
                return ObjectCollisionAny.self
            case .objectTouchLayerArea:
                return ObjectTouchLayerArea.self
            case .objectReset:
                return ResetObject.self
            
            case .layer:
                return Layer.self
            case .layerArea:
                return LayerArea.self
            case .clickInLayerArea:
                return ClickInLayerArea.self
            case .layerRender:
                return LayerRender.self
            
            case .scene:
                return Scene.self
            case .sceneFinished:
                return SceneFinished.self
            
            case .game:
                return Game.self
            case .gamePlatformOSX:
                return GamePlatformOSX.self
            case .gamePlatformIPAD:
                return GamePlatformIPAD.self
            case .gamePlayScene:
                return GamePlayScene.self
            
            case .behaviorTree:
                return BehaviorTree.self
            case .inverter:
                return Inverter.self
            case .sequence:
                return Sequence.self
            case .selector:
                return Selector.self
            case .restart:
                return Restart.self
            case .keyDown:
                return KeyDown.self
            
            case .valueVariable:
                return ValueVariable.self
            case .directionVariable:
                return DirectionVariable.self
            case .addValueVariable:
                return AddValueVariable.self
            case .subtractValueVariable:
                return SubtractValueVariable.self
            case .resetValueVariable:
                return ResetValueVariable.self
            case .testValueVariable:
                return TestValueVariable.self
        }
    }
}

extension KeyedDecodingContainer {
    
    /// Decode a heterogeneous list of objects for a given family.
    /// - Parameters:
    ///     - heterogeneousType: The decodable type of the list.
    ///     - family: The ClassFamily enum for the type family.
    ///     - key: The CodingKey to look up the list in the current container.
    /// - Returns: The resulting list of heterogeneousType elements.
    func decode<T : Decodable, U : NodeClassFamily>(_ heterogeneousType: [T].Type, ofFamily family: U.Type, forKey key: K) throws -> [T] {
        var container = try self.nestedUnkeyedContainer(forKey: key)
        var list = [T]()
        var tmpContainer = container
        while !container.isAtEnd {
            let typeContainer = try container.nestedContainer(keyedBy: NodeDiscriminator.self)
            let family: U = try typeContainer.decode(U.self, forKey: U.discriminator)
            if let type = family.getType() as? T.Type {
                list.append(try tmpContainer.decode(type))
            }
        }
        return list
    }
}
