//
//  PhysicsMath.swift
//  Shape-Z
//
//  Created by Markus Moenig on 29/7/20.
//  Copyright © 2020 Markus Moenig. All rights reserved.
//

import Foundation

/**
 * Holds a three degree of freedom orientation.
 *
 * Quaternions have
 * several mathematical properties that make them useful for
 * representing orientations, but require four items of data to
 * hold the three degrees of freedom. These four items of data can
 * be viewed as the coefficients of a complex number with three
 * imaginary parts. The mathematics of the quaternion is then
 * defined and is roughly correspondent to the math of 3D
 * rotations. A quaternion is only a valid rotation if it is
 * normalised: i.e. it has a length of 1.
 *
 * @note Angular velocity and acceleration can be correctly
 * represented as vectors. Quaternions are only needed for
 * orientation.
 */

class _Quaternion {
    
    var r                   : Float

    var i                   : Float
    var j                   : Float
    var k                   : Float

    init(_ r: Float = 1,_ i: Float = 0,_ j: Float = 0,_ k: Float = 0)
    {
        self.r = r
        self.i = i
        self.j = j
        self.k = k
    }
    
    /**
     * Normalises the quaternion to unit length, making it a valid
     * orientation quaternion.
     */
    func normalise()
    {
        var d : Float = r*r+i*i+j*j+k*k

        // Check for zero length quaternion, and use the no-rotation
        // quaternion in that case.
        if d < Float.ulpOfOne {
            r = 1
            return
        }

        d = 1.0 / sqrt(d)
        r *= d
        i *= d
        j *= d
        k *= d
    }

    /**
     * Multiplies the quaternion by the given quaternion.
     *
     * @param multiplier The quaternion by which to multiply.
     */
    func multiply(_ multiplier: _Quaternion)
    {
        let q : _Quaternion = self
        r = q.r*multiplier.r - q.i*multiplier.i -
            q.j*multiplier.j - q.k*multiplier.k
        i = q.r*multiplier.i + q.i*multiplier.r +
            q.j*multiplier.k - q.k*multiplier.j
        j = q.r*multiplier.j + q.j*multiplier.r +
            q.k*multiplier.i - q.i*multiplier.k
        k = q.r*multiplier.k + q.k*multiplier.r +
            q.i*multiplier.j - q.j*multiplier.i
    }

    /**
     * Adds the given vector to this, scaled by the given amount.
     * This is used to update the orientation quaternion by a rotation
     * and time.
     *
     * @param vector The vector to add.
     *
     * @param scale The amount of the vector to add.
     */
    func addScaledVector(_ vector: float3,_ scale: Float)
    {
        let q = _Quaternion(0,
            vector.x * scale,
            vector.y * scale,
            vector.z * scale)
        
        q.multiply(self)
        r += q.r * 0.5
        i += q.i * 0.5
        j += q.j * 0.5
        k += q.k * 0.5
    }
    
    func rotateByVector(_ vector: float3)
    {
        let q = _Quaternion(0, vector.x, vector.y, vector.z);
        multiply(q)
    }
}

/**
 * Holds a transform matrix, consisting of a rotation matrix and
 * a position. The matrix has 12 elements, it is assumed that the
 * remaining four are (0,0,0,1); producing a homogenous matrix.
 */

class _Matrix4
{
    /**
     * Holds the transform matrix data in array form.
     */
    
    var data                    : [Float]
    
    /**
     * Creates an identity matrix.
     */
    init()
    {
        data = Array(repeating: 0, count: 12)
        data[0] = 1
        data[5] = 1
        data[10] = 1
    }
    
    /**
     * Sets the matrix to be a diagonal matrix with the given coefficients.
     */
    func setDiagonal(_ a: Float,_ b: Float,_ c: Float)
    {
        data[0] = a
        data[5] = b
        data[10] = c
    }
    
