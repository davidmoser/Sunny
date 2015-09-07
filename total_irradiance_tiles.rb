require 'solar_integration/progress.rb'
require 'solar_integration/globals.rb'
require 'solar_integration/dhtml_dialog.rb'
require 'solar_integration/tile.rb'
require 'solar_integration/data_collector.rb'

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
    @contribution_per_state = $solar_integration.sun_data.contribution_per_state
    @ghi_factor = $solar_integration.sun_data.ghi_factor
    Sketchup.active_model.commit_operation
    
    @coloring_allowed = false
    @section_irradiances = Hash.new(0)
    @scale = $irradiance_statistics.scale
    $irradiance_statistics.add_tiles(self)
  end
  
  def prepare_section(sun_state, irradiance, section)
    @section_irradiances[section] += irradiance # % of W/m2
  end
  
  def section_preparation_finished
    @max_irradiance = @section_irradiances.values.reduce(0,:+) * @contribution_per_state # W/m2
    @scale.update_tile_colors
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
    tile.irradiance *= @contribution_per_state # kWh/m2
    tile.relative_irradiance = tile.irradiance * 100 / @max_irradiance
    @scale.recolor(tile)
  end
  
  def update_tile_colors
    return if not @coloring_allowed
    for tile in @tiles.values
      @scale.recolor(tile)
    end
  end
end