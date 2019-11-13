//
//  SceneRenderer.swift
//  Shape-Z
//
//  Created by Markus Moenig on 5/8/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class SceneRenderer {
    
    var fragment        : MMFragment!
    var mmView          : MMView
    
    var nodeGraph       : NodeGraph!
        
    init(_ view : MMView )
    {
        mmView = view
        fragment = MMFragment(view)
    }
    
    func setup( nodeGraph: NodeGraph, instances: [Object], scene: Scene? = nil ) -> BuilderInstance?
    {
        self.nodeGraph = nodeGraph
        
        for inst in instances {
            var renderDirectly : Bool = true
            if inst.properties["updateMode"] != nil && inst.properties["updateMode"] == 1 {
                renderDirectly = false
            }
            if renderDirectly {
                inst.fragmentInstance = nodeGraph.builder.buildObjects(objects: [inst], camera: Camera(), fragment: fragment, renderMode: Object.getRenderMode(inst))
            } else {
                // Render to texture
                inst.instance = nodeGraph.builder.buildObjects(objects: [inst], camera: Camera())
            }
        }
        
        let builderInstance = BuilderInstance()
        builderInstance.objects = instances
        builderInstance.scene = scene
        
        return builderInstance
    }
    
    func render( width: Float, height: Float, camera: Camera, instance: BuilderInstance, outTexture: MTLTexture? = nil )
    {
        let texture : MTLTexture
        
        if outTexture == nil {
            if fragment.width != width || fragment.height != height {
                fragment.allocateTexture(width: width, height: height)
            }
            texture = fragment.texture
        } else {
            texture = outTexture!
        }
                
        if fragment.encoderStart(outTexture: texture) {
            let sortedInstances = instance.objects.sorted(by: { $0.properties["z-index"]! < $1.properties["z-index"]! })
            for inst in sortedInstances {
                if inst.properties["active"] == 1 && inst.shapes.count > 0 {
                    
                    var renderDirectly : Bool = true

                    if inst.properties["updateMode"] != nil && inst.properties["updateMode"] == 1 {
                        // Render to texture first
                        //print("render to texture for", inst.name)
                        renderDirectly = false
                    }
                    
                    if renderDirectly == true {
                        // Render directly
                        updateInstance(width, height, inst, camera: camera, scene: instance.scene)
                        
                        var honorBBox : Bool = false
                        var clipRectApplied : Bool = false
                        var renderIt : Bool = true
                        
                        if inst.properties["bBox"] != nil && inst.properties["bBox"] == 1 {
                            honorBBox = true
                        }
                        
                        if let objectRect = inst.objectRect, nodeGraph.playButton == nil, honorBBox {
                                                                            
                            var res = convertToScreenSpace(x: (inst.properties["posX"]!) * camera.zoom, y: (inst.properties["posY"]!) * camera.zoom, screenWidth: width, screenHeight: height, camera: camera)
                            
                            let bBoxBorder : Float = inst.properties["bBoxBorder"]! + 2
                                                        
                            let objectMidX : Float = objectRect.xPos + objectRect.width / 2
                            let objectMidY : Float = -objectRect.yPos + objectRect.height / 2

                            res.x -= objectRect.width/2 * camera.zoom + bBoxBorder * camera.zoom - objectMidX * camera.zoom
                            res.y -= objectRect.height/2 * camera.zoom + bBoxBorder * camera.zoom - objectMidY * camera.zoom
                                          
                            //if !res.x.isNaN || !res.y.isNaN {
                                renderIt = fragment.applyClipRect(MMRect(res.x, res.y, (objectRect.width+bBoxBorder*2) * camera.zoom, (objectRect.height + bBoxBorder*2) * camera.zoom))
                                clipRectApplied = renderIt
                            //}
                        }
                        
                        if renderIt {
                            fragment.encodeRun(inst.fragmentInstance!.fragmentState!, inBuffer: inst.fragmentInstance!.buffer, inTexture: inst.fragmentInstance!.font!.atlas)
                        }
                        
                        if clipRectApplied {
                            fragment.renderEncoder!.setScissorRect( MTLScissorRect(x:0, y:0, width:Int(width), height:Int(height) ) )
                        }
                    } else {
                        // Render to texture
                        var texNeedsUpdate : Bool = false
                        let computeInst = inst.instance!
                        
                        let realWidth : Float = width//Float(Int(width / camera.zoom))
                        let realHeight : Float = height//Float(Int(height / camera.zoom))

                        if computeInst.texture == nil || Float(computeInst.texture!.width) != realWidth || Float(computeInst.texture!.height) != realHeight {
                            texNeedsUpdate = true
                            computeInst.texture = fragment.allocateTexture(width: realWidth, height: realHeight, output: false)
                            print("New Texture", realWidth, realHeight)
                        }
                        
                        if let texture = computeInst.texture {
                            if texNeedsUpdate == true {
                                print("Update", camera.zoom)
                                nodeGraph.builder.updateInstanceData(instance: computeInst, camera: camera, frame: 0)
                                nodeGraph.builder.render(width: realWidth, height: realHeight, instance: computeInst, camera: camera, outTexture: texture)
                            }
                            
                            mmView.drawTexture.draw(texture, x: 0, y: 0, zoom: 1/camera.zoom, fragment: fragment, prem: false)
                        }
                    }
                }
            }
            fragment.encodeEnd()
        }
    }
    
    func updateInstance(_ width: Float,_ height: Float,_ inst: Object, camera: Camera, scene: Scene? = nil)
    {
        let instance = inst.fragmentInstance!

        //print( inst.properties["posX"], inst.instanceOf!.properties["posY"] )
                
        instance.data![0] = camera.xPos
        instance.data![1] = camera.yPos
        instance.data![2] = 1/camera.zoom
        
        //instance.data![4] = instance.layerGlobals!.position.x
        //instance.data![5] = instance.layerGlobals!.position.y
        
        instance.data![6] = width//instance.layerGlobals!.limiterSize.x / 2
        instance.data![7] = height//instance.layerGlobals!.limiterSize.y / 2
        
        instance.data![8] = instance.data![8] + (1000/60) / 1000
        instance.data![9] = 0.1
        instance.data![10] = 1

        instance.scene = scene
        nodeGraph.builder.updateInstanceData(instance: instance, camera: camera, frame: 0)
        
        memcpy(instance.buffer!.contents(), instance.data!, instance.data!.count * MemoryLayout<Float>.stride)
    }
    
    func convertToScreenSpace(x: Float, y: Float, screenWidth: Float, screenHeight: Float, camera: Camera) -> SIMD2<Float>
    {
        var result : SIMD2<Float> = SIMD2<Float>()
                
        result.x = x - camera.xPos
        result.y = camera.yPos - y
        
        result.x += screenWidth/2
        result.y += screenWidth/2 * screenHeight / screenWidth
        
        return result
    }
}
