require 'solar_integration/globals.rb'

class SkySections
  def initialize(irradiances, data_collectors)
    hash_map = SphericalHashMap.new
    
    @hash_to_section = Hash.new{|m,k| m[k]=SkySection.new(k)}
    for state in irradiances.keys
      hash = hash_map.get_hash(state.vector)
      @hash_to_section[hash].sun_states.push state
    end
    
    prepare_sections(irradiances, data_collectors)
    
    data_collectors.each{|c|c.section_preparation_finished}
  end
  
  def sections
    return @hash_to_section.values
  end
  
  def prepare_sections(irradiances, data_collectors)
    for s in sections.each
      for state in s.sun_states
        data_collectors.each {|c| c.prepare_section(state, irradiances[state], s)}
      end
    end
  end
end

class SkySection
  attr_reader :sun_states, :index
  
  def initialize(index)
    @index = index
    @sun_states = []
  end
end

