//
//  Gizmo.swift
//  Shape-Z
//
//  Created by Markus Moenig on 23/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
import simd

/// Gizmo used in all views
class Gizmo : MMWidget
{
    enum GizmoMode {
        case Normal, Point
    }
    
    enum GizmoState : Float {
        case Inactive, CenterMove, xAxisMove, yAxisMove, Rotate, xAxisScale, yAxisScale, xyAxisScale, GizmoUIMenu, GizmoUI, GizmoUIMouseLocked, AddPoint, RemovePoint, ColorWidgetClosed, ColorWidgetOpened, FloatWidgetClosed, FloatWidgetOpened, PointHover, InfoAreaHover
    }
    
    enum GizmoContext : Float {
        case ShapeEditor, ObjectEditor, MaterialEditor
    }
    
    var app             : App!
    
    var mode            : GizmoMode = .Normal
    var context         : GizmoContext = .ShapeEditor
    var materialType    : Object.MaterialType = .Body
    var inSceneEditor   : Bool = false

    var hoverState      : GizmoState = .Inactive
    var dragState       : GizmoState = .Inactive
    
    var normalState     : MTLRenderPipelineState!
    var pointState      : MTLRenderPipelineState!

    let width           : Float
    let height          : Float
    
    var object          : Object?
    var objects         : [Object]
    var rootObject      : Object?
    
    var dragStartOffset : float2?
    var gizmoCenter     : float2 = float2()
    
    var startRotate     : Float = 0
    
    var initialValues   : [UUID:[String:Float]] = [:]

    var gizmoRect       : MMRect = MMRect()
    var gizmoNode       : GizmoNode!
    
    var gizmoInfoArea   : GizmoInfoArea!

    var gizmoUIMenuRect : MMRect = MMRect()
    var gizmoUIOpen     : Bool = false
    
    var gizmoVariableShape              : Shape? = nil
    var gizmoVariableConnection         : UINodeConnection? = nil
    var gizmoNodeUIMasterPicker         : NodeUIMasterPicker? = nil
    var gizmoNodeUIFloatVariablePicker  : NodeUIFloatVariablePicker? = nil
    
    var gizmoPtPlusRect : MMRect = MMRect()
    var gizmoPtMinusRect: MMRect = MMRect()
    var gizmoPtLockRect : MMRect = MMRect()
    
    var hoverUIItem     : NodeUI?
    var hoverUITitle    : NodeUI?
    
    // --- MaterialEditor context
    var colorWidget     : MMColorPopupWidget!
    var floatWidget     : MMFloatPopUp!

    // --- For the point based gizmo
    
    var pointShape      : Shape? = nil
    var pointMaterial   : Material? = nil
    var pointIndex      : Int = 0
    
    var scale           : Float = 1
    
    var maxDelegate     : NodeMaxDelegate? = nil
    
    var undoProperties  : [String:Float] = [:]
    var undoData        : Data? = nil

    override required init(_ view : MMView)
    {
        var function = view.renderer.defaultLibrary.makeFunction( name: "drawGizmo" )
        normalState = view.renderer.createNewPipelineState( function! )
        function = view.renderer.defaultLibrary.makeFunction( name: "drawPointGizmo" )
        pointState = view.renderer.createNewPipelineState( function! )
        
        width = 260
        height = 260
        objects = []
        
        colorWidget = MMColorPopupWidget(view)
        floatWidget = MMFloatPopUp(view)

        super.init(view)

        gizmoInfoArea = GizmoInfoArea(self)
        gizmoNode = GizmoNode(self)
        
        // --- Color change handling
        colorWidget.changed = { (color, continuous) -> () in
            let selectedMaterials = self.object!.getSelectedMaterials(self.materialType)
            var props : [String:Float] = [:]
            
            if self.mode == .Normal {
                props["value_x"] = color.x
                props["value_y"] = color.y
                props["value_z"] = color.z
                props["value_w"] = color.w
            } else
            if self.mode == .Point {
                props["pointvalue_\(self.pointIndex)_x"] = color.x
                props["pointvalue_\(self.pointIndex)_y"] = color.y
                props["pointvalue_\(self.pointIndex)_z"] = color.z
                props["pointvalue_\(self.pointIndex)_w"] = color.w
            }
            
            for material in selectedMaterials {
                self.processGizmoMaterialProperties(props, material: material)
            }
            if !continuous {
                self.performUndo(ignoreDragState: true)
                self.undoProperties = selectedMaterials[0].properties
            }
            self.rootObject!.maxDelegate!.update(false, updateLists: !continuous)
        }
        
        // --- Float change handling
        floatWidget.changed = { (value, continuous) -> () in
            let selectedMaterials = self.object!.getSelectedMaterials(self.materialType)
            var props : [String:Float] = [:]
            
            if self.mode == .Normal {
                props["value_x"] = value
                props["value_y"] = value
                props["value_z"] = value
                props["value_w"] = 1
            } else
            if self.mode == .Point {
                props["pointvalue_\(self.pointIndex)_x"] = value
                props["pointvalue_\(self.pointIndex)_y"] = value
                props["pointvalue_\(self.pointIndex)_z"] = value
                props["pointvalue_\(self.pointIndex)_w"] = 1
            }
            for material in selectedMaterials {
                self.processGizmoMaterialProperties(props, material: material)
            }
            if !continuous {
                print("invoke undo")
                self.performUndo(ignoreDragState: true)
                self.undoProperties = selectedMaterials[0].properties
            }
            self.rootObject!.maxDelegate!.update(false, updateLists: !continuous)
        }
    }
    
