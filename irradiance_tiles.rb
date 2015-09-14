require 'sketchup.rb'
require 'solar_integration/progress.rb'
require 'solar_integration/globals.rb'
require 'solar_integration/dhtml_dialog.rb'
require 'solar_integration/tile.rb'
require 'solar_integration/data_collector.rb'

class IrradianceTiles < DataCollector
  attr_accessor :group, :tiles, :max_irradiance, :total_irradiation, :grid

  class TilesObserver < Sketchup::EntityObserver
    def onEraseEntity(entity)
      $irradiance_statistics.update_values
    end
  end
  
  def initialize(grid)
    @grid = grid
    @group = grid.face.parent.entities.add_group
    @group.name = 'Irradiance Tiles'
    @group.set_attribute 'solar_integration', 'exists', true # marking the group
    @group.add_observer(TilesObserver.new)
    
    progress = Progress.new(grid.number_of_subsquares, 'Creating tiles...')
    Sketchup.active_model.start_operation('Creating tiles', true)
    @tiles = Hash.new
    grid.squares.each do |square|
      square.points.each do |p|
        @tiles[p] = Tile.new(@group, p, grid.subside1, grid.subside2)
        progress.work
      end
    end
    
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
    @scale.recolor(tile)
  end
  
  def wrapup
    tile_wrapup(@current_tile)
    @total_irradiation = @tiles.values.collect{|s|s.irradiance}.reduce(:+) * @grid.tile_area
    @coloring_allowed = true
    $irradiance_statistics.update_values
  end
 
  def update_tile_colors
    return if not @coloring_allowed
    for tile in @tiles.values
      @scale.recolor(tile)
    end
  end
end