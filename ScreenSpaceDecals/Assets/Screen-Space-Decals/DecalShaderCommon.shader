Shader "Decal/DecalCommonShader"
{
	Properties
	{		
		_MainColor("Color",Color)=(1,1,1,1)
		_MainTex ("Diffuse", 2D) = "white" {}
		_SpecularMap("Specular Map",2D)="white"{}
		_NormalMap("Normal Map",2D) = "white"{}
		_Gloss("Gloss",Range(0,10.0))=1.0
		_Roughness("Roughness",Range(0.001,1.0)) = 0.001
		_BlendFactor("BlendFactor",Range(0,1.0)) = 0.001
	}
	SubShader
	{
		Pass
		{
			Fog { Mode Off } 
			ZWrite Off
			Blend SrcAlpha OneMinusSrcAlpha

			CGPROGRAM
			#pragma target 3.0
			#pragma vertex vert
			#pragma fragment frag
			#pragma exclude_renderers nomrt
			#include "UnityCG.cginc"
			#include "UnityDeferredLibrary.cginc"
			struct v2f
			{
				half4 pos : SV_POSITION;
				half2 uv : TEXCOORD0;
				half4 screenUV : TEXCOORD1;
				half3 ray : TEXCOORD2;
				half3 orientation : TEXCOORD3;
				half3 eyeVec:TEXCOORD4;
				half3 oriSpace[3]:TEXCOORD5;
			};
			//CBUFFER_START(UnityPerCamera2)
			////half4x4 _CameraToWorld;
			//CBUFFER_END
			v2f vert (half3 v : POSITION)
			{
				v2f o;
				UNITY_INITIALIZE_OUTPUT(v2f, o);
				o.pos = mul (UNITY_MATRIX_MVP, half4(v,1));
				o.uv = v.xz+0.5;
				half2 uv=v.xz+0.5;
				o.screenUV = ComputeScreenPos (o.pos);
				o.ray = mul (UNITY_MATRIX_MV, half4(v,1)).xyz * half3(1,1,-1);
				o.orientation = mul ((half3x3)_Object2World, half3(0,1,0));
				half3 worldPos=mul((half3x3)_Object2World,v);
				half3 Campos=half3(0.0,0.0,0.0);
				half3 worldCam=mul((half3x3)_CameraToWorld,Campos);
				o.eyeVec=normalize(worldPos-worldCam);
				o.oriSpace[0] = mul((half3x3)_Object2World, half3(1, 0, 0));
				o.oriSpace[1] = mul((half3x3)_Object2World, half3(0, 1, 0));
				o.oriSpace[2] = mul((half3x3)_Object2World, half3(0, 0, 1));
				return o;
			}
			sampler2D _MainTex;
			sampler2D _SpecularMap;
			sampler2D _NormalMap;
			half _Gloss;
			half _Roughness;
			half _BlendFactor;
			half4 _MainColor;
			//sampler2D_half _CameraDepthTexture;
			sampler2D _NormalsCopy;
			sampler2D _SpecularCopy;
			sampler2D _EmissionsCopy;
			sampler2D _DiffuseCopy;
			void frag(
                v2f i, 
				out half4 outDiffuse : COLOR0,
				out half4 outSpecRoughness : COLOR1,
				out half4 outNormal : COLOR2,
                out half4 outEmission : COLOR3
			)
			{
				i.ray = i.ray * (_ProjectionParams.z / i.ray.z);
				half2 uv = i.screenUV.xy / i.screenUV.w;
				half depth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv);
				depth = Linear01Depth (depth);
				half4 vpos = half4(i.ray * depth,1);
				half3 wpos = mul (_CameraToWorld, vpos).xyz;
				half3 opos = mul (_World2Object, half4(wpos,1)).xyz;

				clip (half3(0.5,0.5,0.5) - abs(opos.xyz));


				i.uv = opos.xz +0.5;


				half3 normal = tex2D(_NormalsCopy, uv).rgb;
				half3 normalWorld = normal.rgb * 2.0 - 1.0;
				//i.uv = i.uv*(1 + dot(i.oriSpace[1], normalWorld));
				//i.uv += (1 - saturate(dot(i.oriSpace[1], normalWorld)));
				half3 nor = UnpackNormal(tex2D(_NormalMap, i.uv));
				half3x3 norMat = half3x3(i.oriSpace[0], i.oriSpace[2], i.oriSpace[1]);
				half3 worldNor = mul(nor, norMat);
				normalWorld = worldNor + normalWorld;


				half3 diffuse=saturate(dot(_LightDir,normalWorld) *0.8+0.2)*_LightColor;
				half4 specularFactor=tex2D(_SpecularMap,i.uv);  
				half3 view=i.eyeVec;
				half3 s= (pow(max(dot((view+_LightDir),normalWorld),0.0),_Gloss))*_LightColor;
				half4 col = tex2D (_MainTex, i.uv)*_MainColor;
				half3 colo = col + diffuse;
				half3 sourceEmission = tex2D(_EmissionsCopy, uv).rgb;
				half4 sourceSpecular=tex2D(_SpecularCopy,uv);
				half4 sourcediffuse = tex2D(_DiffuseCopy, uv);
				half4 spec = specularFactor* half4(s,1);
				
				outDiffuse = lerp(sourcediffuse, half4(colo, col.a), col.a);
				outSpecRoughness=lerp(sourceSpecular,spec,col.a);
				outNormal = lerp(tex2D(_NormalsCopy, uv), half4(normalWorld*0.5 + 0.5, 1), col.a);
			}
			ENDCG
		}		
	}

	Fallback Off
}
