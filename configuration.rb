require 'solar_integration/dhtml_dialog.rb'
require 'solar_integration/data_collector.rb'

class Configuration < DhtmlDialog
  attr_reader :sun_states, :grid_length, :tsi,
    :infer_square_length_from_face, :square_length, :inclination_cutoff, :sky_section_size,
    :active_data_collectors
  
  def initialize
    @dialog = UI::WebDialog.new('Nice configuration', true, 'solar_integration_configuration', 400, 400, 150, 150, true)
    @template_name = 'configuration.html'
    @skip_variables = ['@active_data_collectors']
    super
    @sun_states = 1000
    @grid_length = 30 #cm
    @tsi = 700 # W/m^2
    @advanced_options_on = false
    @infer_square_length_from_face = true
    @square_length = 300 #cm
    @inclination_cutoff = 10 # degrees
    @sky_section_size = 10 # degrees
    @active_data_collectors = [TotalIrradianceSquares] # not configurable at the moment
  end
  
end