    /**
     * Returns a matrix which is this matrix multiplied by the given
     * other matrix.
     */
    func multiply(_ o: _Matrix4) -> _Matrix4
    {
        let result = _Matrix4()
        result.data[0] = (o.data[0]*data[0]) + (o.data[4]*data[1]) + (o.data[8]*data[2])
        result.data[4] = (o.data[0]*data[4]) + (o.data[4]*data[5]) + (o.data[8]*data[6])
        result.data[8] = (o.data[0]*data[8]) + (o.data[4]*data[9]) + (o.data[8]*data[10])

        result.data[1] = (o.data[1]*data[0]) + (o.data[5]*data[1]) + (o.data[9]*data[2])
        result.data[5] = (o.data[1]*data[4]) + (o.data[5]*data[5]) + (o.data[9]*data[6])
        result.data[9] = (o.data[1]*data[8]) + (o.data[5]*data[9]) + (o.data[9]*data[10])

        result.data[2] = (o.data[2]*data[0]) + (o.data[6]*data[1]) + (o.data[10]*data[2])
        result.data[6] = (o.data[2]*data[4]) + (o.data[6]*data[5]) + (o.data[10]*data[6])
        result.data[10] = (o.data[2]*data[8]) + (o.data[6]*data[9]) + (o.data[10]*data[10])

        result.data[3] = (o.data[3]*data[0]) + (o.data[7]*data[1]) + (o.data[11]*data[2]) + data[3]
        result.data[7] = (o.data[3]*data[4]) + (o.data[7]*data[5]) + (o.data[11]*data[6]) + data[7]
        result.data[11] = (o.data[3]*data[8]) + (o.data[7]*data[9]) + (o.data[11]*data[10]) + data[11]

        return result;
    }
    
    /**
     * Transform the given vector by this matrix.
     *
     * @param vector The vector to transform.
     */
    func multiplyWithVector(_ vector: float3) -> float3
    {
        return float3(
            vector.x * data[0] +
            vector.y * data[1] +
            vector.z * data[2] + data[3],

            vector.x * data[4] +
            vector.y * data[5] +
            vector.z * data[6] + data[7],

            vector.x * data[8] +
            vector.y * data[9] +
            vector.z * data[10] + data[11]
        )
    }
    
    /**
     * Transform the given vector by this matrix.
     *
     * @param vector The vector to transform.
     */
    func transform(_ vector: float3) -> float3
    {
        return multiplyWithVector(vector)
    }
    
    /**
     * Returns the determinant of the matrix.
     */
    func getDeterminant() -> Float
    {
        return -data[8]*data[5]*data[2] +
            data[4]*data[9]*data[2] +
            data[8]*data[1]*data[6] -
            data[0]*data[9]*data[6] -
            data[4]*data[1]*data[10] +
            data[0]*data[5]*data[10]
    }
    
    func setInverse(_ m: _Matrix4)
    {
        // Make sure the determinant is non-zero.
        var det = getDeterminant()
        if det == 0 { return }
        det = 1.0 / det

        data[0] = (-m.data[9]*m.data[6]+m.data[5]*m.data[10])*det
        data[4] = (m.data[8]*m.data[6]-m.data[4]*m.data[10])*det
        data[8] = (-m.data[8]*m.data[5]+m.data[4]*m.data[9])*det

        data[1] = (m.data[9]*m.data[2]-m.data[1]*m.data[10])*det
        data[5] = (-m.data[8]*m.data[2]+m.data[0]*m.data[10])*det
        data[9] = (m.data[8]*m.data[1]-m.data[0]*m.data[9])*det

        data[2] = (-m.data[5]*m.data[2]+m.data[1]*m.data[6])*det
        data[6] = (+m.data[4]*m.data[2]-m.data[0]*m.data[6])*det
        data[10] = (-m.data[4]*m.data[1]+m.data[0]*m.data[5])*det

        data[3] = (m.data[9]*m.data[6]*m.data[3]
                   - m.data[5]*m.data[10]*m.data[3]
                   - m.data[9]*m.data[2]*m.data[7]
                   + m.data[1]*m.data[10]*m.data[7]
                   + m.data[5]*m.data[2]*m.data[11]
                   - m.data[1]*m.data[6]*m.data[11])*det
        data[7] = (-m.data[8]*m.data[6]*m.data[3]
                   + m.data[4]*m.data[10]*m.data[3]
                   + m.data[8]*m.data[2]*m.data[7]
                   - m.data[0]*m.data[10]*m.data[7]
                   - m.data[4]*m.data[2]*m.data[11]
                   + m.data[0]*m.data[6]*m.data[11])*det
        data[11] = (m.data[8]*m.data[5]*m.data[3]
                   - m.data[4]*m.data[9]*m.data[3]
                   - m.data[8]*m.data[1]*m.data[7]
                   + m.data[0]*m.data[9]*m.data[7]
                   + m.data[4]*m.data[1]*m.data[11]
                   - m.data[0]*m.data[5]*m.data[11])*det
    }
    
