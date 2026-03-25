
#version 430

layout(location=0) uniform float iTime;
layout(location=0) out vec4 nc;
const float FAR = 80.,
            end0 = 48., end1 = 83.8, end2 = 128.;

int mode;
float ktime;
vec3 uvw;

mat2 rot(float a) { float c=cos(a), s=sin(a); return mat2(c,s,-s,c); }

float WNoise(vec3 p) {
    float d=0.,s=1.;
    mat2 mr = rot(.95);

    for(float i=0.; i<5.; i++) {
        vec3 q = p*s, g = fract(floor(q)*vec3(123.34,233.53,314.15));
        g += dot(g, g + 23.234);
        q = fract(q)-.5;
        q.xy *= rot(9.*dot(g,g));
        d += sin(q.x*9.)*smoothstep(.25, .0, dot(q,q))/s;
        p.yx *= mr;
        p.yz *= mr;
        s *= 1.5;
    }
    return .4*d;
}

float fbm(vec3 p){
    return WNoise(p*.6)*.57+WNoise(p*1.2)*.28+WNoise(p*2.4)*.15+.5;
    //p.x*=8.;
    //return .5*(WNoise(p*.2) + WNoise(p.yxz) + 1.);
}

vec2 min2(vec2 a, vec2 b, vec3 u) {
    if (a.x<b.x) return a;
    uvw = u;
    return b;
}

float smin(float a, float b, float k){
    float h = clamp(.5+.5*(b-a)/k,0.,1.);
    return mix(b,a,h)-k*h*(1.-h);
}

float sdBox(vec3 d, vec3 b){
    d = abs(d)-b;
    return length(max(d,0.))+min(max(d.x,max(d.y,d.z)),0.);
}

float sdCaps(vec3 p, vec3 a, vec3 b){
    b-=a; p-=a;
    float k = clamp(dot(p,b)/dot(b,b), 0., 1.);
    return length(p - b*k) + abs(.01*cos(40.*k))-.02*cos(1.5+6.*k);
}

float sdCyl(vec3 p, float d, float h){
    vec2 e = vec2(length(p.xz)-d, abs(p.y)-h);
    return min(max(e.x,e.y),0.)+length(max(e,0.));
}

float limb(vec3 p, vec3 p1, vec3 p2){
    return min(min(length(p),length(p-p1))-.2, min(sdCaps(p,vec3(0),p1), sdCaps(p,p1,p2)-.01)-.15);
}

