require 'progressbar.rb'
require 'solar_integration/spherical_hash_map.rb'

# determines if the @faces cast a shadow onto @position
# initialization is expensive, but calling has_shadow is fast
class ShadowCaster
  attr_accessor :hash_map
  
  # the position (apex) and each mesh triangle (base) in 
  # shadow_faces define a pyramid, if the sun is 'in the pyramid direction',
  # then the mesh triangle casts a shadow onto center_point.
  # the pyramid (for us) is defined by the array of its three inward side plane
  # normals (we don't need the base)
  def prepare_position(position, normal)
    shadow_faces = find_shadow_faces(position, normal)
    @hash_map = SphericalHashMap.new(10,10)
    for shadow_face in shadow_faces
      mesh = shadow_face.mesh(0)
      for index in 1..mesh.count_polygons
        polygon = mesh.polygon_points_at(index).collect{|p| p-position}
        pyramid = []
        polygon.each.with_index do |p,i|
          pyramid.push p*polygon[(i+1)%polygon.length]
        end
        # sign checking/fixing
        if pyramid[0] % polygon[2] < 0
          pyramid.collect! {|n| n.reverse}
        end
        @hash_map.add_value(polygon, pyramid)
      end
    end
  end
  
  # it might help efficiency to set the shadow casting pyramid to the
  # first place in pyramids, as it probably(really?) casts a shadow
  # for the next evaluation as well, arranging the sun states in a sensible
  # way might be required ... an optimization for later
  def has_shadow(sun_direction)
    for pyramid in @hash_map.get_values(sun_direction)
      has_shadow = true
      for normal in pyramid
        if normal % sun_direction < 0
          has_shadow = false
        end
      end
      return true if has_shadow
    end
    return false
  end
  
  
  # for the shadow cast onto the face only faces that are above the horizon
  # and on the front side of the face are relevant
  def find_shadow_faces(point, normal)
    hor_normal = Geom::Vector3d.new(0,0,1)
    faces = []
    for f in Sketchup.active_model.active_entities.select{|f| f.typename=='Face'}
      for v in f.vertices
        if is_above_plane(v.position, point, hor_normal) and
            is_above_plane(v.position, point, normal)
          faces.push f
          break
        end
      end
    end
    return faces
  end
  
  ## Little helpers
  def is_above_plane(point, plane_base, plane_normal)
      return (point - plane_base) % plane_normal > 0
  end
  
end