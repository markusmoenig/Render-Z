//
//  GizmoInfoArea.swift
//  Shape-Z
//
//  Created by Markus Moenig on 13.06.19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import Foundation

class GizmoInfoAreaItem {
    
    var mmView      : MMView
    var title       : String
    var variable    : String
    var value       : Float
    var rect        : MMRect
    
    var titleLabel  : MMTextLabel
    var valueLabel  : MMTextLabel

    init(_ mmView: MMView,_ title: String,_ variable: String,_ value: Float)
    {
        self.mmView = mmView
        self.title = title
        self.variable = variable
        self.value = value
        
        rect = MMRect()
        
        titleLabel = MMTextLabel(mmView, font: mmView.openSans, text:title, scale: 0.3 )
        valueLabel = MMTextLabel(mmView, font: mmView.openSans, text:String(format: "%.02f", value), scale: 0.3 )
    }
    
    func setValue(_ value: Float)
    {
        self.value = value
        valueLabel.setText(String(format: "%.02f", value))
    }
}

class GizmoInfoArea {
    
    enum GizmoProperty {
        case WidthProperty, HeightProperty
    }
    
    var gizmo           : Gizmo
    var items           : [GizmoInfoAreaItem] = []
    
    var hoverItem       : GizmoInfoAreaItem? = nil
    
    init(_ gizmo: Gizmo)
    {
        self.gizmo = gizmo
    }
    
    func reset()
    {
        items = []
        hoverItem = nil
    }
    
    func addItem(_ title: String,_ variable: String,_ value: Float)
    {
        let item = GizmoInfoAreaItem(gizmo.mmView, title, variable, value)
        items.append(item)
    }
    
    func addItemsFor(_ state: Gizmo.GizmoState,_ transformed: [String:Float])
    {
        if state == .CenterMove {
            addItem("X", "posX", transformed["posX"]!)
            addItem("Y", "posY", transformed["posY"]!)
        } else
        if state == .xAxisMove {
            addItem("X", "posX", transformed["posX"]!)
        } else
        if state == .yAxisMove {
            addItem("Y", "posY", transformed["posY"]!)
        } else
        if state == .xAxisScale {
            let widthProperty = getProperty(.WidthProperty)
            addItem("Width", widthProperty, transformed[widthProperty]!)
        } else
        if state == .yAxisScale {
            let heightProperty = getProperty(.HeightProperty)
            addItem("Height", heightProperty, transformed[heightProperty]!)
        }
        if state == .Rotate {
            addItem("Rotation", "rotate", transformed["rotate"]!)
        }
    }
    
    func getProperty(_ prop: GizmoProperty) -> String
    {
        var result = ""
        if prop == .WidthProperty {
            if gizmo.context == .ShapeEditor {
                let selectedShapeObjects = gizmo.object!.getSelectedShapes()
                if selectedShapeObjects.count == 1 {
                    result = selectedShapeObjects[0].widthProperty
                }
            }
        } else
        if prop == .HeightProperty {
            if gizmo.context == .ShapeEditor {
                let selectedShapeObjects = gizmo.object!.getSelectedShapes()
                if selectedShapeObjects.count == 1 {
                    result = selectedShapeObjects[0].heightProperty
                }
            }
        }
        
        return result
    }
    
    func updateItems(_ transformed: [String:Float])
    {
        for item in items {
            if transformed[item.variable] != nil {
                let value = transformed[item.variable]!
                item.setValue(value)
            }
        }
    }
    
    func mouseMoved(_ event: MMMouseEvent) -> Bool
    {
        hoverItem = nil

        for item in items {
            if item.rect.contains(event.x, event.y) {
                hoverItem = item
                break
            }
        }
        
        return hoverItem != nil
    }
    
    func mouseDown(_ event: MMMouseEvent) -> Bool
    {
        if hoverItem != nil {
            
            getNumberDialog(view: gizmo.mmView, title: hoverItem!.title, message: "Enter new value", defaultValue: hoverItem!.value, cb: { (value) -> Void in

                let object = self.gizmo.object
                let context = self.gizmo.context
                
                if object != nil && context == .ShapeEditor {
                    let selectedShapes = object!.getSelectedShapes()
                    for shape in selectedShapes {
                        shape.updateSize()
                    }
                    
                    let properties : [String:Float] = [
                        self.hoverItem!.variable : value
                    ]
                    self.gizmo.processGizmoProperties(properties, shape: selectedShapes[0])
                    self.hoverItem!.setValue(value)
                    
                    // Undo for shape based action
                    if selectedShapes.count == 1 && !NSDictionary(dictionary: selectedShapes[0].properties).isEqual(to: self.gizmo.undoProperties) {
                        
                        func applyProperties(_ shape: Shape,_ old: [String:Float],_ new: [String:Float])
                        {
                            self.gizmo.mmView.undoManager!.registerUndo(withTarget: self) { target in
                                shape.properties = old
                                
                                applyProperties(shape, new, old)
                            }
                            self.gizmo.app.updateObjectPreview(self.gizmo.rootObject!)
                            self.gizmo.mmView.update()
                        }
                        
                        applyProperties(selectedShapes[0], self.gizmo.undoProperties, selectedShapes[0].properties)
                    }
                }
                
            } )
        }
        return hoverItem != nil
    }

    func draw()
    {
        if items.isEmpty { return }
        
        let rect = gizmo.rect
        var x : Float = rect.x + 5
        
        for item in items {
            
            if item === hoverItem {
                gizmo.mmView.drawBox.draw( x: item.rect.x, y: item.rect.y, width: item.rect.width, height: item.rect.height, round: 4, borderSize: 0, fillColor : gizmo.mmView.skin.ToolBarButton.hoverColor )
            }
            
            item.titleLabel.rect.x = x
            item.titleLabel.rect.y = rect.y + rect.height - 15
            item.titleLabel.draw()
            
            item.rect.x = x - 4
            item.rect.y = item.titleLabel.rect.y - 4
            item.rect.height = item.titleLabel.rect.height + 8

            x += item.titleLabel.rect.width + 5
            
            item.valueLabel.rect.x = x
            item.valueLabel.rect.y = item.titleLabel.rect.y
            item.valueLabel.draw()
            
            x += item.valueLabel.rect.width + 10
            
            item.rect.width = x - item.rect.x - 6
        }
    }
}
