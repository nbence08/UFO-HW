#version 300 es 
precision highp float;

uniform struct {
  vec3 position;
  mat4 rayDirMatrix;
} camera;

uniform struct {
  mat4 surface;
  mat4 clipper;
  vec3 ideality;

  vec3 diffuseCoeff;
  vec3 specularCoeff;

  vec3 powerDensity;
  float area;

  vec3 absorb;
} quadrics[7];

uniform struct {
  vec4 position;
  vec3 powerDensity;
} lights[2];

uniform struct {
  samplerCube envTexture;
  vec4 randoms[64];
  vec3 lightRandoms[100];
  sampler2D previousFrameTexture;
  float iFrame;
} scene;


in vec2 tex;
in vec4 rayDir;

out vec4 fragmentColor;

const float PI   = 3.14159265358979323846264; // PI
const float PHIG = 1.61803398874989484820459 * 00000.1; // Golden Ratio   
const float PIG  = 3.14159265358979323846264 * 00000.1; // PI
const float SQ2G = 1.41421356237309504880169 * 10000.0; // Square Root of Two

float goldRand(in vec3 seed){
    return fract(sin(dot(seed.xy*(seed.z+PHIG), vec2(PHIG, PIG)))*SQ2G);
}


float intersectQuadric(vec4 e, vec4 d, mat4 surface, mat4 clipper){
  float a = dot(d * surface, d);
  float b = dot(d * surface, e) + dot(e * surface, d);
  float c = dot(e * surface, e);

  if(abs(a) < 0.001){
  	float t = - c / b;
  	vec4 h = e + d*t;
  	if(dot(h * clipper, h) > 0.0) {
  	  t = -1.0;    
 		}
 		return t;
  }

  float discr = b*b - 4.0*a*c;
  if(discr < 0.0){
    return -1.0;
  }
  float t1 = (-b - sqrt(discr)) / (2.0 * a);
  float t2 = (-b + sqrt(discr)) / (2.0 * a);  

  vec4 h1 = e + d * t1;
  if(dot(h1 * clipper, h1) > 0.0) {
    t1 = -1.0;
  }

  vec4 h2 = e + d * t2;
  if(dot(h2 * clipper, h2) > 0.0) {
    t2 = -1.0;    
  }

  return (t1<0.0)?t2:((t2<0.0)?t1:min(t1, t2));
}

bool findBestHit(vec4 e, vec4 d, out float bestT, out int bestIndex){
  bestT = 1000000.0;
  for(int i=0; i<quadrics.length(); i++){
    float t = intersectQuadric(e, d, quadrics[i].surface, quadrics[i].clipper);
    if(t > 0.0 && t < bestT){
      bestT = t;
      bestIndex = i;
    }
  }
  if(bestT < 999999.0)
    return true;
  else
    return false; 
}

bool findNoEmittanceHit(vec4 e, vec4 d, out float bestT, out int bestIndex){
  int sugIndex;
  float sugT;
  vec4 newEye = e;
  bool ret = findBestHit(e, d, sugT, sugIndex);
  if(!ret) return false;

  while(length(quadrics[sugIndex].powerDensity) > 0.01){
    newEye = newEye + d*sugT + d*0.01;
    ret = findBestHit(newEye, d, sugT, sugIndex);
    
    if(!ret) return false;
  }

  bestT = sugT;
  bestIndex = sugIndex;
  return true;
}

vec3 directLighting(vec3 x, vec3 n, vec3 v, int index){
  //x = hitPoint, n = normal, v = viewDir
	vec3 reflectedRadiance = vec3(0, 0, 0);
	for(int i=0; i<lights.length(); i++){
    vec3 lightPos = lights[i].position.xyz;
    vec3 lightDiff = lightPos - x * lights[i].position.w;
    float lightDist = length(lightDiff);
    vec3 lightDir = lightDiff / lightDist;//normalize(vec3(1, 1, 1));

    vec4 eShadow = vec4(x + n * 0.01, 1);
    vec4 dShadow = vec4(lightDir, 0);    
    float shadowT;
    int shadowIndex;
    if(!findNoEmittanceHit(eShadow, dShadow, shadowT, shadowIndex) ||
           shadowT * lights[i].position.w > lightDist) {
      vec3 lightPowerDensity = lights[i].powerDensity;
      lightPowerDensity /= lightDist * lightDist;
      vec3 diffuseCoeff = quadrics[index].diffuseCoeff;
      vec3 specularCoeff = quadrics[index].specularCoeff;
      float shininess = 15.0;
      float cosa = dot(n, lightDir);
      if(cosa < 0.0) {
        cosa = 0.0;
      } else {
        reflectedRadiance += lightPowerDensity * cosa * diffuseCoeff;

        float cosb = dot(n, v);
        vec3 halfway = normalize(v + lightDir);
        float cosd = dot(halfway, n);
        if(cosd < 0.0)
        	cosd = 0.0;
          // lightPowerDensity * cosa * BRDF
        reflectedRadiance += lightPowerDensity * specularCoeff * 
        	pow(cosd, shininess) * cosa / max(cosa, cosb);
      }
    }
  }
  return reflectedRadiance;
}

