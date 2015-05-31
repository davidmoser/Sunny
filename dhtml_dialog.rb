require 'solar_integration/json_serialization.rb'

class DhtmlDialog < JsonSerialization
  def initialize
    dialog_title = title(self.class.name)
    @dialog_name = underscore(self.class.name)
    
    @dialog = UI::WebDialog.new(dialog_title, true, 'solar_integration_' + @dialog_name, 400, 400, 150, 150, true)
    
    # initialize dialog values, then restore from file if saved
    initialize_values
    if File.exist? initialization_path
      file = File.open(initialization_path, 'r')
      update_from_json(file.read)
    end
    
    if not @skip_variables
      @skip_variables = []
    end
    @skip_variables += ['@dialog', '@dialog_name', '@title']
    
    @dialog.set_file( template_path )
    @dialog.set_full_security
    
    @dialog.add_action_callback('return_data') do |dialog, json|
      puts json
      update_from_json(json)
      save
    end
    
    @dialog.add_action_callback('force_update_dialog') do |dialog|
      update_dialog
    end
    
    @dialog.add_action_callback('reset') do |dialog|
      initialize_values
    end
  end
  
  def update_dialog
    script = "receiveData(#{to_json(nil)});"
    @dialog.execute_script(script)
  end
  
  def initialization_path
    directory = File.dirname(template_path)
    return File.join(directory, @dialog_name + '.json')
  end
  
  def template_path
    return Sketchup.find_support_file(@dialog_name + '.html', INSTALLATION_FOLDER)
  end
  
  def save
    data = to_json(nil)
    File.open(initialization_path, 'w') { |f| f.write(data) }
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