    /** Returns a new matrix containing the inverse of this matrix. */
    func inverse() -> _Matrix4
    {
        let result = _Matrix4()
        result.setInverse(self)
        return result
    }
    
    /**
     * Inverts the matrix.
     */
    func invert()
    {
        setInverse(self)
    }
    
    /**
     * Transform the given direction vector by this matrix.
     *
     * @note When a direction is converted between frames of
     * reference, there is no translation required.
     *
     * @param vector The vector to transform.
     */
    func transformDirection(_ vector: float3) -> float3
    {
        return float3(
            vector.x * data[0] +
            vector.y * data[1] +
            vector.z * data[2],

            vector.x * data[4] +
            vector.y * data[5] +
            vector.z * data[6],

            vector.x * data[8] +
            vector.y * data[9] +
            vector.z * data[10]
        )
    }
    
    /**
     * Transform the given direction vector by the
     * transformational inverse of this matrix.
     *
     * @note This function relies on the fact that the inverse of
     * a pure rotation matrix is its transpose. It separates the
     * translational and rotation components, transposes the
     * rotation, and multiplies out. If the matrix is not a
     * scale and shear free transform matrix, then this function
     * will not give correct results.
     *
     * @note When a direction is converted between frames of
     * reference, there is no translation required.
     *
     * @param vector The vector to transform.
     */
    func transformInverseDirection(_ vector: float3) -> float3
    {
        return float3(
            vector.x * data[0] +
            vector.y * data[4] +
            vector.z * data[8],

            vector.x * data[1] +
            vector.y * data[5] +
            vector.z * data[9],

            vector.x * data[2] +
            vector.y * data[6] +
            vector.z * data[10]
        )
    }
    
    /**
     * Transform the given vector by the transformational inverse
     * of this matrix.
     *
     * @note This function relies on the fact that the inverse of
     * a pure rotation matrix is its transpose. It separates the
     * translational and rotation components, transposes the
     * rotation, and multiplies out. If the matrix is not a
     * scale and shear free transform matrix, then this function
     * will not give correct results.
     *
     * @param vector The vector to transform.
     */
    func transformInverse(_ vector: float3) -> float3
    {
        var tmp = vector
        tmp.x -= data[3]
        tmp.y -= data[7]
        tmp.z -= data[11]
        return float3(
            tmp.x * data[0] +
            tmp.y * data[4] +
            tmp.z * data[8],

            tmp.x * data[1] +
            tmp.y * data[5] +
            tmp.z * data[9],

            tmp.x * data[2] +
            tmp.y * data[6] +
            tmp.z * data[10]
        )
    }
    
    /**
     * Gets a vector representing one axis (i.e. one column) in the matrix.
     *
     * @param i The row to return. Row 3 corresponds to the position
     * of the transform matrix.
     *
     * @return The vector.
     */
    func getAxisVector(_ i: Int) -> float3
    {
        return float3(data[i], data[i+4], data[i+8])
    }
    
    /**
     * Sets this matrix to be the rotation matrix corresponding to
     * the given quaternion.
     */
    func setOrientationAndPos(_ q: _Quaternion,_ pos: float3)
    {
        data[0] = 1 - (2*q.j*q.j + 2*q.k*q.k)
        data[1] = 2*q.i*q.j + 2*q.k*q.r
        data[2] = 2*q.i*q.k - 2*q.j*q.r
        data[3] = pos.x

        data[4] = 2*q.i*q.j - 2*q.k*q.r
        data[5] = 1 - (2*q.i*q.i  + 2*q.k*q.k)
        data[6] = 2*q.j*q.k + 2*q.i*q.r
        data[7] = pos.y

        data[8] = 2*q.i*q.k + 2*q.j*q.r
        data[9] = 2*q.j*q.k - 2*q.i*q.r
        data[10] = 1 - (2*q.i*q.i  + 2*q.j*q.j)
        data[11] = pos.z
    }
    
    /**
     * Fills the given array with this transform matrix, so it is
     * usable as an open-gl transform matrix. OpenGL uses a column
     * major format, so that the values are transposed as they are
     * written.
     */
    func fillGLArray(_ a: [Float])
    {
        var array = a
        array[0] = data[0]
        array[1] = data[4]
        array[2] = data[8]
        array[3] = 0

        array[4] = data[1]
        array[5] = data[5]
        array[6] = data[9]
        array[7] = 0

        array[8] = data[2]
        array[9] = data[6]
        array[10] = data[10]
        array[11] = 0

        array[12] = data[3]
        array[13] = data[7]
        array[14] = data[11]
        array[15] = 1
    }
    
