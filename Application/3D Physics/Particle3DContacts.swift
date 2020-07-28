//
//  ParticleContacts3D.swift
//  Shape-Z
//
//  Created by Markus Moenig on 25/7/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation
import simd

class Particle3DContactResolver
{
    var iterations                  : Int
    var iterationsUsed              : Int = 0

    init(iterations: Int)
    {
        self.iterations = iterations
    }
    
    func setIterations(iterations: Int)
    {
        self.iterations = iterations
    }
    
    func resolveContacts(particleContacts: [Particle3DContact], duration: Float)
    {
        iterationsUsed = 0
        while iterationsUsed < iterations {
            // Find the contact with the largest closing velocity;

            var max = Float.greatestFiniteMagnitude
            var maxIndex = particleContacts.count
            
            for (i, contact) in particleContacts.enumerated() {
                let sepVel : Float = contact.calculateSeparatingVelocity()
                
                if (sepVel < max && (sepVel < 0 || contact.penetration > 0))
                {
                    max = sepVel
                    maxIndex = i
                }
            }
            
            // Do we have anything worth resolving?
            if maxIndex == particleContacts.count {
                break
                
            }
            
            particleContacts[maxIndex].resolve(duration: duration)

            // Update the interpenetrations for all particles
            let move = particleContacts[maxIndex].particleMovement
            
            for (i, contact) in particleContacts.enumerated() {
                if (contact.particle.0 === particleContacts[maxIndex].particle.0)
                {
                    contact.penetration -= simd_dot(move.0, particleContacts[i].contactNormal)
                } else
                if contact.particle.0 === particleContacts[maxIndex].particle.1 {
                    contact.penetration -= simd_dot(move.1, particleContacts[i].contactNormal)
                }
                
                if contact.particle.1 != nil {
                    if contact.particle.1 === particleContacts[maxIndex].particle.0
                    {
                        contact.penetration += simd_dot(move.0, particleContacts[i].contactNormal)
                    } else
                    if contact.particle.1 === particleContacts[maxIndex].particle.1
                    {
                        contact.penetration += simd_dot(move.1, particleContacts[i].contactNormal)
                    }
                }
            }

            iterationsUsed += 1
        }
    }
}


class Particle3DContact
{
    
    var particle                : (Particle3D, Particle3D?)
    
    var restitution             : Float = 0.4
    
    var contactNormal           : float3
    var penetration             : Float

    var particleMovement        : (float3, float3) = (float3(0,0,0), float3(0,0,0))

    init(particle: (Particle3D, Particle3D?), normal: float3, penetration: Float )
    {
        self.particle = particle
        self.contactNormal = normal
        self.penetration = penetration
    }
    
    func resolve(duration: Float)
    {
        resolveVelocity(duration: duration)
        resolveInterpenetration(duration: duration)
    }
    
    func resolveInterpenetration(duration: Float)
    {
        // If we don't have any penetration, skip this step.
        if penetration <= 0 {
            return
        }

        // The movement of each object is based on their inverse mass, so
        // total that.
        var totalInverseMass = particle.0.getInverseMass()
        if let particle1 = particle.1 {
            totalInverseMass += particle1.getInverseMass()
        }

        // If all particles have infinite mass, then we do nothing
        if totalInverseMass <= 0 {
            return
        }

        // Find the amount of penetration resolution per unit of inverse mass
        let movePerIMass = contactNormal * (penetration / totalInverseMass)

        // Calculate the the movement amounts
        particleMovement.0 = movePerIMass * particle.0.getInverseMass()
        if let particle1 = particle.1 {
            particleMovement.1 = movePerIMass * -particle1.getInverseMass()
        } else {
            particleMovement.1 = float3(0,0,0)
        }

        // Apply the penetration resolution
        particle.0.setPosition(position: particle.0.getPosition() + particleMovement.0)
        if let particle1 = particle.1 {
            particle1.setPosition(position: particle1.getPosition() + particleMovement.1)
        }
    }

    func resolveVelocity(duration: Float)
    {
        // Find the velocity in the direction of the contact
        let separatingVelocity = calculateSeparatingVelocity()
        
        // Check if it needs to be resolved
        if separatingVelocity > 0 {
            // The contact is either separating, or stationary - there's
            // no impulse required.
            return;
        }
        
        // Calculate the new separating velocity
        var newSepVelocity = -separatingVelocity * restitution
        
        // Check the velocity build-up due to acceleration only
        var accCausedVelocity = particle.0.getAcceleration()
        if let particle1 = particle.1 {
            accCausedVelocity -= particle1.getAcceleration()
        }
        let accCausedSepVelocity = simd_dot(accCausedVelocity, contactNormal) * duration
        
        // If we've got a closing velocity due to acceleration build-up,
        // remove it from the new separating velocity
        if accCausedSepVelocity < 0 {
            newSepVelocity += restitution * accCausedSepVelocity

            // Make sure we haven't removed more than was
            // there to remove.
            if newSepVelocity < 0 {
                newSepVelocity = 0
            }
        }
        
        let deltaVelocity = newSepVelocity - separatingVelocity

        // We apply the change in velocity to each object in proportion to
        // their inverse mass (i.e. those with lower inverse mass [higher
        // actual mass] get less change in velocity)..
        var totalInverseMass = particle.0.getInverseMass()
        if let particle1 = particle.1 {
            totalInverseMass += particle1.getInverseMass()
        }
        
        // If all particles have infinite mass, then impulses have no effect
        if totalInverseMass <= 0 {
            return
        }

        // Calculate the impulse to apply
        let impulse = deltaVelocity / totalInverseMass

        // Find the amount of impulse per unit of inverse mass
        let impulsePerIMass : float3 = contactNormal * impulse
        
        // Apply impulses: they are applied in the direction of the contact,
        // and are proportional to the inverse mass.
        particle.0.setVelocity(velocity: particle.0.getVelocity() + impulsePerIMass * particle.0.getInverseMass())
        
        if let particle1 = particle.1 {
            particle1.setVelocity(velocity: particle1.getVelocity() + impulsePerIMass * -particle1.getInverseMass())
        }
    }
    
    func calculateSeparatingVelocity() -> Float
    {
        var relativeVelocity = particle.0.getVelocity()
        if let particle1 = particle.1 {
            relativeVelocity -= particle1.getVelocity()
        }
        return simd_dot(relativeVelocity, contactNormal)
    }
}
