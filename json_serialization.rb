require 'json'

class JsonSerialization
  def to_json(options)
    if not @skip_variables
      @skip_variables = []
    end
    if not @skip_variables.include? '@skip_variables'
      @skip_variables.push '@skip_variables'
    end

    data = Hash[
      instance_variables
            .select{|v|!@skip_variables or !@skip_variables.include?(v.to_s)}
            .select{|v|v.to_s.start_with?('@')}
            .collect { |v| [v[1..-1], instance_variable_get(v)] }]

    data['ruby_class'] = self.class.name
    return data.to_json(options)
  end
  
  def update_from_json(json)
    hash = JSON.parse(json, symbolize_names: true)
    update_from_hash(hash)
  end
  
  def update_from_hash(hash)
    hash.each do |k, v|
      next if k == 'ruby_class'
      if v.class == Hash and v.include? :ruby_class
        sub_obj = instance_variable_get('@' + k.to_s)
        if not sub_obj
          sub_obj = Object.const_get(v[:ruby_class]).new
        end
        sub_obj.update_from_hash(v)
      elsif self.class.method_defined? "#{k}="
        send("#{k}=", v)
      else
        instance_variable_set('@' + k.to_s, v)
      end
    end
  end
  
  def self.from_json(data)
    obj = self.new
    self.update_from_json(obj, data)
  end
end