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
    
    var distanceCode    : String = ""
    var globalCode      : String = ""
    var dynamicCode     : String? = nil

    var widthProperty   : String = ""
    var heightProperty  : String = ""
    
    var pointsVariable  : Bool = false
    
    var pointCount      : Int = 0
    var pointsScale     : Bool = false
    var supportsRounding: Bool = false
    
    private enum CodingKeys: String, CodingKey {
        case name
        case mode
        case properties
        case uuid
        case distanceCode
        case globalCode
        case dynamicCode
        case widthProperty
        case heightProperty
        case pointsVariable
        case pointCount
        case pointsScale
        case supportsRounding
    }
    
    required init()
    {
        properties = [:]
        name = "Unnamed Shape"
     
        uuid = UUID()
        
        properties["posX"] = 0
        properties["posY"] = 0
        properties["rotate"] = 0
        properties["inverse"] = 0
        properties["smoothBoolean"] = 0
        properties["rounding"] = 0
        properties["annular"] = 0
    }
    
    required init(from decoder: Decoder) throws
    {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        mode = try container.decode(ShapeMode.self, forKey: .mode)
        uuid = try container.decode(UUID.self, forKey: .uuid)
        properties = try container.decode([String: Float].self, forKey: .properties)
        distanceCode = try container.decode(String.self, forKey: .distanceCode)
        globalCode = try container.decode(String.self, forKey: .globalCode)
        dynamicCode = try container.decode(String?.self, forKey: .dynamicCode)
        widthProperty = try container.decode(String.self, forKey: .widthProperty)
        heightProperty = try container.decode(String.self, forKey: .heightProperty)
        pointsVariable = try container.decode(Bool.self, forKey: .pointsVariable)
        pointCount = try container.decode(Int.self, forKey: .pointCount)
        pointsScale = try container.decode(Bool.self, forKey: .pointsScale)
        supportsRounding = try container.decode(Bool.self, forKey: .supportsRounding)
    }
    
    func encode(to encoder: Encoder) throws
    {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(name, forKey: .name)
        try container.encode(mode, forKey: .mode)
        try container.encode(uuid, forKey: .uuid)
        try container.encode(properties, forKey: .properties)
        try container.encode(distanceCode, forKey: .distanceCode)
        try container.encode(globalCode, forKey: .globalCode)
        try container.encode(dynamicCode, forKey: .dynamicCode)
        try container.encode(widthProperty, forKey: .widthProperty)
        try container.encode(heightProperty, forKey: .heightProperty)
        try container.encode(pointsVariable, forKey: .pointsVariable)
        try container.encode(pointCount, forKey: .pointCount)
        try container.encode(pointsScale, forKey: .pointsScale)
        try container.encode(supportsRounding, forKey: .supportsRounding)
    }
    
    /// Creates the distance code for the shape, optionally using the supplied transformed properties or insertig the metal code for accessing the shape data structure
    func createDistanceCode( uvName: String, transProperties: [String:Float]? = nil, layerIndex: Int? = nil, pointIndex: Int? = nil, shapeIndex: Int? = nil) -> String
    {
        var code = distanceCode
        let props = transProperties != nil ? transProperties : properties
        
        code = code.replacingOccurrences(of: "__uv__", with: String(uvName))
        
        for (name,value) in props! {
            if name == widthProperty && layerIndex != nil {
                var widthCode = "layerData->shapes[\(layerIndex!)].size.x"
                if supportsRounding {
                    widthCode += "- layerData->shapes[\(layerIndex!)].rounding"
                }
                widthCode += "- layerData->shapes[\(layerIndex!)].annular"
                code = code.replacingOccurrences(of: "__" + name + "__", with: widthCode)
            } else
            if name == heightProperty && layerIndex != nil {
                var heightCode = "layerData->shapes[\(layerIndex!)].size.y"
                if supportsRounding {
                    heightCode += "- layerData->shapes[\(layerIndex!)].rounding"
                }
                heightCode += "- layerData->shapes[\(layerIndex!)].annular"
                code = code.replacingOccurrences(of: "__" + name + "__", with: heightCode)
            } else
            if (name == widthProperty || name == heightProperty) && transProperties != nil {
                var widthHeightCode = String(value)
                let minSize : Float = min(transProperties![widthProperty]!,transProperties![heightProperty]!)
                if supportsRounding {
                    widthHeightCode += "- \(transProperties!["rounding"]!*minSize)"
                }
                widthHeightCode += "- \(transProperties!["annular"]!*minSize)"
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
        
        if dynamicCode != nil && shapeIndex != nil {
            // --- Handling of variable points for a shape
            code = code.replacingOccurrences(of: "__shapeIndex__", with: String(shapeIndex!))
            if pointsVariable {
                code = code.replacingOccurrences(of: "__pointsVariable__", with: self.name + String(shapeIndex!))
            }
        }
        
        return code
    }
    
    /// Create the code for a shape with variable points
    func createPointsVariableCode(shapeIndex: Int, transProperties: [String:Float]? = nil, pointIndex: Int? = nil, maxPoints: Int? = nil) -> String
    {
        var result = ""
        let props = transProperties != nil ? transProperties : properties
        let varName = name+String(shapeIndex)

        let points : Int = maxPoints != nil ? maxPoints! : pointCount
        
        result += "float2 \(varName)[\(points)];\n"
        for i in 0..<points {
            if pointIndex == nil {
                result += "\(varName)[\(i)].x = \(props!["point_\(i)_x"]!);\n"
                result += "\(varName)[\(i)].y = \(props!["point_\(i)_y"]!);\n"
            } else {
                result += "\(varName)[\(i)] = layerData->points[\(pointIndex!+i)];\n"
            }
        }
        return result
    }
    
    /// Updates the untransformed size of the shape
    func updateSize()
    {
        var size = float2(0)
        
        if pointCount == 0 {
            size.x = properties[widthProperty]! * 2
            size.y = properties[heightProperty]! * 2
        } else {
            
            let posX = properties["posX"]!
            let posY = -properties["posY"]!
            
            let width = properties[widthProperty]!
            let height = properties[heightProperty]!
            
            var minX : Float = 100000, minY : Float = 100000, maxX : Float = -100000, maxY : Float = -100000
            for i in 0..<pointCount {
                minX = min( minX, posX + properties["point_\(i)_x"]! - width )
                minY = min( minY, posY - properties["point_\(i)_y"]! - height )
                maxX = max( maxX, posX + properties["point_\(i)_x"]! + width )
                maxY = max( maxY, posY - properties["point_\(i)_y"]! + height )
            }
            
            size.x = maxX - minX
            size.y = maxY - minY
        }
        properties["sizeX"] = size.x
        properties["sizeY"] = size.y
    }
}
