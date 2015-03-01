require 'solar_integration/spherical_hash_map.rb'
require 'solar_integration/angle_conversion.rb'

Z_AXIS = Geom::Vector3d.new(0,0,1)
ORIGIN = Geom::Point3d.new(0,0,0)
INCLINATION_CUTOFF = 10

# creates a new @hash_map for each position and fills it with pyramids
class ShadowCaster
  attr_accessor :hash_map
  
  def initialize(polygons, face)
    # only consider polygons above face plane
    @polygons = polygons.select{|p| p.any? {|v| ORIGIN.vector_to(v)%face.normal>0}}
  end
  
  def prepare_position(position)
    relative_polygons = calculate_relative_polygons(position)
    shadow_polygons = find_shadow_polygons(relative_polygons)
    @hash_map = SphericalHashMap.new(10,10)
    for shadow_polygon in shadow_polygons
      @hash_map.add_value(shadow_polygon, Pyramid.new(shadow_polygon))
    end
  end
  
  def has_shadow(sun_direction)
    for pyramid in @hash_map.get_values(sun_direction)
      return true if pyramid.has_shadow(sun_direction)
    end
    return false
  end
  
  def calculate_relative_polygons(position)
    @polygons.collect do |polygon|
      polygon.collect {|p| position.vector_to(p)}
    end
  end
end

class Pyramid
  # the position (apex) and each mesh triangle (base) in 
  # shadow_faces define a pyramid, if the sun is 'in the pyramid direction',
  # then the mesh triangle casts a shadow onto center_point.
  # the pyramid (for us) is defined by the array of its three inward side plane
  # normals (we don't need the base)
  def initialize(polygon)
    @normals = []
    polygon.each.with_index do |p,i|
      @normals.push p*polygon[(i+1)%polygon.length]
    end
    # sign checking/fixing
    if @normals[0] % polygon[2] < 0
      @normals.collect! {|n| n.reverse}
    end
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

# for the shadow cast onto the face only faces that are above the horizon
# and on the front side of the face are relevant
def find_shadow_polygons(polygons)
  return polygons.select{|p| is_shadow_polygon(p)}
end

def is_shadow_polygon(polygon)
  # polygon is below horizontal plane
  return false if polygon.all? {|p| p[2]<0}

  # polygon is below (horizontal) inclanation cutoff
  polar_min_max = PolarMinMax.new(polygon)
  return false if 90 - to_degree(polar_min_max.pl_min) <= INCLINATION_CUTOFF
  
  # polygon is not in any possible sun_direction
  # ... wouldn't help much since hash map does same job with same effort
  # rearranging hash map for 'solar north pole' seems sensible, performance boost not clear
  ##TODO
  
  return true
end
