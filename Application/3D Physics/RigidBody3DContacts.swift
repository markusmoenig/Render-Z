//
//  RigidBody3DContacts.swift
//  Shape-Z
//
//  Created by Markus Moenig on 29/7/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation

class RigiBody3DContactResolver
{
    var velocityIterations          : Int = 0
    var velocityIterationsUsed      : Int = 0
    var positionIterations          : Int = 0
    var positionIterationsUsed      : Int = 0

    var velocityEpsilon             : Float = 0.01
    var positionEpsilon             : Float = 0.01


    init(iterations: Int)
    {
        self.velocityIterations = iterations
        self.positionIterations = iterations
    }
    
    func isValid() -> Bool
    {
        return (velocityIterations > 0) &&
               (positionIterations > 0) &&
               (positionEpsilon >= 0.0) &&
               (positionEpsilon >= 0.0)
    }
    
    func setIterations(iterations: Int)
    {
        self.velocityIterations = iterations
        self.positionIterations = iterations
    }
    
    func resolveContacts(contacts: [RigidBody3DContact], duration: Float)
    {
        if !isValid() { return }

        // Prepare the contacts for processing
        prepareContacts(contacts, duration);

        // Resolve the interpenetration problems with the contacts.
        adjustPositions(contacts, duration);

        // Resolve the velocity problems with the contacts.
        adjustVelocities(contacts, duration);
    }
    
    func prepareContacts(_ contacts: [RigidBody3DContact],_ duration: Float)
    {
        // Generate contact velocity and axis information.
        for contact in contacts {
            contact.calculateInternals(duration)
        }
    }
    
    func adjustVelocities(_ contacts: [RigidBody3DContact],_ duration: Float)
    {
        var velocityChange = [float3(0,0,0), float3(0,0,0)]
        var rotationChange = [float3(0,0,0), float3(0,0,0)]
        var deltaVel = float3(0,0,0)

        // iteratively handle impacts in order of severity.
        velocityIterationsUsed = 0
        while (velocityIterationsUsed < velocityIterations)
        {
            // Find contact with maximum magnitude of probable velocity change.
            var max = velocityEpsilon
            var index = contacts.count
            for (i, contact) in contacts.enumerated() {
                if contact.desiredDeltaVelocity > max {
                    max = contact.desiredDeltaVelocity
                    index = i
                }
            }
            if index == contacts.count { break }

            // Match the awake state at the contact
            contacts[index].matchAwakeState()

            // Do the resolution on the contact that came out top.
            contacts[index].applyVelocityChange(&velocityChange, &rotationChange)

            // With the change in velocity of the two bodies, the update of
            // contact velocities means that some of the relative closing
            // velocities need recomputing.
            for i in 0..<contacts.count
            {
                if contacts[i].body.0 === contacts[index].body.0 {
                    deltaVel = velocityChange[0] + cross(rotationChange[0], contacts[i].relativeContactPosition[0])

                    // The sign of the change is negative if we're dealing
                    // with the second body in a contact.
                    contacts[i].contactVelocity += contacts[i].contactToWorld.transformTranspose(deltaVel) * 1.0
                    contacts[i].calculateDesiredDeltaVelocity(duration)
                }
                
                if contacts[i].body.0 === contacts[index].body.1 {
                    deltaVel = velocityChange[1] + cross(rotationChange[1], contacts[i].relativeContactPosition[0])

                    // The sign of the change is negative if we're dealing
                    // with the second body in a contact.
                    contacts[i].contactVelocity += contacts[i].contactToWorld.transformTranspose(deltaVel) * 1.0
                    contacts[i].calculateDesiredDeltaVelocity(duration)
                }
                
                if contacts[i].body.1 === contacts[index].body.0 {
                    deltaVel = velocityChange[0] + cross(rotationChange[0], contacts[i].relativeContactPosition[1])

                    // The sign of the change is negative if we're dealing
                    // with the second body in a contact.
                    contacts[i].contactVelocity += contacts[i].contactToWorld.transformTranspose(deltaVel) * -1.0
                    contacts[i].calculateDesiredDeltaVelocity(duration)
                }
                
                if contacts[i].body.1 === contacts[index].body.1 {
                    deltaVel = velocityChange[1] + cross(rotationChange[1], contacts[i].relativeContactPosition[1])

                    // The sign of the change is negative if we're dealing
                    // with the second body in a contact.
                    contacts[i].contactVelocity += contacts[i].contactToWorld.transformTranspose(deltaVel) * -1.0
                    contacts[i].calculateDesiredDeltaVelocity(duration)
                }
                
                /*
                let b : [RigidBody3D?] = [contacts[i].body.0, contacts[i].body.1]
                // Check each body in the contact
                //for (unsigned b = 0; b < 2; b++) if (c[i].body[b])
                for b in 0..<2 {
                        // Check for a match with each body in the newly
                        // resolved contact
                        for d in 0..<2 {
                            if (contacts[i].body[b] == contacts[index].body[d])
                            {
                                deltaVel = velocityChange[d] +
                                    rotationChange[d].vectorProduct(
                                        c[i].relativeContactPosition[b]);

                                // The sign of the change is negative if we're dealing
                                // with the second body in a contact.
                                c[i].contactVelocity +=
                                    c[i].contactToWorld.transformTranspose(deltaVel)
                                    * (b?-1:1);
                                c[i].calculateDesiredDeltaVelocity(duration);
                            }
                        }
                    }
                }*/
            }
            velocityIterationsUsed += 1
        }
    }
    
