using UnityEngine;
using System.Collections;
using System.Collections.Generic;
[ExecuteInEditMode]
public class EffectLDecal : MonoBehaviour
{
    public enum Kind
    {
        AllEffect,
        DiffuseNormalSpecular,
        DiffuseOnly,
        NormalsOnly,
        SpecularOnly,
        EmissionOnly,        
    }
    public Kind m_Kind;
    public Material m_Material;
    public Vector3 Size;
    public Mesh mesh;

    public Matrix4x4 matrix
    {
        get
        {
            return Matrix4x4.TRS(transform.position, transform.rotation, Size);
        }
    }
    //private void OnGUI()
    //{
    //    GUILayout.Button(transform.localToWorldMatrix.GetColumn(3).ToString());
    //    GUILayout.Button(transform.position.ToString());
    //}

    private void OnEnable()
    {
        EffectLDecalSystem.instance.AddDecal(this);
    }
    private void OnDisable()
    {
        EffectLDecalSystem.instance.RemoveDecal(this);
    }
    private void Start()
    {
        EffectLDecalSystem.instance.AddDecal(this);
    }
    private void DrawGizmo(bool selected)
    {
        var col = new Color(0.0f, 0.7f, 1f, 1.0f);
        col.a = selected ? 0.3f : 0.1f;
        Gizmos.color = col;
        Gizmos.matrix = matrix;
        Gizmos.DrawMesh(mesh);
        col.a = selected ? 0.5f : 0.2f;
        Gizmos.color = col;
        Gizmos.DrawWireMesh(mesh);
    }
    private void OnDrawGizmos()
    {
        DrawGizmo(false);
    }
    private void OnDrawGizmosSelected()
    {
        DrawGizmo(true);
    }
}
public class EffectLDecalSystem
{
    static EffectLDecalSystem m_instance;
    public static EffectLDecalSystem instance
    {
        get
        {
            if (m_instance == null)
            {
                m_instance = new EffectLDecalSystem();
            }
            return m_instance;
        }
    }
    internal HashSet<EffectLDecal> m_DecalsAll = new HashSet<EffectLDecal>();
    internal HashSet<EffectLDecal> m_DecalsNormals = new HashSet<EffectLDecal>();
    internal HashSet<EffectLDecal> m_DecalsDiffuse = new HashSet<EffectLDecal>();
    internal HashSet<EffectLDecal> m_DecalsSpecular = new HashSet<EffectLDecal>();
    internal HashSet<EffectLDecal> m_DecalsEmission = new HashSet<EffectLDecal>();
    internal HashSet<EffectLDecal> m_DecalsCommon = new HashSet<EffectLDecal>();
    public void AddDecal(EffectLDecal d)
    {
        RemoveDecal(d);
        if (d.m_Kind == EffectLDecal.Kind.AllEffect)
            m_DecalsAll.Add(d);
        if (d.m_Kind == EffectLDecal.Kind.NormalsOnly)
            m_DecalsNormals.Add(d);
        if (d.m_Kind == EffectLDecal.Kind.DiffuseOnly)
            m_DecalsDiffuse.Add(d);
        if (d.m_Kind == EffectLDecal.Kind.SpecularOnly)
            m_DecalsSpecular.Add(d);
        if (d.m_Kind == EffectLDecal.Kind.EmissionOnly)
            m_DecalsEmission.Add(d);
        if (d.m_Kind == EffectLDecal.Kind.DiffuseNormalSpecular)
            m_DecalsCommon.Add(d);                                    
    }
    public void RemoveDecal(EffectLDecal a)
    {
        m_DecalsAll.Remove(a);
        m_DecalsNormals.Remove(a);
        m_DecalsDiffuse.Remove(a);
        m_DecalsSpecular.Remove(a);
        m_DecalsEmission.Remove(a);
        m_DecalsCommon.Remove(a);
    }
}