    func row(_ row: Int) -> float4
    {
        return float4(
            data[row*4],
            data[row*4+1],
            data[row*4+2],
            data[row*4+3]
        )
    }
    
    func extractEulerAngleXYZ() -> float3
    {
        var rotXangle : Float = 0
        var rotYangle : Float = 0
        var rotZangle : Float = 0

        rotXangle = atan2(-row(1).z, row(2).z)
        let cosYangle = sqrt(pow(row(0).x, 2) + pow(row(0).y, 2))
        rotYangle = atan2(row(0).z, cosYangle)
        let sinXangle = sin(rotXangle)
        let cosXangle = cos(rotXangle)
        rotZangle = atan2(cosXangle * row(1).x + sinXangle * row(2).x, cosXangle * row(1).y + sinXangle * row(2).y)
        return float3(rotXangle, rotYangle, rotZangle)
    }
}

/**
 * Holds an inertia tensor, consisting of a 3x3 row-major matrix.
 * This matrix is not padding to produce an aligned structure, since
 * it is most commonly used with a mass (single real) and two
 * damping coefficients to make the 12-element characteristics array
 * of a rigid body.
 */
class _Matrix3
{
    /**
     * Holds the tensor matrix data in array form.
     */
    
    var data                    : [Float]
    
    /**
     * Creates an identity matrix.
     */
    init()
    {
        data = Array(repeating: 0, count: 9)
    }
    
    /**
     * Creates a new matrix with the given three vectors making
     * up its columns.
     */
    init(_ compOne: float3,_ compTwo: float3,_ compThree: float3)
    {
        data = Array(repeating: 0, count: 9)
        setComponents(compOne, compTwo, compThree)
    }
    
    /**
     * Creates a new matrix with explicit coefficients.
     */
    init(_ c0: Float,_ c1: Float,_ c2: Float,_ c3: Float,_ c4: Float,_ c5: Float,
         _ c6: Float,_ c7: Float,_ c8: Float)
    {
        data = Array(repeating: 0, count: 9)

        data[0] = c0; data[1] = c1; data[2] = c2
        data[3] = c3; data[4] = c4; data[5] = c5
        data[6] = c6; data[7] = c7; data[8] = c8
    }
    
    /**
     * Sets the matrix to be a diagonal matrix with the given
     * values along the leading diagonal.
     */
    func setDiagonal(_ a: Float,_ b: Float,_ c: Float)
    {
        setInertiaTensorCoeffs(a, b, c)
    }
    
    /**
     * Sets the value of the matrix from inertia tensor values.
     */
    func setInertiaTensorCoeffs(_ ix: Float,_ iy: Float,_ iz: Float, ixy: Float = 0, ixz: Float = 0, iyz: Float = 0)
    {
        data[0] = ix
        data[1] = -ixy; data[3] = -ixy
        data[2] = -ixz; data[6] = -ixz
        data[4] = iy
        data[5] = -ixz; data[7] = -iyz
        data[8] = iz
    }
    
    /**
     * Sets the value of the matrix as an inertia tensor of
     * a rectangular block aligned with the body's coordinate
     * system with the given axis half-sizes and mass.
     */
    func setBlockInertiaTensor(_ halfSizes: float3,_ mass: Float)
    {
        let squares : float3 = halfSizes * halfSizes
        
        setInertiaTensorCoeffs(0.3 * mass*(squares.y + squares.z),
            0.3 * mass*(squares.x + squares.z),
            0.3 * mass*(squares.x + squares.y))
    }
    
    /**
     * Sets the matrix to be a skew symmetric matrix based on
     * the given vector. The skew symmetric matrix is the equivalent
     * of the vector product. So if a,b are vectors. a x b = A_s b
     * where A_s is the skew symmetric form of a.
     */
    func setSkewSymmetric(_ vector: float3)
    {
        data[0] = 0
        data[4] = 0
        data[8] = 0
        data[1] = -vector.z
        data[2] = vector.y
        data[3] = vector.z
        data[5] = -vector.x
        data[6] = -vector.y
        data[7] = vector.x
    }
    
