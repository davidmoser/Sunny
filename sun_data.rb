require 'solar_integration/progress.rb'

# information about all the sun paths, irradiances etc.
class SunData
  attr_reader :states, :wh_per_m2
  
  def initialize
    @states = Array.new
    day_interval = 10
    minute_interval = 10
    tsi = 700 # W/m^2
    
    hours_per_state = Float(day_interval * minute_interval) / 60
    @wh_per_m2 = hours_per_state * tsi
    
    # initialize states
    # TODO: don't use Sketchup, it's slow (ui feedback)
    # TODO: determine local tsi (atmospheric thickness, cloud cover, etc.)
    si = Sketchup.active_model.shadow_info
    t_old = si['ShadowTime']
    
    (1..365).step(day_interval).each do |day|
      (0..(24*60)).step(minute_interval).each do |minute|
        t = Time.at(day * 24 * 60 * 60 + minute * 60)
        si['ShadowTime'] = t
        @states.push SunState.new(si['SunDirection'],t, 1)
      end
    end

    si['ShadowTime'] = t_old # restore initial time
    
    @states.select! {|s| s.local_vector[2]>0}
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
  def initialize(entities, center)
    sun_data = SunData.new
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