    func adjustPositions(_ contacts: [RigidBody3DContact],_ duration: Float)
    {
        var index : Int = 0
        var linearChange = [float3(0,0,0), float3(0,0,0)]
        var angularChange = [float3(0,0,0), float3(0,0,0)]

        var max : Float = 0
        var deltaPosition = float3(0,0,0)

        // iteratively resolve interpenetrations in order of severity.
        positionIterationsUsed = 0;
        while (positionIterationsUsed < positionIterations)
        {
            // Find biggest penetration
            max = positionEpsilon
            index = contacts.count
            for (i, _) in contacts.enumerated() {
                if contacts[i].penetration > max
                {
                    max = contacts[i].penetration
                    index = i
                }
            }
            if index == contacts.count { break }

            // Match the awake state at the contact
            contacts[index].matchAwakeState()

            // Resolve the penetration.
            contacts[index].applyPositionChange(&linearChange, &angularChange, max)

            // Again this action may have changed the penetration of other
            // bodies, so we update contacts.
            
            for i in 0..<contacts.count
            {
                if contacts[i].body.0 === contacts[index].body.0 {
                    deltaPosition = linearChange[0] + cross(angularChange[0], contacts[i].relativeContactPosition[0])
                    contacts[i].penetration += dot(deltaPosition, contacts[i].contactNormal) * -1
                }
                
                if contacts[i].body.0 === contacts[index].body.1 {
                    deltaPosition = linearChange[1] + cross(angularChange[1], contacts[i].relativeContactPosition[0])
                    contacts[i].penetration += dot(deltaPosition, contacts[i].contactNormal) * -1
                }
                
                if contacts[i].body.1 === contacts[index].body.0 {
                    deltaPosition = linearChange[0] + cross(angularChange[0], contacts[i].relativeContactPosition[1])
                    contacts[i].penetration += dot(deltaPosition, contacts[i].contactNormal) * 1
                }
                
                if contacts[i].body.1 === contacts[index].body.1 {
                    deltaPosition = linearChange[1] + cross(angularChange[1], contacts[i].relativeContactPosition[1])
                    contacts[i].penetration += dot(deltaPosition, contacts[i].contactNormal) * 1
                }
            }
            
            /*
            for (i = 0; i < numContacts; i++)
            {
                // Check each body in the contact
                for (unsigned b = 0; b < 2; b++) if (c[i].body[b])
                {
                    // Check for a match with each body in the newly
                    // resolved contact
                    for (unsigned d = 0; d < 2; d++)
                    {
                        if (c[i].body[b] == c[index].body[d])
                        {
                            deltaPosition = linearChange[d] +
                                angularChange[d].vectorProduct(
                                    c[i].relativeContactPosition[b]);

                            // The sign of the change is positive if we're
                            // dealing with the second body in a contact
                            // and negative otherwise (because we're
                            // subtracting the resolution)..
                            c[i].penetration +=
                                deltaPosition.scalarProduct(c[i].contactNormal)
                                * (b?1:-1);
                        }
                    }
                }
            }*/
            positionIterationsUsed += 1
        }
    }
}


class RigidBody3DContact
{
    var body                    : (RigidBody3D, RigidBody3D?)
    
