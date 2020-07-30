//
//  Particle3DWorld.swift
//  Shape-Z
//
//  Created by Markus Moenig on 27/7/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation
import simd

class RigidBody3DWorld
{
    var bodies                  : [RigidBody3D] = []
 
    var calculateIterations     : Bool = true

    var resolver                : RigiBody3DContactResolver
    var contacts                : [RigidBody3DContact] = []
        
    init()
    {
        resolver = RigiBody3DContactResolver(iterations: 0)
    }
    
    func addBody(_ body: RigidBody3D)
    {
        bodies.append(body)
    }
    
    func startFrame()
    {
        for body in bodies {
            body.clearAccumulators()
            body.calculateDerivedData()
        }
    }
    
    func runPhysics(duration: Float)
    {
        for body in bodies {
            body.integrate(duration: duration)
        }
        
        if calculateIterations {
            resolver.setIterations(iterations: contacts.count * 2)
        }
        resolver.resolveContacts(contacts: contacts, duration: duration)
        
        contacts = []
    }
}
