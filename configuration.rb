require 'solar_integration/dhtml_dialog.rb'
require 'solar_integration/data_collector.rb'

class Configuration < DhtmlDialog
  attr_accessor :sun_states, :tile_length, :tsi,
    :infer_square_length_from_face, :square_length, :inclination_cutoff, :sky_section_size,
    :active_data_collectors, :advanced_options_on, :assume_faces_up
  
  def initialize_values
    @skip_variables = ['@active_data_collectors']
    @sun_states = 1000
    @tile_length = 0.3 # m
    @tsi = 250 # W/m^2
    @advanced_options_on = false
    @infer_square_length_from_face = true
    @square_length = 3 # m
    @inclination_cutoff = 10 # degrees
    @sky_section_size = 5 # degrees
    @assume_faces_up = true
    @active_data_collectors = [TotalIrradianceTiles] # not configurable at the moment
  end
  
end

