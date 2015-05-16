require 'solar_integration/progress.rb'
require 'solar_integration/globals.rb'
require 'solar_integration/dhtml_dialog.rb'

class DataCollector
  # during shadow calculation the current point for which all sun states
  # are rendered, i.e. shadow is checked, is set to this variable
  attr_writer :current_point
  
  def initialize(grid)
  end
  
  # for performance reasons the sky is split in sections
  # before rendering shadows all sections are rendered with all sun states
  # i.e. as if there was no shadow at all, that accumulated data for a section
  # can then be used when during shadow calculation it is evident that there's
  # no shadow cast for a particular section, in which case put_section is called
  def prepare_section(sun_state, irradiance, section)
  end
  
  # all sections have been rendered
  def section_preparation_finished
  end

  # called during shadow rendering.
  # sun shines with strength irradiance on @current_point
  # if @current_point is in the shadow then irradiance=nil.
  def put(sun_state, irradiance)
  end
  
  # if for @current_point there aren't any shadow casting polygons
  # from a certain sky section, then this method is called instead of put
  def put_section(section)
  end
  
  def wrapup
  end
end

class TotalIrradianceTiles < DataCollector
  attr_accessor :group, :tiles, :max_irradiance, :color_bar
  
  def initialize(grid)
    @group = grid.face.parent.entities.add_group
    @group.name = 'Irradiance Tiles'
    
    progress = Progress.new(grid.number_of_subsquares, 'Creating tiles...')
    Sketchup.active_model.start_operation('Creating tiles', true)
    @tiles = Hash.new
    grid.squares.each do |square|
      square.points.each do |p|
        @tiles[p] = Tile.new(@group, p, grid.subside1, grid.subside2)
        progress.work
      end
    end
    Sketchup.active_model.commit_operation
    
    @coloring_allowed = false
    @section_irradiances = Hash.new(0)
    $irradiance_statistics.add_tiles(self)
  end
  
  def prepare_section(sun_state, irradiance, section)
    @section_irradiances[section] += irradiance
  end
  
  def section_preparation_finished
    @max_irradiance = @section_irradiances.values.reduce(:+)
    $irradiance_statistics.update_tile_colors
  end
  
  def current_point=(current_point)
    if @current_tile
      @current_tile.recolor(@color_bar)
    end
    @current_tile = @tiles[current_point]
  end
  
  def put(sun_state, irradiance)
    return if not irradiance
    @current_tile.irradiance += irradiance
  end

  def put_section(section)
    @current_tile.irradiance += @section_irradiances[section]
  end
  
  def wrapup
    @current_tile.recolor(@color_bar)
    @tiles.values.each do |s|
      s.face.set_attribute 'solar_integration', 'total_irradiance', s.irradiance
    end
    @coloring_allowed = true
  end
  
  def update_tile_colors
    return if not @coloring_allowed
    for tile in @tiles.values
      tile.recolor(@color_bar)
    end
  end
end

# singleton to hold all rendered tiles, color them, sum up irradiance
class IrradianceStatistics < DhtmlDialog
  attr_reader :tile_groups, :color_by_relative_value
  
  def initialize
    @dialog = UI::WebDialog.new('Nice configuration', true, 'solar_integration_configuration', 400, 400, 150, 150, true)
    @template_name = 'irradiance_statistics.html'
    @skip_variables = ['@tiless']
    super()
    @tiless = []
    @color_by_relative_value = true
  end
  
  def add_tiles(tiles)
    @tiless.push tiles
  end
  
  def create_color_bar(tiles)
    if @color_by_relative_value
      color_bar = RelativeColorBar.new(0.8,1)
      color_bar.max_number = tiles.max_irradiance
    else
      max = @tiless.collect{|t|t.max_irradiance}.max
      color_bar = AbsoluteColorBar.new(0.8*max, max)
    end
    return color_bar
  end
  
  def update_tile_colors
    for tiles in @tiless
      tiles.color_bar = create_color_bar(tiles)
      tiles.update_tile_colors
    end
  end
  
  def color_by_relative_value=(color_by_relative_value)
    @color_by_relative_value = color_by_relative_value
    update_tile_colors
  end
  
end

# a square has a @center, @irradiance information and the reference
# to its visual representation @face
class Tile
  attr_accessor :irradiance, :face
  
  def initialize(group, center, side1, side2)
    @irradiance = 0
    @center = center
    corner = center + Geom::Vector3d.linear_combination(-0.5,side1,-0.5,side2)
    @face = group.entities.add_face([corner, corner+side1, corner+side1+side2, corner+side2])
    @face.edges.each{|e|e.hidden=true}
  end
  
  def recolor(color_bar)
    @face.material=color_bar.to_color(@irradiance)
  end
end

class AbsoluteColorBar
  def initialize(min, max)
    @min = min
    @max = max
  end
  
  def to_color(number)
    return [(number-@min) / (@max-@min), 0, 0]
  end
end

class RelativeColorBar < AbsoluteColorBar
  attr_accessor :max_number
  
  def to_color(number)
    fraction = number / @max_number
    return [(fraction-@min) / (@max-@min), 0, 0]
  end
end

class PolarAngleIrradianceHistogram < DataCollector
  def initialize(grid)
    @histogram = Hash.new(0)
    @bin_size = to_radian(1)
  end
  
  def put(sun_state, irradiance)
    return if not irradiance
    v = sun_state.vector
    rho = Math::hypot(v[0], v[1])
    polar_angle = Math::atan2(rho, v[2])
    bin = to_degree((polar_angle / @bin_size).floor * @bin_size)
    @histogram[bin] += irradiance
  end
  
  def wrapup
    @histogram = @histogram.sort_by { |a,i| a }
    File.open('polar_angle_histogram.txt', 'w') do |file|
      @histogram.each { |a,i| file.write("#{a},#{i}\n") }
    end
  end
end