
class Configuration
  attr_reader :hash_map_class, :grid_length, :sub_divisions, \
              :active_data_collectors, :inclination_cutoff, \
              :sun_states, :tsi
    
  def initialize
    @grid_length = 3
    @sub_divisions = 10
    @inclination_cutoff = 10
    @hash_map_class = SphericalHashMap
    @active_data_collectors = [TotalIrradianceSquares]
    @sun_states = 1000
    @tsi = 700 # W/m^2
  end
  
  def add_prompt(prompt, default, list)
    @prompts.push prompt
    @defaults.push default
    @lists.push list
  end
  
  def update
    # this handling is ugly, create parameter classes
    
    @prompts = []
    @defaults = []
    @lists = []
    
    add_prompt 'Grid length (m)', @grid_length, ''
    add_prompt 'Number of sub divisions', @sub_divisions, ''
    add_prompt 'Inclination cutoff (degree)', @inclination_cutoff, ''
    
    @hash_map_classes = ObjectSpace.each_object(Class).select { |c| c < AbstractHashMap }
    add_prompt 'Hash map class', @hash_map_class.to_s, @hash_map_classes.join('|')
    
    add_prompt 'Number of sun states', @sun_states, ''
    add_prompt 'TSI (W/m^2)', @tsi, ''
    
    @data_collectors = ObjectSpace.each_object(Class).select{|c| c < DataCollector}
    @data_collectors.each do |dc|
      add_prompt dc.to_s, (@active_data_collectors.include? dc)? 'active':'inactive', 'active|inactive' 
    end
    
    input = UI.inputbox(@prompts, @defaults, @lists, 'Solar Integration Parameters')
    return if not input
    
    @grid_length = input[0].to_i
    @sub_divisions = input[1].to_i
    @inclination_cutoff = input[2].to_i
    @hash_map_class = @hash_map_classes.find{|c| c.to_s==input[3]}
    
    @sun_states = input[4].to_i
    @tsi = input[5].to_i
    
    @active_data_collectors = []
    i = 6
    @data_collectors.each do |dc|
      @active_data_collectors.push dc if input[i]=='active'
      i += 1
    end
    
  end
end

