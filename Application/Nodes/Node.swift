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

    var name            : String = ""
    var uuid            : UUID = UUID()
    
    var xPos            : Float = 50
    var yPos            : Float = 50

    var rect            : MMRect = MMRect()
    
    var maxDelegate     : NodeMaxDelegate?
    
    var titleTextBuffer : MMTextBuffer?
    var previewTexture  : MTLTexture?
    
    private enum CodingKeys: String, CodingKey {
        case name
        case uuid
        case xPos
        case yPos
    }
    
    init()
    {
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        xPos = try container.decode(Float.self, forKey: .xPos)
        yPos = try container.decode(Float.self, forKey: .yPos)
    }

    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(xPos, forKey: .xPos)
        try container.encode(yPos, forKey: .yPos)
    }
    
    func updatePreview(app: App)
    {
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
    
    static var discriminator: NodeDiscriminator = .type
    
    func getType() -> AnyObject.Type {
        switch self {
        case .object:
            return Object.self
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