    var restitution             : Float = 0.8
    var friction                : Float = 0.8

    var contactNormal           : float3
    var contactPoint            : float3

    var penetration             : Float

    //
    
    var contactToWorld          = _Matrix3()
    var contactVelocity         = float3(0,0,0)
    var desiredDeltaVelocity    : Float = 0
    var relativeContactPosition = [float3(0,0,0), float3(0,0,0)]
    
    init(body: (RigidBody3D, RigidBody3D?), contactPoint: float3, normal: float3, penetration: Float)
    {
        self.body = body
        self.contactNormal = normal
        self.contactPoint = contactPoint
        self.penetration = penetration
    }
    
    func matchAwakeState()
    {
        // Collisions with the world never cause a body to wake up.
        if body.1 == nil { return }

        let body0awake = body.0.getAwake()
        let body1awake = body.1!.getAwake()

        // Wake up only the sleeping one
        if body0awake || body1awake {
            if body0awake {
                body.1!.setAwake()
            } else {
                body.0.setAwake()
            }
        }
    }
    
    func swapBodies()
    {
        contactNormal *= -1;

        let temp = body.0
        body.0 = body.1!
        body.1 = temp
    }
    
    func calculateContactBasis()
    {
        var contactTangent : [float3] = [float3(0,0,0), float3(0,0,0)]

        // Check whether the Z-axis is nearer to the X or Y axis
        if (abs(contactNormal.x) > abs(contactNormal.y))
        {
            // Scaling factor to ensure the results are normalised
            let s = 1.0 / sqrt(contactNormal.z*contactNormal.z +
                contactNormal.x*contactNormal.x)

            // The new X-axis is at right angles to the world Y-axis
            contactTangent[0].x = contactNormal.z*s
            contactTangent[0].y = 0
            contactTangent[0].z = -contactNormal.x*s

            // The new Y-axis is at right angles to the new X- and Z- axes
            contactTangent[1].x = contactNormal.y*contactTangent[0].x
            contactTangent[1].y = contactNormal.z*contactTangent[0].x -
                contactNormal.x*contactTangent[0].z
            contactTangent[1].z = -contactNormal.y*contactTangent[0].x
        }
        else
        {
            // Scaling factor to ensure the results are normalised
            let s = 1.0 / sqrt(contactNormal.z*contactNormal.z +
                contactNormal.y*contactNormal.y)

            // The new X-axis is at right angles to the world X-axis
            contactTangent[0].x = 0
            contactTangent[0].y = -contactNormal.z*s
            contactTangent[0].z = contactNormal.y*s

            // The new Y-axis is at right angles to the new X- and Z- axes
            contactTangent[1].x = contactNormal.y*contactTangent[0].z -
                contactNormal.z*contactTangent[0].y
            contactTangent[1].y = -contactNormal.x*contactTangent[0].z
            contactTangent[1].z = contactNormal.x*contactTangent[0].y
        }

        // Make a matrix from the three vectors.
        contactToWorld.setComponents(contactNormal, contactTangent[0], contactTangent[1])
    }
    
    func calculateLocalVelocity(_ bodyIndex: Int,_ duration: Float) -> float3
    {
        let thisBody: RigidBody3D
        
        if bodyIndex == 0 {
            thisBody = body.0
        } else {
            thisBody = body.1!
        }
            
        // Work out the velocity of the contact point.
        var velocity = float3(0,0,0)
            
        velocity = cross(thisBody.getRotation(), relativeContactPosition[bodyIndex])
        velocity += thisBody.getVelocity()

        // Turn the velocity into contact-coordinates.
        var contactVelocity = contactToWorld.transformTranspose(velocity)

        // Calculate the ammount of velocity that is due to forces without
        // reactions.
        var accVelocity = thisBody.getLastFrameAcceleration() * duration

        // Calculate the velocity in contact-coordinates.
        accVelocity = contactToWorld.transformTranspose(accVelocity)

        // We ignore any component of acceleration in the contact normal
        // direction, we are only interested in planar acceleration
        accVelocity.x = 0

        // Add the planar velocities - if there's enough friction they will
        // be removed during velocity resolution
        contactVelocity += accVelocity

        // And return it
        return contactVelocity
    }
    
