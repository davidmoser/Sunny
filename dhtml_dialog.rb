require 'json'

class DhtmlDialog
  def initialize
    dialog_title = title(self.class.name)
    @dialog_name = underscore(self.class.name)
    
    @dialog = UI::WebDialog.new(dialog_title, true, 'solar_integration_' + @dialog_name, 400, 400, 150, 150, true)
    
    # initialize dialog values, then restore from file if saved
    initialize_values
    if File.exist? initialization_path
      file = File.open(initialization_path, 'r')
      deserialize(file.read)
    end
    
    if not @skip_variables
      @skip_variables = []
    end
    @skip_variables += ['@dialog', '@dialog_name', '@skip_variables', '@title']
    
    @dialog.set_file( template_path )
    @dialog.set_full_security
    
    @dialog.add_action_callback('return_data') do |dialog, json|
      puts json
      deserialize(json)
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
  
  def initialization_path
    directory = File.dirname(template_path)
    return File.join(directory, @dialog_name + '.json')
  end
  
  def template_path
    return Sketchup.find_support_file(@dialog_name + '.html', INSTALLATION_FOLDER)
  end
  
  def instance_variable_set(symbol, obj)
    super(symbol, obj)
    save
  end
  
  def save
    data = serialize
    File.open(initialization_path, 'w') { |f| f.write(data) }
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
