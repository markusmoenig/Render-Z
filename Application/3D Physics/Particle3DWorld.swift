//
//  Particle3DWorld.swift
//  Shape-Z
//
//  Created by Markus Moenig on 27/7/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation
import simd

class Particle3DWorld
{
    var particles               : [Particle3D] = []
 
    var calculateIterations     : Bool = true

    var resolver                : Particle3DContactResolver
    var contacts                : [Particle3DContact] = []
        
    init()
    {
        resolver = Particle3DContactResolver(iterations: 0)
    }
    
    func addParticle(particle: Particle3D)
    {
        particles.append(particle)
    }
    
    func startFrame()
    {
        for particle in particles {
            particle.clearAccumulator()
        }
    }
    
    func integrate(duration: Float)
    {
        for particle in particles {
            particle.integrate(duration: duration)
        }
    }
    
    func runPhysics(duration: Float)
    {
        integrate(duration: duration)
        
        if calculateIterations {
            resolver.setIterations(iterations: contacts.count * 2)
        }
        resolver.resolveContacts(particleContacts: contacts, duration: duration)
        
        contacts = []
    }
}
