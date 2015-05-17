require 'json'

class DhtmlDialog
  def initialize
    if not @dialog
      raise 'initialize @dialog with a webdialog'
      # e.g. @dialog = UI::WebDialog.new('Nice configuration', true, 'solar_integration_configuration', 400, 400, 150, 150, true)
    end
    if not @template_name
      raise 'initialize @template_name with name of html file'
      # e.g. @template_name = 'configuration.html'
    end
    if not @skip_variables
      @skip_variables = []
    end
    @skip_variables += ['@dialog', '@template_name', '@skip_variables']
    
    path = Sketchup.find_support_file @template_name, INSTALLATION_FOLDER
    @dialog.set_file( path )
    @dialog.set_full_security
    
    @dialog.add_action_callback('return_data') do |dialog, json|
      puts json
      data = JSON.parse(json, symbolize_names: true)
      data.each do |k, v|
        self.send("#{k}=", v)
      end
    end
    
    @dialog.add_action_callback('force_update_dialog') do |dialog|
      update_dialog
    end
  end
  
  def update_dialog
    script = "receiveData(#{create_json});"
    @dialog.execute_script(script)
  end
  
  def create_json
    hash = Hash[
      instance_variables
            .select{|v|!@skip_variables.include?(v.to_s)}
            .select{|v|v.to_s.start_with?('@')}
            .collect { |v| [v[1..-1], instance_variable_get(v)] }]
    return JSON.generate(hash)
  end
  
  def show
    @dialog.show
  end
end