    // Set the object the gizmo will be working on
    func setObject(_ object:Object?, rootObject: Object?=nil, context: GizmoContext = .ShapeEditor, materialType: Object.MaterialType = .Body, customDelegate: NodeMaxDelegate? = nil, inSceneEditor: Bool = false)
    {
        if self.object !== object {
            if self.object != nil && object != nil && self.object!.uuid == object!.uuid {
            } else {
                gizmoInfoArea.reset()
            }
        }
                
        self.object = object
        self.context = context
        self.materialType = materialType
        self.inSceneEditor = inSceneEditor
        
        if rootObject != nil {
            self.rootObject = rootObject
        } else {
            self.rootObject = object
        }
        
        // Assign the maxDelegate
        if self.rootObject != nil {
            maxDelegate = customDelegate == nil ? self.rootObject!.maxDelegate : customDelegate
        }
        
        colorWidget.setState(.Closed)
        if context == .MaterialEditor {
            let selectedMaterials = object!.getSelectedMaterials(materialType)
            if selectedMaterials.count > 0 {
                let material = selectedMaterials[0]
                if material.pointCount == 0 {
                    colorWidget.setValue(color: SIMD3<Float>(material.properties["value_x"]!, material.properties["value_y"]!, material.properties["value_z"]!))
                    floatWidget.value = material.properties["value_x"]!
                }
            }
        }
        
        mode = .Normal
        if object != nil {
            objects = [object!]
        } else {
            objects = []
        }
        
        // Setup Gizmo UI
        gizmoNode.uiItems = []
        gizmoNode.uiConnections = []
        gizmoNodeUIMasterPicker = nil
        gizmoNodeUIFloatVariablePicker = nil
        gizmoVariableShape = nil
        gizmoVariableConnection = nil
        
        if context == .ShapeEditor
        {
            let selectedShapes = object!.getSelectedShapes()
            
            func getInterpolatedValue(variable: String) -> Float
            {
                if selectedShapes.count == 0 { return 0}
                
                var value : Float = 0
                var count : Float = 0
                for shape in selectedShapes {
                    value += shape.properties[variable]!
                    count += 1
                }
                value /= count
                return value
            }
            
            // Smoothing
            gizmoNode.properties["smoothBoolean"] = getInterpolatedValue(variable: "smoothBoolean")
            gizmoNode.uiItems.append(
                NodeUINumber(gizmoNode, variable: "smoothBoolean", title: "Smooth Bool", range: float2(0, 1), value: 0.0)
            )
        
            // Shape specific variables
            for shape in selectedShapes {
                
                if shape.supportsRounding {
                    gizmoNode.properties["rounding"] = getInterpolatedValue(variable: "rounding")
                    gizmoNode.uiItems.append(
                        NodeUINumber(gizmoNode, variable: "rounding", title: "Rounding", range: float2(0, 1), value: 0.0)
                    )
                }
            }
            
            // Variables which work for every shape
            // -- Annular
            gizmoNode.properties["annular"] = getInterpolatedValue(variable: "annular")
            gizmoNode.uiItems.append(
                NodeUINumber(gizmoNode, variable: "annular", title: "Annular", range: float2(0, 1), value: 0.0)
            )
            
            if selectedShapes.count == 1 {
                let shape = selectedShapes[0]
                
                if shape.name == "Text" {
                    gizmoNode.uiItems.append(
                        NodeUIText(gizmoNode, variable: "text", title: "Text", value: shape.customText!)
                    )
                } else
                if shape.name == "Variable" {
                    gizmoVariableShape = shape

                    gizmoVariableConnection = UINodeConnection(.FloatVariable)
                    gizmoNode.uiConnections.append(gizmoVariableConnection!)

                    gizmoNodeUIMasterPicker = NodeUIMasterPicker(gizmoNode, variable: "master", title: "Class", connection: gizmoVariableConnection!)
                    gizmoNode.uiItems.append(
                        gizmoNodeUIMasterPicker!
                    )
                    
                    gizmoNodeUIFloatVariablePicker = NodeUIFloatVariablePicker(gizmoNode, variable: "var", title: "Variable", connection: gizmoVariableConnection!)
                    gizmoNode.uiItems.append(
                        gizmoNodeUIFloatVariablePicker!
                    )
                    
                    if gizmoVariableShape!.customReference != nil {
                        if let connectedNode = app.nodeGraph.getNodeForUUID(gizmoVariableShape!.customReference!) {

                            gizmoVariableConnection?.connectedTo = gizmoVariableShape!.customReference!
                            
                            gizmoVariableConnection?.target = connectedNode
                            
                            if let master = app.nodeGraph.getMasterForNode(connectedNode) {
                                gizmoVariableConnection?.connectedMaster = master.uuid
                                gizmoVariableConnection?.masterNode = master
                            }
                        }
                    }

                    app.nodeGraph.updateNode(gizmoNode!)
                    gizmoVariableShape!.customReference = gizmoVariableConnection!.connectedTo
                }
                
                var customs : [NodeUI] = []
                for (key, value) in shape.properties {
                    if key.starts(with: "custom_") {
                        let cKey = String(key.dropFirst(7))
                        let title = cKey.capitalizingFirstLetter()
                        customs.append(
                            NodeUINumber(gizmoNode, variable: key, title: title, range: float2(shape.properties[cKey + "_min"]!, shape.properties[cKey + "_max"]!), int: shape.properties[cKey + "_int"]! == 0 ? false : true, value: value)
                        )
                    }
                }
                let sorted = customs.sorted(by: { $0.title.lowercased() < $1.title.lowercased() })
                for item in sorted {
                    gizmoNode.uiItems.append( item )
                }
                
                // -- Update the info area
                
                if !gizmoInfoArea.items.isEmpty {
                    let transformed = getTransformedProperties(shape)
                    gizmoInfoArea.updateItems(transformed)
                }
            }
            
            // --

            gizmoNode.setupUI(mmView: mmView)
        } else
        if context == .MaterialEditor {
            
            let selectedMaterials = object!.getSelectedMaterials(materialType)
            if selectedMaterials.count == 1 {
                let material = selectedMaterials[0]
                
                if !material.isCompound {
                    gizmoNode.properties["channel"] = material.properties["channel"]
                    gizmoNode.uiItems.append(
                        NodeUISelector(gizmoNode, variable: "channel", title: "Channel", items: ["Base Color", "Subsurface","Roughness", "Metallic", "Specular", "Specular Tint", "Clearcoat", "Clearc. Gloss", "Anisotropic", "Sheen", "Sheen Tint", "Border"], index: 0)
                    )
                    
                    gizmoNode.properties["limiterType"] = material.properties["limiterType"]
                    gizmoNode.uiItems.append(
                        NodeUISelector(gizmoNode, variable: "limiterType", title: "Limiter", items: ["None", "Rectangle", "Sphere", "Border"], index: 0)
                    )
                    
                    gizmoNode.properties["bump"] = material.properties["bump"]
                    gizmoNode.uiItems.append(
                        NodeUISelector(gizmoNode, variable: "bump", title: "Bump", items: ["Off", "On","Ignore Channel"], index: 0)
                    )
                }
                
                var customs : [NodeUI] = []
                for (key, value) in material.properties {
                    if key.starts(with: "custom_") {
                        let cKey = String(key.dropFirst(7))
                        let title = cKey.capitalizingFirstLetter()
                        customs.append(
                            NodeUINumber(gizmoNode, variable: key, title: title, range: float2(material.properties[cKey + "_min"]!, material.properties[cKey + "_max"]!), int: material.properties[cKey + "_int"]! == 0 ? false : true, value: value)
                        )
                    }
                }
                let sorted = customs.sorted(by: { $0.title.lowercased() < $1.title.lowercased() })
                for item in sorted {
                    gizmoNode.uiItems.append( item )
                }
                
                // -- Update the info area
                
                if !gizmoInfoArea.items.isEmpty {
                    let transformed = getTransformedProperties(material)
                    gizmoInfoArea.updateItems(transformed)
                }
            }
            
            gizmoNode.setupUI(mmView: mmView)
        } else
        if context == .ObjectEditor && inSceneEditor && self.object != nil {
            gizmoNode.properties["opacity"] = self.object!.properties["opacity"]
            gizmoNode.uiItems.append(
                NodeUINumber(gizmoNode, variable: "opacity", title: "Opacity", range: float2(0, 1), value: 1.0)
            )
            gizmoNode.properties["z-index"] = self.object!.properties["z-index"]
            gizmoNode.uiItems.append(
                NodeUINumber(gizmoNode, variable: "z-index", title: "Z-Index", range: float2(-5, 5), int: true, value: 0.0)
            )
            gizmoNode.properties["active"] = self.object!.properties["active"]
            gizmoNode.uiItems.append(
                NodeUISelector(gizmoNode, variable: "active", title: "Active", items: ["No", "Yes"], index: 1)
            )
            gizmoNode.setupUI(mmView: mmView)
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        if object == nil { return }

        #if os(OSX)
        if hoverUITitle != nil {
            hoverUITitle?.titleClicked()
            return
        }
        #endif
        
        undoData = nil
        // If shape editor has no shape, set to inactive
        if object!.selectedShapes.count == 0 && context == .ShapeEditor { hoverState = .Inactive; return }
        
        // Check if an gizmo info area item was clicked
        if gizmoInfoArea.mouseDown(event) {
            hoverState = .InfoAreaHover
            if mode == .Normal && context == .ShapeEditor {
                let selectedShapes = object!.getSelectedShapes()
                if selectedShapes.count == 1 {
                    undoProperties = selectedShapes[0].properties
                    if isRecording() {
                        undoData = try? JSONEncoder().encode(rootObject!.sequences)
                    }
                }
            } else
            if mode == .Normal && context == .MaterialEditor {
                let selectedMaterials = object!.getSelectedMaterials(materialType)
                if selectedMaterials.count == 1 {
                    undoProperties = selectedMaterials[0].properties
                    if isRecording() {
                        undoData = try? JSONEncoder().encode(rootObject!.sequences)
                    }
                }
            } else
            if mode == .Normal && context == .ObjectEditor {
                undoProperties = object!.properties
                if isRecording() {
                    undoData = try? JSONEncoder().encode(rootObject!.sequences)
                }
            }
            return
        }

//        #if os(iOS) || os(watchOS) || os(tvOS)
        if mode == .Normal {
            updateNormalHoverState(editorRect: rect, event: event)
            
            // --- Open / Close UI menu
            if hoverState == .GizmoUIMenu {
                if gizmoUIOpen == false {
                    gizmoUIOpen = true
                } else {
                    gizmoUIOpen = false
                }
                return
            } else
            if gizmoUIOpen && hoverState == .GizmoUI {
                hoverUIItem!.mouseDown(event)
                hoverState = .GizmoUIMouseLocked
            }
            
            // --- Point Controls
            
            if hoverState == .AddPoint {
                let shape = object!.getSelectedShapes()[0]
                let transformed = shape.properties//getTransformedProperties(shape)

                let ptX = (transformed["point_0_x"]! + transformed["point_\(shape.pointCount-1)_x"]!) / 2
                let ptY = (transformed["point_0_y"]! + transformed["point_\(shape.pointCount-1)_y"]!) / 2
                
                shape.properties["point_\(shape.pointCount)_x"] = ptX
                shape.properties["point_\(shape.pointCount)_y"] = ptY
                shape.pointCount += 1
                
                maxDelegate!.update(true)
            } else
            if hoverState == .RemovePoint {
                let shape = object!.getSelectedShapes()[0]
                if shape.pointCount > 3 {
                    shape.pointCount -= 1
                    maxDelegate!.update(true)
                }
            }
        } else {
            updatePointHoverState(editorRect: rect, event: event)
        }
//        #endif
    
        // --- Check if a point was clicked (including the center point for the normal gizmo)
        if hoverState == .PointHover && object != nil && context == .ShapeEditor {
            pointShape = nil
            
            let attributes = getCurrentGizmoAttributes()
            let posX : Float = attributes["posX"]!
            let posY : Float = attributes["posY"]!
            
            // --- Points
            let selectedShapes = object!.getSelectedShapes()
            if selectedShapes.count == 1 {
                for shape in selectedShapes {
                    
                    for index in 0..<shape.pointCount {
                        
                        var pX = posX + attributes["point_\(index)_x"]!
                        var pY = posY + attributes["point_\(index)_y"]!
                        
                        let ptConn = object!.getPointConnections(shape: shape, index: index)
                        
                        if ptConn.0 != nil {
                            // The point controls other point(s)
                            ptConn.0!.valueX = pX
                            ptConn.0!.valueY = pY
                        }
                        
                        if ptConn.1 != nil {
                            // The point is being controlled by another point
                            pX = ptConn.1!.valueX
                            pY = -ptConn.1!.valueY
                        }
                        
                        let pointInScreen = convertToScreenSpace(x: pX, y: pY)
                        
                        let radius : Float = 10
                        let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                        if rect.contains(event.x, event.y) {
                            if ptConn.1 != nil {
                                // If point is a slave remove the connection
                                object!.removePointConnection(toShape: shape, toIndex: index)
                            } else {
                                // If point controls itself enter point gizmo
                                pointShape = shape
                                pointIndex = index
                                mode = .Point
                                hoverState = .CenterMove
                            }
                        }
                    }
                }
            }
        } else
        if hoverState == .PointHover && object != nil && context == .MaterialEditor {
            pointMaterial = nil
            
            let attributes = getCurrentGizmoAttributes()
            let posX : Float = attributes["posX"]!
            let posY : Float = attributes["posY"]!
            
            // --- Points
            let selectedMaterials = object!.getSelectedMaterials(materialType)
            if selectedMaterials.count == 1 {
                for material in selectedMaterials {
                    
                    for index in 0..<material.pointCount {
                        
                        let pX = posX + attributes["point_\(index)_x"]!
                        let pY = posY + attributes["point_\(index)_y"]!
                        
                        let pointInScreen = convertToScreenSpace(x: pX, y: pY)
                        
                        let radius : Float = 10
                        let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                        if rect.contains(event.x, event.y) {
                            // Enter point gizmo
                            pointMaterial = material
                            pointIndex = index
                            mode = .Point
                            hoverState = .CenterMove
                        }
                    }
                }
            }
        }
        
        // --- ColorWidget
        if context == .MaterialEditor {
            if colorWidget.states.contains(.Opened) {
                if colorWidget.rect.contains(event.x, event.y) {
                    colorWidget.mouseDown(event)
                } else {
                    colorWidget.setState(.Closed)
                }
                return
            } else
                if floatWidget.states.contains(.Opened) {
                    if floatWidget.rect.contains(event.x, event.y) {
                        floatWidget.mouseDown(event)
                    } else {
                        floatWidget.setState(.Closed)
                    }
                    return
            }
        }
        
        //  Open Color or Float Widget ?
        if hoverState == .ColorWidgetClosed {
            colorWidget.setState(.Opened)
            let selectedMaterials = object!.getSelectedMaterials(materialType)
            if selectedMaterials.count > 0 {
                undoProperties = selectedMaterials[0].properties
            }
            return
        } else
        if hoverState == .FloatWidgetClosed {
            floatWidget.setState(.Opened)
            let selectedMaterials = object!.getSelectedMaterials(materialType)
            if selectedMaterials.count > 0 {
                undoProperties = selectedMaterials[0].properties
            }
            return
        }
        
        // --- Gizmo Action
        if hoverState != .Inactive {
            mmView.mouseTrackWidget = self
            dragState = hoverState != .GizmoUIMouseLocked ? hoverState : .Inactive
            mmView.lockFramerate()
            
            dragStartOffset = convertToSceneSpace(x: event.x, y: event.y)
            startRotate = getAngle(cx: gizmoCenter.x, cy: gizmoCenter.y, ex: event.x, ey: event.y, degree: true)

            initialValues = [:]
            gizmoInfoArea.reset()
            
            if mode == .Normal && context == .ShapeEditor {
                
                for shape in object!.getSelectedShapes() {
                    let transformed = getTransformedProperties(shape)
                    
                    if object!.selectedShapes.count == 1 {
                        gizmoInfoArea.addItemsFor(hoverState, transformed)
                    }
                    
                    initialValues[shape.uuid] = [:]
                    initialValues[shape.uuid]!["posX"] = transformed["posX"]!
                    initialValues[shape.uuid]!["posY"] = transformed["posY"]!
                    initialValues[shape.uuid]!["rotate"] = transformed["rotate"]!
                    
                    initialValues[shape.uuid]![shape.widthProperty] = transformed[shape.widthProperty]!
                    initialValues[shape.uuid]![shape.heightProperty] = transformed[shape.heightProperty]!
                    
                    undoProperties = shape.properties
                    if isRecording() {
                        undoData = try? JSONEncoder().encode(rootObject!.sequences)
                    }
                }
            } else
            if mode == .Normal && context == .MaterialEditor {
                let materials = object!.getSelectedMaterials(materialType)

                for material in materials {
                    let transformed = getTransformedProperties(material)
                    
                    if materials.count == 1 {
                        gizmoInfoArea.addItemsFor(hoverState, transformed)
                    }
                    
                    initialValues[material.uuid] = [:]
                    initialValues[material.uuid]!["posX"] = transformed["posX"]!
                    initialValues[material.uuid]!["posY"] = transformed["posY"]!
                    initialValues[material.uuid]!["rotate"] = transformed["rotate"]!
                    
                    initialValues[material.uuid]!["limiterWidth"] = transformed["limiterWidth"]!
                    initialValues[material.uuid]!["limiterHeight"] = transformed["limiterHeight"]!

                    initialValues[material.uuid]![material.widthProperty] = transformed[material.widthProperty]!
                    initialValues[material.uuid]![material.heightProperty] = transformed[material.heightProperty]!
                    
                    undoProperties = material.properties
                    if isRecording() {
                        undoData = try? JSONEncoder().encode(rootObject!.sequences)
                    }
                }
            } else
            if mode == .Normal && context == .ObjectEditor {
                for object in objects {
                    
                    initialValues[object.uuid] = [:]
                    let transformed = object.properties
                    if objects.count == 1 {
                        gizmoInfoArea.addItemsFor(hoverState, transformed)
                    }
                    
                    initialValues[object.uuid]!["posX"] = transformed["posX"]!
                    initialValues[object.uuid]!["posY"] = transformed["posY"]!
                    initialValues[object.uuid]!["rotate"] = transformed["rotate"]!
                    initialValues[object.uuid]!["scaleX"] = transformed["scaleX"]!
                    initialValues[object.uuid]!["scaleY"] = transformed["scaleY"]!
                    
                    undoProperties = object.properties
                    if isRecording() {
                        undoData = try? JSONEncoder().encode(rootObject!.sequences)
                    }
                }
            } else
            if mode == .Point {
                // Save the point position
                if context == .ShapeEditor {
                    let shape = pointShape!
                    
                    let transformed = getTransformedProperties(shape)

                    initialValues[shape.uuid] = [:]
                    initialValues[shape.uuid]!["posX"] = transformed["point_\(pointIndex)_x"]!
                    initialValues[shape.uuid]!["posY"] = transformed["point_\(pointIndex)_y"]!
                    
                    undoProperties = shape.properties
                    if isRecording() {
                        undoData = try? JSONEncoder().encode(rootObject!.sequences)
                    }
                    let properties : [String:Float] = [
                        "point_\(pointIndex)_x" : transformed["point_\(pointIndex)_x"]!,
                        "point_\(pointIndex)_y" : transformed["point_\(pointIndex)_y"]!
                    ]
                    gizmoInfoArea.addItemsFor(hoverState, properties)
                } else
                if context == .MaterialEditor {
                    let material = pointMaterial!
                    
                    let transformed = getTransformedProperties(material)

                    initialValues[material.uuid] = [:]
                    initialValues[material.uuid]!["posX"] = transformed["point_\(pointIndex)_x"]!
                    initialValues[material.uuid]!["posY"] = transformed["point_\(pointIndex)_y"]!
                    
                    undoProperties = material.properties
                    if isRecording() {
                        undoData = try? JSONEncoder().encode(rootObject!.sequences)
                    }
                    let properties : [String:Float] = [
                        "point_\(pointIndex)_x" : transformed["point_\(pointIndex)_x"]!,
                        "point_\(pointIndex)_y" : transformed["point_\(pointIndex)_y"]!
                    ]
                    gizmoInfoArea.addItemsFor(hoverState, properties)
                }
            }
        }
        
        // --- If no point selected switch to normal mode
        if mode == .Point && pointShape == nil && context == .ShapeEditor {
            mode = .Normal
        } else
        if mode == .Point && pointMaterial == nil && context == .MaterialEditor {
            mode = .Normal
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        if context == .MaterialEditor && colorWidget.states.contains(.Opened) {
            if colorWidget.rect.contains(event.x, event.y) {
                colorWidget.mouseUp(event)
            }
            return
        } else
        if context == .MaterialEditor && floatWidget.states.contains(.Opened) {
            floatWidget.mouseUp(event)
            return
        }

        // Undo
        performUndo()

        if hoverState == .GizmoUIMouseLocked {
            hoverUIItem!.mouseUp(event)
        }
        if dragState != .Inactive {
            mmView.unlockFramerate()
        }
        mmView.mouseTrackWidget = nil
        #if os(OSX)
        if hoverState != .CenterMove {
            hoverState = .Inactive
        }
        #elseif os(iOS)
        hoverState = .Inactive
        if hoverUITitle != nil {
            hoverUITitle?.titleClicked()
        }
        #endif
    
        dragState = .Inactive

        /// After dragging a point, check if it overlaps with any point in a previous shape
        /// If yes, connect them
        if mode == .Point && context == .ShapeEditor {
            //pointShape = shape
            //pointIndex = index
            let shapeTransformed = getTransformedProperties(pointShape!)
            let x = shapeTransformed["posX"]! + pointShape!.properties["point_\(pointIndex)_x"]!
            let y = shapeTransformed["posY"]! + pointShape!.properties["point_\(pointIndex)_y"]!
            
            for shape in object!.shapes {
                if shape === pointShape { break }
                let transformed = getTransformedProperties(shape)
                
                for i in 0..<shape.pointCount {
                    let pX = transformed["posX"]! + shape.properties["point_\(i)_x"]!
                    let pY = transformed["posY"]! + shape.properties["point_\(i)_y"]!
                    
                    if abs(x - pX) < 10 && abs(y - pY) < 10 {
                        //let conn = ObjectPointConnection(fromShape: shape.uuid, fromIndex: i, toShape: pointShape!.uuid, toIndex: pointIndex)
                        
                        // Connections of the source point
                        let sourceConnections = object!.getPointConnections(shape: shape, index: i)
                        
                        // Connections of the dest point
                        let destConnections = object!.getPointConnections(shape: pointShape!, index: pointIndex)
                        
                        // Make sure that the dest point is not already a destination
                        if destConnections.1 == nil {
                            var conn : ObjectPointConnection? = sourceConnections.0
                            
                            if conn == nil {
                                conn = ObjectPointConnection(fromShape: shape.uuid, fromIndex: i, toShape: pointShape!.uuid, toIndex: pointIndex)
                                object!.pointConnections.append(conn!)
                            } else {
                                conn!.toShapes[pointShape!.uuid] = pointIndex
                            }
                            
                            mode = .Normal
                            maxDelegate!.update(false)
                            break
                        }
                    }
                }
            }
        }
        update()
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if hoverState == .GizmoUIMouseLocked {
            hoverUIItem!.mouseMoved(event)
            return
        }

        if hoverUIItem != nil {
            hoverUIItem!.mouseLeave()
        }
        
        if hoverUITitle != nil {
            hoverUITitle?.titleHover = false
            hoverUITitle = nil
            mmView.update()
        }
        
        // ColorWidget / FloatWidget
        if context == .MaterialEditor && colorWidget.states.contains(.Opened) {
            if colorWidget.rect.contains(event.x, event.y) {
                colorWidget.mouseMoved(event)
            }
            return
        } else
        if context == .MaterialEditor && floatWidget.states.contains(.Opened) {
            floatWidget.mouseMoved(event)
            return
        }
        
        if dragState == .Inactive {
            let oldHoverState = hoverState
            let oldHoverItem = gizmoInfoArea.hoverItem
            
            if !gizmoInfoArea.mouseMoved(event) {
                if mode == .Normal {
                    updateNormalHoverState(editorRect: rect, event: event)
                } else {
                    updatePointHoverState(editorRect: rect, event: event)
                }
            }
            
            if oldHoverState != hoverState || oldHoverItem !== gizmoInfoArea.hoverItem {
                update()
            }
        } else {
            let pos = convertToSceneSpace(x: event.x, y: event.y)
            let selectedShapeObjects = object!.getSelectedShapes()
            let selectedMaterialObjects = object!.getSelectedMaterials(materialType)
            maxDelegate!.update(false)
            
            if dragState == .CenterMove {
                if context == .ShapeEditor {
                    if mode == .Normal {
                        for shape in selectedShapeObjects {
                            let properties : [String:Float] = [
                                "posX" : initialValues[shape.uuid]!["posX"]! + (pos.x - dragStartOffset!.x) / scale,
                                "posY" : initialValues[shape.uuid]!["posY"]! - (pos.y - dragStartOffset!.y) / scale,
                            ]
                            gizmoInfoArea.updateItems(properties)
                            processGizmoProperties(properties, shape: shape)
                        }
                    } else {
                        let shape = pointShape!
                        let properties : [String:Float] = [
                            "point_\(pointIndex)_x" : initialValues[shape.uuid]!["posX"]! + (pos.x - dragStartOffset!.x) / scale,
                            "point_\(pointIndex)_y" : initialValues[shape.uuid]!["posY"]! - (pos.y - dragStartOffset!.y) / scale,
                            ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoProperties(properties, shape: shape)
                    }
                } else
                if context == .MaterialEditor {
                    if mode == .Normal {
                        for material in selectedMaterialObjects {
                            let properties : [String:Float] = [
                                "posX" : initialValues[material.uuid]!["posX"]! + (pos.x - dragStartOffset!.x) / scale,
                                "posY" : initialValues[material.uuid]!["posY"]! - (pos.y - dragStartOffset!.y) / scale,
                            ]
                            gizmoInfoArea.updateItems(properties)
                            processGizmoMaterialProperties(properties, material: material)
                        }
                    } else {
                        let material = pointMaterial!
                        let properties : [String:Float] = [
                            "point_\(pointIndex)_x" : initialValues[material.uuid]!["posX"]! + (pos.x - dragStartOffset!.x) / scale,
                            "point_\(pointIndex)_y" : initialValues[material.uuid]!["posY"]! - (pos.y - dragStartOffset!.y) / scale,
                        ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoMaterialProperties(properties, material: material)
                    }
                } else
                if context == .ObjectEditor {
                    for object in objects {
                        let properties : [String:Float] = [
                            "posX" : initialValues[object.uuid]!["posX"]! + (pos.x - dragStartOffset!.x) / scale,
                            "posY" : initialValues[object.uuid]!["posY"]! - (pos.y - dragStartOffset!.y) / scale,
                            ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoObjectProperties(properties, object: object)
                    }
                }
            } else
            if dragState == .xAxisMove {
                if context == .ShapeEditor {
                    if mode == .Normal {
                        for shape in selectedShapeObjects {
                            let properties : [String:Float] = [
                                "posX" : initialValues[shape.uuid]!["posX"]! + (pos.x - dragStartOffset!.x) / scale,
                                ]
                            gizmoInfoArea.updateItems(properties)
                            processGizmoProperties(properties, shape: shape)
                        }
                    } else {
                        let shape = pointShape!
                        let properties : [String:Float] = [
                            "point_\(pointIndex)_x" : initialValues[shape.uuid]!["posX"]! + (pos.x - dragStartOffset!.x) / scale,
                            ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoProperties(properties, shape: shape)
                    }
                } else
                if context == .MaterialEditor {
                    if mode == .Normal {
                        for material in selectedMaterialObjects {
                            let properties : [String:Float] = [
                                "posX" : initialValues[material.uuid]!["posX"]! + (pos.x - dragStartOffset!.x) / scale,
                            ]
                            gizmoInfoArea.updateItems(properties)
                            processGizmoMaterialProperties(properties, material: material)
                        }
                    } else {
                        let material = pointMaterial!
                        let properties : [String:Float] = [
                            "point_\(pointIndex)_x" : initialValues[material.uuid]!["posX"]! + (pos.x - dragStartOffset!.x) / scale,
                        ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoMaterialProperties(properties, material: material)
                    }
                } else
                if context == .ObjectEditor {
                    for object in objects {
                        let properties : [String:Float] = [
                            "posX" : initialValues[object.uuid]!["posX"]! + (pos.x - dragStartOffset!.x) / scale,
                            ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoObjectProperties(properties, object: object)
                    }
                }
            } else
            if dragState == .yAxisMove {
                if context == .ShapeEditor {
                    if  mode == .Normal {
                        for shape in selectedShapeObjects {
                            let properties : [String:Float] = [
                                "posY" : initialValues[shape.uuid]!["posY"]! - (pos.y - dragStartOffset!.y) / scale,
                                ]
                            gizmoInfoArea.updateItems(properties)
                            processGizmoProperties(properties, shape: shape)
                        }
                    } else {
                        let shape = pointShape!
                        let properties : [String:Float] = [
                            "point_\(pointIndex)_y" : initialValues[shape.uuid]!["posY"]! - (pos.y - dragStartOffset!.y) / scale,
                            ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoProperties(properties, shape: shape)
                    }
                } else
                if context == .MaterialEditor {
                    if  mode == .Normal {
                        for material in selectedMaterialObjects {
                            let properties : [String:Float] = [
                                "posY" : initialValues[material.uuid]!["posY"]! - (pos.y - dragStartOffset!.y) / scale,
                            ]
                            gizmoInfoArea.updateItems(properties)
                            processGizmoMaterialProperties(properties, material: material)
                        }
                    } else {
                        let material = pointMaterial!
                        let properties : [String:Float] = [
                            "point_\(pointIndex)_y" : initialValues[material.uuid]!["posY"]! - (pos.y - dragStartOffset!.y) / scale,
                        ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoMaterialProperties(properties, material: material)
                    }
                } else
                if context == .ObjectEditor {
                    for object in objects {
                        let properties : [String:Float] = [
                            "posY" : initialValues[object.uuid]!["posY"]! - (pos.y - dragStartOffset!.y) / scale,
                            ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoObjectProperties(properties, object: object)
                    }
                }
            } else
            if dragState == .xAxisScale {
                if context == .ShapeEditor {
                    for shape in selectedShapeObjects {
                        let propName : String = shape.widthProperty
                        var value = initialValues[shape.uuid]![propName]! + (pos.x - dragStartOffset!.x) / scale
                        if value < 0 {
                            value = 0
                        }
                        var properties : [String:Float] = [
                            propName : value,
                        ]
                        // Shift for uniform scaling
                        if mmView.shiftIsDown && shape.heightProperty != shape.widthProperty {
                            properties[shape.heightProperty] = initialValues[shape.uuid]![shape.heightProperty]! + (pos.x - dragStartOffset!.x) / scale
                        }
                        gizmoInfoArea.updateItems(properties)
                        processGizmoProperties(properties, shape: shape)
                    }
                } else
                if context == .MaterialEditor {
                    for material in selectedMaterialObjects {
                        let propName : String
                        if material.properties["limiterType"]! == 0 {
                            propName = material.widthProperty
                        } else {
                            propName = "limiterWidth"
                        }
                        var value = initialValues[material.uuid]![propName]! + (pos.x - dragStartOffset!.x) / scale
                        if value < 0 {
                            value = 0
                        }
                        let properties : [String:Float] = [
                            propName : value,
                        ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoMaterialProperties(properties, material: material)
                    }
                } else
                if context == .ObjectEditor {
                    for object in objects {
                        var value = initialValues[object.uuid]!["scaleX"]! + ((pos.x - dragStartOffset!.x)) * 0.1 / scale
                        if value < 0 {
                            value = 0
                        }
                        var properties : [String:Float] = [
                            "scaleX" : value,
                        ]
                        // In the scene editor do uniform scaling
                        if context == .ObjectEditor && inSceneEditor {
                            properties["scaleY"] = value
                        }
                        gizmoInfoArea.updateItems(properties)
                        processGizmoObjectProperties(properties, object: object)
                    }
                }
            } else
            if dragState == .yAxisScale {
                if context == .ShapeEditor {
                    for shape in selectedShapeObjects {
                        let propName : String = shape.heightProperty
                        var value = initialValues[shape.uuid]![propName]! - (pos.y - dragStartOffset!.y) / scale
                        if value < 0 {
                            value = 0
                        }
                        var properties : [String:Float] = [
                            propName : value,
                        ]
                        // Shift for uniform scaling
                        if mmView.shiftIsDown && shape.heightProperty != shape.widthProperty {
                            properties[shape.widthProperty] = initialValues[shape.uuid]![shape.widthProperty]! - (pos.y - dragStartOffset!.y) / scale
                        }
                        gizmoInfoArea.updateItems(properties)
                        processGizmoProperties(properties, shape: shape)
                    }
                } else
                if context == .MaterialEditor {
                    for material in selectedMaterialObjects {
                        let propName : String
                        if material.properties["limiterType"]! == 0 {
                            propName = material.heightProperty
                        } else {
                            propName = "limiterHeight"
                        }
                        var value = initialValues[material.uuid]![propName]! - (pos.y - dragStartOffset!.y) / scale
                        if value < 0 {
                            value = 0
                        }
                        var properties : [String:Float] = [
                            propName : value,
                        ]
                        if material.properties["limiterType"]! >= 2 {
                            properties[material.widthProperty] = material.properties[propName]
                        }
                        gizmoInfoArea.updateItems(properties)
                        processGizmoMaterialProperties(properties, material: material)
                    }
                } else
                if context == .ObjectEditor {
                    for object in objects {
                        var value = initialValues[object.uuid]!["scaleY"]! - ((pos.y - dragStartOffset!.y)) * 0.1 / scale
                        if value < 0 {
                            value = 0
                        }
                        var properties : [String:Float] = [
                            "scaleY" : value,
                        ]
                        // In the scene editor do uniform scaling
                        if context == .ObjectEditor && inSceneEditor {
                            properties["scaleX"] = value
                        }
                        
                        gizmoInfoArea.updateItems(properties)
                        processGizmoObjectProperties(properties, object: object)
                    }
                }
            } else
            if dragState == .Rotate {
                let angle = getAngle(cx: gizmoCenter.x, cy: gizmoCenter.y, ex: event.x, ey: event.y, degree: true)
                if context == .ShapeEditor {
                    for shape in selectedShapeObjects {
                        let initialValue = initialValues[shape.uuid]!["rotate"]!
                        var value = initialValue + ((angle - startRotate)).truncatingRemainder(dividingBy: 360)
                        if value < 0 {
                            value = 360 + value
                        }
                        let properties : [String:Float] = [
                            "rotate" : value
                        ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoProperties(properties, shape: shape)
                    }
                } else
                if context == .MaterialEditor {
                    for material in selectedMaterialObjects {
                        let initialValue = initialValues[material.uuid]!["rotate"]!
                        var value = initialValue + ((angle - startRotate)).truncatingRemainder(dividingBy: 360)
                        if value < 0 {
                            value = 360 + value
                        }
                        let properties : [String:Float] = [
                            "rotate" : value
                        ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoMaterialProperties(properties, material: material)
                    }
                } else
                if context == .ObjectEditor {
                    for object in objects {
                        let initialValue = initialValues[object.uuid]!["rotate"]!
                        var value = initialValue + ((angle - startRotate)).truncatingRemainder(dividingBy: 360)
                        if value < 0 {
                            value = 360 + value
                        }
                        let properties : [String:Float] = [
                            "rotate" : value
                        ]
                        gizmoInfoArea.updateItems(properties)
                        processGizmoObjectProperties(properties, object: object)
                    }
                }
            }
        }
    }
    
    /// Processes the new values for the properties of the given shape, either as a keyframe or a global change
    func processGizmoProperties(_ properties: [String:Float], shape: Shape)
    {
        if !isRecording() {
            for(name, value) in properties {
                shape.properties[name] = value
            }
        } else {
            let timeline = maxDelegate!.getTimeline()!
            let uuid = shape.uuid
            timeline.addKeyProperties(sequence: rootObject!.currentSequence!, uuid: uuid, properties: properties)
        }
    }
    
    /// Processes the new values for the properties of the given object, either as a keyframe or a global change
    func processGizmoObjectProperties(_ properties: [String:Float], object: Object)
    {
        if !isRecording() {
            for(name, value) in properties {
                object.properties[name] = value
            }
        } else {
            let timeline = maxDelegate!.getTimeline()!
            let uuid = object.uuid
            timeline.addKeyProperties(sequence: rootObject!.currentSequence!, uuid: uuid, properties: properties)
        }
    }
    
    /// Processes the new values for the properties of the given material, either as a keyframe or a global change
    func processGizmoMaterialProperties(_ properties: [String:Float], material: Material)
    {
        if !isRecording() {
            for(name, value) in properties {
                material.properties[name] = value
            }
        } else {
            let timeline = maxDelegate!.getTimeline()!
            let uuid = material.uuid
            timeline.addKeyProperties(sequence: rootObject!.currentSequence!, uuid: uuid, properties: properties)
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        if object == nil { hoverState = .Inactive; return }
        let selectedShapes = object!.getSelectedShapes()
        let selectedMaterials = object!.getSelectedMaterials(materialType)
        
        if selectedShapes.count == 0 && context == .ShapeEditor { hoverState = .Inactive; return }
        if selectedMaterials.count == 0 && context == .MaterialEditor { hoverState = .Inactive; return }
        
        let editorRect = rect
        
        let mmRenderer = mmView.renderer!
        
        let scaleFactor : Float = mmView.scaleFactor
        
        var data: [Float] = [
            width, height,
            hoverState.rawValue, 0
        ];
        
        let attributes = getCurrentGizmoAttributes()
        let posX : Float = attributes["posX"]!
        let posY : Float = attributes["posY"]!
        
        var screenSpace = convertToScreenSpace(x: posX, y: posY )

        mmRenderer.setClipRect(editorRect)

        let renderEncoder = mmRenderer.renderEncoder!
        if mode == .Normal {
            // --- Shape Points
            if context == .ShapeEditor && selectedShapes.count == 1 {
                // Points only get drawn when only one shape is selected
                for shape in selectedShapes {
                    for index in 0..<shape.pointCount {
                        
                        var pX = posX + attributes["point_\(index)_x"]!
                        var pY = posY + attributes["point_\(index)_y"]!

                        let ptConn = object!.getPointConnections(shape: shape, index: index)
                        
                        if ptConn.0 != nil {
                            // The point controls other point(s)
                            ptConn.0!.valueX = pX
                            ptConn.0!.valueY = pY
                        }
                        
                        if ptConn.1 != nil {
                            // The point is being controlled by another point
                            pX = ptConn.1!.valueX
                            pY = -ptConn.1!.valueY
                        }
                        
                        let pointInScreen = convertToScreenSpace(x: pX, y: pY)

                        var pFillColor = float4(repeating: 1)
                        var pBorderColor = float4( 0, 0, 0, 1)
                        let radius : Float = 10
                        #if os(OSX)
                        let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                        if rect.contains(mmView.mousePos.x, mmView.mousePos.y) {
                            let temp = pBorderColor
                            pBorderColor = pFillColor
                            pFillColor = temp
                        }
                        #endif
                        
                        if ptConn.1 != nil {
                            /// Point is linked to a previous point
                            pFillColor = float4(0,0,0,1)
                            pBorderColor = pFillColor
                        }

                        mmView.drawSphere.draw(x: pointInScreen.x - radius, y: pointInScreen.y - radius, radius: radius, borderSize: 3, fillColor: pFillColor, borderColor: pBorderColor)
                    }
                    
                    // --- Correct the gizmo position to be between the points
                    if shape.pointCount > 0 {
                        var offX : Float = 0
                        var offY : Float = 0
                        
                        for i in 0..<shape.pointCount {
                            offX += attributes["point_\(i)_x"]!
                            offY += attributes["point_\(i)_y"]!
                        }
                        offX /= Float(shape.pointCount)
                        offY /= Float(shape.pointCount)
                        
                        let pX = posX + offX
                        let pY = posY + offY
                        screenSpace = convertToScreenSpace(x: pX, y: pY )
                    }
                    
                    // --- Test if we have to hover highlight both scale axes
                    if selectedShapes.count == 1 && (hoverState == .xAxisScale || hoverState == .yAxisScale) {
                        if shape.widthProperty == shape.heightProperty || mmView.shiftIsDown {
                            data[3] = 1
                        }
                    }
                }
            } else
            // --- Shape Points
            if context == .MaterialEditor && selectedMaterials.count == 1 {
                // Points only get drawn when only one material is selected
                for material in selectedMaterials {
                    for index in 0..<material.pointCount {
                        
                        let pX = posX + attributes["point_\(index)_x"]!
                        let pY = posY + attributes["point_\(index)_y"]!
                        
                        let pointInScreen = convertToScreenSpace(x: pX, y: pY)
                        
                        var pFillColor = float4(repeating: 1)
                        var pBorderColor = float4( 0, 0, 0, 1)
                        let radius : Float = 10
                        #if os(OSX)
                        let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                        if rect.contains(mmView.mousePos.x, mmView.mousePos.y) {
                            let temp = pBorderColor
                            pBorderColor = pFillColor
                            pFillColor = temp
                        }
                        #endif
                        
                        mmView.drawSphere.draw(x: pointInScreen.x - radius, y: pointInScreen.y - radius, radius: radius, borderSize: 3, fillColor: pFillColor, borderColor: pBorderColor)
                    }
                    
                    // --- Correct the gizmo position to be between the points
                    if material.pointCount > 0 {
                        var offX : Float = 0
                        var offY : Float = 0
                        
                        for i in 0..<material.pointCount {
                            offX += attributes["point_\(i)_x"]!
                            offY += attributes["point_\(i)_y"]!
                        }
                        offX /= Float(material.pointCount)
                        offY /= Float(material.pointCount)
                        
                        let pX = posX + offX
                        let pY = posY + offY
                        screenSpace = convertToScreenSpace(x: pX, y: pY )
                    }
                    
                    // --- Test if we have to hover highlight both scale axes
                    if selectedMaterials.count == 1 && (hoverState == .xAxisScale || hoverState == .yAxisScale) {
                        if material.widthProperty == material.heightProperty && material.properties["limiterType"]! == 0 {
                            data[3] = 1
                        }
                        if material.properties["limiterType"]! >= 2 {
                            data[3] = 1
                        }
                    }
                }
            } else
            if (hoverState == .xAxisScale || hoverState == .yAxisScale) && context == .ObjectEditor && inSceneEditor {
                // Uniform scaling
                data[3] = 1
            }
            
            // --- Render Bound Box
            
            let margin : Float = 70
            if context == .ObjectEditor && inSceneEditor {
                gizmoRect.x = screenSpace.x - 100
                gizmoRect.y = screenSpace.y - 100
                gizmoRect.width = 200
                gizmoRect.height = 200
            } else {
                gizmoRect.x = attributes["sizeMinX"]! - margin
                gizmoRect.y = attributes["sizeMinY"]! - margin
                gizmoRect.width = attributes["sizeMaxX"]! - attributes["sizeMinX"]! + 2 * margin
                gizmoRect.height = attributes["sizeMaxY"]! - attributes["sizeMinY"]! + 2 * margin
            }
            
            if context == .ShapeEditor || (context == .ObjectEditor && inSceneEditor) {
                mmView.drawBox.draw(x: gizmoRect.x, y: gizmoRect.y, width: gizmoRect.width, height: gizmoRect.height, round: 0, borderSize: 2, fillColor: float4(repeating: 0), borderColor: float4(0.5, 0.5, 0.5, 1))
            }
            
            // --- Render Point Buttons
            
            if selectedShapes.count == 1 && selectedShapes[0].pointsVariable {
                // + / - Buttons
                
                gizmoPtPlusRect.width = 30
                gizmoPtPlusRect.height = 28
                
                gizmoPtPlusRect.x = gizmoRect.x + 5
                gizmoPtPlusRect.y = gizmoRect.y + 6

                let skin = mmView.skin.MenuWidget

                var fColor : float4
                if hoverState == .AddPoint {
                    fColor = skin.button.hoverColor
                } else {
                    fColor = skin.button.color
                }
                
                mmView.drawBoxedShape.draw(x: gizmoPtPlusRect.x, y: gizmoPtPlusRect.y, width: gizmoPtPlusRect.width, height: gizmoPtPlusRect.height, round: skin.button.round, borderSize: skin.button.borderSize, fillColor: fColor, borderColor: float4(repeating: 0), shape: .Plus)
                
                // -
                gizmoPtMinusRect.width = 30
                gizmoPtMinusRect.height = 28
                
                gizmoPtMinusRect.x = gizmoPtPlusRect.x + gizmoPtPlusRect.width + 1
                gizmoPtMinusRect.y = gizmoRect.y + 6
                
                if hoverState == .RemovePoint {
                    fColor = skin.button.hoverColor
                } else {
                    fColor = skin.button.color
                }
                
                mmView.drawBoxedShape.draw(x: gizmoPtMinusRect.x, y: gizmoPtMinusRect.y, width: gizmoPtMinusRect.width, height: gizmoPtMinusRect.height, round: skin.button.round, borderSize: skin.button.borderSize, fillColor: fColor, borderColor: float4(repeating: 0), shape: .Minus)
            }

            gizmoUIMenuRect.width = 30
            gizmoUIMenuRect.height = 28
            
            // --- Material context: Color/Value in left corner
            if context == .MaterialEditor && selectedMaterials.count == 1 && selectedMaterials[0].properties["channel"]! == 0 && selectedMaterials[0].pointCount == 0 {
                colorWidget.rect.x = gizmoRect.x + 5
                colorWidget.rect.y = gizmoRect.y + gizmoRect.height - gizmoUIMenuRect.height - 3
                if colorWidget.states.contains(.Opened) {
                    mmView.delayedDraws.append(colorWidget)
                } else {
                    colorWidget.draw()
                }
            } else
            if context == .MaterialEditor && selectedMaterials.count == 1 && selectedMaterials[0].properties["channel"]! != 0 && selectedMaterials[0].pointCount == 0 {
                floatWidget.rect.x = gizmoRect.x + 5
                floatWidget.rect.y = gizmoRect.y + gizmoRect.height - gizmoUIMenuRect.height - 3
                if floatWidget.states.contains(.Opened) {
                    mmView.delayedDraws.append(floatWidget)
                } else {
                    floatWidget.draw()
                }
            }
            
            // --- Render Menu
            if gizmoNode.uiItems.count > 0 {
                let skin = mmView.skin.MenuWidget
                
                gizmoUIMenuRect.x = gizmoRect.x + gizmoRect.width - gizmoUIMenuRect.width - 5
                gizmoUIMenuRect.y = gizmoRect.y + gizmoRect.height - gizmoUIMenuRect.height - 3
                
                let fColor : float4
                if hoverState == .GizmoUIMenu {
                    fColor = skin.button.hoverColor
                } else if gizmoUIOpen {
                    fColor = skin.button.activeColor
                } else {
                    fColor = skin.button.color
                }
                
                mmView.drawBoxedMenu.draw(x: gizmoUIMenuRect.x, y: gizmoUIMenuRect.y, width: gizmoUIMenuRect.width, height: gizmoUIMenuRect.height, round: skin.button.round, borderSize: skin.button.borderSize, fillColor: fColor, borderColor: float4(repeating: 0)/*-skin.button.borderColor*/)
                
                if gizmoUIOpen {
                    // --- Draw the UI
                    let uiItemX = gizmoRect.x + (gizmoRect.width - gizmoNode.uiArea.width) / 2 - 5
                    var uiItemY = gizmoRect.y + gizmoRect.height + 5
                    
                    for uiItem in gizmoNode.uiItems {
                        uiItem.rect.x = uiItemX
                        uiItem.rect.y = uiItemY
                        
                        uiItem.draw(mmView: mmView, maxTitleSize: gizmoNode.uiMaxTitleSize, maxWidth: gizmoNode.uiMaxWidth, scale: 1)
                        uiItemY += uiItem.rect.height
                    }
                }
            }
            
            // --- Render Gizmo
            let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( screenSpace.x - width / 2, screenSpace.y - height / 2, width, height, scale: scaleFactor ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            let buffer = mmRenderer.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            
            renderEncoder.setRenderPipelineState(normalState!)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        } else {
            // Point Mode
            
            // --- Draw all other points
            
            // --- Points
            
            if context == .ShapeEditor {
                for shape in selectedShapes {
                    
                    for index in 0..<shape.pointCount {
                        
                        if shape === pointShape! && index == pointIndex {
                            continue
                        }
                        
                        let ptConn = object!.getPointConnections(shape: shape, index: index)
                        
                        var pX = posX + attributes["point_\(index)_x"]!
                        var pY = posY + attributes["point_\(index)_y"]!
                        
                        if ptConn.0 != nil {
                            // The point controls other point(s)
                            ptConn.0!.valueX = pX
                            ptConn.0!.valueY = pY
                        }
                        
                        if ptConn.1 != nil {
                            // The point is being controlled by another point
                            pX = ptConn.1!.valueX
                            pY = -ptConn.1!.valueY
                        }
                        
                        let pointInScreen = convertToScreenSpace(x: pX, y: pY)
                        
                        var pFillColor = float4(repeating: 1)
                        var pBorderColor = float4( 0, 0, 0, 1)
                        let radius : Float = 10
                        #if os(OSX)
                        let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                        if rect.contains(mmView.mousePos.x, mmView.mousePos.y) {
                            let temp = pBorderColor
                            pBorderColor = pFillColor
                            pFillColor = temp
                        }
                        #endif
                        
                        if ptConn.1 != nil {
                            /// Point is linked to a previous point
                            pFillColor = float4(0,0,0,1)
                            pBorderColor = pFillColor
                        }
                        
                        mmView.drawSphere.draw(x: pointInScreen.x - radius, y: pointInScreen.y - radius, radius: radius, borderSize: 3, fillColor: pFillColor, borderColor: pBorderColor)
                    }
                }
            } else
            if context == .MaterialEditor {
                for material in selectedMaterials {
                    
                    for index in 0..<material.pointCount {
                        
                        if material === pointMaterial! && index == pointIndex {
                            continue
                        }
                        
                        let pX = posX + attributes["point_\(index)_x"]!
                        let pY = posY + attributes["point_\(index)_y"]!
                        
                        let pointInScreen = convertToScreenSpace(x: pX, y: pY)
                        
                        var pFillColor = float4(repeating: 1)
                        var pBorderColor = float4( 0, 0, 0, 1)
                        let radius : Float = 10
                        #if os(OSX)
                        let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                        if rect.contains(mmView.mousePos.x, mmView.mousePos.y) {
                            let temp = pBorderColor
                            pBorderColor = pFillColor
                            pFillColor = temp
                        }
                        #endif
                        
                        mmView.drawSphere.draw(x: pointInScreen.x - radius, y: pointInScreen.y - radius, radius: radius, borderSize: 3, fillColor: pFillColor, borderColor: pBorderColor)
                    }
                }
            }
            
            let pX = posX + attributes["point_\(pointIndex)_x"]!
            let pY = posY + attributes["point_\(pointIndex)_y"]!
            
            screenSpace = convertToScreenSpace(x: pX, y: pY)
            
            // --- Render Gizmo
            let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( screenSpace.x - width / 2, screenSpace.y - height / 2, width, height, scale: scaleFactor ) )
            renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
            
            let buffer = mmRenderer.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
            
            renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
            
            renderEncoder.setRenderPipelineState(pointState)
            renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
            
            // --- Material context: Color/Value in left corner
            if context == .MaterialEditor && pointMaterial!.properties["channel"] == 0 {
                colorWidget.rect.x = screenSpace.x - 55
                colorWidget.rect.y = screenSpace.y + 22
                colorWidget.setValue(color: SIMD3<Float>(pointMaterial!.properties["pointvalue_\(pointIndex)_x"]!, pointMaterial!.properties["pointvalue_\(pointIndex)_y"]!, pointMaterial!.properties["pointvalue_\(pointIndex)_z"]!))
                colorWidget.draw()
            } else
            if context == .MaterialEditor && pointMaterial!.properties["channel"] != 0 {
                floatWidget.rect.x = screenSpace.x - 55
                floatWidget.rect.y = screenSpace.y + 22
                floatWidget.value = pointMaterial!.properties["pointvalue_\(pointIndex)_x"]!
                floatWidget.draw()
            }
        }
        
        gizmoInfoArea.draw()
        mmRenderer.setClipRect()
    }
    
    /// Update the hover state for the normal gizmo
    func updateNormalHoverState(editorRect: MMRect, event: MMMouseEvent)
    {
        hoverState = .Inactive
        if object == nil { return }
        
        let selectedShapes = object!.getSelectedShapes()

        // --- UI
        if gizmoNode.uiItems.count > 0 {
            if gizmoUIMenuRect.contains(event.x, event.y) {
                hoverState = .GizmoUIMenu
                return
            }
            
            if gizmoUIOpen {
                let uiItemX = self.gizmoRect.x + (self.gizmoRect.width - gizmoNode.uiArea.width) / 2 - 5
                var uiItemY = self.gizmoRect.y + self.gizmoRect.height + 5
                let uiRect = MMRect()
                let titleWidth : Float = (gizmoNode.uiMaxTitleSize.x + NodeUI.titleSpacing)
                for uiItem in gizmoNode.uiItems {
                    
                    if uiItem.supportsTitleHover {
                        uiRect.x = uiItem.titleLabel!.rect.x - 2
                        uiRect.y = uiItem.titleLabel!.rect.y - 2
                        uiRect.width = uiItem.titleLabel!.rect.width + 4
                        uiRect.height = uiItem.titleLabel!.rect.height + 6
                        
                        if uiRect.contains(event.x, event.y) {
                            uiItem.titleHover = true
                            hoverUITitle = uiItem
                            mmView.update()
                            return
                        }
                    }

                    uiRect.x = uiItemX
                    uiRect.y = uiItemY
                    uiRect.width = uiItem.rect.width
                    uiRect.height = uiItem.rect.height
                    
                    if uiRect.contains(event.x, event.y) {
                        hoverUIItem = uiItem
                        hoverState = .GizmoUI
                        hoverUIItem!.mouseMoved(event)
                        return
                    }
                    uiItemY += uiItem.rect.height
                }
            }
        }
        
        // --- Material ColorWidget
        if context == .MaterialEditor {
            let selectedMaterials = object!.getSelectedMaterials(materialType)
            if selectedMaterials.count > 0 && selectedMaterials[0].properties["channel"] == 0
            {
                if !colorWidget.states.contains(.Opened) {
                    if colorWidget.rect.contains(event.x, event.y) {
                        hoverState = .ColorWidgetClosed
                        return
                    }
                } else {
                    if colorWidget.rect.contains(event.x, event.y) {
                        hoverState = .ColorWidgetOpened
                        return
                    }
                }
            } else
            if selectedMaterials.count > 0 && selectedMaterials[0].properties["channel"] != 0
            {
                if !floatWidget.states.contains(.Opened) {
                    if floatWidget.rect.contains(event.x, event.y) {
                        hoverState = .FloatWidgetClosed
                        return
                    }
                } else {
                    if floatWidget.rect.contains(event.x, event.y) {
                        hoverState = .FloatWidgetOpened
                        return
                    }
                }
            }
        }
        
        // --- Point Controls

        if selectedShapes.count == 1 && selectedShapes[0].pointsVariable {
            if gizmoPtPlusRect.contains(event.x, event.y) {
                hoverState = .AddPoint
                return
            }
            if gizmoPtMinusRect.contains(event.x, event.y) {
                hoverState = .RemovePoint
                return
            }
        }

        // --- Core Gizmo
        let attributes = getCurrentGizmoAttributes()
        var posX : Float = attributes["posX"]!
        var posY : Float = attributes["posY"]!
        
        if context == .ShapeEditor {
            if selectedShapes.count == 1 {
                
                for shape in selectedShapes {
                    
                    // --- Check for point hover
                    for index in 0..<shape.pointCount {
                        
                        var pX = posX + attributes["point_\(index)_x"]!
                        var pY = posY + attributes["point_\(index)_y"]!
                        
                        let ptConn = object!.getPointConnections(shape: shape, index: index)
                        
                        if ptConn.0 != nil {
                            // The point controls other point(s)
                            ptConn.0!.valueX = pX
                            ptConn.0!.valueY = pY
                        }
                        
                        if ptConn.1 != nil {
                            // The point is being controlled by another point
                            pX = ptConn.1!.valueX
                            pY = -ptConn.1!.valueY
                        }
                        
                        let pointInScreen = convertToScreenSpace(x: pX, y: pY)
                        
                        var pFillColor = float4(repeating: 1)
                        var pBorderColor = float4( 0, 0, 0, 1)
                        let radius : Float = 10
                        let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                        if rect.contains(event.x, event.y) {
                            hoverState = .PointHover
                        }
                    }
                }
                
                // Correct Gizmo position via points
                for shape in selectedShapes {

                    if shape.pointCount > 0 {
                        var offX : Float = 0
                        var offY : Float = 0

                        for i in 0..<shape.pointCount {
                            offX += attributes["point_\(i)_x"]!
                            offY += attributes["point_\(i)_y"]!
                        }
                        offX /= Float(shape.pointCount)
                        offY /= Float(shape.pointCount)
                        
                        posX += offX
                        posY += offY
                    }
                }
            }
        } else
        if context == .MaterialEditor {
            let selectedMaterials = object!.getSelectedMaterials(materialType)
            if selectedMaterials.count == 1 {
                
                for material in selectedMaterials {
                    
                    // --- Check for point hover
                    for index in 0..<material.pointCount {
                        
                        var pX = posX + attributes["point_\(index)_x"]!
                        var pY = posY + attributes["point_\(index)_y"]!
                        
                        let pointInScreen = convertToScreenSpace(x: pX, y: pY)
                        
                        var pFillColor = float4(repeating: 1)
                        var pBorderColor = float4( 0, 0, 0, 1)
                        let radius : Float = 10
                        let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                        if rect.contains(event.x, event.y) {
                            hoverState = .PointHover
                        }
                    }
                }
                
                // Adjust gizmo for point position
                for material in selectedMaterials {
                    
                    if material.pointCount > 0 {
                        var offX : Float = 0
                        var offY : Float = 0
                        
                        for i in 0..<material.pointCount {
                            offX += attributes["point_\(i)_x"]!
                            offY += attributes["point_\(i)_y"]!
                        }
                        offX /= Float(material.pointCount)
                        offY /= Float(material.pointCount)
                        
                        posX += offX
                        posY += offY
                    }
                }
            }
        }
        
        gizmoCenter = convertToScreenSpace(x: posX, y: posY)

        let gizmoRect : MMRect =  MMRect()
        
        gizmoRect.x = gizmoCenter.x - width / 2
        gizmoRect.y = gizmoCenter.y - height / 2
        gizmoRect.width = width
        gizmoRect.height = height

        if gizmoRect.contains( event.x, event.y ) {
        
            func sdTriangleIsosceles(_ uv : float2, q : float2) -> Float
            {
                var p : float2 = uv
                p.x = abs(p.x)
                
                let a : float2 = p - q * simd_clamp( dot(p,q)/dot(q,q), 0.0, 1.0 )
                let b : float2 = p - q*float2( simd_clamp( p.x/q.x, 0.0, 1.0 ), 1.0 )
                let s : Float = -sign( q.y )
                let d : float2 = min( float2( dot(a,a), s*(p.x*q.y-p.y*q.x) ),
                                float2( dot(b,b), s*(p.y-q.y)  ));
                
                return -sqrt(d.x)*sign(d.y);
            }
            
            func rotateCW(_ pos : float2, angle: Float) -> float2
            {
                let ca : Float = cos(angle), sa = sin(angle)
                return pos * float2x2(float2(ca, -sa), float2(sa, ca))
            }
            
            let x = event.x - gizmoRect.x
            let y = event.y - gizmoRect.y
            
            var center = simd_float2(x:x, y:y)
            center = center - simd_float2(x:width/2, y: height/2)
            
            var uv = center
            var dist = simd_length( uv ) - 15
            
            if dist < 4 {
                hoverState = .CenterMove
                return
            }
            
            // Right Arrow - Move
            uv -= float2(75,0);
            var d : float2 = simd_abs( uv ) - float2( 18, 3)
            dist = simd_length(max(d,float2(repeating: 0))) + min(max(d.x,d.y),0.0);
            uv = center - float2(110,0);
            uv = rotateCW(uv, angle: 1.5708 );
            dist = min( dist, sdTriangleIsosceles(uv, q: float2(10,-20)))
            
            if dist < 4 {
                hoverState = .xAxisMove
                return
            }
            
            // Right Arrow - Scale
            uv = center - float2(25,0);
            d = simd_abs( uv ) - float2( 25, 3)
            dist = simd_length(max(d,float2(repeating: 0))) + min(max(d.x,d.y),0.0);
            
            uv = center - float2(50,0.4);
            d = simd_abs( uv ) - float2( 8, 7)
            dist = min( dist, length(max(d,float2(repeating: 0))) + min(max(d.x,d.y),0.0) );
            
            if dist < 4 {
                hoverState = .xAxisScale
                return
            }
            
            // Up Arrow - Move
            uv = center + float2(0,75);
            d = simd_abs( uv ) - float2( 3, 18)
            dist = simd_length(max(d,float2(repeating: 0))) + min(max(d.x,d.y),0.0);
            uv = center + float2(0,110);
            dist = min( dist, sdTriangleIsosceles(uv, q: float2(10,20)))
            
            if dist < 4 {
                hoverState = .yAxisMove
                return
            }
            
            // Up Arrow - Scale
            uv = center + float2(0,25);
            d = simd_abs( uv ) - float2( 3, 25)
            dist = simd_length(max(d,float2(repeating: 0))) + min(max(d.x,d.y),0.0);

            uv = center + float2(0.4,50);
            d = simd_abs( uv ) - float2( 7, 8)
            dist = min( dist, length(max(d,float2(repeating: 0))) + min(max(d.x,d.y),0.0) );
            
            if dist < 4 {
                hoverState = .yAxisScale
                return
            }
            
            // Rotate
            dist = simd_length( center ) - 73
            let ringSize : Float = 10//6
            
            let border = simd_clamp(dist + ringSize, 0.0, 1.0) - simd_clamp(dist, 0.0, 1.0)
            if ( border > 0.0 ) {
                hoverState = .Rotate
                return
            }
        }
    }
    
    /// Update the hover state for the point gizmo
    func updatePointHoverState(editorRect: MMRect, event: MMMouseEvent)
    {
        hoverState = .Inactive
        if object == nil { return }
    
        // --- Material ColorWidget
        if context == .MaterialEditor {
            let selectedMaterials = object!.getSelectedMaterials(materialType)

            if selectedMaterials.count > 0 && selectedMaterials[0].properties["channel"] == 0
            {
                if !colorWidget.states.contains(.Opened) {
                    if colorWidget.rect.contains(event.x, event.y) {
                        hoverState = .ColorWidgetClosed
                        return
                    }
                } else {
                    if colorWidget.rect.contains(event.x, event.y) {
                        hoverState = .ColorWidgetOpened
                        return
                    }
                }
            } else
            if selectedMaterials.count > 0 && selectedMaterials[0].properties["channel"] != 0
            {
                if !floatWidget.states.contains(.Opened) {
                    if floatWidget.rect.contains(event.x, event.y) {
                        hoverState = .FloatWidgetClosed
                        return
                    }
                } else {
                    if floatWidget.rect.contains(event.x, event.y) {
                        hoverState = .FloatWidgetOpened
                        return
                    }
                }
            }
        }
        
        let attributes = getCurrentGizmoAttributes()
        var posX : Float = attributes["posX"]!
        var posY : Float = attributes["posY"]!
        
        // Check for point hover state
        if context == .ShapeEditor {
            let selectedShapes = object!.getSelectedShapes()
            
            for shape in selectedShapes {
                
                for index in 0..<shape.pointCount {
                    
                    //if shape === pointShape! && index == pointIndex {
                    //    continue
                    // }
                    
                    let ptConn = object!.getPointConnections(shape: shape, index: index)
                    
                    var pX = posX + attributes["point_\(index)_x"]!
                    var pY = posY + attributes["point_\(index)_y"]!
                    
                    if ptConn.0 != nil {
                        // The point controls other point(s)
                        ptConn.0!.valueX = pX
                        ptConn.0!.valueY = pY
                    }
                    
                    if ptConn.1 != nil {
                        // The point is being controlled by another point
                        pX = ptConn.1!.valueX
                        pY = -ptConn.1!.valueY
                    }
                    
                    let pointInScreen = convertToScreenSpace(x: pX, y: pY)
                    
                    var pFillColor = float4(repeating: 1)
                    var pBorderColor = float4( 0, 0, 0, 1)
                    let radius : Float = 10
                    
                    let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                    if rect.contains(event.x, event.y) {
                        hoverState = .PointHover
                    }
                }
            }
        } else
        if context == .MaterialEditor {
            let selectedMaterials = object!.getSelectedMaterials(materialType)
            if selectedMaterials.count == 1 {
                
                for material in selectedMaterials {
                    
                    // --- Check for point hover
                    for index in 0..<material.pointCount {
                        
                        var pX = posX + attributes["point_\(index)_x"]!
                        var pY = posY + attributes["point_\(index)_y"]!
                        
                        let pointInScreen = convertToScreenSpace(x: pX, y: pY)
                        
                        var pFillColor = float4(repeating: 1)
                        var pBorderColor = float4( 0, 0, 0, 1)
                        let radius : Float = 10
                        let rect = MMRect(pointInScreen.x - radius, pointInScreen.y - radius, 2 * radius, 2 * radius)
                        if rect.contains(event.x, event.y) {
                            hoverState = .PointHover
                        }
                    }
                }
            }
        }
        
        posX = attributes["posX"]! + attributes["point_\(pointIndex)_x"]!
        posY = attributes["posY"]! + attributes["point_\(pointIndex)_y"]!
        
        gizmoCenter = convertToScreenSpace(x: posX, y: posY)
    
        let gizmoRect : MMRect =  MMRect()
        
        gizmoRect.x = gizmoCenter.x - width / 2
        gizmoRect.y = gizmoCenter.y - height / 2
        gizmoRect.width = width
        gizmoRect.height = height
        
        if gizmoRect.contains( event.x, event.y ) {
            
            func sdTriangleIsosceles(_ uv : float2, q : float2) -> Float
            {
                var p : float2 = uv
                p.x = abs(p.x)
                
                let a : float2 = p - q * simd_clamp( dot(p,q)/dot(q,q), 0.0, 1.0 )
                let b : float2 = p - q*float2( simd_clamp( p.x/q.x, 0.0, 1.0 ), 1.0 )
                let s : Float = -sign( q.y )
                let d : float2 = min( float2( dot(a,a), s*(p.x*q.y-p.y*q.x) ),
                                      float2( dot(b,b), s*(p.y-q.y)  ));
                
                return -sqrt(d.x)*sign(d.y);
            }
            
            func rotateCW(_ pos : float2, angle: Float) -> float2
            {
                let ca : Float = cos(angle), sa = sin(angle)
                return pos * float2x2(float2(ca, -sa), float2(sa, ca))
            }
            
            let x = event.x - gizmoRect.x
            let y = event.y - gizmoRect.y
            
            var center = simd_float2(x:x, y:y)
            center = center - simd_float2(x:width/2, y: height/2)
            
            var uv = center
            var dist = simd_length( uv ) - 15
            
            if dist < 0 {
                hoverState = .CenterMove
                return
            }
            
            // Right Arrow - Move
            uv -= float2(50,0);
            var d : float2 = simd_abs( uv ) - float2( 50, 3)
            dist = simd_length(max(d,float2(repeating: 0))) + min(max(d.x,d.y),0.0);
            uv = center - float2(110,0);
            uv = rotateCW(uv, angle: 1.5708 );
            dist = min( dist, sdTriangleIsosceles(uv, q: float2(10,-20)))
            
            if dist < 4 {
                hoverState = .xAxisMove
                return
            }
            
            // Up Arrow - Move
            uv = center + float2(0,50);
            d = simd_abs( uv ) - float2( 3, 50)
            dist = simd_length(max(d,float2(repeating: 0))) + min(max(d.x,d.y),0.0);
            uv = center + float2(0,110);
            dist = min( dist, sdTriangleIsosceles(uv, q: float2(10,20)))
            
            if dist < 4 {
                hoverState = .yAxisMove
                return
            }
        }
    }
    
    /// Converts the coordinate from scene space to screen space
    func convertToScreenSpace(x: Float, y: Float) -> float2
    {
        var result : float2 = float2()
        
        let camera = maxDelegate!.getCamera()!
        
        result.x = (x - camera.xPos + 0.5)// / 700 * rect.width
        result.y = (y - camera.yPos + 0.5)// / 700 * rect.width
        
        result.x += rect.width/2
        result.y += rect.width/2 * rect.height / rect.width
        
        result.x += rect.x
        result.y += rect.y
        
        return result
    }
    
    /// Converts the coordinate from screen space to scene space
    func convertToSceneSpace(x: Float, y: Float) -> float2
    {
        var result : float2 = float2()
        
        result.x = (x - rect.x)// * 700 / rect.width
        result.y = (y - rect.y)// * 700 / rect.width
        
        let camera = maxDelegate!.getCamera()!

        // --- Center
        result.x -= rect.width / 2 - camera.xPos
        result.y += camera.yPos
        result.y -= rect.width / 2 * rect.height / rect.width
        
        return result
    }
    
    /// Returns true if the timeline is currently recording
    func isRecording() -> Bool
    {
        let timeline = maxDelegate!.getTimeline()!

        return timeline.isRecording
    }
    
    /// Get transformed properties
    func getTransformedProperties(_ shape: Shape) -> [String:Float]
    {
        let timeline = maxDelegate!.getTimeline()!
        
        let transformed = timeline.transformProperties(sequence: rootObject!.currentSequence!, uuid: shape.uuid, properties: shape.properties)
        return transformed
    }
    
    /// Get transformed properties
    func getTransformedProperties(_ material: Material) -> [String:Float]
    {
        let timeline = maxDelegate!.getTimeline()!
        
        let transformed = timeline.transformProperties(sequence: rootObject!.currentSequence!, uuid: material.uuid, properties: material.properties)
        return transformed
    }
    
    /// Returns the angle between the start / end points
    func getAngle(cx : Float, cy : Float, ex : Float, ey : Float, degree : Bool ) -> Float
    {
        var a : Float = atan2(-ey - -cy, ex - cx);
        if a < 0 {
            a += 2 * Float.pi; //angle is now in radians
        }
        
        a -= (Float.pi/2); //shift by 90deg
        //restore value in range 0-2pi instead of -pi/2-3pi/2
        if a < 0 {
            a += 2 * Float.pi;
        }
        if a < 0 {
            a += 2 * Float.pi;
        }
        a = abs((Float.pi * 2) - a); //invert rotate
        
        if degree {
            a = a*180/Float.pi; //convert to deg
        }
        return a;
    }
    
    /// Gets the attributes of the current Gizmo, i.e. its position and possibly further info
    func getCurrentGizmoAttributes() -> [String:Float]
    {
        var attributes : [String:Float] = [:]
        
        let objectProperties = transformTo(object!, timeline: maxDelegate!.getTimeline()!)

        attributes["posX"] = objectProperties["posX"]! * scale
        attributes["posY"] = -objectProperties["posY"]! * scale
        attributes["rotate"] = objectProperties["rotate"]!

        var sizeMinX : Float = 100000
        var sizeMinY : Float = 100000

        var sizeMaxX : Float = -100000
        var sizeMaxY : Float = -100000
        
        if context == .ShapeEditor {
            let selectedShapeObjects = object!.getSelectedShapes()
            if !selectedShapeObjects.isEmpty {
                
                for shape in selectedShapeObjects {
                    
                    let transformed = getTransformedProperties(shape)
                    
                    let posX = transformed["posX"]! * scale
                    let posY = -transformed["posY"]! * scale
                    let rotate = transformed["rotate"]!

                    // --- Calc Bounding Rectangle
                    
                    if shape.pointCount == 0 {
                        var size = float2()
                        
                        size.x = transformed[shape.widthProperty]! * 2 * scale
                        size.y = transformed[shape.heightProperty]! * 2 * scale
                        
                        if posX - size.x / 2 < sizeMinX {
                            sizeMinX = posX - size.x / 2
                        }
                        if posY - size.y / 2 < sizeMinY {
                            sizeMinY = posY - size.y / 2
                        }
                        if posX + size.x / 2 > sizeMaxX {
                            sizeMaxX = posX + size.x / 2
                        }
                        if posY + size.y / 2 > sizeMaxY {
                            sizeMaxY = posY + size.y / 2
                        }
                    } else {
                        let width = transformed[shape.widthProperty]!
                        let height = transformed[shape.heightProperty]!
                        
                        var minX : Float = 100000, minY : Float = 100000, maxX : Float = -100000, maxY : Float = -100000
                        for i in 0..<shape.pointCount {
                            minX = min( minX, posX + transformed["point_\(i)_x"]! * scale - width )
                            minY = min( minY, posY - transformed["point_\(i)_y"]! * scale - height )
                            maxX = max( maxX, posX + transformed["point_\(i)_x"]! * scale + width )
                            maxY = max( maxY, posY - transformed["point_\(i)_y"]! * scale + height )
                        }
                        
                        sizeMinX = minX
                        sizeMinY = minY
                        sizeMaxX = maxX
                        sizeMaxY = maxY
                    }
                    
                    // ---
                    
                    attributes["posX"]! += posX
                    attributes["posY"]! += posY
                    attributes["rotate"]! += rotate
                    
                    for i in 0..<shape.pointCount {
                        attributes["point_\(i)_x"] = transformed["point_\(i)_x"]! * scale
                        attributes["point_\(i)_y"] = -transformed["point_\(i)_y"]! * scale
                    }
                }
                
                attributes["posX"]! /= Float(selectedShapeObjects.count)
                attributes["posY"]! /= Float(selectedShapeObjects.count)
                attributes["rotate"]! /= Float(selectedShapeObjects.count)
            }
        } else
        if context == .MaterialEditor {
            let selectedMaterialObjects = object!.getSelectedMaterials(materialType)
            if !selectedMaterialObjects.isEmpty {
                
                for material in selectedMaterialObjects {
                
                    let transformed = getTransformedProperties(material)
                    
                    let posX = transformed["posX"]! * scale
                    let posY = -transformed["posY"]! * scale
                    let rotate = transformed["rotate"]!
                    
                    // --- Calc Bounding Rectangle
                    
                    let defaultSize : Float = 20
                    if material.pointCount == 0 {
                        var size = float2()
                        
                        size.x = defaultSize * 2//transformed[material.widthProperty]! * 2
                        size.y = defaultSize * 2 //transformed[material.heightProperty]! * 2
                        
                        if posX - size.x / 2 < sizeMinX {
                            sizeMinX = posX - size.x / 2
                        }
                        if posY - size.y / 2 < sizeMinY {
                            sizeMinY = posY - size.y / 2
                        }
                        if posX + size.x / 2 > sizeMaxX {
                            sizeMaxX = posX + size.x / 2
                        }
                        if posY + size.y / 2 > sizeMaxY {
                            sizeMaxY = posY + size.y / 2
                        }
                    } else {
                        let width = defaultSize//transformed[material.widthProperty]!
                        let height = defaultSize//transformed[material.heightProperty]!
                        
                        var minX : Float = 100000, minY : Float = 100000, maxX : Float = -100000, maxY : Float = -100000
                        for i in 0..<material.pointCount {
                            minX = min( minX, posX + transformed["point_\(i)_x"]! * scale - width )
                            minY = min( minY, posY - transformed["point_\(i)_y"]! * scale - height )
                            maxX = max( maxX, posX + transformed["point_\(i)_x"]! * scale + width )
                            maxY = max( maxY, posY - transformed["point_\(i)_y"]! * scale + height )
                        }
                        
                        sizeMinX = minX
                        sizeMinY = minY
                        sizeMaxX = maxX
                        sizeMaxY = maxY
                    }
                    
                    // ---
                    
                    attributes["posX"]! += posX
                    attributes["posY"]! += posY
                    attributes["rotate"]! += rotate
                    
                    for i in 0..<material.pointCount {
                        attributes["point_\(i)_x"] = transformed["point_\(i)_x"]! * scale
                        attributes["point_\(i)_y"] = -transformed["point_\(i)_y"]! * scale
                    }
                }
                
                attributes["posX"]! /= Float(selectedMaterialObjects.count)
                attributes["posY"]! /= Float(selectedMaterialObjects.count)
                attributes["rotate"]! /= Float(selectedMaterialObjects.count)
            }
        }
        
        let minScreen = convertToScreenSpace(x: sizeMinX, y: sizeMinY)
        let maxScreen = convertToScreenSpace(x: sizeMaxX, y: sizeMaxY)
        
        attributes["sizeMinX"] = minScreen.x + objectProperties["posX"]!
        attributes["sizeMinY"] = minScreen.y - objectProperties["posY"]!
        attributes["sizeMaxX"] = maxScreen.x + objectProperties["posX"]!
        attributes["sizeMaxY"] = maxScreen.y - objectProperties["posY"]!

        return attributes
    }
    
    /// Transforms the object properties until the given object is reached
    func transformTo(_ object: Object, timeline: MMTimeline) -> [String:Float]
    {
        let rootObject = self.rootObject!
        var finished : Bool = false

        let objectProperties : [String:Float]
        if rootObject.currentSequence != nil {
            objectProperties = timeline.transformProperties(sequence: rootObject.currentSequence!, uuid: rootObject.uuid, properties: rootObject.properties)
        } else {
            objectProperties = object.properties
        }
       
        var parentPosX : Float = objectProperties["posX"]!
        var parentPosY : Float = objectProperties["posY"]!
        var parentRotate : Float = objectProperties["rotate"]!
        
        func parseItem(_ item: Object)
        {
            // Transform Object Properties
            let objectProperties = timeline.transformProperties(sequence: rootObject.currentSequence!, uuid: item.uuid, properties: item.properties)
            
            parentPosX += objectProperties["posX"]!
            parentPosY += objectProperties["posY"]!
            parentRotate += objectProperties["rotate"]!
            
            if item === object {
                finished = true
                return
            }
            
            for childItem in item.childObjects {
                if finished {
                    return
                }
                parseItem(childItem)
            }
            
            parentPosX -= objectProperties["posX"]!
            parentPosY -= objectProperties["posY"]!
            parentRotate -= objectProperties["rotate"]!
        }
        
        for item in rootObject.childObjects {
            if !finished {
                parseItem(item)
            }
        }
        
        var properties : [String:Float] = [:]
        properties["posX"] = parentPosX
        properties["posY"] = parentPosY
        properties["rotate"] = parentRotate
        
        //print( properties )
        
        return properties
    }
    
    /// Perform Undo
    func performUndo(ignoreDragState : Bool = false)
    {
        if object != nil && context == .ShapeEditor {
            let selectedShapes = object!.getSelectedShapes()
            for shape in selectedShapes {
                shape.updateSize()
            }
            
            if !isRecording() {
                // Undo for shape based action when not using the timeline
                if selectedShapes.count == 1 && dragState != .Inactive && !NSDictionary(dictionary: selectedShapes[0].properties).isEqual(to: undoProperties) {
                    func applyProperties(_ shape: Shape,_ old: [String:Float],_ new: [String:Float])
                    {
                        mmView.undoManager!.registerUndo(withTarget: self) { target in
                            shape.properties = old
                            
                            applyProperties(shape, new, old)
                            self.app.updateObjectPreview(self.rootObject!)
                        }
                    }
                    
                    applyProperties(selectedShapes[0], undoProperties, selectedShapes[0].properties)
                }
            } else {
                // Undo for shape based action when using the timeline
                if selectedShapes.count == 1 && dragState != .Inactive && undoData != nil {
                    undoTimelineAction()
                }
            }
        } else
        if object != nil && context == .MaterialEditor
        {
            let selectedMaterials = object!.getSelectedMaterials(materialType)
            
            if !isRecording() {
                // Undo for material based action
                if selectedMaterials.count == 1 && (dragState != .Inactive || ignoreDragState) && !NSDictionary(dictionary: selectedMaterials[0].properties).isEqual(to: undoProperties) {
                    func applyProperties(_ material: Material,_ old: [String:Float],_ new: [String:Float])
                    {
                        mmView.undoManager!.registerUndo(withTarget: self) { target in
                            material.properties = old
                            
                            applyProperties(material, new, old)
                            self.app.updateObjectPreview(self.rootObject!)
                        }
                    }
                    
                    applyProperties(selectedMaterials[0], undoProperties, selectedMaterials[0].properties)
                }
            } else {
                // Undo for material based action when using the timeline
                if selectedMaterials.count == 1 && dragState != .Inactive && undoData != nil {
                    undoTimelineAction()
                }
            }
        } else
        if object != nil && context == .ObjectEditor && dragState != .Inactive {
            if !isRecording() {
                if objects.count == 1 && !NSDictionary(dictionary: object!.properties).isEqual(to: undoProperties) {
                    func applyProperties(_ object: Object,_ old: [String:Float],_ new: [String:Float])
                    {
                        mmView.undoManager!.registerUndo(withTarget: self) { target in
                            
                            if object.instanceOf == nil {
                                object.properties = old
                            } else {
                                if let layer = self.app.nodeGraph.getSceneOfInstance(object.uuid) {
                                    for inst in layer.objectInstances {
                                        if inst.uuid == object.uuid {
                                            inst.properties = old
                                        }
                                    }
                                }
                            }
                            
                            applyProperties(object, new, old)
                            self.app.updateObjectPreview(self.rootObject!)
                        }
                        mmView.update()
                    }
                    
                    if object!.instanceOf != nil {
                        // This is an instance, we need to update the instance properties
                        if let layer = app.nodeGraph.getSceneOfInstance(object!.uuid) {
                            for inst in layer.objectInstances {
                                if inst.uuid == object!.uuid {
                                    inst.properties = object!.properties
                                }
                            }
                        }
                    }
                    
                    applyProperties(object!, undoProperties, object!.properties)
                }
            } else {
                // Undo for object based action when using the timeline
                if objects.count == 1 && undoData != nil {
                    undoTimelineAction()
                }
            }
        }
        // Update the material list
        if object != nil && context == .MaterialEditor {
            maxDelegate!.update(false, updateLists: true)
        }
    }
    
    /// Undo a timeline based action
    func undoTimelineAction()
    {
        let origSequences = try? JSONDecoder().decode([MMTlSequence].self, from: undoData!)
        let modifiedData = try? JSONEncoder().encode(rootObject!.sequences)
        let modifiedSequences = try? JSONDecoder().decode([MMTlSequence].self, from: modifiedData!)
        
        let object = rootObject!
            
        func applyTimelineData(_ object: Object,_ old: [MMTlSequence],_ new: [MMTlSequence])
        {
            mmView.undoManager!.registerUndo(withTarget: self) { target in
                object.sequences = old
                if object.sequences.count > 0 {
                    object.currentSequence = object.sequences[0]
                }
                applyTimelineData(object, new, old)
            }
            self.app.updateObjectPreview(self.rootObject!)
        }
            
        applyTimelineData(rootObject!, origSequences!, modifiedSequences!)
    }
}

/// Used to make the Gizmo act as a Node for the UI
class GizmoNode : Node
{
    var gizmo       : Gizmo?
    
    init(_ gizmo: Gizmo)
    {
        self.gizmo = gizmo
        super.init()
    }
    
    required init(from decoder: Decoder) throws
    {
        self.gizmo = nil
        super.init()
    }
    
    override func variableChanged(variable: String, oldValue: Float, newValue: Float, continuous: Bool = false, noUndo: Bool = false)
    {
        //print( "variableChanged", variable, oldValue, newValue, continuous, noUndo)
        
        gizmo?.app.nodeGraph.updateNode(gizmo!.gizmoNode)
        gizmo?.gizmoVariableShape?.customReference = gizmo?.gizmoVariableConnection!.connectedTo

        if gizmo!.context == .ShapeEditor
        {
            let selectedShapes = gizmo!.object!.getSelectedShapes()
            if variable == "text" && selectedShapes.count == 1 {
                let shape = selectedShapes[0]
                
                for item in uiItems {
                    if let uiText = item as? NodeUIText {
                        shape.customText = uiText.value
                        gizmo!.maxDelegate!.update(true)
                        return
                    }
                }
            }
            
            let properties : [String:Float] = [variable:newValue]
            for shape in selectedShapes {
                gizmo!.processGizmoProperties(properties, shape: shape)
            }
            gizmo!.maxDelegate!.update(false)
        } else
        if gizmo!.context == .MaterialEditor
        {
            let selectedMaterials = gizmo!.object!.getSelectedMaterials(gizmo!.materialType)
            let properties : [String:Float] = [variable:newValue]
            for material in selectedMaterials {
                gizmo!.processGizmoMaterialProperties(properties, material: material)
            }
            gizmo!.maxDelegate!.update(true, updateLists: true)
        } else
        if gizmo!.context == .ObjectEditor && gizmo!.inSceneEditor {
            if let object = gizmo!.object {
                object.properties[variable] = newValue
                gizmo!.maxDelegate!.update(false, updateLists: false)
            }
        }
        
        if noUndo == false {
            //super.variableChanged(variable: variable, oldValue: oldValue, newValue: newValue, continuous: continuous)
        }
    }
}
