require 'progressbar.rb'
require 'solar_integration/spherical_hash_map.rb'

Z_AXIS = Geom::Vector3d.new(0,0,1)
ORIGIN = Geom::Point3d.new(0,0,0)

# determines if the @faces cast a shadow onto @position
# initialization is expensive, but calling has_shadow is fast
class AbstractShadowCaster
  attr_accessor :hash_map
  
  def initialize(face)
    @normal = face.normal
  end
  
  def prepare_position(position)
    raise 'need to implement'
  end
  
  def has_shadow(sun_direction)
    for pyramid in @hash_map.get_values(sun_direction)
      return true if pyramid.has_shadow(sun_direction)
    end
    return false
  end
end

# creates a new @hash_map for each position and fills it with pyramids
class ShadowCaster < AbstractShadowCaster
  def prepare_position(position)
    shadow_faces = find_shadow_faces(position, @normal)
    @hash_map = SphericalHashMap.new(10,10)
    for shadow_face in shadow_faces
      mesh = shadow_face.mesh(0)
      for index in 1..mesh.count_polygons
        pyramid = Pyramid.new
        pyramid.update(position, mesh.polygon_points_at(index), @hash_map)
      end
    end
  end
end

class Pyramid
  # the position (apex) and each mesh triangle (base) in 
  # shadow_faces define a pyramid, if the sun is 'in the pyramid direction',
  # then the mesh triangle casts a shadow onto center_point.
  # the pyramid (for us) is defined by the array of its three inward side plane
  # normals (we don't need the base)
  def update(position, abs_polygon, hash_map)
    polygon = abs_polygon.collect{|p| p-position}
    @normals = []
    polygon.each.with_index do |p,i|
      @normals.push p*polygon[(i+1)%polygon.length]
    end
    # sign checking/fixing
    if @normals[0] % polygon[2] < 0
      @normals.collect! {|n| n.reverse}
    end
    
    return hash_map.add_value(polygon, self)
  end
  
  # it might help efficiency to set the shadow casting pyramid to the
  # first place in pyramids, as it probably(really?) casts a shadow
  # for the next evaluation as well, arranging the sun states in a sensible
  # way might be required ... an optimization for later
  def has_shadow(sun_direction)
    for normal in @normals
      return false if normal % sun_direction < 0
    end
    return true
  end
end

# keeps single @hash_map using LazyPyramids
class LazyShadowCaster < AbstractShadowCaster
  def initialize(face)
    lowest_position = face.vertices.collect{|v|v.position}.min{|v|ORIGIN.vector_to(v.position)%Z_AXIS}
    @shadow_faces = find_shadow_faces(lowest_position, normal)
    @hash_map = LazySphericalHashMap.new(10,10)
    @pyramids = []
    
    for shadow_face in @shadow_faces
      mesh = shadow_face.mesh(0)
      for index in 1..mesh.count_polygons
        pyramid = LazyPyramid.new(mesh.polygon_points_at(index))
        @pyramids.push pyramid
      end
    end
  end
  
  def prepare_position(position)
    step = @current_position.distance position
    @current_position = position
    
    for pyramid in @pyramids
      pyramid.update(position, @hash_map, step)
    end
  end
end

# keeps laziness, only refreshes hash_map if laziness is low
# polygons that are far away are updated less often.
# we loose some accuracy, but gain performance
class LazyPyramid < Pyramid
  def initialize(polygon, resolution_angle)
    @polygon  = polygon
    @laziness = 0
    @keys = []
    @resolution = Math::sin(resolution_angle * 2*Math::PI / 360)
  end
  
  def update(position, hash_map, step)
    @laziness -= step
    return if @laziness>0
    @laziness = @polygon.min{|p|position.distance p} * @resolution
    @keys.each{|k| hash_map[k].remove(self)}
    @keys = super(position, @polygon, hash_map)
  end
end

# for the shadow cast onto the face only faces that are above the horizon
# and on the front side of the face are relevant
def find_shadow_faces(point, normal)
  faces = []
  for f in Sketchup.active_model.active_entities.select{|f| f.typename=='Face'}
    for v in f.vertices
      if is_above_plane(v.position, point, Z_AXIS) and
          is_above_plane(v.position, point, normal)
        faces.push f
        break
      end
    end
  end
  return faces
end

def is_above_plane(point, plane_base, plane_normal)
    return (point - plane_base) % plane_normal > 0
end
