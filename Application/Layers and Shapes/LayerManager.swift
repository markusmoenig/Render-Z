//
//  LayerManager.swift
//  Shape-Z
//
//  Created by Markus Moenig on 15/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class LayerManager : Codable
{
    var layers          : [Layer]
    var currentIndex    : Int
    
    var compute         : MMCompute?
    
    var width           : Float!
    var height          : Float!
    
    var camera          : [Float]

    var app             : App?
    
    private enum CodingKeys: String, CodingKey {
        case layers
        case currentIndex
        case camera
    }
    
    init()
    {
        layers = []
        
        currentIndex = 0
        
        width = 0
        height = 0
        
        camera = [0,0]
        
        let layer = Layer( layerManager: self )
        addLayer( layer )
    }
    
    func addLayer(_ layer: Layer)
    {
        layers.append( layer )
    }
    
    func build()
    {
    }
    
    @discardableResult func render(width:Float, height:Float) -> MTLTexture
    {
        let layer = layers[currentIndex]
        
        self.width = width; self.height = height
        let texture = layer.render(width:width, height:height)
        return texture
    }
    
    /// Returns the current layer
    func getCurrentLayer() -> Layer
    {
        return layers[currentIndex]
    }
    
    /// Returns the current object
    func getCurrentObject() -> Object?
    {
        let layer = getCurrentLayer()
        return layer.getCurrentObject()
    }
    
    /// Returns either the uuid of the current shape or object
    func getCurrentUUID() -> UUID
    {
        let object = getCurrentObject()
        let shape : Shape? = object?.getCurrentShape()
        
        if shape != nil {
            return shape!.uuid
        } else {
            return object!.uuid
        }
    }
    
    /// Get the object and shape id at the specific location
    func getShapeAt( x: Float, y: Float, multiSelect: Bool = false)
    {
        var source =
        """
            #include <metal_stdlib>
            #include <simd/simd.h>
            using namespace metal;

            float4 merge(float4 d1, float4 d2)
            {
                if ( d1.x < d2.x ) return d1;
                else return d2;
            }


            float2 translate(float2 p, float2 t)
            {
                return p - t;
            }
            
            float2 rotateCW(float2 pos, float angle)
            {
                float ca = cos(angle), sa = sin(angle);
                return pos * float2x2(ca, -sa, sa, ca);
            }

            float2 rotateCCW(float2 pos, float angle)
            {
                float ca = cos(angle),  sa = sin(angle);
                return pos * float2x2(ca, sa, -sa, ca);
            }

        """
        
        source += getGlobalCode()
        
        source +=
        """
        
            kernel void
            selectedAt(device float4  *out [[ buffer(0) ]],
            uint id [[ thread_position_in_grid ]])
            {
                float2 fragCoord = float2( \(x), \(y) );
                float2 uv = 700. * (fragCoord.xy + float(0.5)) / \(width!);
        
                float2 center = float2( 350., 350. * \(height!) / \(width!) );
                uv = translate(uv, center - float2( \(camera[0]), \(camera[1]) ) );
                float2 tuv = uv;
        
                float4 dist = float4(1000, -1, -1, -1);
        
        """
        
        for (layerIndex, layer) in layers.enumerated() {
            for (objectIndex, object) in layer.objects.enumerated() {
                for (shapeIndex, shape) in object.shapes.enumerated() {
                    
                    let timeline = app!.bottomRegion!.timeline
                    let transformed = timeline.transformProperties(sequence:layer.sequence, uuid:shape.uuid, properties:shape.properties)
                    let posX : Float = transformed["posX"]!
                    let posY : Float = transformed["posY"]!
                    let rotate : Float = transformed["rotate"]! * Float.pi / 180

                    source += "uv = translate( tuv, float2( \(posX), \(posY) ) );\n"
                    if rotate != 0.0 {
                        if shape.pointCount < 2 {
                            source += "uv = rotateCW( uv, \(rotate) );\n"
                        } else {
                            let offX = (transformed["point_0_x"]! + transformed["point_1_x"]!) / 2
                            let offY = (transformed["point_0_y"]! + transformed["point_1_y"]!) / 2
                            source += "uv = rotateCW( uv - float2( \(offX), \(offY) ), \(rotate) );\n"
                            source += "uv += float2( \(offX), \(offY) );\n"
                        }
                    }
                    source += "dist = merge( dist, float4(" + shape.createDistanceCode(uvName: "uv", transProperties: transformed) + ", \(layerIndex), \(objectIndex), \(shapeIndex) ) );"
                }
            }
        }
    
        source +=
        """
        
                out[id] = dist;
            }
        """
        
        if compute == nil {
            compute = MMCompute()
        }
            
        let library = compute!.createLibraryFromSource(source: source)
        let state = compute!.createState(library: library, name: "selectedAt")

        let outBuffer = compute!.device.makeBuffer(length: MemoryLayout<float4>.stride, options: [])!
        compute!.runBuffer(state, outBuffer: outBuffer)
        
        let result = outBuffer.contents().load(as: float4.self)
//        print( result )
        
        if result.x < 0 {
            let layerId : Int = Int(result.y)
            let layer = layers[layerId]
            
            let objectId : Int = Int(result.z)
            let object = layer.objects[objectId]
            
            let shapeId : Int = Int(result.w)
            let shape = object.shapes[shapeId]
            
            if !multiSelect {
                object.selectedShapes = [shape.uuid]
            } else if !object.selectedShapes.contains(shape.uuid) {
                object.selectedShapes.append( shape.uuid )
            }
            
            app!.gizmo.setObject(object)
            app!.rightRegion!.changed = true
        } else
        if !multiSelect {
            if let object = getCurrentObject() {
                object.selectedShapes = []
                
                app!.gizmo.setObject(nil)
                app!.rightRegion!.changed = true
            }
        }
    }
    
    /// Gets the global code of all shapes in the project
    func getGlobalCode() -> String
    {
        var coll : [String] = []
        var result = ""
        
        for layer in layers {
            for object in layer.objects {
                for shape in object.shapes {
                
                    if !coll.contains(shape.name) {
                        result += shape.globalCode
                        coll.append( shape.name )
                    }
                }
            }
        }
        
        return result
    }
}
