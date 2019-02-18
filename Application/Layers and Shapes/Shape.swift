//
//  Shape.swift
//  Shape-Z
//
//  Created by Markus Moenig on 14/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class Shape : Codable
{
    enum ShapeMode : Int, Codable {
        case Merge, Subtract, Intersect
    }
    
    var name            : String
    var properties      : [String: Float]
    var uuid            : UUID
    
    var mode            : ShapeMode = .Merge
    
    var globalCode      : String = ""
    var distanceCode    : String = ""
    
    var widthProperty   : String = ""
    var heightProperty  : String = ""
    
    var pointCount      : Int = 0
    var pointsScale     : Bool = false

    private enum CodingKeys: String, CodingKey {
        case name
        case mode
        case properties
        case uuid
        case globalCode
        case distanceCode
        case widthProperty
        case heightProperty
        case pointCount
        case pointsScale
    }
    
    required init()
    {
        properties = [:]
        name = "Unnamed Shape"
     
        uuid = UUID()
        
        properties["posX"] = 0
        properties["posY"] = 0
        properties["rotate"] = 0
    }
    

    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        mode = try container.decode(ShapeMode.self, forKey: .mode)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        properties = try container.decode([String: Float].self, forKey: .properties)
        globalCode = try container.decode(String.self, forKey: .globalCode)
        distanceCode = try container.decode(String.self, forKey: .distanceCode)
        widthProperty = try container.decode(String.self, forKey: .widthProperty)
        heightProperty = try container.decode(String.self, forKey: .heightProperty)
        pointCount = try container.decode(Int.self, forKey: .pointCount)
        pointsScale = try container.decode(Bool.self, forKey: .pointsScale)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(mode, forKey: .mode)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(properties, forKey: .properties)
        try container.encode(globalCode, forKey: .globalCode)
        try container.encode(distanceCode, forKey: .distanceCode)
        try container.encode(widthProperty, forKey: .widthProperty)
        try container.encode(heightProperty, forKey: .heightProperty)
        try container.encode(pointCount, forKey: .pointCount)
        try container.encode(pointsScale, forKey: .pointsScale)
    }
    
    func createDistanceCode( uvName: String, transProperties: [String:Float]? = nil, layerIndex: Int? = nil ) -> String
    {
        var code = distanceCode
        let props = transProperties != nil ? transProperties : properties
        
        code = code.replacingOccurrences(of: "__uv__", with: String(uvName))
        
        for (name,value) in props! {
            if name == widthProperty && layerIndex != nil {
                code = code.replacingOccurrences(of: "__" + name + "__", with: "layerData->shape[\(layerIndex!)].size.x")
            } else
            if name == heightProperty && layerIndex != nil {
                code = code.replacingOccurrences(of: "__" + name + "__", with: "layerData->shape[\(layerIndex!)].size.y")
            } else
            if name.starts(with: "point_") && layerIndex != nil {
                let index = name.index(name.startIndex, offsetBy: 6)
                let coord = name.index(name.endIndex, offsetBy: -1)
                
                if name[index] == "0" && pointCount > 0 {
                    code = code.replacingOccurrences(of: "__" + name + "__", with: "layerData->shape[\(layerIndex!)].point0.\(name[coord])")
                } else
                if name[index] == "1" && pointCount > 1 {
                    code = code.replacingOccurrences(of: "__" + name + "__", with: "layerData->shape[\(layerIndex!)].point1.\(name[coord])")
                } else
                if name[index] == "2" && pointCount > 2 {
                    code = code.replacingOccurrences(of: "__" + name + "__", with: "layerData->shape[\(layerIndex!)].point2.\(name[coord])")
                }
            } else {
                code = code.replacingOccurrences(of: "__" + name + "__", with: String(value))
            }
        }
        
        return code
    }
    
    func getCurrentSize(_ transformed: [String:Float]) -> float2
    {
        var size : float2 =  float2()

        size.x = transformed[widthProperty]! * 2
        size.y = transformed[heightProperty]! * 2
        
        if pointCount >= 2 {
            let x0 = abs( transformed["point_0_x"]! )
            let y0 = abs( transformed["point_0_y"]! )
            let x1 = abs( transformed["point_1_x"]! )
            let y1 = abs( transformed["point_1_y"]! )
            
            size.x += max(x0, x1)
            size.y += max(y0, y1)
        }
        
        return size
    }
}