    func calculateDesiredDeltaVelocity(_ duration: Float)
    {
        let velocityLimit: Float = 0.25

        // Calculate the acceleration induced velocity accumulated this frame
        var velocityFromAcc: Float = 0;

        if body.0.getAwake() {
            velocityFromAcc += dot(body.0.getLastFrameAcceleration(), contactNormal) * duration
        }

        if body.1 != nil && body.1!.getAwake() {
            velocityFromAcc -= dot(body.1!.getLastFrameAcceleration(), contactNormal) * duration

        }

        // If the velocity is very slow, limit the restitution
        var thisRestitution = restitution
        if abs(contactVelocity.x) < velocityLimit {
            thisRestitution = 0.0
        }

        // Combine the bounce velocity with the removed
        // acceleration velocity.
        desiredDeltaVelocity = -contactVelocity.x - thisRestitution * (contactVelocity.x - velocityFromAcc)
    }
    
    func calculateInternals(_ duration: Float)
    {
        // Calculate an set of axis at the contact point.
        calculateContactBasis()

        // Store the relative position of the contact relative to each body
        relativeContactPosition[0] = contactPoint - body.0.getPosition()
        if let body1 = body.1 {
            relativeContactPosition[1] = contactPoint - body1.getPosition()
        }

        // Find the relative velocity of the bodies at the contact point.
        contactVelocity = calculateLocalVelocity(0, duration)
        if body.1 != nil {
            contactVelocity -= calculateLocalVelocity(1, duration)
        }

        // Calculate the desired change in velocity for resolution
        calculateDesiredDeltaVelocity(duration)
    }
    
    func applyVelocityChange(_ velocityChange: inout [float3],_ rotationChange: inout [float3])
    {
        // Get hold of the inverse mass and inverse inertia tensor, both in
        // world coordinates.
        var inverseInertiaTensor = [_Matrix3(), _Matrix3()]
        inverseInertiaTensor[0] = body.0.getInverseInertiaTensorWorld()
        
        if let body1 = body.1 {
            inverseInertiaTensor[0] = body1.getInverseInertiaTensorWorld()
        }

        // We will calculate the impulse for each contact axis
        var impulseContact = float3(0,0,0)

        if friction == 0.0 {
            // Use the short format for frictionless contacts
            impulseContact = calculateFrictionlessImpulse(inverseInertiaTensor)
        } else {
            // Otherwise we may have impulses that aren't in the direction of the
            // contact, so we need the more complex version.
            impulseContact = calculateFrictionImpulse(inverseInertiaTensor)
        }

        // Convert impulse to world coordinates
        let impulse = contactToWorld.transform(impulseContact)

        // Split in the impulse into linear and rotational components
        let impulsiveTorque = cross(relativeContactPosition[0], impulse)

        rotationChange[0] = inverseInertiaTensor[0].transform(impulsiveTorque);
        velocityChange[0] = float3(0,0,0)
        velocityChange[0] += impulse * body.0.getInverseMass()

        // Apply the changes
        body.0.addVelocity(velocityChange[0])
        body.0.addRotation(rotationChange[0])

        if let body1 = body.1 {
            // Work out body one's linear and angular changes
            let impulsiveTorque = cross(impulse, relativeContactPosition[1])

            rotationChange[1] = inverseInertiaTensor[1].transform(impulsiveTorque)
            velocityChange[1] = float3(0,0,0)
            velocityChange[1] += impulse * -body1.getInverseMass()

            // And apply them.
            body1.addVelocity(velocityChange[1])
            body1.addRotation(rotationChange[1])
        }
    }
    
    func calculateFrictionlessImpulse(_ inverseInertiaTensor: [_Matrix3]) -> float3
    {
        var impulseContact = float3(0,0,0)

        // Build a vector that shows the change in velocity in
        // world space for a unit impulse in the direction of the contact
        // normal.
        var deltaVelWorld = cross(relativeContactPosition[0], contactNormal)

        deltaVelWorld = inverseInertiaTensor[0].transform(deltaVelWorld)
        deltaVelWorld = cross(deltaVelWorld,relativeContactPosition[0])

        // Work out the change in velocity in contact coordiantes.
        var deltaVelocity = dot(deltaVelWorld, contactNormal)

        // Add the linear component of velocity change
        deltaVelocity += body.0.getInverseMass()

        // Check if we need to the second body's data
        if let body1 = body.1 {
            // Go through the same transformation sequence again
            var deltaVelWorld = cross(relativeContactPosition[1], contactNormal)
            
            deltaVelWorld = inverseInertiaTensor[1].transform(deltaVelWorld)
            deltaVelWorld = cross(deltaVelWorld, relativeContactPosition[1])

            // Add the change in velocity due to rotation
            deltaVelocity += dot(deltaVelWorld, contactNormal)

            // Add the change in velocity due to linear motion
            deltaVelocity += body1.getInverseMass()
        }

        // Calculate the required size of the impulse
        impulseContact.x = desiredDeltaVelocity / deltaVelocity
        impulseContact.y = 0
        impulseContact.z = 0
        return impulseContact
    }
    
