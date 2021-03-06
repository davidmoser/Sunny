require 'sketchup.rb'
require 'solar_integration/spherical_hash_map.rb'
require 'solar_integration/globals.rb'
require 'solar_integration/polygon_collector.rb'

# creates a new @hash_map for each position and fills it with pyramids
class ShadowCaster
  attr_accessor :hash_map, :pyramids

  include PolygonCollector

  def initialize(grid, sun_transformation)
    @sun_transformation = sun_transformation

    polygons = collect_model_polygons(Sketchup.active_model)

    # only consider polygons with points above face plane
    lowest_face_point = grid.face.vertices.collect { |v| v.position }.min_by { |p| p[2] }
    @polygons = polygons.select { |p| p.any? { |v| lowest_face_point.vector_to(v)%grid.normal>1 } }
    @polygons.select! { |p| p.any? { |v| lowest_face_point[2]<v[2] } }

    @pyramids = @polygons.collect { |p| Pyramid.new(p, grid.square_length, @sun_transformation) }
  end

  def prepare_center(center)
    @shadow_pyramids = @pyramids.select { |p| p.is_shadow_pyramid(center) }
  end

  def prepare_position(position)
    position = position.transform(@sun_transformation)
    @hash_map = SphericalHashMap.new
    for pyramid in @shadow_pyramids
      pyramid.calculate_normals(position)
      @hash_map.add_value(pyramid.relative_polygon, pyramid)
    end
  end

  def has_shadow? sun_direction
    for pyramid in @hash_map.get_values(sun_direction)
      return true if pyramid.has_shadow? sun_direction
    end
    return false
  end

  def is_shadow_section? section
    return @hash_map.get_values_for_hash(section.index).length > 0
  end

end

class Pyramid
  attr_reader :polygon, :relative_polygon

  def initialize(polygon, square_length, sun_transformation)
    @sun_transformation = sun_transformation
    @local_polygon = polygon
    @sun_polygon = polygon.collect { |p| p.transform(@sun_transformation) }

    @halve_diagonal = square_length.m / Math::sqrt(2)
    @inclination_cutoff = $solar_integration.configuration.inclination_cutoff
  end

  def calculate_relative_polygon(position)
    return @sun_polygon.collect { |p| position.vector_to(p) }
  end

  # check if the polygon might cast a shadow on square with center
  def is_shadow_pyramid(center)
    relative_polygon = @local_polygon.collect { |p| center.vector_to(p) }
    distance = relative_polygon.collect { |v| v.length }.min

    return true if distance <= @halve_diagonal

    angle_error = to_degree(Math::asin(@halve_diagonal / distance))

    # polygon is below (horizontal) inclination cutoff
    polar_min_max = PolarMinMax.new(relative_polygon)
    return false if 90 - to_degree(polar_min_max.pl_min) < @inclination_cutoff - angle_error

    # polygon is not in any possible sun_direction
    relative_polygon = calculate_relative_polygon(center.transform(@sun_transformation))
    polar_min_max = PolarMinMax.new(relative_polygon)
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
    @relative_polygon = calculate_relative_polygon(position)

    @normals = @relative_polygon.collect.with_index do |p, i|
      p*@relative_polygon[(i+1)%@relative_polygon.length]
    end

    # sign checking/fixing
    if @normals[0] % @relative_polygon[2] < 0
      @normals.collect! { |n| n.reverse }
    end
  end

  def has_shadow? sun_direction
    for normal in @normals
      return false if normal % sun_direction < 0
    end
    return true
  end

  def visualize(entities, base)
    @local_polygon.each { |p| entities.add_edges base, p }
  end
end

