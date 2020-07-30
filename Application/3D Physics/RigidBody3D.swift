//
//  RigiBody.swift
//  Shape-Z
//
//  Created by Markus Moenig on 29/7/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation
import simd

class RigidBody3D
{
    var inverseMass                 : Float = 1
    var inverseInertiaTensor        = _Matrix3()

    var linearDamping               : Float = 0
    var angularDamping              : Float = 0
    
    var position                    = float3(0,0,0)
    var orientation                 = _Quaternion()
    var velocity                    = float3(0,0,0)
    var rotation                    = float3(0,0,0)

    var inverseInertiaTensorWorld   = _Matrix3()

    var motion : Float              = 1
    
    var isAwake                     = true

    var canSleep                    = false

    var transformMatrix             = _Matrix4()

    var forceAccum                  = float3(0,0,0)
    var torqueAccum                 = float3(0,0,0)
    var acceleration                = float3(0,0,0)

    var lastFrameAcceleration       = float3(0,0,0)
    
    static var sleepEpsilon         : Float = 0.1
    
    var object                      : StageItem
    var objectSpheres               : ObjectSpheres3D

    init(_ object: StageItem, _ objectSpheres: ObjectSpheres3D)
    {
        self.object = object
        self.objectSpheres = objectSpheres
    }
    
    func calculateDerivedData()
    {
        orientation.normalise()

        // Calculate the transform matrix for the body.
        _calculateTransformMatrix(transformMatrix, position, orientation)

        // Calculate the inertiaTensor in world space.
        _transformInertiaTensor(inverseInertiaTensorWorld,
            orientation,
            inverseInertiaTensor,
            transformMatrix)
    }
    