    func calculateFrictionImpulse(_ inverseInertiaTensor: [_Matrix3]) -> float3
    {
        var impulseContact = float3(0,0,0)
        var inverseMass = body.0.getInverseMass()

        // The equivalent of a cross product in matrices is multiplication
        // by a skew symmetric matrix - we build the matrix for converting
        // between linear and angular quantities.
        let impulseToTorque = _Matrix3()
        impulseToTorque.setSkewSymmetric(relativeContactPosition[0])

        // Build the matrix to convert contact impulse to change in velocity
        // in world coordinates.
        let deltaVelWorld = _Matrix3()
        deltaVelWorld.data = impulseToTorque.data
        deltaVelWorld.multiply(inverseInertiaTensor[0])
        deltaVelWorld.multiply(impulseToTorque)
        deltaVelWorld.multiply(-1)

        // Check if we need to add body two's data
        if let body1 = body.1 {
            // Set the cross product matrix
            impulseToTorque.setSkewSymmetric(relativeContactPosition[1])

            // Calculate the velocity change matrix
            let deltaVelWorld2 = _Matrix3()
            deltaVelWorld2.data = impulseToTorque.data
            deltaVelWorld2.multiply(inverseInertiaTensor[1])
            deltaVelWorld2.multiply(impulseToTorque)
            deltaVelWorld2.multiply(-1)

            // Add to the total delta velocity.
            deltaVelWorld.add(deltaVelWorld2)

            // Add to the inverse mass
            inverseMass += body1.getInverseMass()
        }

        // Do a change of basis to convert into contact coordinates.
        let deltaVelocity = contactToWorld.transpose()
        deltaVelocity.multiply(deltaVelWorld)
        deltaVelocity.multiply(contactToWorld)

        // Add in the linear velocity change
        deltaVelocity.data[0] += inverseMass
        deltaVelocity.data[4] += inverseMass
        deltaVelocity.data[8] += inverseMass

        // Invert to get the impulse needed per unit velocity
        let impulseMatrix = deltaVelocity.inverse()

        // Find the target velocities to kill
        let velKill = float3(desiredDeltaVelocity, -contactVelocity.y, -contactVelocity.z)

        // Find the impulse to kill target velocities
        impulseContact = impulseMatrix.transform(velKill)

        // Check for exceeding friction
        let planarImpulse = sqrt( impulseContact.y*impulseContact.y + impulseContact.z*impulseContact.z)
        if (planarImpulse > impulseContact.x * friction)
        {
            // We need to use dynamic friction
            impulseContact.y /= planarImpulse
            impulseContact.z /= planarImpulse

            impulseContact.x = deltaVelocity.data[0] +
                deltaVelocity.data[1]*friction*impulseContact.y +
                deltaVelocity.data[2]*friction*impulseContact.z
            impulseContact.x = desiredDeltaVelocity / impulseContact.x
            impulseContact.y *= friction * impulseContact.x
            impulseContact.z *= friction * impulseContact.x
        }
        return impulseContact
    }
    
