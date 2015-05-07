require 'json'

class WebConfiguration
  
  def initialize
    @dialog = UI::WebDialog.new('Nice configuration', true, 'solar_integration_configuration', 400, 400, 150, 150, true)
    @data = {:square_length => 0.1, :sun_states => 1000}
    
    path = Sketchup.find_support_file 'configuration.html', INSTALLATION_FOLDER
    @dialog.set_file( path )
    
    @dialog.add_action_callback('put_data') do |dialog, json|
      @data = JSON.parse(json, symbolize_names: true)
      UI.messagebox("Value is #{@data[:square_length]}")
    end
    
    @dialog.add_action_callback('get_data') do |dialog|
      json = JSON.generate(@data)
      script = "data =#{json};"
      dialog.execute_script(script)
    end
  end
  
  def show
    @dialog.show
  end
end
