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
        case Inactive, CenterMove, xAxisMove, yAxisMove, Rotate, xAxisScale, yAxisScale, xyAxisScale
    }
    
    var hoverState          : GizmoState = .Inactive
    var dragState           : GizmoState = .Inactive
    
    var component            : CodeComponent!

    func setComponent(_ comp: CodeComponent)
    {
        component = comp
    }
    
    /// Returns the StageItem hierarchy for the given component
    func getHierarchyOfComponent(_ comp: CodeComponent) -> [StageItem]
    {
        for item in globalApp!.pipeline.codeBuilder.sdfStream.ids.values {
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
        
        for stageItem in getHierarchyOfComponent(comp).reversed() {
            if let transComponent = stageItem.components[stageItem.defaultName] {

                // Transform
                var properties : [String:Float] = [:]
                properties[name] = transComponent.values[name]!
                
                let transformed = timeline.transformProperties(sequence: transComponent.sequence, uuid: transComponent.uuid, properties: properties, frame: timeline.currentFrame)
                
                value += transformed[name]!
            }
        }
        return value
    }
}
