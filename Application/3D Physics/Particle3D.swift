//
//  Particle3D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 25/7/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation
import simd

class Particle3D
{
    var position            = float3(0,0,0)
    
    var velocity            = float3(0,0,0)
    var acceleration        = float3(0,-9.8,0)

    var forceAccum          = float3(0,0,0)

    var damping             : Float = 0.99

    var inverseMass         : Float = 1.0

    var object              : StageItem
    var objectSpheres       : ObjectSpheres3D

    init(_ object: StageItem, _ objectSpheres: ObjectSpheres3D)
    {
        self.object = object
        self.objectSpheres = objectSpheres
    }
    
    func integrate(duration: Float)
    {
        // We don't integrate things with zero mass.
        if inverseMass <= 0.0 { return }

        // Update linear position
        position += velocity * duration
        
        // Work out the acceleration from the force
        var resultingAcc = acceleration
        resultingAcc += forceAccum * inverseMass
        
        // Update linear velocity from the acceleration
        velocity += resultingAcc * duration
        
        // Impose drag
        velocity *= pow(damping, duration)
        
        // Clear the forces
        clearAccumulator()
    }
    
    func getPosition() -> float3
    {
        return position
    }
    
    func setPosition(position: float3)
    {
        self.position = position
    }
    
    func getMass() -> Float
    {
        if inverseMass == 0 {
            return Float.greatestFiniteMagnitude
        } else {
            return 1.0 / inverseMass
        }
    }
    
    func getInverseMass() -> Float
    {
        return inverseMass
    }
    
    func setMass(mass: Float)
    {
        if mass != 0.0 {
            inverseMass = 1 / mass
        } else {
            inverseMass = 0
        }
    }
    
    func setInverseMass(inverseMass: Float)
    {
        self.inverseMass = inverseMass
    }
    
    func hasFiniteMass() -> Bool
    {
        return inverseMass >= 0.0
    }
    
    func getDamping() -> Float
    {
        return damping
    }
    
    func setDamping(damping: Float)
    {
        self.damping = damping
    }
    
    func getVelocity() -> float3
    {
        return velocity
    }
    
    func setVelocity(velocity: float3)
    {
        self.velocity = velocity
    }
    
    func getAcceleration() -> float3
    {
        return acceleration
    }
    
    func setAcceleration(acceleration: float3)
    {
        self.acceleration = acceleration
    }
    
    func addForce(force: SIMD3<Float>)
    {
        forceAccum += force
    }
    
    func clearAccumulator()
    {
        forceAccum = float3(0,0,0)
    }
}
