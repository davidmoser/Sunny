


class SkySections
  def initialize(sun_states, angular_resolution, configuration)
    @configuration = configuration
    @angular_resolution = angular_resolution
    hash_map = get_new_hash_map
    
    @hash_to_section = Hash.new{|m,k| m[k]=SkySection.new(k)}
    for state in sun_states
      hash = hash_map.get_hash(state.vector)
      @hash_to_section[hash].sun_states.push state
    end
  end
  
  def sections
    return @hash_to_section.values
  end
  
  def get_new_hash_map
    @configuration.hash_map_class.new(@angular_resolution)
  end
  
end


class SkySection
  attr_reader :sun_states, :index
  
  def initialize(index)
    @index = index
    @sun_states = []
  end
end

