using System.Collections;
using System.Collections.Generic;
using UnityEngine;
[ExecuteInEditMode]
public class DecalCamera : MonoBehaviour {
	private Camera cam;
	private void OnEnable() {
		cam=GetComponent<Camera>();
	}	
	private void OnPreRender() 
	{
		cam.depthTextureMode|=DepthTextureMode.DepthNormals;
		
	}
	/*private void Update() {
		cam.depthTextureMode=DepthTextureMode.DepthNormals;
		Matrix4x4 currentViewMat=cam.cameraToWorldMatrix;
		Shader.SetGlobalMatrix("currentInverseMat",currentViewMat);
	}*/
}
