require 'solar_integration/dhtml_dialog.rb'
require 'solar_integration/irradiance_tiles.rb'

class Configuration < DhtmlDialog
  attr_accessor :sun_states,
    :tile_length,
    :advanced_options_on,
    :infer_square_length_from_face,
    :square_length,
    :inclination_cutoff,
    :sky_section_size,
    :assume_faces_up,
    :global_horizontal_irradiation,
    :cell_efficiency,
    :system_losses,
    :active_data_collectors
  
  def initialize
    @skip_variables = ['@active_data_collectors']
    @active_data_collectors = [IrradianceTiles] # not configurable at the moment
    super
  end
  
  def initialize_values
    @sun_states = 1000
    @tile_length = 0.3 # m
    @advanced_options_on = false
    @infer_square_length_from_face = true
    @square_length = 3 # m
    @inclination_cutoff = 10 # degrees
    @sky_section_size = 5 # degrees
    @assume_faces_up = true
    @global_horizontal_irradiation = 1200 # kWh / m2 / year, central europe
    @cell_efficiency = 20 # %
    @system_losses = 11 # 8% temperature, 3% reflection
  end
end

