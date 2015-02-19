require 'sketchup.rb'
require 'progressbar.rb'
require 'solar_integration/flat_bounding_box.rb'
require 'solar_integration/spherical_hash_map.rb'

SKETCHUP_CONSOLE.show

UI.menu('Plugins').add_item('Integrate selection') {
  model = Sketchup.active_model
  
  for face in model.selection
    if face.typename=='Face'
      $solar_integration.integrate(face)
    end
  end
}

class SolarIntegration
  def initialize
    @grid_length = 10 ##TODO: is that always cm?
    @solar_data = SolarData.new
    @layer = Sketchup.active_model.layers.add 'solarintegration'
  end

  def integrate(face)
    grid = Grid.new(face, @grid_length)
    shadow_faces = find_shadow_faces(face)
    
    progress_bar = ProgressBar.new(grid.squares.length, 'Integrating irradiances...')
    
    for square in grid.squares
      shadow_caster = ShadowCaster.new(square.center, shadow_faces)
      square.irradiance = integrate_grid_face(grid.normal, shadow_caster)
      progress_bar.update(grid.squares.find_index(square))
    end
    minmax = grid.squares.collect{|s| s.irradiance}.minmax
    color_bar = ColorBar.new(*minmax)
    grid.squares.each {|s| s.color_bar=color_bar }
  end
  
  # for the shadow cast onto the face only faces that are above the horizon
  # and on the front side of the face are relevant
  def find_shadow_faces(face)
    hor_base = face.bounds.min
    hor_normal = Geom::Vector3d.new(0,0,1)
    face_base = face.vertices[0].position
    face_normal = face.normal
    
    faces = []
    
    for f in Sketchup.active_model.active_entities.select{|f| f.typename=='Face'}
      for v in f.vertices
        if is_above_plane(v.position, hor_base, hor_normal) and
            is_above_plane(v.position, face_base, face_normal)
          faces.push f
          break
        end
      end
    end
    return faces
  end
  
  def integrate_grid_face(normal, shadow_caster)
    # integrate over all solar position and tsis for point
    irradiance = 0
    for state in @solar_data.states
      if state.vector%normal > 0 and !shadow_caster.has_shadow(state.vector)
        irradiance += (normal % state.vector) * state.tsi
      end
    end
    return irradiance
  end
  
  ## Little helpers
  def is_above_plane(point, plane_base, plane_normal)
      return (point - plane_base) % plane_normal > 0
  end
  
end
# a grid is the splitting of a face into small @squares
# all the small squares have the common @normal
class Grid
  attr_reader :squares, :normal, :area
  
  def initialize(face, grid_length)
    @face = face
    @grid_length = grid_length
    
    @group = Sketchup.active_model.entities.add_group
    
    bounding_box = attach_flat_bounding_box(face)
    
    v1 = bounding_box[1] - bounding_box[0]
    v2 = bounding_box[3] - bounding_box[0]
    l1 = v1.length / grid_length
    l2 = v2.length / grid_length
    @side1 = Geom::Vector3d.linear_combination(grid_length, v1.normalize, 0, v1)
    @side2 = Geom::Vector3d.linear_combination(grid_length, v2.normalize, 0, v1)
    # a cross product is a 2-form, doesn't have unit length, but area.
    # might be a problem depending on how unit conversion works ... keep an eye on it.
    @normal = @side1 * @side2
    @area = @normal.length
    @normal.normalize!
    base = bounding_box[0]
    
    progress_bar = ProgressBar.new(l1.floor*l2.floor, 'Creating squares...')
    @squares = []
    (0..l1).each do |i|
      (0..l2).each do |j|
        center = base + Geom::Vector3d.linear_combination(i+0.5,@side1,j+0.5,@side2)
        if face.classify_point(center) == 1
          # lift by 1cm so not to intersect with original face
          @squares.push Square.new(@group, center + @normal, @side1, @side2)
          progress_bar.update(i*l2.floor + j)
        end
      end
    end
  end  
end

# a square has a @center, @irradiance information and the reference
# to its visual representation @face
class Square
  attr_reader :center
  attr_accessor :irradiance, :color_bar
  
  def initialize(group, center, side1, side2)
    @center = center
    corner = center + Geom::Vector3d.linear_combination(-0.5,side1,-0.5,side2)
    @face = group.entities.add_face([corner, corner+side1, corner+side1+side2, corner+side2])
  end
  
  def color_bar=(color_bar)
    @color_bar = color_bar
    update_color
  end
  
  def update_color
    @face.material = @color_bar.to_color(@irradiance)
  end
end

class ColorBar
  def initialize(min, max)
    @min = min
    @max = max
  end
  def to_color(number)
    return [(number-@min) / (@max-@min), 0, 0]
  end
end

# information about all the sun paths, irradiances etc.
class SolarData
  attr_reader :states
  #@tsis = [500, 700, 1000, 700, 500] # total solar irradiation arriving at ground from the direction of the sun w/m^2
  
  def initialize
    @states = Array.new
    @day_times = 1..23
    # initialize states
    # only using single time for now
    model = Sketchup.active_model
    si=model.shadow_info
    t_old = si['ShadowTime']
    t = Time.new(2014)
    t_end = Time.new(2015)
    while t<t_end
      si['ShadowTime'] = t
      @states.push SolarState.new(si['SunDirection'],t, 1)
      t += 60*60
    end
    si['ShadowTime'] = t_old # restore initial time
    # generate states for times
    # initialize vectors given location on earth and time
    # initialize tsi (atmospheric thickness, cloud cover, etc.)
  end
end

class SolarState
  attr_reader :vector, :time, :tsi
  def initialize(vector, time, tsi)
    @vector = vector
    @time = time
    @tsi = tsi
  end
end

# determines if the @faces cast a shadow onto @position
# initialization is expensive, but calling has_shadow is fast
class ShadowCaster
  def initialize(position, faces)
    @hash_map = SphericalHashMap.new
    create_pyramids(position, faces)
  end
  
  # the center of a square (apex) and each mesh triangle (base) in 
  # shadow_faces define a pyramid, if the sun is 'in the pyramid direction',
  # then the mesh triangle casts a shadow onto center_point.
  # the pyramid (for us) is defined by the array of its three inward side plane
  # normals (we don't need the base)
  def create_pyramids(apex, faces)
    for face in faces
      mesh = face.mesh(0)
      for index in 1..mesh.count_polygons
        polygon = mesh.polygon_points_at(index).collect{|p| p-apex}
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
    for pyramid in @inclination_map.get_values(sun_direction)
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
  
end

$solar_integration = SolarIntegration.new
