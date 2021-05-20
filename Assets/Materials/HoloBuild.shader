Shader "QZH/HoloBuild"
{
    Properties
    {
		[Header(Real)]
		[Space]
		_Color("Main Color",COLOR)=(1,1,1,1)
        _MainTex ("Texture", 2D) = "white" {}
		_NormalMap("NormalMap",2D)="white"{}
		_EmissonMap("Emisson Map",2D)="white"{}
		[HDR]_EmissionCol("Emission Col",COLOR)=(1,1,1,1)
		_Smoothness("Smoothness",Range(0.1,1))=0.5
		[HDR]_GrowCol("GrowColor",Color)=(1,1,1,1)
		_Grow("grow",Range(0,2))=0.0
		_GrowWidth("grow width",float)=0.0
		_heigh("Heigh",float)=5.0
		_Frequency("frequency",float)=5.0

    }
    SubShader
    {
		Tags{
		"Queue"="Geometry" 
		"RenderType"="Opaque"
		"RenderPipeline"="UniversalPipeline"
		}
		//写实风格
		Pass{
			Tags { "LightMode"="UniversalForward" }
			Blend SrcAlpha OneMinusSrcAlpha
			Cull Back
			ZWrite Off
			HLSLPROGRAM
			#pragma vertex vertReal
			#pragma fragment fragReal
			
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/ShaderGraphFunctions.hlsl"
            #include "Packages/com.unity.shadergraph/ShaderGraphLibrary/ShaderVariablesFunctions.hlsl"
			//CBUFFER_START(UnityPerMaterial)
			half4 _Color;
			//CBUFFER_END
			half _Grow;
			half _GrowWidth;
			half _heigh;
			TEXTURE2D(_MainTex);
			float4 _MainTex_ST;
			SAMPLER(sampler_MainTex);

			TEXTURE2D(_NormalMap);
			float4 _NormalMap_ST;
			SAMPLER(sampler_NormalMap);

			TEXTURE2D(_EmissonMap);
			float4 _EmissonMap_ST;
			SAMPLER(sampler_EmissonMap);

			float4 _GrowCol;
			float4 _EmissionCol;
			float _Smoothness;
			half _Frequency;

			struct a2v {
				float4 vertex : POSITION;
				float3 normal : NORMAL;
				float4 tangent : TANGENT;
				float4 texcoord : TEXCOORD0;
			};
			
			struct v2f {
				float4 pos : SV_POSITION;
				float4 uv : TEXCOORD0;
				float4 normalWS:TEXCOORD1;
                float4 tangentWS:TEXCOORD2;
                float4 bitangentWS:TEXCOORD3;
				
				//SHADOW_COORDS(4)
			};
			
			v2f vertReal(a2v v) {
				v2f o;
				o.pos = TransformObjectToHClip(v.vertex);
				float3 normal=TransformObjectToWorldNormal(v.normal);
				o.uv.xy = v.texcoord.xy * _MainTex_ST.xy + _MainTex_ST.zw;
				o.uv.zw = v.texcoord.xy * _NormalMap_ST.xy + _NormalMap_ST.zw;
				
				float3 worldPos =TransformObjectToWorld(v.vertex.xyz);  
				o.normalWS = float4(normal,worldPos.x);  
				o.tangentWS = float4(TransformObjectToWorldDir(v.tangent.xyz),worldPos.y);  
				o.bitangentWS = float4(cross(o.normalWS.xyz, o.tangentWS.xyz) * v.tangent.w,worldPos.z); 
				
				return o;
			}
			
			half4 fragReal(v2f i) : SV_Target {
				float3 worldPos = float3(i.normalWS.w,i.tangentWS.w,i.bitangentWS.w);
				Light light=GetMainLight();
				half3 lightDir = normalize(light.direction);
				half3 viewDir = normalize(GetCameraPositionWS()-worldPos);
				// 采样法线贴图并解析出法线空间的法线
                float3 normalTS=
                	UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap,sampler_NormalMap,i.uv.zw)); 
                float3x3 tangentToWorld=float3x3(
                	normalize(i.tangentWS.xyz),
                	normalize(i.bitangentWS.xyz),
                	normalize(i.normalWS.xyz));
				
				float3 bump=mul(normalTS,tangentToWorld);
				
				half3 final;
				half3 diffuse = light.color.rgb * saturate(dot(bump, lightDir))* _Color.rgb*SAMPLE_TEXTURE2D(_MainTex,sampler_MainTex,i.uv.xy).rgb;
				final=diffuse;

				// half3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz * diffuse;
				// final+=ambient;
				half3 emmison=SAMPLE_TEXTURE2D(_EmissonMap,sampler_EmissonMap,i.uv.xy).rgb*_EmissionCol.rgb;
				final+=emmison;
				half3 halfDir=(lightDir+viewDir)/2;
				half3 specular=pow(saturate(dot(halfDir,bump)),_Smoothness*255)*light.color.rgb;
				final+=specular;
				half a=saturate(sin(worldPos.y*_Frequency)*sin(worldPos.x*_Frequency)*sin(worldPos.z*_Frequency));
				half4 excessive=half4(_GrowCol.rgb,a);
				float grow=smoothstep(worldPos.y-_GrowWidth,worldPos.y,_Grow*_heigh);
				excessive.a*=grow;
				//float _Grow=_Grow>1.0?_Grow-1:_Grow;
				
				return lerp(excessive,half4(final,1.0),saturate(_Grow-1.0));
			}

			ENDHLSL
		}
		
    }
}
