//
//  GroundShaders.swift
//  Render-Z
//
//  Created by Markus Moenig on 12/4/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import MetalKit

class GroundShaders
{
    var groundEditor            : GroundEditor!
    let mmView                  : MMView
    
    var previewSettings         = PipelineRenderSettings()
    var previewPipeline         : Pipeline2D
    
    let previewScene            = Scene(.TwoD, "Ground Preview")
    
    var lastPreviewWidth        : Float = 0
    var lastPreviewHeight       : Float = 0
    
    var mergeComponent          : CodeComponent? = nil

    init(_ view: MMView)
    {
        mmView = view
        previewPipeline = Pipeline2D(view)
        previewSettings.transparent = true
    }
    
    func buildRegionPreview()
    {
        let shapeStage = previewScene.getStage(.ShapeStage)
        shapeStage.children2D = []
        
        let oldMode = globalApp!.currentSceneMode
        globalApp!.currentSceneMode = .TwoD
        //for region in groundEditor.groundItem.children {
        if let region = groundEditor.currentRegion {
            //if region.componentLists["shapes2D"] == nil {
            //continue
            //}
            
            let stageItem = shapeStage.createChild()
            if mergeComponent == nil {
                mergeComponent = globalApp!.libraryDialog.getItem(ofId: "Boolean", withName: "Merge")
            }
            
            for regionComp in region.componentLists["shapes2D"]! {
                regionComp.subComponent = mergeComponent
                stageItem.componentLists["shapes2D"]!.append(regionComp)
            }
            shapeStage.children2D.append(stageItem)
        }
        globalApp!.currentSceneMode = oldMode
        
        previewPipeline.build(scene: previewScene)
        globalApp!.currentEditor.updateOnNextDraw(compile: true)
        updateRegionPreview()
    }
    
    func updateRegionPreview()
    {
        // Set the camera values
        let preStage = previewScene.getStage(.PreStage)
        let camera : CodeComponent = getFirstComponentOfType(preStage.children2D, .Camera2D)!
                
        setPropertyValue1(component: camera, name: "cameraX", value: -groundEditor.offset.x * groundEditor.gridSize * groundEditor.graphZoom)
        setPropertyValue1(component: camera, name: "cameraY", value: -groundEditor.offset.y * groundEditor.gridSize * groundEditor.graphZoom)
        setPropertyValue1(component: camera, name: "scale", value: 1/groundEditor.graphZoom)

        previewPipeline.render(groundEditor.rect.width, groundEditor.rect.height, settings: previewSettings)
        lastPreviewWidth = groundEditor.rect.width
        lastPreviewHeight = groundEditor.rect.height
        //globalApp!.currentEditor.updateOnNextDraw(compile: false)
    }
    
    func drawPreview()
    {
        // Do the preview
        if let texture = previewPipeline.finalTexture {
            if groundEditor.rect.width == Float(texture.width) && groundEditor.rect.height == Float(texture.height) {
                mmView.drawTexture.draw(texture, x: groundEditor.rect.x, y: groundEditor.rect.y)
            } else {
                mmView.drawTexture.drawScaled(texture, x: groundEditor.rect.x, y: groundEditor.rect.y, width: groundEditor.rect.width, height: groundEditor.rect.height)
            }
            previewPipeline.renderIfResolutionChanged(groundEditor.rect.width, groundEditor.rect.height)
        }
    }
    
    func selectComponentAt(event: MMMouseEvent)
    {
        let x : Float = event.x - groundEditor.rect.x
        let y : Float = event.y - groundEditor.rect.y
        
        // Selection
        if let texture = previewPipeline.depthTexture {
            
            if let convertTo = globalApp!.currentPipeline!.codeBuilder.compute.allocateTexture(width: Float(texture.width), height: Float(texture.height), output: true, pixelFormat: .rgba32Float) {
            
                globalApp!.currentPipeline!.codeBuilder.renderCopy(convertTo, texture, syncronize: true)
                
                let region = MTLRegionMake2D(min(Int(x), convertTo.width-1), min(Int(y), convertTo.height-1), 1, 1)

                var texArray = Array<SIMD4<Float>>(repeating: SIMD4<Float>(repeating: 0), count: 1)
                //convertTo.getBytes(UnsafeMutableRawPointer(mutating: texArray), bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * convertTo.width), from: region, mipmapLevel: 0)
                texArray.withUnsafeMutableBytes { texArrayPtr in
                    convertTo.getBytes(texArrayPtr.baseAddress!, bytesPerRow: (MemoryLayout<SIMD4<Float>>.size * convertTo.width), from: region, mipmapLevel: 0)
                }
                let value = texArray[0]
                                
                if value.x <= 0 {
                    let comp = groundEditor.currentRegion!.componentLists["shapes2D"]![Int(value.w)]
                    groundEditor.setCurrentRegion(groundEditor.currentRegion!, comp)
                } else {
                    groundEditor.currentComponent = nil
                }
                
                mmView.update()
            }
        }
    }
}