vec2 map(vec3 p00){
   
    vec3 pb0, pb = p00, pw = pb;

    uvw = pb;

    bool m0 = mode == 0, s1 = mode==2 && iTime>end2-6.;
    float t = iTime- (s1 ? end2-3.:end1-.4),
    
      cy = fract(.3*t),
      r  = m0 ? 0. : (.7*cos(.1*t)-.84)*sin(6.28*cy),
      k  = m0 ? 0. : smoothstep(7.5,2.5, abs(20.*cy-9.)),
      a  = -r-.1-.4*k,
      b  = -r-2.1*k-.4,
      c  = m0 ? 1.57 : b+1.8,
      e  = -.8-1.1*k,
      f  = .3+1.4*k,
      d  = FAR, dc = d;

    if (mode == 1) {
        // boules et cube
        a = 2.*smoothstep(-1.,1.,cos(3.14*iTime))-1.;
        pb = p00 - vec3(0,5,0);
        pb.xy *= rot(a);
        pb += vec3(0,6.6,0);
        pb.xz *= rot(iTime+a);
        uvw = pb;

        d = mod(iTime+.5,4.)>1. ? sdBox(pb,vec3(1.2))-.5 : length(pb)-2.2;
        if (mod(iTime+.5,12.)>6.) {
            p00 -= vec3(0,6.6,0);
            p00.yx *= rot(a);
            p00 += vec3(0,8.3,0);
            p00.xz *= rot(iTime-a);
            d = smin(d, length(p00) - 1., .5);
        }
        return vec2(d, 5);
    }

    if (m0) {
        pb.x += ktime;
        pb0 = pb;
        pb.xz -= vec2(4,8)*round(pb.xz/vec2(4,8));
        pw.xz -= 8.*round(pw.xz/8.);
        pw = pw.xzy - vec3(0,-2,0);
    }

    vec3 p2r = 9.*vec3(0,-cos(r),sin(r)),
         p0  = pw - p2r - vec3(0,10,.3),
         p   = p0 + vec3(0,.7,0);

    p.yz *= rot(c);

    vec2 r1 = vec2(d);

    if (m0) {
        r1 = min2(vec2(p.y+1.9,3), vec2(sdBox(p-vec3(0,.5,-2),vec3(6,.01*abs(cos(44.*(pb0.x+pb0.z))),1))-.1, 4), pb0); // sol, table
        r1 = min2(r1, vec2(sdBox(pb-vec3(.5,1.4,.35),vec3(.4))-.1, 5), pb);              // boite
        r1 = min2(r1, vec2(length(pb-vec3(-.85,1.5,.35))-.6, 6), pb);                     // sphere
        e = cos(pow(cos(iTime),3.)+sign(p.x)); // mouvement des bras
    }

    // corps
    d = max(sdBox(p-vec3(0,.7,0),vec3(.4,.5,0))-.4, -p.y-.5);

    // bras (symétrie)
    p.x = abs(p.x);
    p -= vec3(.8,1.2,.2);

    vec3 p2 = vec3(.4,sin(e),-cos(e)),
         p3 = p2 + vec3(.7*k-.4,sin(f),-cos(f));

    d = min(d, limb(p, p2, p3));

    // main → world (pour cordes)
    vec3 p3w = p3 + vec3(.8,1.2,.2);
    p3w.yz *= rot(-c);
    p3w += vec3(0,9.3,.3);  // corde droite sans p2r ! :)
    if (!s1) p3w += p2r;
    pw.x = abs(pw.x);

    // tête
    p -= vec3(-.8,1.,-.3);
    p.yz *= rot(a+r);

    float dh = max(sdCyl(p,.4,1.)-.4, -p.y-.5);
    dh = min(dh, length(p-vec3(0,1.2,0))-.4);
    p.x = abs(p.x);
    
    d = min(d, max(dh, -length(p-vec3(.22,.4,-.5))+.32));

    // hanches
    d = min(d, sdCyl(p0.zxy-vec3(0,0,-.8),.1,.5)-.2);

    // jambes (symétrie)
    p = p0;
    p.x = abs(p.x)-.4;
    p.y += .8;
    p2 = vec3(0,sin(a),-cos(a));
    p3 = p2 + .8*vec3(-.1,sin(b),-cos(b));

    d = min(d, limb(p, p2, p3));

    // pieds
    p -= p3;
    p.yz *= rot(m0 ? 3. : -r + 2.5 - 2.*k + .2*(p0.x>0.?-k:k));

    d = min(d, max(sdCyl(p-vec3(0,-.3,0),0.,.3)-.25, p.z-.13));

    if (!m0) { // balancoire
        // corde main → haut
        dc = sdCaps(pw, p3w, vec3(1.5,9,0))-.05;
        // cordes planche → main
        p = vec3(1.3,-.25,0);
        p.yz *= rot(-c);
        p += p2r + vec3(0,9,.4);
        dc = min(dc, sdCaps(pw, p3w, p)-.05);

        // planche
        p = pw - p;
        p.yz *= rot(a);
        dc = min(dc, sdBox(p-vec3(-1.5,.2*k-.1,0), vec3(1.7,.1,.4)));
    }
    
    // main
    pw -= p3w;
    pw.yz *= rot(1.+1.5*a);

    d = smin(d, sdBox(pw-vec3(.03,.15,-.05), vec3(.02,.15,.2))-.05, .1);

    if (iTime < end2-10.5 || length(p00-vec3(0,1,-1)) > 6.)
        r1 = min2(r1, vec2(d,1), p0); // personnage visible
 
    return abs(iTime-end2+8.25)<2.25 ? vec2(FAR) : min2(r1, vec2(dc,2), p);

}

float fade(float t) {
    return smoothstep(0., 2., abs(iTime - t));
}