    /**
     * Sets the matrix values from the given three vector components.
     * These are arranged as the three columns of the vector.
     */
    func setComponents(_ compOne: float3,_ compTwo: float3,_ compThree: float3)
    {
        data[0] = compOne.x
        data[1] = compTwo.x
        data[2] = compThree.x
        data[3] = compOne.y
        data[4] = compTwo.y
        data[5] = compThree.y
        data[6] = compOne.z
        data[7] = compTwo.z
        data[8] = compThree.z
    }
    
    /**
     * Transform the given vector by this matrix.
     *
     * @param vector The vector to transform.
     */
    func multiplyVector(_ vector: float3) -> float3
    {
        return float3(
            vector.x * data[0] + vector.y * data[1] + vector.z * data[2],
            vector.x * data[3] + vector.y * data[4] + vector.z * data[5],
            vector.x * data[6] + vector.y * data[7] + vector.z * data[8]
        )
    }
    
    /**
     * Transform the given vector by this matrix.
     *
     * @param vector The vector to transform.
     */
    func transform(_ vector: float3) -> float3
    {
        return multiplyVector(vector)
    }
    
    /**
     * Transform the given vector by the transpose of this matrix.
     *
     * @param vector The vector to transform.
     */
    func transformTranspose(_ vector: float3) -> float3
    {
        return float3(
            vector.x * data[0] + vector.y * data[3] + vector.z * data[6],
            vector.x * data[1] + vector.y * data[4] + vector.z * data[7],
            vector.x * data[2] + vector.y * data[5] + vector.z * data[8]
        )
    }
    
     /**
      * Gets a vector representing one row in the matrix.
      *
      * @param i The row to return.
      */
     func getRowVector(_ i: Int) -> float3
     {
         return float3(data[i*3], data[i*3+1], data[i*3+2])
     }
    
    /**
     * Gets a vector representing one axis (i.e. one column) in the matrix.
     *
     * @param i The row to return.
     *
     * @return The vector.
     */
    func getAxisVector(_ i: Int) -> float3
    {
        return float3(data[i], data[i+3], data[i+6]);
    }
    
    /**
     * Sets the matrix to be the inverse of the given matrix.
     *
     * @param m The matrix to invert and use to set this.
     */
    func setInverse(_ m: _Matrix3)
    {
        let t4 = m.data[0]*m.data[4]
        let t6 = m.data[0]*m.data[5]
        let t8 = m.data[1]*m.data[3]
        let t10 = m.data[2]*m.data[3]
        let t12 = m.data[1]*m.data[6]
        let t14 = m.data[2]*m.data[6]

        // Calculate the determinant
        let t16 = (t4*m.data[8] - t6*m.data[7] - t8*m.data[8] +
                    t10*m.data[7] + t12*m.data[5] - t14*m.data[4])

        // Make sure the determinant is non-zero.
        if t16 == 0.0 { return }
        let t17 = 1 / t16

        data[0] = (m.data[4]*m.data[8]-m.data[5]*m.data[7])*t17
        data[1] = -(m.data[1]*m.data[8]-m.data[2]*m.data[7])*t17
        data[2] = (m.data[1]*m.data[5]-m.data[2]*m.data[4])*t17
        data[3] = -(m.data[3]*m.data[8]-m.data[5]*m.data[6])*t17
        data[4] = (m.data[0]*m.data[8]-t14)*t17
        data[5] = -(t6-t10)*t17
        data[6] = (m.data[3]*m.data[7]-m.data[4]*m.data[6])*t17
        data[7] = -(m.data[0]*m.data[7]-t12)*t17
        data[8] = (t4-t8)*t17
    }
    
    /** Returns a new matrix containing the inverse of this matrix. */
    func inverse() -> _Matrix3
    {
        let result = _Matrix3()
        result.setInverse(self)
        return result
    }

    /**
     * Inverts the matrix.
     */
    func invert()
    {
        setInverse(self)
    }
    
    /**
     * Sets the matrix to be the transpose of the given matrix.
     *
     * @param m The matrix to transpose and use to set this.
     */
    func setTranspose(_ m: _Matrix3)
    {
        data[0] = m.data[0]
        data[1] = m.data[3]
        data[2] = m.data[6]
        data[3] = m.data[1]
        data[4] = m.data[4]
        data[5] = m.data[7]
        data[6] = m.data[2]
        data[7] = m.data[5]
        data[8] = m.data[8]
    }

