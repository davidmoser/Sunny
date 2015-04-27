require 'solar_integration/progress.rb'

# information about the sun positions, irradiances etc.
class SunData
  attr_reader :states, :wh_per_m2
  
  # randomly selects sun states, choosing e.g. a state every full hour for each
  # day is very bad sampling (small differences between days, large differences
  # between hours).
  def initialize(configuration)
    @states = Array.new
    
    minutes_per_year = 365 * 24 * 60 * 60
    
    hours_per_state = Float(minutes_per_year) / configuration.sun_states
    @wh_per_m2 = hours_per_state * configuration.tsi
    
    # initialize states
    # TODO: don't use Sketchup, it's slow (ui feedback)
    # TODO: determine local tsi (atmospheric thickness, cloud cover, etc.)
    si = Sketchup.active_model.shadow_info
    t_old = si['ShadowTime']

    while @states.length < configuration.sun_states
      t = Time.at(rand(60*minutes_per_year))
      si['ShadowTime'] = t
      local_vector = si['SunDirection']
      # only interested in day time sun states
      if local_vector[2]>0
        @states.push SunState.new(local_vector,t, 1)
      end
    end
      
    si['ShadowTime'] = t_old # restore initial time
  end
end

class SunState
  attr_reader :vector, :time, :tsi, :local_vector
  def initialize(local_vector, time, tsi)
    @local_vector = local_vector
    @vector = local_vector.transform(SUN_TRANSFORMATION)
    @time = time
    @tsi = tsi
  end
end

# to debug the hash map
class SunDataVisualizationSphere
  def initialize(sun_data, entities, center)
    @group = entities.add_group
    @radius = 30
    
    progress = Progress.new(sun_data.states.length, 'Creating sun data sphere...')
    Sketchup.active_model.start_operation('Creating sund data sphere', true)
    p_old = center
    sun_data.states.each do |s|
      p_new = center + s.local_vector.transform(@radius)
      @group.entities.add_edges(p_old, p_new)
      p_old = p_new
      progress.work
    end
    Sketchup.active_model.commit_operation
  end
end