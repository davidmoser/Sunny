require 'solar_integration/spherical_hash_map.rb'
require 'solar_integration/angle_conversion.rb'

X_AXIS = Geom::Vector3d.new(1,0,0)
Z_AXIS = Geom::Vector3d.new(0,0,1)
ORIGIN = Geom::Point3d.new(0,0,0)
ECLIPTIC_ANGLE = to_radian(23.4)

# creates a new @hash_map for each position and fills it with pyramids
class ShadowCaster
  attr_accessor :hash_map, :pyramids, :sun_transformation
  
  def initialize(polygons, face, configuration)
    # sun_transformation transforms solar north to z axis
    # in that coordinate system the suns inclination lies between +-ECLIPTIC_ANGLE
    si = Sketchup.active_model.shadow_info
    sun_angle = to_radian(90 - si['Latitude'])
    north_angle = to_radian(si['NorthAngle'])
    @sun_transformation = Geom::Transformation.rotation(ORIGIN, X_AXIS, sun_angle) \
                        * Geom::Transformation.rotation(ORIGIN, Z_AXIS, north_angle)
    
    @configuration = configuration
    
    # only consider polygons above face plane
    @polygons = polygons.select{|p| p.any? {|v| ORIGIN.vector_to(v)%face.normal>0}}
    @pyramids = @polygons.collect{|p| Pyramid.new(p, configuration, @sun_transformation)}
    
    # the empty map used in get_section
    @hash_map = @configuration.hash_map_class.new(10)
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
    transformed_sun_direction = sun_direction.transform(@sun_transformation)
    for pyramid in @hash_map.get_values(transformed_sun_direction)
      return true if pyramid.has_shadow(transformed_sun_direction)
    end
    return false
  end
  
  def get_section_index(sun_direction)
    return @hash_map.get_hash(sun_direction.transform(@sun_transformation))
  end
  
  def is_section_empty?(section_index)
    return @hash_map.get_values_for_hash(section_index).length == 0
  end
  
end

class Pyramid
  attr_reader :polygon, :relative_polygon
  
  def initialize(polygon, configuration, sun_transformation)
    @sun_transformation = sun_transformation
    @configuration = configuration
    @polygon = polygon
  end
  
  def calculate_relative_polygon(position)
    @relative_polygon = @polygon.collect {|p| position.vector_to(p)}
  end
  
  def transform_relative_polygon
    @relative_polygon.collect!{|v| v.transform(@sun_transformation)}
  end
  
  # check if the polygon might cast a shadow on square with center
  def is_shadow_pyramid(center)
    calculate_relative_polygon(center)
    distance = @relative_polygon.collect{|v| v.length}.min
    angle_error = to_degree(@configuration.grid_length / 2 / distance)
    
    # polygon is below (horizontal) inclanation cutoff
    polar_min_max = PolarMinMax.new(@relative_polygon)
    return false if 90 - to_degree(polar_min_max.pl_min) < @configuration.inclination_cutoff - angle_error

    # polygon is not in any possible sun_direction
    transform_relative_polygon
    polar_min_max = PolarMinMax.new(@relative_polygon)
    cutoff = ECLIPTIC_ANGLE + angle_error
    return false if 90 - to_degree(polar_min_max.pl_min) < -cutoff \
                  or 90 - to_degree(polar_min_max.pl_max) > cutoff
    
    return true
  end
  
  # the position (apex) and each mesh triangle (base) in 
  # shadow_faces define a pyramid, if the sun is 'in the pyramid direction',
  # then the mesh triangle casts a shadow onto center_point.
  # the pyramid (for us) is defined by the array of its three inward side plane
  # normals (we don't need the base)
  def calculate_normals(position)
    calculate_relative_polygon(position)
    transform_relative_polygon
    @normals = []
    @relative_polygon.each.with_index do |p,i|
      @normals.push p*@relative_polygon[(i+1)%@polygon.length]
    end
    # sign checking/fixing
    if @normals[0] % @relative_polygon[2] < 0
      @normals.collect! {|n| n.reverse}
    end
  end
  
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