    func integrate(duration: Float)
    {
        if !isAwake { return }

        // Calculate linear acceleration from force inputs.
        lastFrameAcceleration = acceleration
        lastFrameAcceleration += forceAccum * inverseMass

        // Calculate angular acceleration from torque inputs.
        let angularAcceleration = inverseInertiaTensorWorld.transform(torqueAccum)
        
        // Adjust velocities
        // Update linear velocity from both acceleration and impulse.
        velocity += lastFrameAcceleration * duration

        // Update angular velocity from both acceleration and impulse.
        rotation += angularAcceleration * duration

        // Impose drag.
        velocity *= pow(linearDamping, duration)
        rotation *= pow(angularDamping, duration)

        // Adjust positions
        // Update linear position.
        position += velocity * duration

        // Update angular position.
        orientation.addScaledVector(rotation, duration)

        // Normalise the orientation, and update the matrices with the new
        // position and orientation
        calculateDerivedData()

        // Clear accumulators.
        clearAccumulators()

        // Update the kinetic energy store, and possibly put the body to
        // sleep.
        if canSleep {
            let currentMotion : Float = dot(velocity,velocity) + dot(rotation,rotation)

            let bias : Float = pow(0.5, duration)
            motion = bias * motion + (1.0 - bias) * currentMotion

            if motion < RigidBody3D.sleepEpsilon { setAwake(false) }
            else if motion > 10 * RigidBody3D.sleepEpsilon { motion = 10 * RigidBody3D.sleepEpsilon }
        }
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
    

    func setInertiaTensor(_ inertiaTensor: _Matrix3)
    {
        inverseInertiaTensor.setInverse(inertiaTensor)
        //_checkInverseInertiaTensor(inverseInertiaTensor)
    }

    func getInertiaTensor(_ inertiaTensor: _Matrix3)
    {
        inertiaTensor.setInverse(inverseInertiaTensor)
    }

    func getInertiaTensor() -> _Matrix3
    {
        let it = _Matrix3()
        getInertiaTensor(it)
        return it
    }

    func getInertiaTensorWorld(_ inertiaTensor: _Matrix3)
    {
        inertiaTensor.setInverse(inverseInertiaTensorWorld)
    }

    func getInertiaTensorWorld() -> _Matrix3
    {
        let it = _Matrix3()
        getInertiaTensorWorld(it)
        return it
    }

    func setInverseInertiaTensor(_ inverseInertiaTensor: _Matrix3)
    {
        //_checkInverseInertiaTensor(inverseInertiaTensor)
        self.inverseInertiaTensor = inverseInertiaTensor
    }

    func getInverseInertiaTensor(_ inverseInertiaTensor: _Matrix3)
    {
        inverseInertiaTensor.data = self.inverseInertiaTensor.data
    }

    func getInverseInertiaTensor() -> _Matrix3
    {
        return inverseInertiaTensor
    }

    func getInverseInertiaTensorWorld(_ inverseInertiaTensor: _Matrix3)
    {
        inverseInertiaTensor.data = inverseInertiaTensorWorld.data
    }

    func getInverseInertiaTensorWorld() -> _Matrix3
    {
        return inverseInertiaTensorWorld
    }


    func setDamping(_ linearDamping: Float,_ angularDamping: Float)
    {
        self.linearDamping = linearDamping
        self.angularDamping = angularDamping
    }

    func setLinearDamping(_ linearDamping: Float)
    {
        self.linearDamping = linearDamping
    }

    func getLinearDamping() -> Float
    {
        return linearDamping
    }

    func setAngularDamping(_ angularDamping: Float)
    {
        self.angularDamping = angularDamping
    }

    func getAngularDamping() -> Float
    {
        return angularDamping
    }

    func setPosition(_ position: float3)
    {
        self.position = position
    }

    func setPosition(_ x: Float,_ y: Float,_ z: Float)
    {
        position.x = x
        position.y = y
        position.z = z
    }

    func getPosition() -> float3
    {
        return position
    }

    func setOrientation(_ orientation: _Quaternion)
    {
        self.orientation = orientation;
        self.orientation.normalise()
    }

    func setOrientation(_ r: Float,_ i: Float,_ j: Float,_ k: Float)
    {
        orientation.r = r
        orientation.i = i
        orientation.j = j
        orientation.k = k
        orientation.normalise()
    }

    func getOrientation(_ orientation: _Quaternion)
    {
        orientation.r = self.orientation.r
        orientation.i = self.orientation.i
        orientation.j = self.orientation.j
        orientation.k = self.orientation.k
    }

    func getOrientation() -> _Quaternion
    {
        return orientation
    }

    /*
    func getOrientation(_ matrix: _Matrix3)
    {
        getOrientation(matrix)
    }*/

    /*
    func getOrientation(matrix: [Float])
    {
        matrix[0] = transformMatrix.data[0]
        matrix[1] = transformMatrix.data[1]
        matrix[2] = transformMatrix.data[2]

        matrix[3] = transformMatrix.data[4]
        matrix[4] = transformMatrix.data[5]
        matrix[5] = transformMatrix.data[6]

        matrix[6] = transformMatrix.data[8]
        matrix[7] = transformMatrix.data[9]
        matrix[8] = transformMatrix.data[10]
    }*/

    func getTransform(_ transform: _Matrix4)
    {
        //memcpy(transform, &transformMatrix.data, sizeof(Matrix4));
        transform.data = transformMatrix.data
    }

    func getTransform() -> [Float]
    {
        //memcpy(matrix, transformMatrix.data, sizeof(real)*12);
        var data = transformMatrix.data
        data[12] = 0
        data[13] = 0
        data[14] = 0
        data[15] = 1
        
        return data
    }
    
    func getGLTransform() -> [Float]
    {
        var matrix = transformMatrix.data

        matrix[0] = transformMatrix.data[0]
        matrix[1] = transformMatrix.data[4]
        matrix[2] = transformMatrix.data[8]
        matrix[3] = 0

        matrix[4] = transformMatrix.data[1]
        matrix[5] = transformMatrix.data[5]
        matrix[6] = transformMatrix.data[9]
        matrix[7] = 0

        matrix[8] = transformMatrix.data[2]
        matrix[9] = transformMatrix.data[6]
        matrix[10] = transformMatrix.data[10]
        matrix[11] = 0

        matrix[12] = transformMatrix.data[3]
        matrix[13] = transformMatrix.data[7]
        matrix[14] = transformMatrix.data[11]
        matrix[15] = 1
        
        return matrix
    }

    func getTransform() -> _Matrix4
    {
        return transformMatrix
    }

    func getPointInLocalSpace(_ point: float3) -> float3
    {
        return transformMatrix.transformInverse(point)
    }

    func getPointInWorldSpace(_ point: float3) -> float3
    {
        return transformMatrix.transform(point)
    }
    
    func getDirectionInLocalSpace(_ direction: float3) -> float3
    {
        return transformMatrix.transformInverseDirection(direction)
    }

    func getDirectionInWorldSpace(_ direction: float3) -> float3
    {
        return transformMatrix.transformDirection(direction)
    }

    func setVelocity(_ velocity: float3)
    {
        self.velocity = velocity
    }

    func setVelocity(_ x: Float,_ y: Float,_ z: Float)
    {
        velocity.x = x
        velocity.y = y
        velocity.z = z
    }

    func getVelocity() -> float3
    {
        return velocity
    }
    
    func addVelocity(_ deltaVelocity: float3)
    {
        velocity += deltaVelocity
    }

    func setRotation(rotation: float3)
    {
        self.rotation = rotation
    }

    func setRotation(_ x: Float,_ y: Float,_ z: Float)
    {
        rotation.x = x
        rotation.y = y
        rotation.z = z
    }
    
    func getRotation() -> float3
    {
        return rotation
    }

    func addRotation(_ deltaRotation: float3)
    {
        rotation += deltaRotation
    }
    
    func getAwake() -> Bool
    {
        return isAwake;
    }

    func setAwake(_ awake: Bool = true)
    {
        if (awake) {
            isAwake = true

            // Add a bit of motion to avoid it falling asleep immediately.
            motion = RigidBody3D.sleepEpsilon * 2.0
        } else {
            isAwake = false
            velocity = float3(0,0,0)
            rotation = float3(0,0,0)
        }
    }

    func setCanSleep(canSleep: Bool)
    {
        self.canSleep = canSleep

        if !canSleep && !isAwake {
            setAwake()
        }
    }

    func getLastFrameAcceleration() -> float3
    {
        return lastFrameAcceleration
    }

    func clearAccumulators()
    {
        forceAccum = float3(0,0,0)
        torqueAccum = float3(0,0,0)
    }

    func addForce(_ force: float3)
    {
        forceAccum += force
        isAwake = true
    }

    func addForceAtBodyPoint(_ force: float3,_ point: float3)
    {
        // Convert to coordinates relative to center of mass.
        let pt = getPointInWorldSpace(point)
        addForceAtPoint(force, pt)
    }

    func addForceAtPoint(_ force: float3,_ point: float3)
    {
        // Convert to coordinates relative to center of mass.
        var pt = point
        pt -= position

        forceAccum += force
        torqueAccum += cross(pt, force)

        isAwake = true
    }

    func addTorque(_ torque: float3)
    {
        torqueAccum += torque
        isAwake = true
    }

    func setAcceleration(_ acceleration: float3)
    {
        self.acceleration = acceleration
    }

    func setAcceleration(_ x: Float,_ y: Float,_ z: Float)
    {
        acceleration.x = x
        acceleration.y = y
        acceleration.z = z
    }

    func getAcceleration() -> float3
    {
        return acceleration
    }
}
