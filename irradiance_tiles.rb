require 'solar_integration/progress.rb'
require 'solar_integration/globals.rb'
require 'solar_integration/dhtml_dialog.rb'
require 'solar_integration/tile.rb'
require 'solar_integration/data_collector.rb'
require 'solar_integration/tiles_observer.rb'

class IrradianceTiles < DataCollector
  
  def initialize(grid)
    @grid = grid
    @group = grid.face.parent.entities.add_group
    @group.name = 'Irradiance Tiles'
    save_to_model('total_area', grid.total_area)
    @group.add_observer(TilesObserver.new)
    
    progress = Progress.new(grid.number_of_subsquares, 'Creating tiles')
    @tiles = Hash.new
    grid.squares.each do |square|
      square.points.each do |p|
        @tiles[p] = Tile.new(@group, p, grid.subside1, grid.subside2)
        progress.work
      end
    end
    progress.finish
    
    @contribution_per_state = $solar_integration.sun_data.contribution_per_state
    
    @coloring_allowed = false
    @section_irradiances = Hash.new(0)
    @statistics = $solar_integration.statistics
    @scale = @statistics.scale
    @statistics.add_tile_group(@group)
  end
  
  def prepare_section(sun_state, irradiance, section)
    @section_irradiances[section] += irradiance # % of W/m2
  end
  
  def section_preparation_finished
    @max_irradiance = @section_irradiances.values.reduce(0,:+) * @contribution_per_state # W/m2
    save_to_model('max_irradiance', @max_irradiance)
  end
  
  def current_point=(current_point)
    if @current_tile
      tile_wrapup(@current_tile)
    end
    @current_tile = @tiles[current_point]
    @current_irradiance = 0
  end
  
  def put(sun_state, irradiance)
    return if not irradiance
    @current_irradiance += irradiance # W/m2
  end

  def put_section(section)
    @current_irradiance += @section_irradiances[section]
  end
  
  def tile_wrapup(tile)
    tile.irradiance = @current_irradiance * @contribution_per_state # kWh/m2
    tile.relative_irradiance = tile.irradiance * 100 / @max_irradiance
    @scale.recolor(tile.face)
  end
  
  def wrapup
    tile_wrapup(@current_tile)
    total_irradiation = @tiles.values.collect{|s|s.irradiance}.reduce(:+) * @grid.tile_area
    save_to_model('total_irradiation', total_irradiation)
    @coloring_allowed = true
    @statistics.update_values
  end
  
  def save_to_model(name, value)
    @group.set_attribute 'solar_integration', name, value
  end
end