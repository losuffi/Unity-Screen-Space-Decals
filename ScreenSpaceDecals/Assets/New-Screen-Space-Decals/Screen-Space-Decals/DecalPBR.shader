// Upgrade NOTE: replaced '_CameraToWorld' with 'unity_CameraToWorld'

Shader "Lyf/Decal/PBR"
{
    Properties
    {
        _Color("Color", Color) = (1,1,1,1)
        _MainTex("Albedo", 2D) = "white" {}
        _ShadowFactor("Shadow Strength",Range(0,1))=0.1
        _Cutoff("Alpha Cutoff", Range(0.0, 1.0)) = 0.5
        _GlossMapScale("Smoothness Scale", Range(0.0, 1.0)) = 1.0

        _MetallicGlossMap("Metallic", 2D) = "black" {}

        [ToggleOff] _SpecularHighlights("Specular Highlights", Float) = 1.0
        [ToggleOff] _GlossyReflections("Glossy Reflections", Float) = 1.0

        _BumpScale("Scale", Float) = 1.0
        _BumpMap("Normal Map", 2D) = "bump" {}
        [Enum(UnityEngine.Rendering.CullMode)] _Cull("Cull Mode", Float) = 0 
		[HideInInspector][Enum(UnityEngine.Rendering.BlendMode)] _SrcFactor("_SrcFactor",Float)=5
		[HideInInspector][Enum(UnityEngine.Rendering.BlendMode)] _DstFactor("_DstFactor",Float)=10
        [ToggleOff] _ZWrite("_ZWrite",Float)=1

    }
    SubShader 
    {
        Pass
        {
            Name "Decal"
            Tags{"LightMode"="ForwardBase" "Render Type"="Opaque" "Queue"="Transparent+1"}
            Blend[_SrcFactor] [_DstFactor]
            Cull[_Cull]
            ZWrite[_ZWrite]
            CGPROGRAM
            #pragma target 3.0
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
            #pragma shader_feature _METALLICGLOSSMAP
            #pragma shader_feature _ _GLOSSYRELECTIONS_OFF
            #pragma shader_feature _FADEINBACKGROUND

            #pragma multi_compile_fwdbase

            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #include "UnityStandardCore.cginc"
            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            uniform sampler2D_float _CameraDepthNormalsTexture;
            uniform sampler2D_float _CameraDepthTexture;
            float _ShadowFactor;
            struct DecalInput
            {
                float4 pos:SV_POSITION;
                float4 screenPos:TEXCOORD0;
                float3 ray:TEXCOORD1;
                SHADOW_COORDS(2)
                float3 worldUp:TEXCOORD3;
                float3 eyeVec:TEXCOORD4;
                float3 viewAxis:TEXCOORD5;
                float3 fragNormal:TEXCOORD6;
            };
            struct a2v
            {
                float4 vertex:POSITION;
                float4 normal:NORMAL;
            };
            DecalInput vert(a2v v)
            {
                DecalInput d;
                d.pos=UnityObjectToClipPos(float4(v.vertex.xyz,1));
                d.ray=UnityObjectToViewPos(v.vertex)*float3(-1,-1,1);
                d.screenPos=ComputeScreenPos(d.pos);
                d.eyeVec=normalize(mul(unity_ObjectToWorld,v.vertex).xyz-_WorldSpaceCameraPos);
                d.worldUp=mul((float3x3)unity_ObjectToWorld,float3(1,0,0));
                d.viewAxis=mul((float3x3)unity_ObjectToWorld,float3(0,1,0));
                d.fragNormal=UnityObjectToWorldNormal(v.normal);
                TRANSFER_SHADOW(d);
                return d;
            }
            float4 frag(DecalInput i):SV_Target
            {
                UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);
                i.ray=i.ray*(_ProjectionParams.z/i.ray.z);
                float2 uv=i.screenPos.xy/i.screenPos.w;
                float3 backgroundNormal;
                float depth;
                DecodeDepthNormal(tex2D(_CameraDepthNormalsTexture,uv),depth,backgroundNormal);
                depth=Linear01Depth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,uv));
                float4 vpos=fixed4(i.ray*depth,1);
                float4 wpos=mul(unity_CameraToWorld,vpos);
                float3 opos=mul(unity_WorldToObject,wpos).xyz;
                //backgroundNormal=UnpackNormal(tex2D(_CameraDepthNormalsTexture,uv));
                float3x3 transMat=UNITY_MATRIX_IT_MV*unity_ObjectToWorld;
                backgroundNormal=normalize(mul(backgroundNormal,(float3x3)UNITY_MATRIX_IT_MV));
                clip(float3(0.5,0.5,0.5)-abs(opos));
                uv=opos.xz+0.5;

                //backgroundNormal=i.n;
                float3x3 normalMat;
                float3 binormal=normalize(cross(float3(1,0,0),backgroundNormal));
                float3 tangentWorld=normalize(cross(backgroundNormal,binormal));
                normalMat=float3x3(tangentWorld,binormal,backgroundNormal);
                float3 normal;
                normal=UnpackNormal(tex2D(_BumpMap,uv));
                normal=mul(normalMat,normal);
                clip(dot(i.viewAxis,i.fragNormal)-0.3);
                
                float4 tex = float4(uv*_MainTex_ST.xy+_MainTex_ST.zw,0,0);
                FragmentCommonData s=MetallicSetup(tex);
                float alpha=Alpha(uv);
                clip(alpha-_Cutoff);
                s.normalWorld=normal;
                s.eyeVec=i.eyeVec;
                s.posWorld=wpos;
                s.diffColor=PreMultiplyAlpha(s.diffColor,alpha,s.oneMinusReflectivity,s.alpha);
                UnityLight mainLight=MainLight();

                #if defined(_FADEINBACKGROUND)
                float atten=1;
                #else
                UNITY_LIGHT_ATTENUATION(atten,i,wpos);
                /*float atten=1;
                #if defined(SHADOWS_SCREEN)
                float2 suv=i.screenPos.xy/i.screenPos.w;
                float dist=SAMPLE_DEPTH_TEXTURE(_ShadowMapTexture, suv);
                float lightShadowDataX=_LightShadowData.x;
                float threshold=i.screenPos.z;
                float result=max(dist>threshold,lightShadowDataX);
                atten = saturate(result+(1-_ShadowFactor));
                #endif*/
                #endif


                float4 ambientOrLightmapUV;
                ambientOrLightmapUV.rgb = Shade4PointLights (
                unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
                unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
                unity_4LightAtten0, wpos, normal);

                half occlusion=Occlusion(uv);
                UnityGI gi=FragmentGI(s,occlusion,ambientOrLightmapUV,atten,mainLight);
                float4 c=UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect);
                c.rgb+=Emission(uv);
                c.a=alpha;
                //c.rgb=backgroundNormal;
                /*UnityLight mainLight=MainLight();
                float4 c;
                c.rgb=albedo*mainLight.color*saturate(dot(normal,mainLight.dir));
                */
                //c.rgb=normal;
                return OutputForward(c,s.alpha);
            }
            ENDCG
        }
    }
    //FallBack "VertexLit"
    CustomEditor "DecalShaderGUI"
}