require 'solar_integration/globals.rb'

module BoundingRectangle
  # the bounding rectangle consists of four 3DPoints forming a rectangle with right
  # angles, in the same plane as the given face, and containing the face and
  # aligned with the longest edge of the face

  def calculate_bounding_rectangle(face)
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

    return [c1, c2, c3, c4]
  end

  def find_uv(face)
    normal = face.normal
    longest_edge = face.edges.max_by{|e|e.length}
    u = longest_edge.start.position - longest_edge.end.position
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
end