//
//  LayerMaxDelegate.swift
//  Shape-Z
//
//  Created by Markus Moenig on 24/2/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class ObjectProfileMaxDelegate : NodeMaxDelegate {
    
    enum PointType {
        case None, Edge, Center, Control
    }
    
    enum MouseMode {
        case None, Dragging
    }
    
    enum SegmentType : Int {
        case Linear, Circle, Bezier, Smoothstep, SmoothMaximum
    }
    
    var app             : App!
    var mmView          : MMView!
    
    var selPointType    : PointType = .None
    var selPointIndex   : Int = 0
    var selControl      : Bool = false

    var hoverPointType  : PointType = .None
    var hoverPointIndex : Int = 0
    var hoverControl    : Bool = false
    
    var mouseMode       : MouseMode = .None

    // Top Region
    var addButton       : MMButtonWidget!
    var removeButton    : MMButtonWidget!

    var pointTypeButton : MMScrollButton!
    
    var textureWidget   : MMTextureWidget!
    var animating       : Bool = false

    // ---
    var profile         : ObjectProfile!
    var masterObject    : Object!
    
    var camera          : Camera = Camera()
    var patternState    : MTLRenderPipelineState?
    var dispatched      : Bool = false
    
    var scale           : Float = 4
    var scaleX          : Float = 4
    
    var left            : Float = 0
    var bottom          : Float = 0
    var right           : Float = 0
    
    var startDrag       : float2 = float2()
    var startPoint      : float2 = float2()
    var xLimits         : float2 = float2()
    
    var lockCenterAt    : Bool = false
    
    var previewTexture  : MTLTexture? = nil
    var builderInstance : BuilderInstance? = nil
    
    var centerLabel     : MMTextLabel!
    var edgeLabel       : MMTextLabel!

    override func activate(_ app: App)
    {
        self.app = app
        mmView = app.mmView
        
        profile = (app.nodeGraph.maximizedNode as! ObjectProfile)
        masterObject = (app.nodeGraph.currentMaster as! Object)
        
        app.topRegion!.rect.width = 0
        app.leftRegion!.rect.width = 0
        app.rightRegion!.rect.width = 0
        app.bottomRegion!.rect.width = 0
        app.editorRegion!.rect.width = app.mmView.renderer.cWidth - 1
        
        centerLabel = MMTextLabel(mmView, font: mmView.openSans, text: "Center")
        edgeLabel = MMTextLabel(mmView, font: mmView.openSans, text: "Edge")

        // Top Region
        if addButton == nil {
            addButton = MMButtonWidget( app.mmView, text: "Add Point" )
            addButton.clicked = { (event) -> Void in
                let count : Int = Int(self.profile.properties["pointCount"]!)
                var x: Float = 40 / self.scaleX

                if self.selPointType == .Control && count > 0 {
                    x = self.profile.properties["point_\(self.selPointIndex)_At"]! + 40 / self.scaleX
                }
                
                self.profile.properties["point_\(count)_At"] = x
                self.profile.properties["point_\(count)_Height"] = 20
                self.profile.properties["point_\(count)_Type"] = 0
                self.profile.properties["pointCount"] = Float(count + 1)
                self.selPointType = .Control
                self.selPointIndex = count
                self.pointTypeButton.index = 0
                self.update(true)
                self.mmView.update()
            }
            
            removeButton = MMButtonWidget( app.mmView, text: "Remove" )
            removeButton.clicked = { (event) -> Void in
                if self.selPointType != .Control { return }
                
                let count : Int = Int(self.profile.properties["pointCount"]!)
                
                for index in self.selPointIndex..<count-1 {
                    self.profile.properties["point_\(index)_At"] = self.profile.properties["point_\(index+1)_At"]!
                    self.profile.properties["point_\(index)_Height"] = self.profile.properties["point_\(index+1)_Height"]!
                    self.profile.properties["point_\(index)_Type"] = self.profile.properties["point_\(index+1)_Type"]!
                }
                self.profile.properties["pointCount"] = Float(count - 1)
                if count-1 > 0 {
                    self.selPointType = .Control
                    self.selPointIndex = max(0, self.selPointIndex-1)
                } else {
                    self.selPointType = .Edge
                    self.removeButton.isDisabled = true
                }
                self.update(true)
                self.mmView.update()
            }
            pointTypeButton = MMScrollButton(app.mmView, items:["Linear", "Circle", "Bezier Spline", "Smooth Min/Max"], index: 0)
            pointTypeButton.changed = { (index)->() in
                let segmentType = SegmentType(rawValue: index)

                if self.selPointType == .Edge {
                    self.profile.properties["edgeType"] = Float(index)
                    
                    if segmentType == .Bezier {
                        self.profile.properties["edgeControlAt"] = self.profile.properties["centerAt"]! / 2
                        self.profile.properties["edgeControlHeight"] = 50
                    }
                    self.update()
                    self.mmView.update()
                } else
                if self.selPointType == .Control {
                    self.profile.properties["point_\(self.selPointIndex)_Type"] = Float(index)
                    if segmentType == .Bezier {
                        self.profile.properties["point_\(self.selPointIndex)_ControlAt"] = self.profile.properties["centerAt"]! / 2
                        self.profile.properties["point_\(self.selPointIndex)_ControlHeight"] = 50
                    }
                    self.update()
                    self.mmView.update()
                }
            }
        }
        
        app.closeButton.clicked = { (event) -> Void in
            self.deactivate()
            app.nodeGraph.maximizedNode = nil
            app.nodeGraph.activate()
            app.closeButton.removeState(.Hover)
            app.closeButton.removeState(.Checked)
        }

        // Editor Region
        if patternState == nil {
            let function = app.mmView.renderer!.defaultLibrary.makeFunction( name: "moduloPattern" )
            patternState = app.mmView.renderer!.createNewPipelineState( function! )
        }

        app.mmView.registerWidgets( widgets: addButton, removeButton, pointTypeButton, app.closeButton)
        
        if profile.properties["prevOffX"] != nil {
             camera.xPos = profile.properties["prevOffX"]!
        }
        if profile.properties["prevOffY"] != nil {
            camera.yPos = profile.properties["prevOffY"]!
        }
        if profile.properties["prevScale"] != nil {
            camera.zoom = profile.properties["prevScale"]!
        }
        
        app.nodeGraph.diskBuilder.getDisksFor(masterObject, builder: app.nodeGraph.builder)
        if masterObject.disks != nil && masterObject.disks!.count > 0 {
            let maxDist : Float = masterObject.disks![0].z
            profile.properties["centerAt"] = maxDist
            lockCenterAt = true
        } else {
            scaleX = 4
        }
        
        selPointType = .Edge
        addButton.isDisabled = false
        removeButton.isDisabled = true
        pointTypeButton.isDisabled = false
        update(true)
    }
    
    override func deactivate()
    {
        app.mmView.deregisterWidgets( widgets: addButton, removeButton, pointTypeButton, app.closeButton)
        masterObject.updatePreview(nodeGraph: app.nodeGraph, hard: true)
    }
    
    /// Called when the project changes (Undo / Redo)
    override func setChanged()
    {
//        shapeListChanged = true
    }
    
    /// Draw the background pattern
    func drawPattern(_ region: MMRegion)
    {
        let mmRenderer = app.mmView.renderer!
    
        let scaleFactor : Float = app.mmView.scaleFactor
        let settings: [Float] = [
            region.rect.width, region.rect.height,
            ];
        
        let renderEncoder = mmRenderer.renderEncoder!
        
        let vertexBuffer = mmRenderer.createVertexBuffer( MMRect( region.rect.x, region.rect.y, region.rect.width, region.rect.height, scale: scaleFactor ) )
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        
        let buffer = mmRenderer.device.makeBuffer(bytes: settings, length: settings.count * MemoryLayout<Float>.stride, options: [])!
        
        renderEncoder.setFragmentBuffer(buffer, offset: 0, index: 0)
        
        renderEncoder.setRenderPipelineState( patternState! )
        renderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
    }
    
    override func drawRegion(_ region: MMRegion)
    {
        if region.type == .Editor {
            
            app.editorRegion!.rect.width = app.mmView.renderer.cWidth - 1
            //drawPattern(region)
            
            mmView.renderer.setClipRect(region.rect)
            app!.mmView.drawBox.draw( x: region.rect.x, y: region.rect.y, width: region.rect.width, height: region.rect.height, round: 0, borderSize: 0, fillColor : float4(0.098, 0.098, 0.098, 1.000), borderColor: float4(repeating:0) )
            mmView.drawTexture.draw(previewTexture!, x: region.rect.x, y: region.rect.y)
            drawGraph(region)
            mmView.renderer.setClipRect()
            
            app.changed = false
        } else
        if region.type == .Top {
            region.layoutH( startX: 10, startY: 4 + 44, spacing: 10, widgets: addButton, removeButton, pointTypeButton )
            region.layoutHFromRight(startX: region.rect.x + region.rect.width - 10, startY: 4 + 44, spacing: 10, widgets: app.closeButton)
            
            addButton.draw()
            removeButton.draw()
            pointTypeButton.draw()
            app.closeButton.draw()
        } else
        if region.type == .Left {
        } else
        if region.type == .Right {
        } else
        if region.type == .Bottom {
        }
    }
    
    func drawGraph(_ region: MMRegion)
    {
        left = region.rect.x + 40
        bottom = region.rect.y + region.rect.height - 40
        right = region.rect.x + region.rect.width - 40
        
        if lockCenterAt {
            scaleX = (region.rect.width - 80) / (profile.properties["centerAt"]!)
        }
        
        let lineColor = float4(0.5, 0.5, 0.5, 1)
        
        mmView.drawLine.draw(sx: left, sy: bottom, ex: right, ey: bottom, radius: 1, fillColor: lineColor)
        
        centerLabel.drawCentered(x: region.rect.x + 40, y: bottom + 10, width: centerLabel.rect.width, height: centerLabel.rect.height)
        edgeLabel.drawCentered(x: region.rect.x + region.rect.width - 40 - edgeLabel.rect.width, y: bottom + 10, width: centerLabel.rect.width, height: centerLabel.rect.height)
        
        // --- Draw Graph
        
        func drawSegment(startAt: Float, startHeight: Float, endAt: Float, endHeight: Float, type: SegmentType, controlAt: Float = 0, controlHeight: Float = 0)
        {
            
            let sX = right - startAt * scaleX, sY = bottom - startHeight * scale
            let eX = right - endAt * scaleX, eY = bottom - endHeight * scale
            
            if type == .Linear {
                // Lines
                mmView.drawLine.draw(sx: sX, sy: sY, ex: eX, ey: eY, radius: 1, fillColor: lineColor)
            } else
            if type == .Smoothstep {
                // Smoothstep
                
                let sXI : Int = Int(startAt*scaleX)
                let eXI : Int = Int(endAt*scaleX)
               
                var lastX : Float = -1
                var lastY : Float = -1
                    
                for xI in sXI..<eXI {
                    let x : Float = Float(xI) - Float(sXI)
                    let y : Float = simd_mix( sY, eY, simd_smoothstep(0, 1, x / (endAt-startAt)/scaleX ))
                    
                    if lastX != -1 {
                        mmView.drawLine.draw(sx: lastX, sy: lastY, ex: sX - x, ey: y, radius: 1, fillColor: lineColor)
                    }
                    
                    lastX = sX - x
                    lastY = y
                }
            } else
            if type == .SmoothMaximum {
                // Smooth Maximum

                let sXI : Int = Int(startAt*scaleX)
                let eXI : Int = Int(endAt*scaleX)
                
                var lastX : Float = -1
                var lastY : Float = -1
                
                func smax(_ a: Float,_ b: Float,_ s : Float ) -> Float
                {
                    let h : Float = simd_clamp(0.5 + 0.5*(a - b)/s, 0.0, 1.0)
                    return simd_mix(b, a, h) + h*(1.0 - h)*s
                }
                
                func smin0(_ a: Float,_ b: Float,_ k: Float) -> Float
                {
                    let h : Float = simd_clamp( 0.5 + 0.5*(b-a)/k, 0.0, 1.0 );
                    return simd_mix( b, a, h ) - k*h*(1.0-h);
                }
                
                for xI in sXI..<eXI {
                    let x : Float = Float(xI) - Float(sXI)
                    let y : Float = simd_mix( sY, eY, smax(x / (endAt-startAt)/scaleX, 0, 1))
                    
                    if lastX != -1 {
                        mmView.drawLine.draw(sx: lastX, sy: lastY, ex: sX - x, ey: y, radius: 1, fillColor: lineColor)
                    }
                    
                    lastX = sX - x
                    lastY = y
                }
            } else
            if type == .Bezier {
                // Quadratic Bezier
                
                let sXI : Int = Int(startAt*scaleX)
                let eXI : Int = Int(endAt*scaleX)
                
                var lastX : Float = -1
                var lastY : Float = -1
                
                for xI in sXI..<eXI {
                    let x : Float = Float(xI) - Float(sXI)
                    //let y : Float = simd_mix( sY, eY, simd_smoothstep(0, 1, x / (endAt-startAt)/scaleX ))
                    
                    let cx = controlAt
                    
                    let ax : Float = startAt
                    let bx : Float = endAt
                    
//                    let temp1 : Float  = (ax - bx) + sqrt(abs(bx * bx - ax * cx))
//                    let temp2 : Float  = ax * (ax - 2 * bx + cx)
//                    let t : Float = temp1 / temp2;
                    
                    let a : Float = ax - 2 * bx + cx
                    let b : Float = 2 * (bx - ax)
                    let c : Float = ax - x
                    
//                    -b ± √(b^2 - 4ac)
//                    (2)  x = -----------------
//                    2a
                    
                    let q : Float = b * b - 4 * a * c
                    let temp11 : Float
                        
                    if q >= 0 {
                        temp11 = -b + sqrt(q)
                    } else {
                        temp11 = -b - sqrt(abs(q))
                    }
                    let temp2 : Float = 2 * a

                    let t : Float = temp11 / temp2

                    //let x : Float = (1 - t) * (1 - t) * sX + 2 * (1 - t) * t * cX + t * t * eX;
                    let y : Float = bottom - ((1 - t) * (1 - t) * startHeight + 2 * (1 - t) * t * controlHeight + t * t * endHeight) * scale
                    
                    //print(temp11, temp2, x, t, y)
                    
                    if lastX != -1 {
                        mmView.drawLine.draw(sx: lastX, sy: lastY, ex: sX - x * scaleX, ey: y, radius: 1, fillColor: lineColor)
                    }
                    
                    lastX = sX - x * scaleX
                    lastY = y
                }
                
                /*
                var lastX : Float = -1
                var lastY : Float = -1
                
                let cX = right - controlAt * scaleX
                let cY = bottom - controlHeight * scale
                
                for t : Float in stride(from: 0, to: 1, by: 0.01) {
                    
                    let x : Float = (1 - t) * (1 - t) * sX + 2 * (1 - t) * t * cX + t * t * eX;
                    let y : Float = (1 - t) * (1 - t) * sY + 2 * (1 - t) * t * cY + t * t * eY;
                    
                    if lastX != -1 {
                        mmView.drawLine.draw(sx: lastX, sy: lastY, ex: x, ey: y, radius: 1, fillColor: lineColor)
                    }
                    
                    lastX = x
                    lastY = y
                }*/
            } else
            if type == .Circle {
                // Circle
                
                /* code for circle
                 
                 var lastX : Float = -1
                 var lastY : Float = -1
                 
                 let pt : Float = atan2(endHeight - startHeight, endAt - startAt )// * 180 / Float.pi

                 for t : Float in stride(from: 0, to: Float.pi, by: 0.01) {
                 
                 let x : Float = ((endAt - startAt) * scaleX) / 2 + (((endAt - startAt) * scaleX) / 2 * cos( pt + t ))
                 let y : Float = /*simd_mix( sY, eY, d)*/ bottom - (((endAt - startAt) * scaleX) / 2 * sin( pt + t ))
                 
                 if lastX != -1 {
                    mmView.drawLine.draw(sx: lastX, sy: lastY, ex: sX - x, ey: y, radius: 1, fillColor: lineColor)
                 }
                 
                 lastX = sX - x
                 lastY = y
                 }
 
                */
                
                let sXI : Int = Int(startAt*scaleX)
                let eXI : Int = Int(endAt*scaleX)
                
                var lastX : Float = -1
                var lastY : Float = -1

                for xI in sXI...eXI {
                    let x : Float = Float(xI) - Float(sXI)

                    let radius : Float = ((endAt - startAt) * scaleX) / 2
                    
                    let xM : Float = x - ((endAt - startAt) / 2) * scaleX
                    let y : Float = simd_mix( sY, eY, x / (endAt-startAt)/scaleX) - ( (sqrt(radius * radius - xM * xM)) )
                    
                    if lastX != -1 {
                        mmView.drawLine.draw(sx: lastX, sy: lastY, ex: sX - x, ey: y, radius: 1, fillColor: lineColor)
                    }
                    
                    lastX = sX - x
                    lastY = y
                }
            }
        }
        
        let pointCount = Int(profile.properties["pointCount"]!)
        if pointCount > 0 {
            
            var type : SegmentType = SegmentType(rawValue: Int(profile.properties["edgeType"]!))!
            var controlAt : Float = type == .Bezier ? profile.properties["edgeControlAt"]! : 0
            var controlHeight : Float = type == .Bezier ? profile.properties["edgeControlHeight"]! : 0
            
            drawSegment(startAt: 0, startHeight: profile.properties["edgeHeight"]!, endAt: profile.properties["point_0_At"]!, endHeight: profile.properties["point_0_Height"]!, type: type, controlAt: controlAt, controlHeight: controlHeight)
            
            for index in 1..<pointCount {
                let type : SegmentType = SegmentType(rawValue: Int(profile.properties["point_\(index-1)_Type"]!))!
                let controlAt : Float = type == .Bezier ? profile.properties["point_\(index-1)_ControlAt"]! : 0
                let controlHeight : Float = type == .Bezier ? profile.properties["point_\(index-1)_ControlHeight"]! : 0
                
                drawSegment(startAt: profile.properties["point_\(index-1)_At"]!, startHeight: profile.properties["point_\(index-1)_Height"]!, endAt: profile.properties["point_\(index)_At"]!, endHeight: profile.properties["point_\(index)_Height"]!, type: type, controlAt: controlAt, controlHeight: controlHeight)
            }
            
            type = SegmentType(rawValue: Int(profile.properties["point_\(pointCount-1)_Type"]!))!
            controlAt = type == .Bezier ? profile.properties["point_\(pointCount-1)_ControlAt"]! : 0
            controlHeight = type == .Bezier ? profile.properties["point_\(pointCount-1)_ControlHeight"]! : 0
            
            drawSegment(startAt: profile.properties["point_\(pointCount-1)_At"]!, startHeight: profile.properties["point_\(pointCount-1)_Height"]!, endAt: profile.properties["centerAt"]!, endHeight: profile.properties["centerHeight"]!, type: type, controlAt: controlAt, controlHeight: controlHeight)
            
        } else {
            let type : SegmentType = SegmentType(rawValue: Int(profile.properties["edgeType"]!))!
            let controlAt : Float = type == .Bezier ? profile.properties["edgeControlAt"]! : 0
            let controlHeight : Float = type == .Bezier ? profile.properties["edgeControlHeight"]! : 0
            drawSegment(startAt: 0, startHeight: profile.properties["edgeHeight"]!, endAt: profile.properties["centerAt"]!, endHeight: profile.properties["centerHeight"]!, type: type, controlAt: controlAt, controlHeight: controlHeight)
        }
        
        // --- Draw Edge Marker
        
        var type : SegmentType
        
        drawPoint(right, bottom - profile.properties["edgeHeight"]! * scale, isSelected: selPointType == .Edge && !selControl, hasHover: hoverPointType == .Edge && !hoverControl)
        type = SegmentType(rawValue: Int(profile.properties["edgeType"]!))!
        if type == .Bezier && selPointType == .Edge {
            drawPoint(right - profile.properties["edgeControlAt"]! * scaleX, bottom - profile.properties["edgeControlHeight"]! * scale, isSelected: selPointType == .Edge && selControl, hasHover: hoverPointType == .Edge && hoverControl, control: true)
        }
        
        // --- Draw Control Points
        for index in 0..<pointCount {
            drawPoint(right - profile.properties["point_\(index)_At"]! * scaleX, bottom - profile.properties["point_\(index)_Height"]! * scale, isSelected: selPointType == .Control && selPointIndex == index && !selControl, hasHover: hoverPointType == .Control && hoverPointIndex == index && !hoverControl, control: false)
            type = SegmentType(rawValue: Int(profile.properties["point_\(index)_Type"]!))!
            if type == .Bezier && selPointType == .Control && selPointIndex == index {
                drawPoint(right - profile.properties["point_\(index)_ControlAt"]! * scaleX, bottom - profile.properties["point_\(index)_ControlHeight"]! * scale, isSelected: selPointType == .Control && selPointIndex == index && selControl, hasHover: hoverPointType == .Control && hoverPointIndex == index && hoverControl, control: true)
            }
        }

        // --- Draw Center Marker
        drawPoint( right - profile.properties["centerAt"]! * scaleX, bottom - profile.properties["centerHeight"]! * scale, isSelected: selPointType == .Center, hasHover: hoverPointType == .Center)
    }
    
    func drawPoint(_ x: Float,_ y : Float, isSelected: Bool = false, hasHover: Bool = false, control: Bool = false)
    {
        var pFillColor = float4(repeating: 1)
        var pBorderColor = float4( 0, 0, 0, 1)
        let radius : Float = 10
        
        if control {
            pFillColor = float4(0.898, 0.694, 0.157, 1.000)
        }

        if isSelected {
            let temp = pBorderColor
            pBorderColor = pFillColor
            pFillColor = temp
        } else
        if hasHover {
            pFillColor = pBorderColor
        }
        
        mmView.drawSphere.draw(x: x - radius, y: y - radius, radius: radius, borderSize: 3, fillColor: pFillColor, borderColor: pBorderColor)
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseMoved(event)
        
        selPointType = hoverPointType
        selPointIndex = hoverPointIndex
        selControl = hoverControl
        startDrag.x = event.x; startDrag.y = event.y
        if selPointType == .Edge {
            mouseMode = .Dragging
            if !selControl {
                startPoint.y = profile.properties["edgeHeight"]!
            } else {
                startPoint.x = profile.properties["edgeControlAt"]!
                startPoint.y = profile.properties["edgeControlHeight"]!
            }
            pointTypeButton.index = Int(profile.properties["edgeType"]!)
            addButton.isDisabled = false
            removeButton.isDisabled = true
            pointTypeButton.isDisabled = false
        } else
        if selPointType == .Center {
            mouseMode = .Dragging
            startPoint.x = profile.properties["centerAt"]!
            startPoint.y = profile.properties["centerHeight"]!
            removeButton.isDisabled = true
            addButton.isDisabled = true
            pointTypeButton.isDisabled = true
        } else
        if selPointType == .Control {
            mouseMode = .Dragging
            if !selControl {
                startPoint.x = profile.properties["point_\(selPointIndex)_At"]!
                startPoint.y = profile.properties["point_\(selPointIndex)_Height"]!
                pointTypeButton.index = Int(profile.properties["point_\(selPointIndex)_Type"]!)

                // Compute x movements limits
                let pointCount = Int(profile.properties["pointCount"]!)
                if selPointIndex == 0 {
                    xLimits.y = 0
                } else {
                    xLimits.y = profile.properties["point_\(selPointIndex-1)_At"]!
                }
                if selPointIndex == pointCount - 1 {
                    xLimits.x = profile.properties["centerAt"]!
                } else {
                    xLimits.x = profile.properties["point_\(selPointIndex+1)_At"]!
                }
            } else {
                startPoint.x = profile.properties["point_\(selPointIndex)_ControlAt"]!
                startPoint.y = profile.properties["point_\(selPointIndex)_ControlHeight"]!
            }
            removeButton.isDisabled = false
            addButton.isDisabled = false
            pointTypeButton.isDisabled = false
        }
        if mouseMode == .Dragging {
            mmView.mouseTrackWidget = app.editorRegion!.widget
        }
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseMode = .None
        mmView.mouseTrackWidget = nil
        update()
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if mouseMode == .Dragging && selPointType != .None {
            if selPointType == .Edge && selControl == false {
                profile.properties["edgeHeight"] = min( 100, max(0, startPoint.y - (event.y - startDrag.y) / scale))
            } else
            if selPointType == .Edge && selControl == true {
                profile.properties["edgeControlAt"] = max(0, startPoint.x - (event.x - startDrag.x) / scaleX)
                profile.properties["edgeControlHeight"] = min( 100, max(0, startPoint.y - (event.y - startDrag.y) / scale))
            } else
            if selPointType == .Center {
                //if !lockCenterAt {
                //    profile.properties["centerAt"]! = max(0, startPoint.x - (event.x - startDrag.x) / scaleX)
                //}
                profile.properties["centerHeight"]! = min( 100, max(0, startPoint.y - (event.y - startDrag.y) / scale))
            } else
            if selPointType == .Control {
                if !selControl {
                    var x : Float = max(0, startPoint.x - (event.x - startDrag.x) / scaleX)
                    x = min(x, xLimits.x)
                    x = max(x, xLimits.y)
                    profile.properties["point_\(selPointIndex)_At"]! = x
                    profile.properties["point_\(selPointIndex)_Height"]! = min( 100, max(0, startPoint.y - (event.y - startDrag.y) / scale))
                } else {
                    profile.properties["point_\(selPointIndex)_ControlAt"]! = startPoint.x - (event.x - startDrag.x) / scaleX
                    profile.properties["point_\(selPointIndex)_ControlHeight"]! = startPoint.y - (event.y - startDrag.y) / scale
                }
            }
            mmView.update()
            update()
        } else
        if mouseMode == .None {
            let radius : Float = 10
            let halfRadius = radius / 2
            
            let oldHoverPointType = hoverPointType, oldHoverPointIndex = hoverPointIndex
            hoverPointType = .None
            let oldHoverControl = hoverControl
            
            // --- Check for Edge / Center Hover
        
            var pY : Float = bottom - profile.properties["edgeHeight"]!*scale
            var pX : Float
            if event.x >= right - halfRadius && event.x <= right + halfRadius && event.y >= pY - halfRadius && event.y <= pY + halfRadius {
                hoverPointType = .Edge
                hoverControl = false
            }
            var type : SegmentType = SegmentType(rawValue: Int(profile.properties["edgeType"]!))!
            if type == .Bezier {
                pX = right - profile.properties["edgeControlAt"]! * scaleX
                pY = bottom - profile.properties["edgeControlHeight"]!*scale
                if event.x >= pX - halfRadius && event.x <= pX + halfRadius && event.y >= pY - halfRadius && event.y <= pY + halfRadius {
                    hoverPointType = .Edge
                    hoverControl = true
                }
            }

            pX = right - profile.properties["centerAt"]! * scaleX
            pY = bottom - profile.properties["centerHeight"]! * scale
            if event.x >= pX - halfRadius && event.x <= pX + halfRadius && event.y >= pY - halfRadius && event.y <= pY + halfRadius {
                hoverPointType = .Center
            }
            
            let pointCount = Int(profile.properties["pointCount"]!)

            // --- Check Control Points
            for index in 0..<pointCount {
                pX = right - profile.properties["point_\(index)_At"]! * scaleX
                pY = bottom - profile.properties["point_\(index)_Height"]! * scale
                if event.x >= pX - halfRadius && event.x <= pX + halfRadius && event.y >= pY - halfRadius && event.y <= pY + halfRadius {
                    hoverPointType = .Control
                    hoverPointIndex = index
                    hoverControl = false
                }
                type = SegmentType(rawValue: Int(profile.properties["point_\(index)_Type"]!))!
                if type == .Bezier {
                    pX = right - profile.properties["point_\(index)_ControlAt"]! * scaleX
                    pY = bottom - profile.properties["point_\(index)_ControlHeight"]! * scale
                    if event.x >= pX - halfRadius && event.x <= pX + halfRadius && event.y >= pY - halfRadius && event.y <= pY + halfRadius {
                        hoverPointType = .Control
                        hoverPointIndex = index
                        hoverControl = true
                    }
                }
            }
            
            //drawPoint(right, bottom - profile.properties["edgeHeight"]!)

            if oldHoverPointType != hoverPointType || oldHoverPointIndex != hoverPointIndex || oldHoverControl != hoverControl {
                mmView.update()
            }
        }
    }
    
    override func mouseScrolled(_ event: MMMouseEvent)
    {
        #if os(iOS) || os(watchOS) || os(tvOS)
        camera.xPos -= event.deltaX! * 2
        camera.yPos -= event.deltaY! * 2
        #elseif os(OSX)
        if app.mmView.commandIsDown && event.deltaY! != 0 {
            camera.zoom += event.deltaY! * 0.003
            camera.zoom = max(0.1, camera.zoom)
            camera.zoom = min(1, camera.zoom)
        } else {
            camera.xPos += event.deltaX! * 2
            camera.yPos += event.deltaY! * 2
        }
        #endif
        
        profile.properties["prevOffX"] = camera.xPos
        profile.properties["prevOffY"] = camera.yPos
        profile.properties["prevScale"] = camera.zoom

        update()
        
        if !dispatched {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.app.mmView.unlockFramerate()
                self.dispatched = false
            }
            dispatched = true
        }
        
        if app.mmView.maxFramerateLocks == 0 {
            app.mmView.lockFramerate()
        }
    }
    
    /// Updates the preview. hard does a rebuild, otherwise just a render
    override func update(_ hard: Bool = false, updateLists: Bool = false)
    {
        let size = float2(app.editorRegion!.rect.width, app!.editorRegion!.rect.height)
        /*
         var recompile : Bool = hard
        if previewTexture == nil || Float(previewTexture!.width) != size.x || Float(previewTexture!.height) != size.y {
            previewTexture = app.nodeGraph.builder.compute!.allocateTexture(width: size.x, height: size.y, output: false)
            recompile = true
        }*/
        
        _ = profile.execute(nodeGraph: app.nodeGraph, root: BehaviorTreeRoot(masterObject), parent: masterObject)
        
        if builderInstance == nil || hard {
            builderInstance = app.nodeGraph.builder.buildObjects(objects: [masterObject], camera: camera, preview: false)
        }
        
        if builderInstance != nil {
            previewTexture = app.nodeGraph.builder.render(width: size.x, height: size.y, instance: builderInstance!, camera: camera)//, outTexture: previewTexture)
        }
    }
}
