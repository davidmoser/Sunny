# adorns a face with a 'bounding_box' attribute,
# that's four 3DPoints forming a rectangle with right angles, in the same plane as the
# given face, and containing the face

X_AXIS = Geom::Vector3d.new(1,0,0)
Y_AXIS = Geom::Vector3d.new(0,1,0)
Z_AXIS = Geom::Vector3d.new(0,0,1)
ORIGIN = Geom::Point3d.new(0,0,0)

def attach_flat_bounding_box(face)
  u, v = find_uv(face)
  u_min, u_max, v_min, v_max = find_extremal_points(u, v, face.vertices)
  
  l1 = [u_min, v]
  l2 = [v_min, u]
  l3 = [u_max, v]
  l4 = [v_max, u]

  c1 = Geom.intersect_line_line(l1, l2)
  c2 = Geom.intersect_line_line(l2, l3)
  c3 = Geom.intersect_line_line(l3, l4)
  c4 = Geom.intersect_line_line(l4, l1)

  bounding_box = [c1, c2, c3, c4]
  #face.set_attribute 'solarintegration', 'flat_bounding_box', bounding_box
  return bounding_box
end

def find_uv(face)
  normal = face.normal
  if !normal.parallel? X_AXIS
    u = normal * X_AXIS
  elsif !normal.parallel? Y_AXIS
    u = normal * Y_AXIS
  else
    u = normal * Z_AXIS
  end
  v = normal * u
  return u, v
end

def find_extremal_points(u, v, list)
  return find_max(u.reverse, list),
         find_max(u, list),
         find_max(v.reverse, list),
         find_max(v, list)
end

def find_max(vec, list)
  return list.max_by{|v| ORIGIN.vector_to(v)%vec}
end
