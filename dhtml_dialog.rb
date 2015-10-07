require 'solar_integration/json_serialization.rb'
require 'json'
require 'sketchup.rb'

class DhtmlDialog < JsonSerialization
  def initialize
    dialog_title = title(self.class.name)
    @dialog_name = underscore(self.class.name)
    
    @dialog = UI::WebDialog.new(dialog_title, true, 'solar_integration_' + @dialog_name, 400, 400, 150, 150, true)
    
    update
    
    if not @skip_variables
      @skip_variables = []
    end
    @skip_variables += ['@dialog', '@dialog_name', '@title', '@saving_allowed']
    
    @dialog.set_file( template_path )
    
    @dialog.add_action_callback('return_data') do |dialog, json|
      puts json
      update_from_json(json)
      if @saving_allowed
        save_to_model
      end
      @saving_allowed = true
    end
    
    @dialog.add_action_callback('puts') do |dialog, text|
      puts text
    end

    @dialog.add_action_callback('force_update_dialog') do |dialog|
      update_dialog
    end
    
    @dialog.add_action_callback('reset') do |dialog|
      initialize_values
    end
    
    @dialog.add_action_callback('puts') do |dialog, text|
      puts text
    end
    
    @dialog.add_action_callback('set_default') do |dialog|
      result = UI.messagebox('Are you sure you want to save the current settings as default?', MB_YESNO)
      if result == IDYES
        save_to_file
        UI.messagebox('Settings have been saved.')
      end
    end
  end
  
  def update_dialog
    script = "receiveData(#{to_json(nil)});"
    @dialog.execute_script(script)
  end
  
  def default_file_path
    directory = File.dirname(template_path)
    return File.join(directory, @dialog_name + '.json')
  end
  
  def template_path
    return Sketchup.find_support_file(@dialog_name + '.html', INSTALLATION_FOLDER)
  end
  
  def save_to_file
    data = to_json(nil)
    File.open(default_file_path, 'w') { |f| f.write(data) }
  end
  
  def save_to_model
    data = to_json(nil)
    Sketchup.active_model.set_attribute('solar_integration', @dialog_name, data)
  end
  
  def update
    @saving_allowed = !@dialog.visible? # prevent saving from dialog callback
    initialize_values # Plugin default
    update_from_file # Saved Sketchup-wide default
    update_from_model # Model settings
    update_dialog
  end
  
  def update_from_file
    if File.exist? default_file_path
      file = File.open(default_file_path, 'r')
      update_from_json(file.read)
    end
  end
  
  def update_from_model
    data = Sketchup.active_model.get_attribute('solar_integration', @dialog_name)
    if data
      update_from_json(data)
    end
  end
  
  def show
    @dialog.show
  end
  
  def underscore(camel_cased_word)
    camel_cased_word.to_s.gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
      .gsub(/([a-z\d])([A-Z])/,'\1_\2')
      .tr("-", "_")
      .downcase
  end
  
  def title(camel_cased_word)
    camel_cased_word.to_s.gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/,'\1 \2')
      .gsub(/([a-z\d])([A-Z])/,'\1 \2')
      .tr("-", "_")
  end
end