    /** Returns a new matrix containing the transpose of this matrix. */
    func transpose() -> _Matrix3
    {
        let result = _Matrix3()
        result.setTranspose(self)
        return result
    }

    /**
     * Returns a matrix which is this matrix multiplied by the given
     * other matrix.
     */
    /*
    func multiply(_ o: _Matrix3) -> _Matrix3
    {
        return _Matrix3(
            data[0]*o.data[0] + data[1]*o.data[3] + data[2]*o.data[6],
            data[0]*o.data[1] + data[1]*o.data[4] + data[2]*o.data[7],
            data[0]*o.data[2] + data[1]*o.data[5] + data[2]*o.data[8],

            data[3]*o.data[0] + data[4]*o.data[3] + data[5]*o.data[6],
            data[3]*o.data[1] + data[4]*o.data[4] + data[5]*o.data[7],
            data[3]*o.data[2] + data[4]*o.data[5] + data[5]*o.data[8],

            data[6]*o.data[0] + data[7]*o.data[3] + data[8]*o.data[6],
            data[6]*o.data[1] + data[7]*o.data[4] + data[8]*o.data[7],
            data[6]*o.data[2] + data[7]*o.data[5] + data[8]*o.data[8]
        )
    }*/
    
    /**
     * Multiplies this matrix in place by the given other matrix.
     */
    func multiply(_ o: _Matrix3)
    {
        var t1: Float
        var t2: Float
        var t3: Float

        t1 = data[0]*o.data[0] + data[1]*o.data[3] + data[2]*o.data[6]
        t2 = data[0]*o.data[1] + data[1]*o.data[4] + data[2]*o.data[7]
        t3 = data[0]*o.data[2] + data[1]*o.data[5] + data[2]*o.data[8]
        data[0] = t1
        data[1] = t2
        data[2] = t3

        t1 = data[3]*o.data[0] + data[4]*o.data[3] + data[5]*o.data[6]
        t2 = data[3]*o.data[1] + data[4]*o.data[4] + data[5]*o.data[7]
        t3 = data[3]*o.data[2] + data[4]*o.data[5] + data[5]*o.data[8]
        data[3] = t1
        data[4] = t2
        data[5] = t3

        t1 = data[6]*o.data[0] + data[7]*o.data[3] + data[8]*o.data[6]
        t2 = data[6]*o.data[1] + data[7]*o.data[4] + data[8]*o.data[7]
        t3 = data[6]*o.data[2] + data[7]*o.data[5] + data[8]*o.data[8]
        data[6] = t1
        data[7] = t2
        data[8] = t3
    }
    
    /**
     * Multiplies this matrix in place by the given scalar.
     */
    func multiply(_ scalar: Float)
    {
        data[0] *= scalar; data[1] *= scalar; data[2] *= scalar
        data[3] *= scalar; data[4] *= scalar; data[5] *= scalar
        data[6] *= scalar; data[7] *= scalar; data[8] *= scalar
    }

    /**
     * Does a component-wise addition of this matrix and the given
     * matrix.
     */
    func add(_ o: _Matrix3)
    {
        data[0] += o.data[0]; data[1] += o.data[1]; data[2] += o.data[2]
        data[3] += o.data[3]; data[4] += o.data[4]; data[5] += o.data[5]
        data[6] += o.data[6]; data[7] += o.data[7]; data[8] += o.data[8]
    }

    /**
     * Sets this matrix to be the rotation matrix corresponding to
     * the given quaternion.
     */
    func setOrientation(_ q: _Quaternion)
    {
        data[0] = 1 - (2*q.j*q.j + 2*q.k*q.k)
        data[1] = 2*q.i*q.j + 2*q.k*q.r
        data[2] = 2*q.i*q.k - 2*q.j*q.r
        data[3] = 2*q.i*q.j - 2*q.k*q.r
        data[4] = 1 - (2*q.i*q.i  + 2*q.k*q.k)
        data[5] = 2*q.j*q.k + 2*q.i*q.r
        data[6] = 2*q.i*q.k + 2*q.j*q.r
        data[7] = 2*q.j*q.k - 2*q.i*q.r
        data[8] = 1 - (2*q.i*q.i  + 2*q.j*q.j)
    }
    
    /**
     * Interpolates a couple of matrices.
     */
    func linearInterpolate(_ a: _Matrix3,_ b: _Matrix3,_ prop: Float) -> _Matrix3
    {
        let result = _Matrix3()
        for i in 0..<9 {
            result.data[i] = a.data[i] * (1-prop) + b.data[i] * prop
        }
        return result
    }
}

