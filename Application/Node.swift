//
//  Node.swift
//  Shape-Z
//
//  Created by Markus Moenig on 31/12/19.
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
    
    var floatChangedCB  : ((String, Float, Float, Bool, Bool)->())? = nil
    var float2ChangedCB : ((String, SIMD2<Float>, SIMD2<Float>, Bool, Bool)->())? = nil
    var float3ChangedCB : ((String, SIMD3<Float>, SIMD3<Float>, Bool, Bool)->())? = nil
    var textChangedCB   : ((String, String, String, Bool, Bool)->())? = nil

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
    
    //var data            : NODE_DATA = NODE_DATA()
    var buffer          : MTLBuffer? = nil
    
    var previewTexture  : MTLTexture?
    
    var terminals       : [Terminal] = []
    var bindings        : [Terminal] = []
    
    var uiItems         : [NodeUI] = []
    var uiConnections   : [UINodeConnection] = []

    var minimumSize     : SIMD2<Float> = SIMD2<Float>()
    var uiArea          : MMRect = MMRect()
    var uiMaxTitleSize  : SIMD2<Float> = SIMD2<Float>()
    var uiMaxWidth      : Float = 0

    var helpUrl         : String? = nil
    
    /// Static sizes
    static var NodeWithPreviewSize : SIMD2<Float> = SIMD2<Float>(260,220)
    static var NodeMinimumSize     : SIMD2<Float> = SIMD2<Float>(230,65)

    private enum CodingKeys: String, CodingKey {
        case name
        case type
        case properties
        case uuid
        case xPos
        case yPos
        case terminals
        case uiConnections
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
        uiConnections = try container.decode([UINodeConnection].self, forKey: .uiConnections)

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
        try container.encode(uiConnections, forKey: .uiConnections)
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
        updateUIState(mmView: mmView)
    }
    
    /// Update the UI State
    func updateUIState(mmView: MMView)
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
        
        updateUIState(mmView: mmView)
    }
    
    /// A UI Variable changed
    func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false, noUndo: Bool = false)
    {
        if let cb = floatChangedCB {
            cb(variable, oldValue, newValue, continuous, noUndo)
        }
    }
    
    func variableChanged(variable: String, oldValue: SIMD3<Float>, newValue: SIMD3<Float>, continuous: Bool = false, noUndo: Bool = false)
    {
        if let cb = float3ChangedCB {
            cb(variable, oldValue, newValue, continuous, noUndo)
        }
    }
    
    func variableChanged(variable: String, oldValue: SIMD2<Float>, newValue: SIMD2<Float>, continuous: Bool = false, noUndo: Bool = false)
    {
        if let cb = float2ChangedCB {
            cb(variable, oldValue, newValue, continuous, noUndo)
        }
    }
    
    func variableChanged(variable: String, oldValue: String, newValue: String, continuous: Bool = false, noUndo: Bool = false)
    {
        if let cb = textChangedCB {
            cb(variable, oldValue, newValue, continuous, noUndo)
        }
    }
}

/// Connects UI items to nodes of other objects, layers, etc

class UINodeConnection: Codable
{
    enum ConnectionType: Int, Codable {
        case Object, ObjectInstance, Animation, FloatVariable, DirectionVariable, SceneArea, Scene, Float2Variable, BehaviorTree, Float3Variable
    }
    
    var connectionType      : ConnectionType = .FloatVariable
    
    var connectedMaster     : UUID? = nil
    var connectedTo         : UUID? = nil
    
    var masterNode          : Node? = nil
    var target              : Any? = nil
    var targetName          : String? = nil
    
    var targets             : [Any] = []
    
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
        case All, Properties, Behavior, FloatVariable, Float2Variable, DirectionVariable, Float3Variable
    }
    
    var name            : String = ""
    var connector       : Connector = .Left
    var brand           : Brand = .All
    var uuid            : UUID!
    
    var uiIndex         : Int = -1
    
    var posX            : Float = 0
    var posY            : Float = 0
    
    var readBinding     : ((Terminal) -> ())? = nil
    var writeBinding    : ((Terminal) -> ())? = nil

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
    
    func pinchGesture(_ scale: Float,_ firstTouch: Bool)
    {
    }
    
    func update(_ hard: Bool = false, updateLists: Bool = false)
    {
    }
    
    func getTimeline() -> MMTimeline?
    {
        return nil
    }
}
