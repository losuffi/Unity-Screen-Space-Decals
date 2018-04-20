#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

//Property
sampler2D _MainTex;
sampler2D _SpecularMap;
sampler2D _NormalMap;
sampler2D _EmissionMap;
half _Cutoff;
half _Gloss;
half _Roughness;
half _BlendFactor;
half _NormalMapScale;
half _NormalFlip;
half _Metallic;
half _Glossiness;
half4 _MainColor;
half4 _EmissionColor;
sampler2D _NormalsCopy;
sampler2D _SpecularCopy;
sampler2D _EmissionsCopy;
sampler2D _DiffuseCopy;

struct VertexOutput
{
    half4 pos : SV_POSITION;
    half2 uv : TEXCOORD0;
    half4 screenUV : TEXCOORD1;
    half3 ray : TEXCOORD2;
    half3 eyeVec:TEXCOORD3;
    half3 oriSpace[3]:TEXCOORD4;
};
struct Decal
{
    half2 screenPos;
    half3 posWorld;
    half2 localUV;
    half depth;
    half3 normal;
    half3 defaultNormal;
};
struct DeferredSource
{
    half4 Albedo;
    half4 RoughnessSpec;
    half4 Normal;
    half4 Emission;
};
struct FragmentCommonData
{
    half occlusion;
    half oneMinusReflectivity;
    half oneMinusRoughness;
    half3 diffuse;
    half3 specular;
    half3 normalWorld;
    half3 eyeVec;
    half3 posWorld;
};

VertexOutput DeferredDecalVert(half4 position:POSITION)
{
    VertexOutput input;
    UNITY_INITIALIZE_OUTPUT(VertexOutput,input);
    input.pos=mul(UNITY_MATRIX_MVP,position);
    input.screenUV=ComputeScreenPos(input.pos);
    input.ray=mul(UNITY_MATRIX_MV,position).xyz*half3(1,1,-1);
    half3 posWorld=mul(_Object2World,position).xyz;
    input.eyeVec=posWorld-_WorldSpaceCameraPos;
    input.oriSpace[0]=mul((half3x3)_Object2World,half3(1,0,0));
    input.oriSpace[1]=mul((half3x3)_Object2World,half3(0,1,0));
    input.oriSpace[2]=mul((half3x3)_Object2World,half3(0,0,1));
    return input;
}
half3 ProjectViewPanel(half3 ObjPos)
{
    half3 viewNormal=mul(_World2Object,_WorldSpaceCameraPos).xyz-half3(0,0,0);
    half3 biViewNormal=normalize(cross(half3(1,0,0),viewNormal));
    half3 tangentNormal=normalize(cross(viewNormal,biViewNormal));
    half3x3 mat=half3x3(tangentNormal,viewNormal,biViewNormal);
    half3 viewPos=mul(mat,ObjPos);
    //clip(half3(0.5,0.5,0.5)-abs(ProjPos.xyz));
    return viewPos;
}
half2 GetDynamicUV(half3 posWorld)
{
    half3 posObj=mul(_World2Object,half4(posWorld,1)).xyz;  
    half3 ProjPos=ProjectViewPanel(posObj);  
    clip(half3(0.5,0.5,0.5)-abs(posObj.xyz));
    return ProjPos.xz+0.5;
}
half2 GetStaticUV(half3 posWorld)
{
    half3 posObj=mul(_World2Object,half4(posWorld,1)).xyz;    
    clip(half3(0.5,0.5,0.5)-abs(posObj.xyz));
    return posObj.xz+0.5;
}
Decal GetDeferredDecal(half3 ray,half4 screenUV,half3 defaultNormal)
{
    Decal output;
    UNITY_INITIALIZE_OUTPUT(Decal,output);
    output.screenPos=screenUV.xy/screenUV.w;
    output.depth=Linear01Depth( SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, output.screenPos));
    half3 posView= ray*(_ProjectionParams.z/ray.z)*output.depth;
    output.posWorld=mul(_CameraToWorld,half4( posView,1));
    #ifdef _DynamicProj
    output.localUV=GetDynamicUV(output.posWorld);
    #else
    output.localUV=GetStaticUV(output.posWorld);
    #endif
    output.normal=tex2D(_NormalsCopy,output.screenPos).rgb*2-1;
    output.defaultNormal=defaultNormal;
    return output;
}

DeferredSource GetSource(half2 screenPos)
{
    DeferredSource output;
    UNITY_INITIALIZE_OUTPUT(DeferredSource,output);
    output.Albedo=tex2D(_DiffuseCopy,screenPos);
    output.RoughnessSpec=tex2D(_SpecularCopy,screenPos);
    output.Normal=tex2D(_NormalsCopy,screenPos);
    output.Emission=tex2D(_EmissionsCopy,screenPos);
    return output;
}