void main() {
    vec2 R  = vec2(2560, 1440) /*vec2(1920, 1080)*/, uv = (2.*gl_FragCoord.xy-R)/R.y;

    ktime = 1.5 + floor(iTime / 1.57) - .5*cos(mod(2.*iTime, 3.14));

    mode = iTime < end0 ? 0 
         : iTime < end1 ? 1
         : iTime < end2 ? 2 : 0;

    bool m0 = mode == 0, m1 = mode == 1, m2 = mode==2;

 // -- Camera -------------------------

    float a = m1 ? (mod(iTime+.5,48.)>24.? mod(iTime+.5,32.) : 3.14)
                 : (m0 ? .1 : .02)*iTime;

    if (iTime<end0) a+=2.;

    vec3 ta = iTime < 24. ? vec3(4,0,.5) : vec3(0,0,0),
         ro = iTime < 24. ? vec3(4,6.*max(ktime-10.,0.),.5) : 15.*vec3(sin(a), .1, cos(a));


    if (m0) ro.y += 4.;
    if (m2) ta.y = 2.2;
    if (m0 && iTime > 40. &&  iTime < end2) {
        ta = vec3(0,2.7,-2); 
        ro = vec3(0,2.7, 29. - .625*iTime);
    }

    vec3 cw = normalize(ta-ro),
         cu = normalize(cross(cw, vec3(0,.99,.01))),
         cv = cross(cu, cw);

    if (iTime < 24.) uv *= rot(.2*ktime);

    vec3 rd = mat3(cu,cv,cw) * normalize(vec3(uv, 2.5)),

// -- Colors ---------------------------
         col = vec3(1,.2,.4),
         bg  = (m0 ? .05 : .3)*vec3(2,3,3);

    if (m1) {
        float phase = mod(iTime+.5, 16.);
        if (phase < 4.) { col = vec3(0); bg = vec3(1); }
        else if (phase > 8. && uv.x > 0.) { vec3 tmp=col; col=bg; bg=tmp; }
    }

// -- Ray marching ----------------------

    float tmin = FAR, t = 0., d;

    for(int i=0; i<200 && (d=map(ro+rd*t).x)>.001*(1.+t*.05) && t<FAR; i++)
        t += .7*d;
    
// -- Shading ---------------------------
    a = length(sin(rd*3.5)*.4+.6)/1.73;
    vec3 back = bg * a + 2.*pow(a, 10.);
    
    if (t < FAR) {

        ro += rd*t;

        vec2 mp = map(ro),
            e = vec2(1,-1)*.001;

        vec3 n = normalize(e.xyy*map(ro+e.xyy).x+e.yyx*map(ro+e.yyx).x+e.yxy*map(ro+e.yxy).x+e.xxx*map(ro+e.xxx).x),
             c = vec3(0),
             r;
             
        e = vec2(.187, 0);

        float mm = mp.y, dn = mp.x, 
            crv = (map(ro+e.xyy)+map(ro-e.xyy)+map(ro+e.yxy)+map(ro-e.yxy)+map(ro+e.yyx)+map(ro-e.yyx) - 3.*dn).x*32. + .5,
            tex = fbm(1.2*uvw),
            hr, sca = 4., occ = 0.;

        for(float hr=.06; hr<.36; hr+=.06) {
            occ += (hr - map(ro + hr*n).x)*sca;
            sca *= .75;
        }

        c = m1 ? mod(iTime+.5,32.)>26. && uvw.x>0. ? bg : col :
            mm == 1.? c + .045 * crv * fbm(ro*128.) :
            mm== 4. ? c + .7 + .3*tex : 
            mm== 3. ? c + .05 + .1*mod(floor(ro.x)+floor(ro.z), 2.) :
            mm== 5. ? c : col;

        if (mm == 1.) n = normalize(n-8.*WNoise(vec3(8,1,4)*cross(n,ro))*smoothstep(0.,4.,.045*crv));
        if (mm < 4.) c *= fbm(ro*64.)*.75 + .5;
        
        r = reflect(rd,n);
        col = (.3+.7*clamp(1. - occ, 0., 1.))*(c*(mix(length(sin(n*2.)*.5+.5)/1.73, smoothstep(-.1,.1, map(ro-rd*.15).x), .7)+.1) + .5*pow(length(sin(r*4.)*.5+.5)/1.73, mm!=1.?7.*tex:10.)*
                (1.-pow(dot(rd,n),2.)));

        if (!m1 && mm == 1.) {
            // envMap
            float ce = smoothstep(.25,1.,fbm(r));
            r = vec3(ce,ce*ce,ce*ce*ce);
            col += 8.*col*mix(r,r.zyx,WNoise(r*.6)+.75);
        }

        // fog
        if (m0) col = mix(col, back, .3+.7*smoothstep(.3,1.1, t/FAR));
        if (m2 && mm<3.) col *= smoothstep(0.,2.,iTime-end1-15.);

    } else {
        col = back;
    }

    nc.rgb = pow(col,vec3(.47))* 
   // pow((1.-uv.x*uv.x*R.y*R.y/R.x/R.x)*(1.-uv.y*uv.y),m1?.4:.1)*
        fade(0.)*fade(24.)*fade(40.)*fade(end0)*fade(end1)*fade(end2-6.)*fade(end2)*smoothstep(4., 0., iTime-end2-13.);

}