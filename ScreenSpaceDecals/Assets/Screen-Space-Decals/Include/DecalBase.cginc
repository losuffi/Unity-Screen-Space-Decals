#include "UnityCG.cginc"
#include "UnityDeferredLibrary.cginc"
#include "UnityStandardUtils.cginc"
#include "UnityPBSLighting.cginc"
#include "AutoLight.cginc"

//Property
sampler2D _MainTex;
sampler2D _SpecularMap;
sampler2D _NormalMap;
half _Gloss;
half _Roughness;
half _BlendFactor;
half4 _MainColor;
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
};
struct DeferredSource
{
    half4 Albedo;
    half4 RoughnessSpec;
    half4 Normal;
    half4 Emission;
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
    input.oriSpace[0]=mul((half3x3)_Object2World,half3(0,0,1));
    input.oriSpace[1]=mul((half3x3)_Object2World,half3(0,1,0));
    input.oriSpace[2]=mul((half3x3)_Object2World,half3(0,0,1));
    return input;
}
half2 GetDynamicUV(half3 posWorld)
{
    half3 posObj=mul(_World2Object,half4(posWorld,1)).xyz;    
    return posObj.xz+0.5;
}
half2 GetStaticUV(half3 posWorld)
{
    half3 posObj=mul(_World2Object,half4(posWorld,1)).xyz;    
    clip(half3(0.5,0.5,0.5)-abs(posObj.xyz));
    return posObj.xz+0.5;
}
Decal GetDeferredDecal(half3 ray,half4 screenUV)
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
