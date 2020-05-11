//
//  Base.swift
//  Render-Z
//
//  Created by Markus Moenig on 19/1/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation

class GizmoBase              : MMWidget
{
    enum GizmoState         : Float {
        case Inactive, CenterMove, xAxisMove, yAxisMove, zAxisMove, Rotate, xAxisScale, yAxisScale, zAxisScale, xyAxisScale, CameraMove, CameraPan, CameraRotate, CameraZoom, xAxisRotate, yAxisRotate, zAxisRotate
    }
    
    var hoverState          : GizmoState = .Inactive
    var dragState           : GizmoState = .Inactive
    
    var clickWasConsumed    : Bool = false
    
    var component           : CodeComponent!
    
    var customCameraCB      : ((_ name: String)->(Float))? = nil

    func setComponent(_ comp: CodeComponent)
    {
        component = comp
    }
    
    /// Returns the StageItem hierarchy for the given component
    func getHierarchyOfComponent(_ comp: CodeComponent) -> [StageItem]
    {
        for item in globalApp!.currentPipeline!.codeBuilder.sdfStream.ids.values {
            if item.1 === comp {
                return item.0
            }
        }
        return []
    }
    
    /// Returns the stage item for the given component (from the stream ids)
    func getHierarchyValue(_ comp: CodeComponent,_ name: String) -> Float
    {
        let timeline = globalApp!.artistEditor.timeline
        var value : Float = 0

        if comp.componentType == .SDF2D || comp.componentType == .SDF3D {
            for stageItem in getHierarchyOfComponent(comp).reversed() {
                if let transComponent = stageItem.components[stageItem.defaultName] {
                    
                    // Transform
                    var properties : [String:Float] = [:]
                    properties[name] = transComponent.values[name]!
                    
                    let transformed = timeline.transformProperties(sequence: transComponent.sequence, uuid: transComponent.uuid, properties: properties, frame: timeline.currentFrame)
                    
                    value += transformed[name]!
                }
            }
        } else
        if comp.componentType == .Transform2D || comp.componentType == .Transform3D {
            
            let stage = globalApp!.project.selected!.getStage(.ShapeStage)
            
            func transformValue(_ comp: CodeComponent)
            {
                if let tValue = comp.values[name] {
                    
                    // Transform
                    var properties : [String:Float] = [:]
                    properties[name] = tValue
                    
                    let transformed = timeline.transformProperties(sequence: comp.sequence, uuid: comp.uuid, properties: properties, frame: timeline.currentFrame)
                    
                    value += transformed[name]!
                }
            }
            
            if let stageItem = globalApp!.project.selected!.getStageItem(comp, selectIt: false) {
                var p = stage.getParentOfStageItem(stageItem).1
                while( p != nil ) {
                    transformValue(p!.components[p!.defaultName]!)
                    p = stage.getParentOfStageItem(p!).1
                }
            }
        }
        return value
    }
    
    /// Returns a property value of the camera
    func getCameraPropertyValue(_ name: String, defaultValue: Float = 0) -> Float
    {
        // Custom camera for embedded use, i.e. terrain editor
        if let cameraCB = customCameraCB {
            return cameraCB(name)
        }
        
        let camera : CodeComponent = getFirstComponentOfType(globalApp!.project.selected!.getStage(.PreStage).getChildren(), globalApp!.currentSceneMode == .TwoD ? .Camera2D : .Camera3D)!

        for uuid in camera.properties {
            let rc = camera.getPropertyOfUUID(uuid)
            if let frag = rc.0 {
                if frag.name == name {
                    return rc.1!.values["value"]!
                }
            }
        }
        
        return defaultValue
    }
    
    /// Returns a property value of the camera
    func getCameraPropertyValue3(_ name: String, defaultValue: SIMD3<Float> = SIMD3<Float>(0,0,0)) -> SIMD3<Float>
    {
        let camera : CodeComponent = getFirstComponentOfType(globalApp!.project.selected!.getStage(.PreStage).getChildren(), globalApp!.currentSceneMode == .TwoD ? .Camera2D : .Camera3D)!

        for uuid in camera.properties {
            let rc = camera.getPropertyOfUUID(uuid)
            if let frag = rc.0 {
                if frag.name == name && frag.typeName == "float3" {
                    let value = extractValueFromFragment( rc.1! )
                    return SIMD3<Float>(value.x, value.y, value.z)
                }
            }
        }
        
        return defaultValue
    }
}