half AlbedoOcclusion(half2 localUV)
{
    half alpha=_MainColor.a;
    alpha*=tex2D(_MainTex,localUV).a;
    clip(alpha-_Cutoff);
    return alpha;
}
half3x3 Tangent2WorldMatrix(half3 y,half3 surfaceNormal)
{
    half3 binormalWorld=normalize(cross(y,surfaceNormal));
    half3 tangentWorld=normalize(cross(surfaceNormal,binormalWorld));
    return half3x3(tangentWorld,binormalWorld,surfaceNormal);
}
half3 NormalWorld(half2 localuv,half3x3 mat,half occlusion)
{
    half3 nor=UnpackNormal(tex2D(_NormalMap,localuv));
    half scale=clamp(_NormalMapScale,0.1,4)*occlusion;
    nor.z/=scale;
    nor=normalize(nor);
    nor.y=lerp(nor.y,-nor.y,_NormalFlip);
    half3 normal=mul(nor,mat);
    normal=normalize(normal);
    return normal;
}
half3 Albedo(half2 localuv)
{
    half3 color=_MainColor.rgb;
    return color*=tex2D(_MainTex,localuv).rgb;
}
half3 EmissionAlpha(half2 localuv)
{
    half4 color=_EmissionColor;
    half4 Emission=tex2D(_EmissionMap,localuv)*color;
    return 1-Emission;
}
half4 EmissionOutput(half4 emission,half occulusion)
{
    #ifdef UNITY_HDR_ON
    emission.rgb=exp2(-emission.rgb);
    #endif;
    return half4(emission.rgb,occulusion);
}
half2 MetaGloss(half2 localuv)
{
    half2 mg=tex2D(_SpecularMap,localuv).ra;
    mg.x*=_Metallic;
    mg.y*=_Glossiness;
    return mg;
}


FragmentCommonData FragmentUnlit(Decal d,half3 r,half3 e)
{
    FragmentCommonData o;
    UNITY_INITIALIZE_OUTPUT(FragmentCommonData,o);
    o.occlusion=AlbedoOcclusion(d.localUV);
    #ifdef OverlayNormal
    half3x3 norMat=Tangent2WorldMatrix(r,d.defaultNormal);
    #else
    half3x3 norMat=Tangent2WorldMatrix(r,d.normal);
    #endif
    o.normalWorld=NormalWorld(d.localUV,norMat,o.occlusion);
    o.eyeVec=normalize(e);
    o.posWorld=d.posWorld;
    o.diffuse=Albedo(d.localUV);
    o.specular=half3(0,0,0);
    o.oneMinusReflectivity=1;
    o.oneMinusRoughness=0;
    return o;
}

inline FragmentCommonData FragmentMetallic(Decal decal,half3 ray,half3 eyeVec)
{
    FragmentCommonData o=FragmentUnlit(decal,ray,eyeVec);
    half2 metallicGloss=MetaGloss(decal.localUV);
    half metallic=metallicGloss.x;
    half oneMinusRoughness=metallicGloss.y;
    half oneMinusReflectivity;
    half3 specular;
    half3 diffuse=DiffuseAndSpecularFromMetallic(Albedo(decal.localUV),metallic,specular,oneMinusReflectivity);
    o.diffuse=diffuse;
    o.specular=specular;
    o.oneMinusReflectivity=oneMinusReflectivity;
    o.oneMinusRoughness=oneMinusRoughness;
    return o;
}

UnityLight DummyLight(half3 normalWorld)
{
    UnityLight l;
    l.color=0;
    l.dir=half3(0,1,0);
    l.ndotl=LambertTerm(normalWorld,l.dir);
    return l;
}

inline UnityGI FragmentGI(FragmentCommonData s,half occlusion,half4 i_ambientOrLightmapUV,half atten,UnityLight light,bool reflections)
{
    UnityGIInput d;
    d.light = light;
    d.worldPos = s.posWorld;
    d.worldViewDir = -s.eyeVec;
    d.atten = atten;
    #if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
        d.ambient = 0;
        d.lightmapUV = i_ambientOrLightmapUV;
    #else
        d.ambient = i_ambientOrLightmapUV.rgb;
        d.lightmapUV = 0;
    #endif

    d.probeHDR[0] = unity_SpecCube0_HDR;
    d.probeHDR[1] = unity_SpecCube1_HDR;
    #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
      d.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
    #endif
    #ifdef UNITY_SPECCUBE_BOX_PROJECTION
      d.boxMax[0] = unity_SpecCube0_BoxMax;
      d.probePosition[0] = unity_SpecCube0_ProbePosition;
      d.boxMax[1] = unity_SpecCube1_BoxMax;
      d.boxMin[1] = unity_SpecCube1_BoxMin;
      d.probePosition[1] = unity_SpecCube1_ProbePosition;
    #endif

    if(reflections)
    {
        Unity_GlossyEnvironmentData g;
        g.roughness=1-s.oneMinusRoughness;
        g.reflUVW=reflect(s.eyeVec,s.normalWorld);
        return UnityGlobalIllumination (d, occlusion, s.normalWorld, g);
    }
    else
    {
        return UnityGlobalIllumination (d, occlusion, s.normalWorld);
    }
}

inline half3 DeferredAmbient(FragmentCommonData frament)
{
    #if UNITY_ENABLE_REFLECTION_BUFFERS
        bool sampleReflectionsInDeferred=false;
    #else
        bool sampleReflectionsInDeferred=true;
    #endif
    UnityLight dummyLight=DummyLight(frament.normalWorld);
    UnityGI gi=FragmentGI(frament,1,0,1,dummyLight,sampleReflectionsInDeferred);
    half3 Ambient=UNITY_BRDF_PBS(frament.diffuse,frament.specular,frament.oneMinusReflectivity,frament.oneMinusRoughness,frament.normalWorld,-frament.eyeVec,gi.light,gi.indirect).rgb;
    Ambient+=UNITY_BRDF_GI(frament.diffuse,frament.specular,frament.oneMinusReflectivity,frament.oneMinusRoughness,frament.normalWorld,-frament.eyeVec,1,gi);
    return Ambient;
}
