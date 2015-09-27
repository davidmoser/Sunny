require 'solar_integration/progress.rb'
require 'solar_integration/globals.rb'

# information about the sun positions, irradiances etc.
class SunData
  attr_reader :states, :contribution_per_state, :sun_transformation
  
  def initialize
    @states = nil
    @contribution_per_state = nil
  end
  
  # is called before integrating a face
  # because recalculation is expensive check for individual parameter changes
  def update
    si = Sketchup.active_model.shadow_info
    la_changed = update_parameter('latitude', si['Latitude'])
    lo_changed = update_parameter('longitude', si['Longitude'])
    na_changed = update_parameter('north_angle', si['NorthAngle'])
    nos_changed = update_parameter('number_of_states', $solar_integration.configuration.sun_states)
    ghi_changed = update_parameter('ghi', $solar_integration.configuration.global_horizontal_irradiation)
    
    update_sun_transformation
    # recalculate or load sun states
    sun_states_change = nos_changed or la_changed or lo_changed or na_changed
    if sun_states_change or not load_states
      update_sun_states
    end
    # recalculate or load contribution per state
    if sun_states_change or ghi_changed
      update_contribution_per_state
    elsif not @contribution_per_state
      @contribution_per_state = get_from_model('contribution_per_state')
    end
  end
  
  def load_states
    if not @states
      begin
        data = get_from_model('states')
        @states = data.collect{|d| SunState.new(d[0], d[1], @sun_transformation)}
      rescue
        puts "exception while loading sun states, data is:\n" + data.to_s
        return false
      end
    end
    return true
  end
  
  def update_parameter(name, value)
    instance_variable_set('@' + name, value)
    old_value = get_from_model(name)
    save_to_model(name, value)
    return (old_value and old_value!=value)
  end
  
  def update_sun_transformation
    # sun_transformation transforms solar north to z axis
    # in that coordinate system the suns inclination lies between +-ECLIPTIC_ANGLE
    sun_angle = to_radian(90 - @latitude)
    north_angle = to_radian(@north_angle)
    @sun_transformation = Geom::Transformation.rotation(ORIGIN, X_AXIS, sun_angle) \
                        * Geom::Transformation.rotation(ORIGIN, Z_AXIS, north_angle)
  end
  
  def update_sun_states
    # randomly selects sun states, choosing e.g. a state every full hour for each
    # day is very bad sampling (small differences between days, large differences
    # between hours).
    @states = Array.new
    si = Sketchup.active_model.shadow_info
    
    t_old = si['ShadowTime']

    seconds_per_year = 365 * 24 * 60 * 60
    while @states.length < @number_of_states
      t = Time.at(rand(seconds_per_year))
      si['ShadowTime'] = t
      local_vector = si['SunDirection']
      # only interested in day time sun states
      if local_vector[2]>0
        @states.push SunState.new(local_vector,t, @sun_transformation)
      end
    end
      
    si['ShadowTime'] = t_old # restore initial time
  
    save_to_model('states', @states.collect{|s|[s.local_vector, s.time]})
  end
  
  def update_contribution_per_state
    total_z_component = 0
    for state in @states
      z_component = (state.local_vector)%Z_AXIS
      if z_component > 0
        total_z_component += z_component
      end
    end
    
    # how much one state contributes to the yearly average
    @contribution_per_state = @ghi / total_z_component
    save_to_model('contribution_per_state', @contribution_per_state)
  end
  
  def get_from_model(name)
    return Sketchup.active_model.get_attribute 'solar_integration', 'sun_data.' + name
  end
  
  def save_to_model(name, value)
    Sketchup.active_model.set_attribute 'solar_integration', 'sun_data.' + name, value
  end
end

class SunState
  attr_reader :vector, :duration, :local_vector, :time
  def initialize(local_vector, time, sun_transformation)
    @local_vector = local_vector
    @vector = local_vector.transform(sun_transformation)
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