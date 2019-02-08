//
//  ShapeFactory.swift
//  Shape-Z
//
//  Created by Markus Moenig on 16/1/19.
//  Copyright © 2019 Markus Moenig. All rights reserved.
//

import MetalKit

struct ShapeDefinition
{
    var name            : String = ""
    var distanceCode    : String = ""
    var globalCode      : String = ""
    var properties      : [String:Float] = [:]
    var widthProperty   : String = ""
    var heightProperty  : String = ""
    var pointCount      : Int = 0
    var pointsScale     : Bool = false
}

class ShapeFactory
{
    var shapes          : [ShapeDefinition]

    init()
    {
        shapes = []
        
        let defaultSize : Float = 20
        var def : ShapeDefinition = ShapeDefinition()
        
        
        // --- Box
        def.name = "Box"
        def.distanceCode = "sdBox(__uv__, float2(__width__,__height__) )"
        def.globalCode =
        """
        float sdBox( float2 p, float2 b )
        {
            float2 d = abs(p)-b;
            return length(max(d,float2(0))) + min(max(d.x,d.y),0.0);
        }
        """
        def.properties["width"] = defaultSize
        def.properties["height"] = defaultSize
        def.widthProperty = "width"
        def.heightProperty = "height"
        shapes.append( def )
        
        // --- Disk
        def = ShapeDefinition()
        def.name = "Disk"
        def.distanceCode = "length(__uv__) - __radius__"
        def.properties["radius"] = defaultSize
        def.widthProperty = "radius"
        def.heightProperty = "radius"
        shapes.append( def )
        
        // --- Line
        def = ShapeDefinition()
        def.name = "Line"
        def.distanceCode = "sdLine(__uv__, float2(__point_0_x__,__point_0_y__), float2(__point_1_x__,__point_1_y__), __lineWidth__, 20)"
        def.globalCode =
        """
            float sdLine(float2 uv, float2 pA, float2 pB, float2 thick, float rounded) {
                rounded = min(thick.y, rounded);
                float2 mid = (pB + pA) * 0.5;
                float2 delta = pB - pA;
                float lenD = length(delta);
                float2 unit = delta / lenD;
                if (lenD < 0.0001) unit = float2(1.0, 0.0);
                float2 perp = unit.yx * float2(-1.0, 1.0);
                float dpx = dot(unit, uv - mid);
                float dpy = dot(perp, uv - mid);
                float disty = abs(dpy) - thick.y + rounded;
                float distx = abs(dpx) - lenD * 0.5 - thick.x + rounded;
        
                float dist = length(float2(max(0.0, distx), max(0.0,disty))) - rounded;
                dist = min(dist, max(distx, disty));
        
                return dist;
            }
        """
        def.properties["lineWidth"] = 5
        def.properties["point_0_x"] = -35
        def.properties["point_0_y"] = -35
        def.properties["point_1_x"] = 35
        def.properties["point_1_y"] = 35
        def.widthProperty = "lineWidth"
        def.heightProperty = "lineWidth"
        def.pointCount = 2
        shapes.append( def )
        
        // --- BiCapsule
        def = ShapeDefinition()
        def.name = "Capsule"
        def.distanceCode = "sdBiCapsule(__uv__, float2(__point_0_x__,__point_0_y__), float2(__point_1_x__,__point_1_y__), __radius1__, __radius2__)"
        def.globalCode =
        """
        float sdBiCapsule(float2 pos, float2 a, float2 b, float r1, float r2) {
            float2 ba = b - a;
            float baMagnitude = length(ba);
            float alpha = (dot(pos - a, ba) / dot(ba, ba));
            float2 capsuleSegmentPos = mix(a, b, alpha);
        
            float pointSphereRadius = r1 - r2;
            float exsecantLength = ((baMagnitude / abs(pointSphereRadius)) - 1.0) * baMagnitude;
            float tangentAngle =  acos(1.0 / (exsecantLength + 1.0));
            float tangentOffset = length(capsuleSegmentPos - pos) / tan(tangentAngle);
            tangentOffset *= sign(pointSphereRadius);
        
            float clampedOffsetAlpha = clamp(alpha - tangentOffset, 0.0, 1.0);
            float2 bicapsuleSegmentPos = mix(a, b, clampedOffsetAlpha);
            float bicapsuleRadius = mix(r1, r2, clampedOffsetAlpha);
            return distance(pos, bicapsuleSegmentPos) - bicapsuleRadius;
        }
        """
        def.properties["radius1"] = 15
        def.properties["radius2"] = 5
        def.properties["point_0_x"] = -25
        def.properties["point_0_y"] = -25
        def.properties["point_1_x"] = 25
        def.properties["point_1_y"] = 25
        def.widthProperty = "radius2"
        def.heightProperty = "radius1"
        def.pointCount = 2
        shapes.append( def )
        
        // --- Triangle
        def = ShapeDefinition()
        def.name = "Triangle"
        def.distanceCode = "sdTriangle(__uv__, float2(__point_0_x__,__point_0_y__), float2(__point_1_x__,__point_1_y__), float2(__point_2_x__,__point_2_y__))"
        def.globalCode =
        """
        float sdTriangle( float2 p, float2 p0, float2 p1, float2 p2 )
        {
            float2 e0 = p1-p0, e1 = p2-p1, e2 = p0-p2;
            float2 v0 = p -p0, v1 = p -p1, v2 = p -p2;
        
            float2 pq0 = v0 - e0*clamp( dot(v0,e0)/dot(e0,e0), 0.0, 1.0 );
            float2 pq1 = v1 - e1*clamp( dot(v1,e1)/dot(e1,e1), 0.0, 1.0 );
            float2 pq2 = v2 - e2*clamp( dot(v2,e2)/dot(e2,e2), 0.0, 1.0 );
        
            float s = sign( e0.x*e2.y - e0.y*e2.x );
            float2 d = min(min(float2(dot(pq0,pq0), s*(v0.x*e0.y-v0.y*e0.x)),
            float2(dot(pq1,pq1), s*(v1.x*e1.y-v1.y*e1.x))),
            float2(dot(pq2,pq2), s*(v2.x*e2.y-v2.y*e2.x)));
        
            return -sqrt(d.x)*sign(d.y);
        }
        """
        def.properties["radius1"] = 0
        def.properties["radius2"] = 0
        def.properties["point_0_x"] = 0
        def.properties["point_0_y"] = -35
        def.properties["point_1_x"] = -35
        def.properties["point_1_y"] = 35
        def.properties["point_2_x"] = 35
        def.properties["point_2_y"] = 35
        def.widthProperty = "radius2"
        def.heightProperty = "radius1"
        def.pointCount = 3
        shapes.append( def )
        
        // --- Ellipse
        def = ShapeDefinition()
        def.name = "Ellipse"
        def.distanceCode = "sdEllipse(__uv__, float2(__width__,__height__) )"
        def.globalCode =
        """
        float sdEllipse( float2 p, float2 ab )
        {
            p = abs(p); if( p.x > p.y ) {p=p.yx;ab=ab.yx;}
            float l = ab.y*ab.y - ab.x*ab.x;
        
            float m = ab.x*p.x/l;      float m2 = m*m;
            float n = ab.y*p.y/l;      float n2 = n*n;
            float c = (m2+n2-1.0)/3.0; float c3 = c*c*c;
        
            float q = c3 + m2*n2*2.0;
            float d = c3 + m2*n2;
            float g = m + m*n2;
        
            float co;
            if( d < 0.0 )
            {
            float h = acos(q/c3)/3.0;
            float s = cos(h);
            float t = sin(h)*sqrt(3.0);
            float rx = sqrt( -c*(s + t + 2.0) + m2 );
            float ry = sqrt( -c*(s - t + 2.0) + m2 );
            co = (ry+sign(l)*rx+abs(g)/(rx*ry)- m)/2.0;
            }
            else
            {
            float h = 2.0*m*n*sqrt( d );
            float s = sign(q+h)*pow(abs(q+h), 1.0/3.0);
            float u = sign(q-h)*pow(abs(q-h), 1.0/3.0);
            float rx = -s - u - c*4.0 + 2.0*m2;
            float ry = (s - u)*sqrt(3.0);
            float rm = sqrt( rx*rx + ry*ry );
            co = (ry/sqrt(rm-rx)+2.0*g/rm-m)/2.0;
            }
        
            float2 r = ab * float2(co, sqrt(1.0-co*co));
            return length(r-p) * sign(p.y-r.y);
        }
        """
        def.properties["width"] = 35.00
        def.properties["height"] = 20.00
        def.widthProperty = "width"
        def.heightProperty = "height"
        shapes.append( def )
    }
    
    func createShape(_ name: String, size: Float = 20) -> Shape
    {
        let shape = Shape()
        
        var shapeDef : ShapeDefinition?
        
        for sh in shapes {
            if sh.name == name {
                shapeDef = sh
                break
            }
        }
        
        if let def = shapeDef {
            shape.name = def.name
            shape.distanceCode = def.distanceCode
            shape.globalCode = def.globalCode
            shape.properties = shape.properties.merging(def.properties) { (current, _) in current }
            shape.widthProperty = def.widthProperty
            shape.heightProperty = def.heightProperty
            shape.pointCount = def.pointCount
            shape.pointsScale = def.pointsScale

            for (name,_) in shape.properties {
                if (name == "radius" || name == "width" || name == "height") && shape.name != "Ellipse" {
                    shape.properties[name] = size
                }
            }
        }
        
        return shape
    }
}