func _transformInertiaTensor(_ iitWorld: _Matrix3,_ q: _Quaternion,_ iitBody: _Matrix3,_ rotmat: _Matrix4)
{
    let t4 = rotmat.data[0]*iitBody.data[0] +
        rotmat.data[1]*iitBody.data[3] +
        rotmat.data[2]*iitBody.data[6]
    let t9 = rotmat.data[0]*iitBody.data[1] +
        rotmat.data[1]*iitBody.data[4] +
        rotmat.data[2]*iitBody.data[7]
    let t14 = rotmat.data[0]*iitBody.data[2] +
        rotmat.data[1]*iitBody.data[5] +
        rotmat.data[2]*iitBody.data[8]
    let t28 = rotmat.data[4]*iitBody.data[0] +
        rotmat.data[5]*iitBody.data[3] +
        rotmat.data[6]*iitBody.data[6]
    let t33 = rotmat.data[4]*iitBody.data[1] +
        rotmat.data[5]*iitBody.data[4] +
        rotmat.data[6]*iitBody.data[7]
    let t38 = rotmat.data[4]*iitBody.data[2] +
        rotmat.data[5]*iitBody.data[5] +
        rotmat.data[6]*iitBody.data[8]
    let t52 = rotmat.data[8]*iitBody.data[0] +
        rotmat.data[9]*iitBody.data[3] +
        rotmat.data[10]*iitBody.data[6]
    let t57 = rotmat.data[8]*iitBody.data[1] +
        rotmat.data[9]*iitBody.data[4] +
        rotmat.data[10]*iitBody.data[7]
    let t62 = rotmat.data[8]*iitBody.data[2] +
        rotmat.data[9]*iitBody.data[5] +
        rotmat.data[10]*iitBody.data[8]

    iitWorld.data[0] = t4*rotmat.data[0] +
        t9*rotmat.data[1] +
        t14*rotmat.data[2]
    iitWorld.data[1] = t4*rotmat.data[4] +
        t9*rotmat.data[5] +
        t14*rotmat.data[6]
    iitWorld.data[2] = t4*rotmat.data[8] +
        t9*rotmat.data[9] +
        t14*rotmat.data[10]
    iitWorld.data[3] = t28*rotmat.data[0] +
        t33*rotmat.data[1] +
        t38*rotmat.data[2]
    iitWorld.data[4] = t28*rotmat.data[4] +
        t33*rotmat.data[5] +
        t38*rotmat.data[6]
    iitWorld.data[5] = t28*rotmat.data[8] +
        t33*rotmat.data[9] +
        t38*rotmat.data[10]
    iitWorld.data[6] = t52*rotmat.data[0] +
        t57*rotmat.data[1] +
        t62*rotmat.data[2]
    iitWorld.data[7] = t52*rotmat.data[4] +
        t57*rotmat.data[5] +
        t62*rotmat.data[6]
    iitWorld.data[8] = t52*rotmat.data[8] +
        t57*rotmat.data[9] +
        t62*rotmat.data[10]
}

func _calculateTransformMatrix(_ transformMatrix : _Matrix4,_ position: float3,_ orientation: _Quaternion)
{
    transformMatrix.data[0] = 1-2*orientation.j*orientation.j -
        2*orientation.k*orientation.k;
    transformMatrix.data[1] = 2*orientation.i*orientation.j -
        2*orientation.r*orientation.k;
    transformMatrix.data[2] = 2*orientation.i*orientation.k +
        2*orientation.r*orientation.j;
    transformMatrix.data[3] = position.x;

    transformMatrix.data[4] = 2*orientation.i*orientation.j +
        2*orientation.r*orientation.k;
    transformMatrix.data[5] = 1-2*orientation.i*orientation.i -
        2*orientation.k*orientation.k;
    transformMatrix.data[6] = 2*orientation.j*orientation.k -
        2*orientation.r*orientation.i;
    transformMatrix.data[7] = position.y;

    transformMatrix.data[8] = 2*orientation.i*orientation.k -
        2*orientation.r*orientation.j;
    transformMatrix.data[9] = 2*orientation.j*orientation.k +
        2*orientation.r*orientation.i;
    transformMatrix.data[10] = 1-2*orientation.i*orientation.i -
        2*orientation.j*orientation.j;
    transformMatrix.data[11] = position.z;
}
