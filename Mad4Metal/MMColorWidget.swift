//
//  MMColorWidget.swift
//  Framework
//
//  Created by Markus Moenig on 04/7/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit
import simd

class MMColorWidget : MMWidget
{
    var value       : float4
    var mouseIsDown : Bool = false
    
    var changed     : ((_ value: float4)->())?

    var compute     : MMCompute!
    var state       : MTLComputePipelineState!
    
    var data        : [Float] = []
    var inBuffer    : MTLBuffer!
    var outBuffer   : MTLBuffer!
    
    init(_ view: MMView, value: float4 = float4(0.5, 0.5, 0.5, 1))
    {
        self.value = value
        super.init(view)
        
        name = "MMColorWidget"
        
        compute = MMCompute()
        
        let source =
        """
        #include <metal_stdlib>
        #include <simd/simd.h>
        using namespace metal;

        typedef struct
        {
            float2      pos;
            float2      size;
        } CW_DATA;

        #define M_PI 3.1415926535897932384626433832795

        float3 getHueColor(float2 pos)
        {
            float theta = 3.0 + 3.0 * atan2(pos.x, pos.y) / M_PI;
            
            return clamp(abs(fmod(theta + float3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
        }

        kernel void colorWheel(constant CW_DATA *data [[ buffer(1) ]],
                                        device float4  *out [[ buffer(0) ]],
                                                  uint  gid [[thread_position_in_grid]])
        {
            float2 uv = float2(2.0, 2.0) * (data->pos - 0.5 * data->size) / data->size.y;
            float l = length(uv);

            l = 1.0 - abs((l - 0.875) * 8.0);
            l = clamp(l * data->size.y * 0.0625, 0.0, 1.0);
            
            float4 col = float4(l * getHueColor(uv), l);

            out[gid] = col;
        }

        """
        
        data.append( 0 ) // Pos
        data.append( 0 )
        data.append( 150 ) // Size
        data.append( 150 )
        
        inBuffer = compute.device.makeBuffer(bytes: data, length: data.count * MemoryLayout<Float>.stride, options: [])!
        
        outBuffer = compute.device.makeBuffer(length: 4 * MemoryLayout<Float>.stride, options: [])!
        
        let library = compute!.createLibraryFromSource(source: source)
        state = compute.createState(library: library, name: "colorWheel")
        
        rect.width = 28
        rect.height = 24
    }
    
    func setState(_ state: MMWidgetStates)
    {
        if state == .Closed {
            rect.width = 28
            rect.height = 24
            removeState(.Opened)
        } else {
            rect.width = 230
            rect.height = 170
            addState(.Opened)
        }
    }
    
    override func mouseDown(_ event: MMMouseEvent)
    {
        mouseIsDown = true
        
        getColorAt(event)
        
        mmView.lockFramerate()
        mmView.mouseTrackWidget = self
    }
    
    override func mouseUp(_ event: MMMouseEvent)
    {
        mouseIsDown = false
        mmView.unlockFramerate()
        mmView.mouseTrackWidget = nil
    }
    
    override func mouseMoved(_ event: MMMouseEvent)
    {
        if mouseIsDown {
            getColorAt(event)
        }
    }
    
    func getColorAt(_ event: MMMouseEvent)
    {
        let x : Float = event.x - rect.x - 10
        let y : Float = event.y - rect.y - 10
        
        if x < 0 || x > 150 { return }
        if y < 0 || y > 150 { return }
        
        data[0] = x
        data[1] = y
        data[2] = 150
        data[3] = 150
        
        memcpy(inBuffer.contents(), data, data.count * MemoryLayout<Float>.stride)
        
        compute!.runBuffer( state, outBuffer: outBuffer, inBuffer: inBuffer )
        
        let result = outBuffer.contents().bindMemory(to: Float.self, capacity: 4)
        
        let color = float4( result[0], result[1], result[2], result[3] )
        if color.w == 1.0 {
            value = color
            if changed != nil {
                changed!(value)
            }
        }
    }
    
    override func draw(xOffset: Float = 0, yOffset: Float = 0)
    {
        if !states.contains(.Opened) {
            mmView.drawBox.draw(x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 2, borderSize: 2, fillColor: value, borderColor: float4(0, 0, 0, 1))
        } else {
            mmView.drawBox.draw(x: rect.x, y: rect.y, width: rect.width, height: rect.height, round: 2, borderSize: 2, fillColor: float4(0.145, 0.145, 0.145, 1), borderColor: float4(0, 0, 0, 1))
            
            mmView.drawColorWheel.draw(x: rect.x + 10, y: rect.y + 10, width: 150, height: 150, color: value)
            
            mmView.drawBox.draw(x: rect.x + rect.width - 60, y: rect.y + 10, width: 50, height: rect.height - 20, round: 2, borderSize: 2, fillColor: value, borderColor: float4(0, 0, 0, 1))
        }
    }
}

