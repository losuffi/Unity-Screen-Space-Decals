using UnityEngine;
using UnityEngine.Rendering;
using System.Collections;
using System.Collections.Generic;
[ExecuteInEditMode]
public class EffectLDecalRenderer : MonoBehaviour
{
    private Dictionary<Camera, CommandBuffer> m_Cams = new Dictionary<Camera, CommandBuffer>();
    private void OnDisable()
    {
        foreach(var cam in m_Cams)
        {
            if (cam.Key)
            {
                cam.Key.RemoveCommandBuffer(CameraEvent.BeforeLighting, cam.Value);
            }
        }
    }
    private void OnWillRenderObject()
    {
        bool act = gameObject.activeInHierarchy && enabled;
        if (!act)
        {
            OnDisable();
            return;
        }
        var cam = Camera.current;
        if (!cam)
        {
            return;
        }
        CommandBuffer buf = null;
        if (m_Cams.ContainsKey(cam))
        {
            buf = m_Cams[cam];
            buf.Clear();
        }
        else
        {
            buf = new CommandBuffer();
            buf.name = "EffectL Decal";
            m_Cams[cam] = buf;
            cam.AddCommandBuffer(CameraEvent.BeforeLighting, buf);
        }
        var sys = EffectLDecalSystem.instance;
        var normalId = Shader.PropertyToID("_NormalsCopy");
        var specularId = Shader.PropertyToID("_SpecularCopy");
        var emissionId = Shader.PropertyToID("_EmissionsCopy");
        buf.GetTemporaryRT(specularId, -1, -1);
        buf.GetTemporaryRT(normalId, -1, -1);
        buf.GetTemporaryRT(emissionId, -1, -1);
        buf.Blit(BuiltinRenderTextureType.GBuffer1, specularId);
        buf.Blit(BuiltinRenderTextureType.GBuffer2, normalId);
        buf.Blit(BuiltinRenderTextureType.GBuffer3, emissionId);
        // render diffuse-only decals into diffuse channel

        buf.SetRenderTarget(BuiltinRenderTextureType.GBuffer0, BuiltinRenderTextureType.CameraTarget);
        foreach (var decal in sys.m_DecalsDiffuse)
        {
            buf.DrawMesh(decal.mesh, decal.matrix, decal.m_Material);
        }
        buf.SetRenderTarget(BuiltinRenderTextureType.GBuffer1, BuiltinRenderTextureType.CameraTarget);
        foreach (var decal in sys.m_DecalsSpecular)
        {
            buf.DrawMesh(decal.mesh, decal.matrix, decal.m_Material);
        }
        buf.SetRenderTarget(BuiltinRenderTextureType.GBuffer2, BuiltinRenderTextureType.CameraTarget);
        foreach (var decal in sys.m_DecalsNormals)
        {
            buf.DrawMesh(decal.mesh, decal.matrix, decal.m_Material);
        }
        buf.SetRenderTarget(BuiltinRenderTextureType.GBuffer3, BuiltinRenderTextureType.CameraTarget);
        foreach (var decal in sys.m_DecalsEmission)
        {
            buf.DrawMesh(decal.mesh, decal.matrix, decal.m_Material);
        }
        RenderTargetIdentifier[] mrt = {
            BuiltinRenderTextureType.GBuffer0,
            BuiltinRenderTextureType.GBuffer1,
            BuiltinRenderTextureType.GBuffer2,
        };
        buf.SetRenderTarget(mrt, BuiltinRenderTextureType.CameraTarget);
        foreach (var decal in sys.m_DecalsCommon)
        {
            buf.DrawMesh(decal.mesh, decal.matrix, decal.m_Material);
        }
        RenderTargetIdentifier[] mrt1 = {
            BuiltinRenderTextureType.GBuffer0,
            BuiltinRenderTextureType.GBuffer1,
            BuiltinRenderTextureType.GBuffer2,
            BuiltinRenderTextureType.GBuffer3,
        };
        buf.SetRenderTarget(mrt1, BuiltinRenderTextureType.CameraTarget);
        foreach (var decal in sys.m_DecalsAll)
        {
            buf.DrawMesh(decal.mesh, decal.matrix, decal.m_Material);
        }
        buf.ReleaseTemporaryRT(specularId);
        buf.ReleaseTemporaryRT(normalId);
        buf.ReleaseTemporaryRT(emissionId);
    }
}
