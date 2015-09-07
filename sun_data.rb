require 'solar_integration/progress.rb'
require 'solar_integration/globals.rb'

# information about the sun positions, irradiances etc.
class SunData
  attr_reader :states, :contribution_per_state, :ghi_factor
  
  def initialize
    @number_of_states = nil
    @contribution_per_state = nil
  end
  
  # randomly selects sun states, choosing e.g. a state every full hour for each
  # day is very bad sampling (small differences between days, large differences
  # between hours).
  def update
    if not @number_of_states==$configuration.sun_states
      load_sun_states
    end
    
    calculate_contribution_per_state
  end
  
  def load_sun_states
    @number_of_states = $configuration.sun_states
    @states = Array.new
    
    # initialize states
    # TODO: don't use Sketchup, it's slow (ui feedback)
    si = Sketchup.active_model.shadow_info
    t_old = si['ShadowTime']

    seconds_per_year = 365 * 24 * 60 * 60
    while @states.length < @number_of_states
      t = Time.at(rand(seconds_per_year))
      si['ShadowTime'] = t
      local_vector = si['SunDirection']
      # only interested in day time sun states
      if local_vector[2]>0
        @states.push SunState.new(local_vector,t)
      end
    end
      
    si['ShadowTime'] = t_old # restore initial time
  end
  
  def calculate_contribution_per_state
    total_z_component = 0
    for state in @states
      vector = state.local_vector
      z_component = vector%Z_AXIS
      if z_component > 0
        total_z_component += z_component
      end
    end
    
    # how much one state contributes to the yearly average
    # divide by 2 because we consider day times only
    @contribution_per_state = $configuration.global_horizontal_irradiation / total_z_component
  end
end

class SunState
  attr_reader :vector, :duration, :local_vector
  def initialize(local_vector, time)
    @local_vector = local_vector
    @vector = local_vector.transform(SUN_TRANSFORMATION)
    @time = time
  end
end

# to debug the hash map
class SunDataVisualizationSphere
  def initialize(sun_data, entities, center)
    @group = entities.add_group
    @radius = 30
    
    progress = Progress.new(sun_data.states.length, 'Creating sun data sphere...')
    Sketchup.active_model.start_operation('Creating sun data sphere', true)
    sun_data.states.each do |s|
      point = center + s.local_vector.transform(@radius)
      @group.entities.add_cpoint(point)
      progress.work
    end
    Sketchup.active_model.commit_operation
  end
end