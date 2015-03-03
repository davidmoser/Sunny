require 'solar_integration/spherical_hash_map.rb'
require 'solar_integration/angle_conversion.rb'

Z_AXIS = Geom::Vector3d.new(0,0,1)
ORIGIN = Geom::Point3d.new(0,0,0)

# creates a new @hash_map for each position and fills it with pyramids
class ShadowCaster
  attr_accessor :hash_map, :pyramids
  
  def initialize(polygons, face, configuration)
    @configuration = configuration
    # only consider polygons above face plane
    @polygons = polygons.select{|p| p.any? {|v| ORIGIN.vector_to(v)%face.normal>0}}
    @pyramids = @polygons.collect{|p| Pyramid.new(p, configuration)}
  end
  
  def prepare_center(center)
    @shadow_pyramids = @pyramids.select{|p| p.is_shadow_pyramid(center)}
  end
  
  def prepare_position(position)
    @hash_map = @configuration.hash_map_class.new(10)
    for pyramid in @shadow_pyramids
      pyramid.calculate_normals(position)
      @hash_map.add_value(pyramid.relative_polygon, pyramid)
    end
  end
  
  def has_shadow(sun_direction)
    for pyramid in @hash_map.get_values(sun_direction)
      return true if pyramid.has_shadow(sun_direction)
    end
    return false
  end
  
end

class Pyramid
  attr_reader :polygon, :relative_polygon
  
  def initialize(polygon, configuration)
    @configuration = configuration
    @polygon = polygon
  end
  
  def update_relative_polygon(position)
    @relative_polygon = @polygon.collect {|p| position.vector_to(p)}
  end
  
  # check if the polygon might cast a shadow on square with center
  def is_shadow_pyramid(center)
    update_relative_polygon(center)
    distance = @relative_polygon.collect{|v| v.length}.min
    angle_error = to_degree(@configuration.grid_length / 2 / distance)
    
    # polygon is below (horizontal) inclanation cutoff
    polar_min_max = PolarMinMax.new(@relative_polygon)
    return false if 90 - to_degree(polar_min_max.pl_min) <= @configuration.inclination_cutoff - angle_error

    # polygon is not in any possible sun_direction
    # ... wouldn't help much since hash map does same job with same effort
    # rearranging hash map for 'solar north pole' seems sensible, performance boost not clear
    ##TODO

    return true
  end
  
  # the position (apex) and each mesh triangle (base) in 
  # shadow_faces define a pyramid, if the sun is 'in the pyramid direction',
  # then the mesh triangle casts a shadow onto center_point.
  # the pyramid (for us) is defined by the array of its three inward side plane
  # normals (we don't need the base)
  def calculate_normals(position)
    update_relative_polygon(position)
    @normals = []
    @relative_polygon.each.with_index do |p,i|
      @normals.push p*@relative_polygon[(i+1)%@polygon.length]
    end
    # sign checking/fixing
    if @normals[0] % @relative_polygon[2] < 0
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
  
  def visualize(entities, base)
    @polygon.each{|p| entities.add_edges base, p}
  end
end

