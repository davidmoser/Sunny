require 'json'

class DhtmlDialog
  def initialize
    initialize_values
    class_name = self.class.name
    
    @dialog = UI::WebDialog.new(title(class_name), true, 'solar_integration_' + underscore(class_name), 400, 400, 150, 150, true)
    
    if not @skip_variables
      @skip_variables = []
    end
    @skip_variables += ['@dialog', '@skip_variables', '@title']
    
    #saved = Sketchup.find_support_file @template_name, INSTALLATION_FOLDER
    
    path = Sketchup.find_support_file(underscore(class_name) + '.html', INSTALLATION_FOLDER)
    @dialog.set_file( path )
    @dialog.set_full_security
    
    @dialog.add_action_callback('return_data') do |dialog, json|
      puts json
      deserialize(json)
    end
    
    @dialog.add_action_callback('force_update_dialog') do |dialog|
      update_dialog
    end
    
    @dialog.add_action_callback('reset') do |dialog|
      initialize_values
    end
  end
  
  def update_dialog
    script = "receiveData(#{serialize});"
    @dialog.execute_script(script)
  end
  
  def serialize
    hash = Hash[
      instance_variables
            .select{|v|!@skip_variables.include?(v.to_s)}
            .select{|v|v.to_s.start_with?('@')}
            .collect { |v| [v[1..-1], instance_variable_get(v)] }]
    return JSON.generate(hash)
  end
  
  def deserialize(data)
      fields = JSON.parse(data, symbolize_names: true)
      fields.each do |k, v|
        self.send("#{k}=", v)
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