vec3 bodiedLighting(vec3 x, vec3 n, vec3 v, int index){
  //x = hitPoint, n = normal, v = viewDir
  vec3 reflectedRadiance = vec3(0, 0, 0);
  float mult = float(scene.lightRandoms.length()) / quadrics[3].area;
  float area = quadrics[3].area;
  float multarea = mult/area;
  for(int i=0; i<scene.lightRandoms.length(); i++){
    vec3 lightPos = scene.lightRandoms[i];

    vec4 gradient = vec4(lightPos, 1.0) * quadrics[3].surface + quadrics[3].surface * vec4(lightPos, 1.0);
    vec3 normal = normalize(gradient.xyz);
    lightPos += normal * 0.01;

    vec3 lightDiff = lightPos - x;
    float lightDist = length(lightDiff);
    vec3 lightDir = lightDiff / lightDist;//normalize(vec3(1, 1, 1));

    vec4 eShadow = vec4(x + n * 0.01, 1);
    vec4 dShadow = vec4(lightDir, 0);    
    float shadowT;
    int shadowIndex;
    if(!findBestHit(eShadow, dShadow, shadowT, shadowIndex) ||
           shadowT > lightDist) {
      vec3 lightPowerDensity = quadrics[3].powerDensity;
      lightPowerDensity /= lightDist * lightDist;
      vec3 diffuseCoeff = quadrics[index].diffuseCoeff;
      vec3 specularCoeff = quadrics[index].specularCoeff;
      float shininess = 15.0;
      float cosa = dot(n, lightDir);
      if(cosa < 0.0) {
        cosa = 0.0;
      } else {
        reflectedRadiance += lightPowerDensity * cosa * diffuseCoeff * multarea;

        float cosb = dot(n, v);
        vec3 halfway = normalize(v + lightDir);
        float cosd = dot(halfway, n);
        if(cosd < 0.0)
          cosd = 0.0;
          // lightPowerDensity * cosa * BRDF
        reflectedRadiance += lightPowerDensity * specularCoeff * 
          pow(cosd, shininess) * cosa / max(cosa, cosb);
      }
    }
  }
  return reflectedRadiance;
}

void main(void) {
  vec4 e = vec4(camera.position, 1);
  vec4 d = vec4(normalize(rayDir.xyz), 0);

  //egyszer a pixelben
  float perPixelNoise = goldRand(vec3(tex * 1024.0, 1.0)) * 6.28318530718;

//    x2 + y2 + z2 - 1 =  0 
//  float bestT = intersectQuadric(e, d, quadrics[0].surface, quadrics[0].clipper);

  fragmentColor = vec4(0,0,0,1);
  vec3 w = vec3(1, 1, 1);

  bool inRefraction = false;
  bool inAbsorbtion = false;
  bool absorbed = false;

  for(int iBounce=0; iBounce<7; iBounce++){
    float t;
    int i;
    bool foundHit;
    if(iBounce == 0 || absorbed){
      //only if directly out of absorber, or first ray
      foundHit = findBestHit(e, d, t, i);
    } else {
      foundHit = findNoEmittanceHit(e, d, t, i);
    }
    
    if(foundHit){
      vec4 hit = e + d * t;
      if((iBounce == 0 || absorbed) && length(quadrics[i].powerDensity) > 0.001){
        //only if directly out of absorber, or first ray
        fragmentColor.rgb = w * quadrics[i].powerDensity;
        absorbed = false;
        break;
      }
      absorbed = false;
      vec4 gradient = hit * quadrics[i].surface + quadrics[i].surface * hit;
      vec3 normal = normalize(gradient.xyz);
      if(dot(normal, d.xyz) > 0.0){
  	    normal = -normal;
  	  }

      //absorption effect (eg. gas)
      if(length(quadrics[i].absorb) > 0.0){
        absorbed = true;
        if(dot(e, quadrics[i].surface * e) < 0.0 && iBounce == 0){
          e.xyz = hit.xyz + normal * 0.0001;
          w *= pow(quadrics[i].absorb, vec3(t, t, t));
          continue;
        }

        if(!inAbsorbtion)
          e.xyz = hit.xyz - normal * 0.0001;
        else {
          e.xyz = hit.xyz + normal * 0.0001;
          w *= pow(quadrics[i].absorb, vec3(t, t, t));
        }
        inAbsorbtion = !inAbsorbtion;
        continue;
      }

      //refraction
      if(quadrics[i].ideality.x < 0.0){
        vec3 newD;
        if(!inRefraction)
          newD = refract(normalize(d.xyz), normalize(normal), -quadrics[i].ideality.x);
        else 
          newD = refract(normalize(d.xyz), normalize(normal), 1.0/(-quadrics[i].ideality.x));

        if(length(newD) < 0.01){
          newD = reflect(d.xyz, normal);
          e.xyz = hit.xyz + normal * 0.0001;
          d.xyz = newD;
          continue;
        }
        
        d.xyz = newD;

        if(!inRefraction)
          e.xyz = hit.xyz - normal * 0.0001;
        else 
          e.xyz = hit.xyz + normal * 0.0001;
        inRefraction = !inRefraction;
        continue;

      }

      //specular and diffuse calculations
  		fragmentColor.rgb += w * directLighting(hit.xyz, normal, -d.xyz, i);
      
      //add bodied light effect
      fragmentColor.rgb += w * bodiedLighting(hit.xyz, normal, -d.xyz, i);
      

      e = hit;
      e.xyz += normal * 0.01;
      vec3 ideal = vec3(0.0, 0.0, 0.0);

      if(length(quadrics[i].ideality) > 0.01){
        ideal = reflect(d.xyz, normal);
      }
      //mirror ray if it is a mirror, else weighted average of the two
      d.xyz = normalize(scene.randoms[iBounce].xyz)*(vec3(1.0,1.0,1.0)-quadrics[i].ideality)
       + ideal * quadrics[i].ideality;

      d.xyz = normalize(normal + d.xyz);
      w *= vec3(0.7, 0.7, 0.75);
    } else {
      fragmentColor.rgb += w * texture ( scene.envTexture, d.xyz).rgb;
      break;
    }
  }
  //averaging frames
  fragmentColor = 
    texture(scene.previousFrameTexture, tex) * (1.0 - 1.0 / scene.iFrame) +
    fragmentColor * 1.0 / scene.iFrame;
}