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
    var dynamicCode     : String? = nil
    var properties      : [String:Float] = [:]
    var widthProperty   : String = ""
    var heightProperty  : String = ""
    
    var pointsVariable  : Bool = false
    var pointCount      : Int = 0
    var pointsScale     : Bool = false

    var supportsRounding: Bool = false
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
        def.supportsRounding = true
        shapes.append( def )
        
        // --- Disk
        def = ShapeDefinition()
        def.name = "Disk"
        def.distanceCode = "(length(__uv__) - __radius__)"
        def.properties["radius"] = defaultSize
        def.widthProperty = "radius"
        def.heightProperty = "radius"
        shapes.append( def )
        
        // --- Line
        def = ShapeDefinition()
        def.name = "Line"
        def.distanceCode = "sdLine(__uv__, float2(__point_0_x__,__point_0_y__), float2(__point_1_x__,__point_1_y__), __lineWidth__)"
        def.globalCode =
        """
        float sdLine( float2 uv, float2 pa, float2 pb, float r) {
            float2 o = uv-pa;
            float2 l = pb-pa;
            float h = clamp( dot(o,l)/dot(l,l), 0.0, 1.0 );
            return -(r-distance(o,l*h));
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
        
        float sdBiCapsule( float2 uv, float2 pa, float2 pb, float ra, float rb) {
            float2 o = uv-pa;
            float2 l = pb-pa;
            float ll = length(l);
            float theta = (ra-rb)/ll;
            float xa = ra*theta;
            float xb = rb*theta;
            float h = dot(o,l)/ll;
            float nc = clamp((h-xa)/(ll-xa+xb),0.0,1.0);
            return -(mix(ra,rb,nc)-distance(o,l*nc));
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
    
        // --- Polygon
        def = ShapeDefinition()
        def.name = "Polygon"
        def.distanceCode = "(sdPolygon__shapeIndex__(__uv__, __pointsVariable__) - __lineWidth__)"
        def.globalCode =
        """
        float sdPolygon_cross2d(float2 v0, float2 v1)
        {
            return v0.x*v1.y - v0.y*v1.x;
        }
        """
        
        def.dynamicCode =
        """
        float sdPolygon__shapeIndex__( float2 p, float2 v[__pointCount__] )
        {
            // https://www.shadertoy.com/view/WdSGRd
            const int num = __pointCount__;
            float d = dot(p-v[0],p-v[0]);
            float s = 1.0;
            for( int i=0, j=num-1; i<num; j=i, i++ )
            {
                // distance
                float2 e = v[j] - v[i];
                float2 w =    p - v[i];
                float2 b = w - e*clamp( dot(w,e)/dot(e,e), 0.0, 1.0 );
                d = min( d, dot(b,b) );
        
                // winding number from http://geomalgorithms.com/a03-_inclusion.html
                //sdPolygon_bvec3 cond = sdPolygon_bvec3( p.y>=v[i].y, p.y<v[j].y, e.x*w.y>e.y*w.x );
                //if( all(cond) || all(not(cond)) ) s*=-1.0;
        
                bool cond1 = p.y>=v[i].y;
                bool cond2 = p.y<v[j].y;
                bool cond3 = e.x*w.y>e.y*w.x;
        
                if( (cond1 && cond2 && cond3) || (!cond1 && !cond2 && !cond3) ) {
                    s*=-1.0;
                }
            }
        
            return s*sqrt(d);
        }
        """
        def.properties["lineWidth"] = 0
        def.properties["point_0_x"] = 20
        def.properties["point_0_y"] = -15
        def.properties["point_1_x"] = -35
        def.properties["point_1_y"] = 35
        def.properties["point_2_x"] = 35
        def.properties["point_2_y"] = 35
        def.widthProperty = "lineWidth"
        def.heightProperty = "lineWidth"
        def.pointCount = 3
        def.pointsVariable = true
        shapes.append( def )
        
        // --- Bezier
        def = ShapeDefinition()
        def.name = "Bezier"
        def.distanceCode = "(udBezier(__uv__, float2(__point_0_x__,__point_0_y__), float2(__point_1_x__,__point_1_y__), float2(__point_2_x__,__point_2_y__)) - __lineWidth__)"
        def.globalCode =
        """
        float udBezier(float2 pos, float2 p0, float2 p1, float2 p2)
        {
            // p(t)    = (1-t)^2*p0 + 2(1-t)t*p1 + t^2*p2
            // p'(t)   = 2*t*(p0-2*p1+p2) + 2*(p1-p0)
            // p'(0)   = 2(p1-p0)
            // p'(1)   = 2(p2-p1)
            // p'(1/2) = 2(p2-p0)
            float2 a = p1 - p0;
            float2 b = p0 - 2.0*p1 + p2;
            float2 c = p0 - pos;
        
            float kk = 1.0 / dot(b,b);
            float kx = kk * dot(a,b);
            float ky = kk * (2.0*dot(a,a)+dot(c,b)) / 3.0;
            float kz = kk * dot(c,a);
        
            float2 res;
        
            float p = ky - kx*kx;
            float p3 = p*p*p;
            float q = kx*(2.0*kx*kx - 3.0*ky) + kz;
            float h = q*q + 4.0*p3;
        
            if(h >= 0.0)
            {
                h = sqrt(h);
                float2 x = (float2(h, -h) - q) / 2.0;
                float2 uv = sign(x)*pow(abs(x), float2(1.0/3.0));
                float t = uv.x + uv.y - kx;
                t = clamp( t, 0.0, 1.0 );
        
                // 1 root
                float2 qos = c + (2.0*a + b*t)*t;
                res = float2( length(qos),t);
            } else {
                float z = sqrt(-p);
                float v = acos( q/(p*z*2.0) ) / 3.0;
                float m = cos(v);
                float n = sin(v)*1.732050808;
                float3 t = float3(m + m, -n - m, n - m) * z - kx;
                t = clamp( t, 0.0, 1.0 );
        
                // 3 roots
                float2 qos = c + (2.0*a + b*t.x)*t.x;
                float dis = dot(qos,qos);
        
                res = float2(dis,t.x);
        
                qos = c + (2.0*a + b*t.y)*t.y;
                dis = dot(qos,qos);
                if( dis<res.x ) res = float2(dis,t.y );
        
                qos = c + (2.0*a + b*t.z)*t.z;
                dis = dot(qos,qos);
                if( dis<res.x ) res = float2(dis,t.z );
        
                res.x = sqrt( res.x );
            }
            return res.x;
        }
        """
        def.properties["lineWidth"] = 5
        def.properties["point_0_x"] = 0
        def.properties["point_0_y"] = -35
        def.properties["point_1_x"] = -35
        def.properties["point_1_y"] = 35
        def.properties["point_2_x"] = 35
        def.properties["point_2_y"] = 35
        def.widthProperty = "lineWidth"
        def.heightProperty = "lineWidth"
        def.pointCount = 3
        shapes.append( def )
        
        // --- Triangle
        def = ShapeDefinition()
        def.name = "Triangle"
        def.distanceCode = "(sdTriangle(__uv__, float2(__point_0_x__,__point_0_y__), float2(__point_1_x__,__point_1_y__), float2(__point_2_x__,__point_2_y__))-__lineWidth__)"
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
        def.properties["lineWidth"] = 0
        def.properties["point_0_x"] = 0
        def.properties["point_0_y"] = -35
        def.properties["point_1_x"] = -35
        def.properties["point_1_y"] = 35
        def.properties["point_2_x"] = 35
        def.properties["point_2_y"] = 35
        def.widthProperty = "lineWidth"
        def.heightProperty = "lineWidth"
        def.pointCount = 3
//        def.supportsRounding = true
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
        
        // --- Cross
        def = ShapeDefinition()
        def.name = "Cross"
        def.distanceCode = "sdCross(__uv__, float2(__width__,__height__), 0.0 )"
        def.globalCode =
        """
        float sdCross( float2 p, float2 b, float r )
        {
            p = abs(p); p = (p.y>p.x) ? p.yx : p.xy;
        
            float2  q = p - b;
            float k = max(q.y,q.x);
            float2  w = (k>0.0) ? q : float2(b.y-p.x,-k);
            return sign(k)*length(max(w,0.0)) + r;
        }
        """
        def.properties["width"] = 35
        def.properties["height"] = 15
        def.widthProperty = "width"
        def.heightProperty = "height"
        def.supportsRounding = true
        shapes.append( def )
        
        // --- Spring
        def = ShapeDefinition()
        def.name = "Spring"
        def.distanceCode = "sdSpring(__uv__, float2(__radius__,__radius__), __custom_stretch__, __custom_spires__, __custom_ratio__, __custom_thickness__ )"
        def.globalCode =
        """
        float sdSpring( float2 uv, float2 size, float stretch, float spires, float ratio, float thickness )
        {
            float2 U = uv / size;
            U = U.yx;
        
            float L = stretch,                   // sprint length
            n = spires,                   // number of spires
            r = ratio,                    // spring radius
            w = thickness;                   // wire radius
            const int N = 8;                     // number of iterations
            const float PI = 3.14159265359;
        
            #define f(x)  ( r * sin(k*(x)) ) // spring equation
            #define df(x) ( x0-(x) + r*k*cos(k*(x))* ( y0 -r*sin(k*(x)) ) )

            #define d(x)  length( float2(x0,y0) - float2( x, f(x) ) ) // distance
        
            float x0 = U.x, y0 = U.y, x=x0, k = 2.*PI*n/L, d;

            x = clamp( x0, -L/2., L/2.);
            float  h = .5, // set to 0 for f(x) = cos()
            xm = ( floor(x*k/PI +h) -h ) *PI/k, // monotonous sin() branch
            xM = (  ceil(x*k/PI +h) -h ) *PI/k; // = range with only one dist extrema
            // ends and beyond requires special care
            xm = max(xm,-L/2.);
            xM = min(xM, L/2.);
            float ym = df(xm), yM = df(xM), y;   // v sign: hack to avoid the extra extrema
            if ( xm ==-L/2. && ym < 0. ) xm=xM, ym= 1., xM+=PI/k, yM=df(xM);
            if ( xM == L/2. && yM > 0. ) xM=xm, yM=-1., xm-=PI/k, ym=df(xm);
            // special case when x is exactly above an extrema
            //if ( yM > 0. ) xM -= .01*PI/k, yM = 1.;  // should be df
            if ( ym < 0. ) xm -= .01*PI/k, ym = 1.;  //-> 1st useless, 2nd = any positive
            // bisection to find distance extrema (i.e. zero of derivative df() )
            for (int i=0; i<N; i++) {
            x = (xm+xM)/2.; y = df(x);
            if ( sign(y)==sign(ym)) xm = x, ym = y;
            else                xM = x, yM = y;
            }
        
            d = d(x);                                   // dist to sine
            d = min( d, d( L/2.) );                     // dist to ends
            d = min( d, d(-L/2.) );
            d -= w;                                     // thickness
        
            return d * size.y;
        }
        """
        def.properties["radius"] = defaultSize
        def.widthProperty = "radius"
        def.heightProperty = "radius"
        def.properties["custom_stretch"] = 1.6
        def.properties["stretch_min"] = 0
        def.properties["stretch_max"] = 5
        def.properties["stretch_int"] = 0
        
        def.properties["custom_spires"] = 5
        def.properties["spires_min"] = 1
        def.properties["spires_max"] = 30
        def.properties["spires_int"] = 1
        
        def.properties["custom_ratio"] = 0.3
        def.properties["ratio_min"] = 0
        def.properties["ratio_max"] = 1
        def.properties["ratio_int"] = 0
        
        def.properties["custom_thickness"] = 0.05
        def.properties["thickness_min"] = 0
        def.properties["thickness_max"] = 1
        def.properties["thickness_int"] = 0
        shapes.append( def )
        
        
        //Optional("a") Optional(245.0) Optional(138.0) Optional(22.0) Optional(27.0)

        // --- Text
        def = ShapeDefinition()
        def.name = "Text"
        def.distanceCode = "sdText(__uv__, float2(__radius__,__radius__), __font_texture__, __text_chars__, __custom_thickness__)"
        def.globalCode =
        """
        float sdText( float2 p, float2 size, texture2d<half, access::sample> texture, thread FontChar *chars, float thickness )
        {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
        
            float2 atlasSize = float2( texture.get_width(), texture.get_height() );
            float d = 100000;
        
            float scale = 60 / size.x;
        
            float xAdvance = 0;
            int index  = 0;
            while(1)
            {
                thread FontChar *text = &chars[index++];

                float2 uv = p / text->charSize * scale;
        
                float2 fontPos = text->charPos;
                float2 fontSize = text->charSize * scale;
        
                uv /= atlasSize / fontSize;
                uv += fontPos / atlasSize + float2( - xAdvance - text->charOffset.x + text->stringInfo.x/4, text->stringInfo.y/2 - text->charOffset.y) / atlasSize;
        
                if (uv.x >= fontPos.x / atlasSize.x && uv.x <= (fontPos.x + fontSize.x / scale) / atlasSize.x && uv.y >= fontPos.y / atlasSize.y && uv.y <= (fontPos.y + fontSize.y / scale) / atlasSize.y)
                {
        
                    const half3 colorSample = texture.sample(textureSampler, uv ).xyz;
        
                    float3 sample = float3( colorSample );// * float3(40 / size.x);
        
                    float dist = max(min(sample.r, sample.g), min(max(sample.r, sample.g), sample.b));// - 0.5;// - 0.5 + 0.3;
                    //dist = clamp(dist, 0.0, 0.9);
                    dist = dist - 0.5 + thickness;
                    //dist *= dot(text->charSize/atlasSize, 0.5/(abs(uv.x/scale)+abs(uv.y/scale)));
        
        
                    dist = 0 - ((dist)*10) / scale;
        
                    d = min(d, dist);

                    //float d = 1.0;//m4mMedian(sample.r, sample.g, sample.b) - 0.5;
                    //float w = clamp(d/fwidth(d) + 0.5, 0.0, 1.0);
                }
        
                xAdvance += text->charAdvance.x;
                if ( text->stringInfo.w == 1 ) break;
            }
        
            return d;
        }
        """
        
        def.properties["radius"] = 60
        def.widthProperty = "radius"
        def.heightProperty = "radius"
        def.supportsRounding = false
        
        def.properties["custom_thickness"] = 0.2
        def.properties["thickness_min"] = 0
        def.properties["thickness_max"] = 0.3
        def.properties["thickness_int"] = 0
        
        shapes.append( def )
        
        // --- Variables
        def = ShapeDefinition()
        def.name = "Variable"
        def.distanceCode = "sdVariable(__uv__, float2(__radius__,__radius__), __font_texture__, __text_chars__, __custom_thickness__)"
        def.globalCode =
        """
        float sdVariable( float2 p, float2 size, texture2d<half, access::sample> texture, thread FontChar *chars, float thickness )
        {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
        
            float2 atlasSize = float2( texture.get_width(), texture.get_height() );
            float d = 100000;
        
            float scale = 60 / size.x;
        
            float xAdvance = 0;
            int index  = 0;
            while(1)
            {
                thread FontChar *text = &chars[index++];
        
                float2 uv = p / text->charSize * scale;
        
                float2 fontPos = text->charPos;
                float2 fontSize = text->charSize * scale;
        
                uv /= atlasSize / fontSize;
                uv += fontPos / atlasSize + float2( - xAdvance - text->charOffset.x + text->stringInfo.x/4, text->stringInfo.y/2 - text->charOffset.y) / atlasSize;
        
                if (uv.x >= fontPos.x / atlasSize.x && uv.x <= (fontPos.x + fontSize.x / scale) / atlasSize.x && uv.y >= fontPos.y / atlasSize.y && uv.y <= (fontPos.y + fontSize.y / scale) / atlasSize.y)
                {
                    const half3 colorSample = texture.sample(textureSampler, uv ).xyz;
        
                    float3 sample = float3( colorSample );// * float3(40 / size.x);
        
                    float dist = max(min(sample.r, sample.g), min(max(sample.r, sample.g), sample.b));// - 0.5 + 0.3;
                    //dist = clamp(dist, 0.0, 0.9);
                    dist = dist - 0.5 + thickness;
        
                    dist = 0 - (dist*10) / scale;
        
                    d = min(d, dist);
        
                    //float d = 1.0;//m4mMedian(sample.r, sample.g, sample.b) - 0.5;
                    //float w = clamp(d/fwidth(d) + 0.5, 0.0, 1.0);
                }
        
                xAdvance += text->charAdvance.x;
                if ( text->stringInfo.w == 1 ) break;
            }
        
            return d;
        }
        
        float sdVariableConstant( float2 p, float2 size, texture2d<half, access::sample> texture, constant FontChar *chars, float thickness )
        {
            constexpr sampler textureSampler(mag_filter::linear, min_filter::linear);
        
            float2 atlasSize = float2( texture.get_width(), texture.get_height() );
            float d = 100000;
        
            float scale = 60 / size.x;
        
            float xAdvance = 0;
            int index  = 0;
            while(1)
            {
                constant FontChar *text = &chars[index++];
        
                float2 uv = p / text->charSize * scale;
        
                float2 fontPos = text->charPos;
                float2 fontSize = text->charSize * scale;
        
                uv /= atlasSize / fontSize;
                uv += fontPos / atlasSize + float2( - xAdvance - text->charOffset.x + text->stringInfo.x/4, text->stringInfo.y/2 - text->charOffset.y) / atlasSize;
        
                if (uv.x >= fontPos.x / atlasSize.x && uv.x <= (fontPos.x + fontSize.x / scale) / atlasSize.x && uv.y >= fontPos.y / atlasSize.y && uv.y <= (fontPos.y + fontSize.y / scale) / atlasSize.y)
                {
                    const half3 colorSample = texture.sample(textureSampler, uv ).xyz;
        
                    float3 sample = float3( colorSample );// * float3(40 / size.x);
        
                    float dist = max(min(sample.r, sample.g), min(max(sample.r, sample.g), sample.b));// - 0.5 + 0.3;
                    //dist = clamp(dist, 0.0, 0.9);
                    dist = dist - 0.5 + thickness;
        
                    dist = 0 - (dist*10) / scale;
        
                    d = min(d, dist);
        
                    //float d = 1.0;//m4mMedian(sample.r, sample.g, sample.b) - 0.5;
                    //float w = clamp(d/fwidth(d) + 0.5, 0.0, 1.0);
                }
        
                xAdvance += text->charAdvance.x;
                if ( text->stringInfo.w == 1 ) break;
            }
        
            return d;
        }
        """
        
        def.properties["radius"] = 60
        def.widthProperty = "radius"
        def.heightProperty = "radius"
        def.supportsRounding = false
        
        def.properties["custom_thickness"] = 0.2
        def.properties["thickness_min"] = 0
        def.properties["thickness_max"] = 0.3
        def.properties["thickness_int"] = 0
        
        def.properties["custom_precision"] = 0
        def.properties["precision_min"] = 0
        def.properties["precision_max"] = 5
        def.properties["precision_int"] = 1
        
        shapes.append( def )
        
        
        // --- Pie
        def = ShapeDefinition()
        def.name = "Pie"
        def.distanceCode = "sdPie(__uv__,__radius__, __custom_angle__ )"
        def.globalCode =
        """
        float sdPie(float2 p, float r, float angle)
        {
            const float PI = 3.14159265359;
            angle = angle * PI / 180;
            float2 c = float2(sin(angle),cos(angle));
            p.x = abs(p.x);
            float l = length(p) - r;
            float m = length(p - c*clamp(dot(p,c),0.0,r) );
            return max(l,m*sign(c.y*p.x-c.x*p.y));
        }
        """
        def.properties["radius"] = defaultSize
        def.widthProperty = "radius"
        def.heightProperty = "radius"
        
        def.properties["custom_angle"] = 45
        def.properties["angle_min"] = 0
        def.properties["angle_max"] = 180
        def.properties["angle_int"] = 0
        
        def.supportsRounding = true;
        shapes.append( def )
        
        // --- Star
        def = ShapeDefinition()
        def.name = "Star"
        def.distanceCode = "sdStar(__uv__,__radius__,__custom_factor__,__custom_sides__)"
        def.globalCode =
        """
        float sdStar(float2 p, float r, float a, float n)
        {
            p = abs(p);
            float m = min(a, 2 * n);
        
            // these 4 lines can be precomputed for a given shape
            float an = 3.141593/float(n);
            float en = 6.283185/m;
            float2  acs = float2(cos(an),sin(an));
            float2  ecs = float2(cos(en),sin(en)); // ecs=vec2(0,1) and simplify, for regular polygon,
        
            // reduce to first sector
            float bn = fmod(atan2(p.x,p.y),2.0*an) - an;
            p = length(p)*float2(cos(bn),abs(sin(bn)));
        
            // line sdf
            p -= r*acs;
            p += ecs*clamp( -dot(p,ecs), 0.0, r*acs.y/ecs.y);

            return length(p)*sign(p.x);
        }
        """
        
        def.properties["custom_factor"] = 6
        def.properties["factor_min"] = 4
        def.properties["factor_max"] = 20
        def.properties["factor_int"] = 0
        
        def.properties["custom_sides"] = 4
        def.properties["sides_min"] = 3
        def.properties["sides_max"] = 20
        def.properties["sides_int"] = 1
        
        /*
        def.properties["custom_angle"] = 4
        def.properties["angle_min"] = 3
        def.properties["angle_max"] = 10
        def.properties["angle_int"] = 0*/
        
        def.properties["radius"] = defaultSize
        def.widthProperty = "radius"
        def.heightProperty = "radius"
        def.supportsRounding = true;
        shapes.append( def )
        
        // --- Horseshoe
        def = ShapeDefinition()
        def.name = "Horseshoe"
        def.distanceCode = "sdHorseshoe(__uv__,__radius__,__custom_angle__,__custom_thickness__,__custom_height__)"
        def.globalCode =
        """
        float sdHorseshoe(float2 p, float r, float cin, float win, float hin )
        {
            float2 c = float2(cos(cin), sin(cin));
            float2 w = float2(hin,win);
        
            w *= r;
        
            p.x = abs(p.x);
            float l = length(p);
            p = float2x2(-c.x, c.y,
            c.y, c.x)*p;
            p = float2((p.y>0.0)?p.x:l*sign(-c.x),
            (p.x>0.0)?p.y:l );
            p = float2(p.x,abs(p.y-r))-w;
            return length(max(p,0.0)) + min(0.0,max(p.x,p.y));
        }
        """
        
        def.properties["custom_angle"] = 1.2
        def.properties["angle_min"] = 0
        def.properties["angle_max"] = 3
        def.properties["angle_int"] = 0
        
        def.properties["custom_thickness"] = 0.5
        def.properties["thickness_min"] = 0
        def.properties["thickness_max"] = 1
        def.properties["thickness_int"] = 0
        
        def.properties["custom_height"] = 0.7
        def.properties["height_min"] = 0
        def.properties["height_max"] = 1
        def.properties["height_int"] = 0
        
        def.properties["radius"] = defaultSize
        def.widthProperty = "radius"
        def.heightProperty = "radius"
        shapes.append( def )
        
        // --- Vesica
        def = ShapeDefinition()
        def.name = "Vesica"
        def.distanceCode = "sdVesica(__uv__,__radius__,__custom_distance__)"
        def.globalCode =
        """
        float sdVesica(float2 p, float r, float d)
        {
            p = abs(p);
            d *= r;

            float b = sqrt(r*r-d*d);  // can delay this sqrt by rewriting the comparison
            return ((p.y-b)*d > p.x*b) ? length(p-float2(0.0,b))
            : length(p-float2(-d,0.0))-r;
        }
        """
        
        def.properties["custom_distance"] = 0.5
        def.properties["distance_min"] = 0
        def.properties["distance_max"] = 1
        def.properties["distance_int"] = 0
        
        def.properties["radius"] = defaultSize
        def.widthProperty = "radius"
        def.heightProperty = "radius"
        shapes.append( def )
    }
    
    /// Create a shape
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
            shape.dynamicCode = def.dynamicCode
            shape.properties = shape.properties.merging(def.properties) { (current, _) in current }
            shape.widthProperty = def.widthProperty
            shape.heightProperty = def.heightProperty
            shape.pointsVariable = def.pointsVariable
            shape.pointCount = def.pointCount
            shape.pointsScale = def.pointsScale
            shape.supportsRounding = def.supportsRounding

            for (name,_) in shape.properties {
                if (name == "radius" || name == "width" || name == "height") && shape.name != "Ellipse" && shape.name != "Cross" && shape.name != "Horseshoe" {
                    shape.properties[name] = size
                }
            }
            
            if shape.name == "Text" {
                shape.customText = "Abc"
            } else
            if shape.name == "Variable" {
                shape.customText = "123"
            }
        }
        shape.updateSize()
        
        return shape
    }
}
