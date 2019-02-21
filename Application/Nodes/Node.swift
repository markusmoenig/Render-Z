//
//  Node.swift
//  Shape-Z
//
//  Created by Markus Moenig on 12/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

//

class Node : Codable
{
    var type            : String = ""
    var properties      : [String: Float]

    var name            : String = ""
    var uuid            : UUID = UUID()
    
    var xPos            : Float = 50
    var yPos            : Float = 50

    var rect            : MMRect = MMRect()
    
    var maxDelegate     : NodeMaxDelegate?
    
    var label           : MMTextLabel?
    var data            : NODE_DATA = NODE_DATA()
    var buffer          : MTLBuffer? = nil
    
    var previewTexture  : MTLTexture?
    
    var terminals       : [Terminal] = []
    
    private enum CodingKeys: String, CodingKey {
        case name
        case type
        case properties
        case uuid
        case xPos
        case yPos
        case terminals
    }
    
    init()
    {
        properties = [:]
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
        
        for terminal in terminals {
            terminal.node = self
        }
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
    }
    
    func onConnect(myTerminal: Terminal, toTerminal: Terminal)
    {
    }
    
    func onDisconnect(myTerminal: Terminal, toTerminal: Terminal)
    {
    }
    
    /// Sets up the node terminals
    func setupTerminals()
    {
    }
    
    /// Update the preview of the node
    func updatePreview(app: App)
    {
    }
}

class Terminal : Codable
{
    enum Connector : Int, Codable {
        case Left, Top, Right, Bottom
    }
    
    enum Brand : Int, Codable {
        case All, Properties, Object
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
    
    func update(_ hard: Bool = false)
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
    
    static var discriminator: NodeDiscriminator = .type
    
    func getType() -> AnyObject.Type
    {
        switch self
        {
            case .object:
                return Object.self
            case .objectPhysics:
                return ObjectPhysics.self
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
