//
//  MMBaseView_mac.swift
//  Framework
//
//  Created by Markus Moenig on 10/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

class MMBaseView : MTKView
{
    var widgets         = [MMWidget]()
    var hoverWidget     : MMWidget?
    var focusWidget     : MMWidget?
    
    var lastX, lastY    : Float?
    
    var scaleFactor     : Float!
    
    var mouseDownPos    : float2!
    
    // --- Drag And Drop
    var dragSource      : MMDragSource? = nil
    
    func platformInit()
    {
        scaleFactor = Float(UIScreen.main.scale)
        mouseDownPos = float2()
        
        let panRecognizer = UIPanGestureRecognizer(target: self, action:(#selector(self.handlePanGesture(_:))))
        addGestureRecognizer(panRecognizer)
    }
    
    @objc func handlePanGesture(_ recognizer: UIPanGestureRecognizer)
    {
        let translation = recognizer.translation(in: self)
//        print( translation )
        
        if ( recognizer.state == .began ) {
            lastX = 0
            lastY = 0
        }
        
        let event = MMMouseEvent(Float(translation.x) + mouseDownPos.x, Float(translation.y) + mouseDownPos.y)
        
        if hoverWidget != nil {
            event.deltaX = Float(translation.x) - lastX!
            event.deltaY = Float(translation.y) - lastY!
            event.deltaZ = 0
            
            hoverWidget?.mouseScrolled(event)
        }
        
        if ( recognizer.state == .ended ) {
            /*
            // 1
            let velocity = recognizer.velocity(in: self)
            let magnitude = sqrt((velocity.x * velocity.x) + (velocity.y * velocity.y))
            let slideMultiplier = magnitude / 200
            print("magnitude: \(magnitude), slideMultiplier: \(slideMultiplier)")
            
            // 2
            let slideFactor = 0.1 * slideMultiplier     //Increase for more of a slide
            // 3
            var finalPoint = CGPoint(x:recognizer.view!.center.x + (velocity.x * slideFactor),
                                     y:recognizer.view!.center.y + (velocity.y * slideFactor))
            // 4
            finalPoint.x = min(max(finalPoint.x, 0), self.bounds.size.width)
            finalPoint.y = min(max(finalPoint.y, 0), self.bounds.size.height)
            */
            // 5
            /*
            UIView.animate(withDuration: Double(slideFactor * 2),
                           delay: 0,
                           // 6
                options: UIViewAnimationOptions.curveEaseOut,
                animations: {recognizer.view!.center = finalPoint },
                completion: nil)
            */
            
            if focusWidget != nil {
                focusWidget!.mouseUp(event)
            }
            
            hoverWidget = nil
            focusWidget = nil
        } else {
            if focusWidget != nil {
                focusWidget!.mouseMoved(event)
            }
        }
        
        lastX = Float(translation.x)
        lastY = Float(translation.y)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let point = touch.location(in: self)
            let event = MMMouseEvent( Float(point.x), Float(point.y) )
            
            mouseDownPos.x = event.x
            mouseDownPos.y = event.y

            if hoverWidget != nil {
                hoverWidget!.removeState(.Hover)
            }
            
            for widget in widgets {
                //            print( x, y, widget.rect.x, widget.rect.y, widget.rect.width, widget.rect.height )
                if widget.rect.contains( event.x, event.y ) {
                    hoverWidget = widget
                    hoverWidget?.mouseDown(event)
//                    hoverWidget!.addState(.Hover)
                    break;
                }
            }
            
            // ---
            
            if hoverWidget != nil {
                
                if focusWidget != nil {
                    focusWidget!.removeState( .Focus )
                }
                
                focusWidget = hoverWidget
//                focusWidget!.addState( .Clicked )
//                focusWidget!.addState( .Focus )
                focusWidget!.clicked(event.x, event.y)
            }
            
//            hoverWidget = nil
//            focusWidget = nil
        }
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//        if let touch = touches.first {
//            let currentPoint = touch.location(in: self)
//        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = touches.first {
            let point = touch.location(in: self)
            let event = MMMouseEvent( Float(point.x), Float(point.y) )
            
//            let x : Float = Float(currentPoint.x)
//            let y : Float = Float(currentPoint.y)
            
            if focusWidget != nil {
                focusWidget!.removeState( .Clicked )
                focusWidget!.mouseUp(event)
            }
            hoverWidget = nil
            focusWidget = nil
        }
    }
}
