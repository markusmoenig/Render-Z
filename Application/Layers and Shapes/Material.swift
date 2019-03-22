//
//  Material.swift
//  Shape-Z
//
//  Created by Markus Moenig on 21/3/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class Material : Codable
{
    var name            : String
    var properties      : [String: Float]
    var uuid            : UUID
    
    var code            : String = ""
    var globalCode      : String = ""

    var widthProperty   : String = ""
    var heightProperty  : String = ""
    
    var pointCount      : Int = 0
    var isDecorator     : Bool = false
    
    private enum CodingKeys: String, CodingKey {
        case name
        case properties
        case uuid
        case code
        case globalCode
        case widthProperty
        case heightProperty
        case pointCount
        case isDecorator
    }
    
    required init()
    {
        properties = [:]
        name = "Unnamed Material"
     
        uuid = UUID()
        
        properties["posX"] = 0
        properties["posY"] = 0
        properties["rotate"] = 0
    }

    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        properties = try container.decode([String: Float].self, forKey: .properties)
        code = try container.decode(String.self, forKey: .code)
        globalCode = try container.decode(String.self, forKey: .globalCode)
        widthProperty = try container.decode(String.self, forKey: .widthProperty)
        heightProperty = try container.decode(String.self, forKey: .heightProperty)
        pointCount = try container.decode(Int.self, forKey: .pointCount)
        isDecorator = try container.decode(Bool.self, forKey: .isDecorator)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(properties, forKey: .properties)
        try container.encode(code, forKey: .code)
        try container.encode(globalCode, forKey: .globalCode)
        try container.encode(widthProperty, forKey: .widthProperty)
        try container.encode(heightProperty, forKey: .heightProperty)
        try container.encode(pointCount, forKey: .pointCount)
        try container.encode(isDecorator, forKey: .isDecorator)
    }
    
    /// Creates the distance code for the shape, optionally using the supplied transformed properties or insertig the metal code for accessing the shape data structure
    func createCode( uvName: String, transProperties: [String:Float]? = nil, layerIndex: Int? = nil, pointIndex: Int? = nil, shapeIndex: Int? = nil, materialIndex: Int? = nil) -> String
    {
        var code = self.code
        let props = transProperties != nil ? transProperties : properties
        
        code = code.replacingOccurrences(of: "__uv__", with: String(uvName))
        
        if materialIndex == nil {
            code = code.replacingOccurrences(of: "__material__", with: "&materials[0]")
        }
        
        for (name,value) in props! {
            
            if name == widthProperty && layerIndex != nil {
                let widthCode = "layerData->shapes[\(layerIndex!)].size.x"
                code = code.replacingOccurrences(of: "__" + name + "__", with: widthCode)
            } else
            if name == heightProperty && layerIndex != nil {
                let heightCode = "layerData->shapes[\(layerIndex!)].size.y"
                code = code.replacingOccurrences(of: "__" + name + "__", with: heightCode)
            } else
            if (name == widthProperty || name == heightProperty) && transProperties != nil {
                let widthHeightCode = String(value)
                let _ : Float = min(transProperties![widthProperty]!,transProperties![heightProperty]!)
                code = code.replacingOccurrences(of: "__" + name + "__", with: widthHeightCode)
            } else
            if name.starts(with: "point_") && pointIndex != nil {
                let index = name.index(name.startIndex, offsetBy: 6)
                let coord = name.index(name.endIndex, offsetBy: -1)
                
                code = code.replacingOccurrences(of: "__" + name + "__", with: "layerData->points[\(pointIndex! + Int(String(name[index]))!)].\(name[coord])")
            } else {
                code = code.replacingOccurrences(of: "__" + name + "__", with: String(value))
            }
        }
        
        return code
    }
}
