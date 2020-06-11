//
//  PipelineCloud3D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 11/6/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class PipelineCloud3D       : Pipeline
{
    enum Stage : Int {
        case None, Compiling, Compiled, HitAndNormals, AO, ShadowsAndMaterials, Reflection
    }

    var currentStage        : Stage = .None
    var maxStage            : Stage = .Reflection

    var instanceMap         : [String:CodeBuilderInstance] = [:]
        
    var width               : Float = 0
    var height              : Float = 0
    
    var reflections         : Int = 0
    var maxReflections      : Int = 4
    
    var maxSamples          : Int = 4

    var renderId            : UInt = 0
    var justStarted         : Bool = true
    var startedRender       : Bool = false
    
    var startId             : UInt = 0
    
    var settings            : PipelineRenderSettings? = nil
    
    var compiledSuccessfully: Bool = true
    
    var idCounter           : Int = 0
    
    var scene               : Scene!
    
    var dummyTerrainTexture : MTLTexture? = nil
    
    var lineNumber          : Float = 0
    var renderIsRunning     : Bool = false
    
    var pointCloudBuilder   : PointCloudBuilder
    var cameraComponent     : CodeComponent!

    override init(_ mmView: MMView)
    {
        pointCloudBuilder = PointCloudBuilder(mmView)
        
        super.init(mmView)
        finalTexture = checkTextureSize(10, 10, nil, .rgba16Float)
        dummyTerrainTexture = checkTextureSize(10, 10, nil, .rg8Sint)
    }
    
    override func setMinimalPreview(_ mode: Bool = false)
    {
        if mode == true {
            maxStage = .HitAndNormals
        } else {
            maxStage = .Reflection
        }
        globalApp!.currentEditor.render()
    }
    
    // Build the pipeline elements
    override func build(scene: Scene)
    {
        self.scene = scene
        let preStage = scene.getStage(.PreStage)
        let result = getFirstItemOfType(preStage.getChildren(), .Camera3D)
        cameraComponent = result.1!
    }
        
    // Render the pipeline
    override func render(_ widthIn: Float,_ heightIn: Float, settings: PipelineRenderSettings? = nil)
    {
        width = round(widthIn); height = round(heightIn)

        checkFinalTexture(true)
        
        var points : [Float] = []
        
        let shapeStage = scene.getStage(.ShapeStage)
        codeBuilder.sdfStream.reset()
        for (index, item) in shapeStage.getChildren().enumerated() {
            if index > 0 {
                if let transform = item.components[item.defaultName] {
                    points.append(transform.values["_posX"]!)
                    points.append(transform.values["_posY"]!)
                    points.append(transform.values["_posZ"]!)
                }
            }
        }
        
        print(points.count)
        pointCloudBuilder.render(points: points, texture: finalTexture!, camera: cameraComponent)
    }
    
    func checkFinalTexture(_ clear: Bool = false)
    {
        let needsResize = width != Float(finalTexture!.width) || height != Float(finalTexture!.height)
        finalTexture = checkTextureSize(width, height, finalTexture, .rgba16Float)
        if needsResize || clear {
            codeBuilder.renderClear(texture: finalTexture!, data: SIMD4<Float>(0, 0, 0, 1))
        }
    }
}
