require 'solar_integration/dhtml_dialog.rb'

class Configuration < DhtmlDialog
  attr_reader :grid_length, :tsi, :infer_square_length_from_face, :square_length,
    :sun_states, :inclination_cutoff, :sky_section_size
  
  def initialize
    @dialog = UI::WebDialog.new('Nice configuration', true, 'solar_integration_configuration', 400, 400, 150, 150, true)
    @template_name = 'configuration.html'
    super
    @sun_states = 1000
    @grid_length = 30 #cm
    @tsi = 700 # W/m^2
    @advanced_options_on = false
    @infer_square_length_from_face = true
    @square_length = 300 #cm
    @inclination_cutoff = 10 # degrees
    @sky_section_size = 10 # degrees
  end
  
  def outside_call_test
    @sun_states += 1
    update_dialog
  end
  
end

