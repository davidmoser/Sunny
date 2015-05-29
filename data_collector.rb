require 'solar_integration/progress.rb'
require 'solar_integration/globals.rb'
require 'solar_integration/dhtml_dialog.rb'

class DataCollector
  # during shadow calculation the current point for which all sun states
  # are rendered, i.e. shadow is checked, is set to this variable
  attr_writer :current_point
  
  def initialize(grid, sun_data)
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
  attr_accessor :group, :tiles, :max_irradiance, :total_irradiation
  
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
    @tile_area = grid.tile_area
    @h_per_state = $solar_integration.sun_data.hours_per_state
    Sketchup.active_model.commit_operation
    
    @coloring_allowed = false
    @section_irradiances = Hash.new(0)
    @color_bar = $irradiance_statistics.color_bar
    $irradiance_statistics.add_tiles(self)
  end
  
  def prepare_section(sun_state, irradiance, section)
    @section_irradiances[section] += irradiance # W/m2
  end
  
  def section_preparation_finished
    @max_irradiance = @section_irradiances.values.reduce(0,:+) * @h_per_state / 1000 # kWh/m2
    $irradiance_statistics.update_color_bar
  end
  
  def current_point=(current_point)
    if @current_tile
      tile_wrapup(@current_tile)
    end
    @current_tile = @tiles[current_point]
  end
  
  def put(sun_state, irradiance)
    return if not irradiance
    @current_tile.irradiance += irradiance # W/m2
  end

  def put_section(section)
    @current_tile.irradiance += @section_irradiances[section]
  end
  
  def wrapup
    tile_wrapup(@current_tile)
    @total_irradiation = 0
    @tiles.values.each do |s|
      s.face.set_attribute 'solar_integration', 'irradiance', s.irradiance
      s.face.set_attribute 'solar_integration', 'relative_irradiance', s.relative_irradiance
      @total_irradiation += s.irradiance * @tile_area # kWh
    end
    @coloring_allowed = true
    $irradiance_statistics.integration_finished
  end
  
  def tile_wrapup(tile)
    tile.irradiance *= @h_per_state / 1000 # kWh/m2
    tile.relative_irradiance = tile.irradiance * 100 / @max_irradiance
    @color_bar.recolor(tile)
  end
  
  def update_tile_colors
    return if not @coloring_allowed
    for tile in @tiles.values
      @color_bar.recolor(tile)
    end
  end
end

# singleton to hold all rendered tiles, color them, sum up irradiance
class IrradianceStatistics < DhtmlDialog
  attr_accessor :tile_groups, :color_by_relative_value, :color_bar,
    :color_bar_value, :max_irradiance, :total_irradiation
  
  def initialize
    @dialog = UI::WebDialog.new('Nice configuration', true, 'solar_integration_configuration', 400, 400, 150, 150, true)
    @template_name = 'irradiance_statistics.html'
    @skip_variables = ['@tiless','@color_bar']
    super()
    @tiless = []
    @color_by_relative_value = true
    @color_bar = ColorBar.new
    @max_irradiance = 10000
    update_color_bar
  end
  
  def add_tiles(tiles)
    @tiless.push tiles
  end
  
  def update_color_bar
    old_color_bar = @color_bar.clone
    @color_bar.color_by_relative_value = @color_by_relative_value
    if active_tiless.length>0
      @max_irradiance = active_tiless.collect{|t|t.max_irradiance}.max or @max_irradiance
    end
    if @color_by_relative_value
      max = 100
    else
      max = @max_irradiance
    end
    @color_bar.min = 0.8*max
    @color_bar.max = max
    if not @color_bar == old_color_bar
      update_tile_colors
    end
  end
  
  def update_tile_colors
    update_color_bar
    active_tiless.each{|t|t.update_tile_colors}
  end
  
  def color_by_relative_value=(color_by_relative_value)
    if not @color_by_relative_value == color_by_relative_value
      @color_by_relative_value = color_by_relative_value
      set_color_bar_value(nil, nil)
      update_color_bar
    end
  end
  
  def set_color_bar_value(irradiance, relative_irradiance)
    if @color_by_relative_value
      @color_bar_value = relative_irradiance
    else
      @color_bar_value = irradiance
    end
    puts @color_bar_value
    update_dialog
  end
  
  def active_tiless
    @tiless.reject! {|t| t.group.deleted?}
    return @tiless
  end
  
  def integration_finished
    @total_irradiation = active_tiless.collect{|t|t.total_irradiation}.reduce(:+)
    update_dialog
  end
end

# a square has a @center, @irradiance information and the reference
# to its visual representation @face
class Tile
  attr_accessor :irradiance, :relative_irradiance, :face
  
  def initialize(group, center, side1, side2)
    @center = center
    corner = center + Geom::Vector3d.linear_combination(-0.5,side1,-0.5,side2)
    @face = group.entities.add_face([corner, corner+side1, corner+side1+side2, corner+side2])
    @face.edges.each{|e|e.hidden=true}
    @irradiance = 0
  end
end

class ColorBar
  attr_accessor :min, :max, :color_by_relative_value
  
  def recolor(tile)
    if @color_by_relative_value
      number = tile.relative_irradiance
    else
      number = tile.irradiance
    end
    tile.face.material = [(number-@min) / (@max-@min), 0, 0]
  end
  
  def ==(o)
    o.class == self.class && o.state == state
  end
  
  def state
    [@min, @max, @color_by_relative_value]
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