    func applyPositionChange(_ linearChange: inout [float3],_ angularChange: inout [float3],_ penetration: Float)
    {
        let angularLimit : Float = 0.2
        var angularMove : [Float] = [0, 0]
        var linearMove : [Float] = [0, 0]

        var totalInertia : Float = 0
        var linearInertia : [Float] = [0, 0]
        var angularInertia : [Float] = [0, 0]

        // We need to work out the inertia of each object in the direction
        // of the contact normal, due to angular inertia only.
            
    
        let inverseInertiaTensor = _Matrix3()
        body.0.getInverseInertiaTensorWorld(inverseInertiaTensor)

        // Use the same procedure as for calculating frictionless
        // velocity change to work out the angular inertia.
        var angularInertiaWorld = cross(relativeContactPosition[0], contactNormal)
        angularInertiaWorld = inverseInertiaTensor.transform(angularInertiaWorld)
        angularInertiaWorld = cross(angularInertiaWorld, relativeContactPosition[0])
        angularInertia[0] = dot(angularInertiaWorld, contactNormal)

        // The linear component is simply the inverse mass
        linearInertia[0] = body.0.getInverseMass()

        // Keep track of the total inertia from all components
        totalInertia += linearInertia[0] + angularInertia[0]

        if let body1 = body.1 {
            let inverseInertiaTensor = _Matrix3()
            body1.getInverseInertiaTensorWorld(inverseInertiaTensor)

            // Use the same procedure as for calculating frictionless
            // velocity change to work out the angular inertia.
            var angularInertiaWorld = cross(relativeContactPosition[1], contactNormal)
            angularInertiaWorld = inverseInertiaTensor.transform(angularInertiaWorld)
            angularInertiaWorld = cross(angularInertiaWorld, relativeContactPosition[1])
            angularInertia[1] = dot(angularInertiaWorld, contactNormal)

            // The linear component is simply the inverse mass
            linearInertia[1] = body1.getInverseMass()

            // Keep track of the total inertia from all components
            totalInertia += linearInertia[1] + angularInertia[1]
        }
        
        let b : [RigidBody3D?] = [body.0, body.1]
    
        for (i, body) in b.enumerated() {
            if let body = body {
                // The linear and angular movements required are in proportion to
                // the two inverse inertias.
                let sign : Float = (i == 0) ? 1 : -1
                angularMove[i] = sign * penetration * (angularInertia[i] / totalInertia)
                linearMove[i] = sign * penetration * (linearInertia[i] / totalInertia)

                // To avoid angular projections that are too great (when mass is large
                // but inertia tensor is small) limit the angular move.
                var projection = relativeContactPosition[i]
                projection += contactNormal * -dot(relativeContactPosition[i], contactNormal)

                // Use the small angle approximation for the sine of the angle (i.e.
                // the magnitude would be sine(angularLimit) * projection.magnitude
                // but we approximate sine(angularLimit) to angularLimit).
                let maxMagnitude = angularLimit * sqrt(projection.x*projection.x+projection.y*projection.y+projection.z*projection.z)

                if (angularMove[i] < -maxMagnitude) {
                    let totalMove = angularMove[i] + linearMove[i]
                    angularMove[i] = -maxMagnitude
                    linearMove[i] = totalMove - angularMove[i]
                } else
                if (angularMove[i] > maxMagnitude) {
                    let totalMove = angularMove[i] + linearMove[i]
                    angularMove[i] = maxMagnitude
                    linearMove[i] = totalMove - angularMove[i]
                }

                // We have the linear amount of movement required by turning
                // the rigid body (in angularMove[i]). We now need to
                // calculate the desired rotation to achieve that.
                if (angularMove[i] == 0)
                {
                    // Easy case - no angular movement means no rotation.
                    angularChange[i] = float3(0,0,0)
                } else {
                    // Work out the direction we'd like to rotate in.
                    let targetAngularDirection = cross(relativeContactPosition[i], contactNormal)

                    var inverseInertiaTensor = _Matrix3()
                    inverseInertiaTensor = body.getInverseInertiaTensorWorld()

                    // Work out the direction we'd need to rotate to achieve that
                    angularChange[i] = inverseInertiaTensor.transform(targetAngularDirection) *
                        (angularMove[i] / angularInertia[i])
                }

                // Velocity change is easier - it is just the linear movement
                // along the contact normal.
                linearChange[i] = contactNormal * linearMove[i];

                // Now we can start to apply the values we've calculated.
                // Apply the linear movement
                var pos = float3(body.getPosition())
                pos += contactNormal * linearMove[i]
                body.setPosition(pos)

                // And the change in orientation
                let q = _Quaternion()
                body.getOrientation(q)
                q.addScaledVector(angularChange[i], 1.0)
                body.setOrientation(q)

                // We need to calculate the derived data for any body that is
                // asleep, so that the changes are reflected in the object's
                // data. Otherwise the resolution will not change the position
                // of the object, and the next collision detection round will
                // have the same penetration.
                if !body.getAwake() {
                    body.calculateDerivedData()
                }
            }
        }
    }
}
