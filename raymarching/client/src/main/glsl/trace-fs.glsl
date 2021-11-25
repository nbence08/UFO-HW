#version 300 es 
precision highp float;
precision highp sampler3D;

uniform struct {
  vec3 position;
  mat4 rayDirMatrix;
  mat4 viewMatrix;
} camera;

uniform struct {
  sampler3D volumeTexture;
  sampler2D matcapTexture;
  float mode;
  float threshold;
} scene;

in vec2 tex;
in vec4 rayDir;

out vec4 fragmentColor;

const float epsilon = 0.001f;

float getIntensity(vec3 pos){
  return texture(scene.volumeTexture, vec3(pos.x, pos.y, pos.z)).r;
}


vec3 top = vec3(1.0, 1.0, 1.0);
vec3 bottom = vec3(0.0, 0.0, 0.0);

bool rayBoxIntersect(vec3 rayStart, vec3 rayDir, out float tmin, out float tmax){
  tmin = -1000.0;
  tmax = 1000.0;


  vec3 rayDirInv = 1.0/rayDir;
  vec3 topTs = (top - rayStart) * rayDirInv;
  vec3 bottomTs = (bottom - rayStart) * rayDirInv;

  tmin = max(tmin, min(topTs.x, bottomTs.x));
  tmin = max(tmin, min(topTs.y, bottomTs.y));
  tmin = max(tmin, min(topTs.z, bottomTs.z));
  
  tmax = min(tmax, max(topTs.x, bottomTs.x));
  tmax = min(tmax, max(topTs.y, bottomTs.y));
  tmax = min(tmax, max(topTs.z, bottomTs.z));

  return tmax >= tmin;
}

vec3 calcNormal(vec3 pos, float intensity){
  float diff = 0.0005;
  float dx = -getIntensity(pos + vec3(diff, 0.0, 0.0)) + getIntensity(pos - vec3(diff, 0.0, 0.0));
  float dy = -getIntensity(pos + vec3(0.0, diff, 0.0)) + getIntensity(pos - vec3(0.0, diff, 0.0));
  float dz = -getIntensity(pos + vec3(0.0, 0.0, diff)) + getIntensity(pos - vec3(0.0, 0.0, diff));
  vec3 normal = normalize(vec3(dx, dy, dz));
  return normal;
}

bool tryShadow(vec3 e, vec3 lightDir, float intensity, vec3 normal, out vec3 fragmentAdd){
  //can be made better by raising limit and lowering shadowStep
  int limit = 20;
  vec3 shadowPos = e;
  shadowPos += 0.04*lightDir;
  float shadowStep = 0.02f;
  for(int j = 0; j < limit; j++){
    if(getIntensity(shadowPos) > (intensity + epsilon)){
      float lightingIntensity = (dot(normal, -lightDir) + 1.0)/2.0 - 0.85;
      fragmentAdd = vec3(lightingIntensity, lightingIntensity, lightingIntensity); //ambient lighting
      return true;
    }
    shadowPos += shadowStep*lightDir;
  }
}

float step = 0.04f;
vec3 lightDir = normalize(vec3(1.0, 0.0, 0.0));
vec3 ambient = vec3(0.075f, 0.075f, 0.075f);
float layers = 5.0;

vec3 gasProperty = vec3(1.5, 0.2, -0.1);

void main(void) {
  float threshold = scene.threshold;
  vec4 e = vec4(camera.position, 1.0);
  vec4 d = vec4(normalize(rayDir.xyz), 0.0);
  float intensity = 0.0;
  float sign = 1.0;
  
  float t0, t1;
  fragmentColor = vec4(0.0, 0.0, 0.0, 1.0);

  if(1.0 < scene.mode && scene.mode < 2.0){
        fragmentColor.xyz += vec3(0.5, 0.6, 0.7);
  }

  float layerDiff = threshold/layers;
  float currLayer = layerDiff;
  int layerCount = 0;
  
  float t = 0.0;
  if(rayBoxIntersect(e.xyz, d.xyz, t0, t1)){
    //only jump to edge of bounding box if outside of bounding box
    if(e.x > top.x || e.y > top.y || e.z > top.z 
      || e.x < bottom.x || e.y < bottom.y || e.z < bottom.z ){
      e += d*t0;
      t += t0;
    }

    for(int i = 0; i < 40; i++){
      //layer mode
      if(2.0 < scene.mode && scene.mode < 3.0){
        if(intensity > currLayer){
          vec3 normal = calcNormal(e.xyz, intensity);
          vec3 viewDir = -d.xyz;
          float opacity = 1.0 - 0.9*clamp(dot(viewDir, normal), 0.0, 1.0);

      if(layerCount % 3 == 0) fragmentColor.xyz += opacity * vec3(currLayer, 0.0, 0.0);
      else if(layerCount % 3 == 1) fragmentColor.xyz += opacity * vec3(0.0, currLayer, 0.0);
      else fragmentColor.xyz += opacity * vec3(0.0, 0.0, currLayer);
      layerCount++;
          currLayer += layerDiff;

          if(abs(currLayer - threshold) < epsilon) return;
        }
      }

      //cloud mode
      if(1.0 < scene.mode && scene.mode < 2.0){

        fragmentColor.xyz += step*intensity*gasProperty;

      }

      //basic and matcap mode
      if((-1.0 < scene.mode && scene.mode < 1.0) || (999.5 < scene.mode && scene.mode < 1000.5)){

        if(intensity > threshold && sign > 0.0){
          sign *= -1.0f;
          step *= 0.1f;
        }
        if(intensity < threshold && sign < 0.0){
          sign *= -1.0f;
          step *= 0.1f;
        }

        if(abs(intensity - threshold) < epsilon){
          intensity = getIntensity(e.xyz);
        
          vec3 normal = calcNormal(e.xyz, intensity);

          if(999.5 < scene.mode && scene.mode < 1000.5){
            fragmentColor = vec4(normal, 1.0);
            return;
          }
          
          if(-1.0 < scene.mode && scene.mode < 0.0){
            //MATCAP
            vec2 capCoord = ( 0.5*( vec2(1.0,1.0)+(camera.viewMatrix * vec4(normal, 0.0)).xy));
            fragmentColor = texture(scene.matcapTexture, capCoord);
            return;
          }
          else if(0.0 < scene.mode && scene.mode < 1.0){
          //shadow calculation
            vec3 fragmentAdd;
            if(tryShadow(e.xyz, lightDir, intensity, normal, fragmentAdd)) {
              fragmentColor.xyz += fragmentAdd;
              return;
            }
            
          //phong shading
            float lightness = 0.7*clamp((dot(normal, lightDir)), 0.0, 1.0);  //diffuse lighting

            vec3 viewDir = -d.xyz;
            vec3 reflectDir = normalize(reflect(-lightDir, normal));
            float specStrength = pow(max(dot(viewDir, reflectDir), 0.0), 32.0); //specular lighting
            lightness += specStrength;
            fragmentColor += vec4(lightness, lightness, lightness, 1.0);
            return;
          
          }
        }
      }

      e += d*step*sign;
      t += step*sign;
      //if outside of bounding box, return
      if(t > t1) return;

      intensity = getIntensity(e.xyz);
    }
  }
}