require 'solar_integration/progress.rb'

# information about all the sun paths, irradiances etc.
class SunData
  attr_reader :states
  #@tsis = [500, 700, 1000, 700, 500] # total solar irradiation arriving at ground from the direction of the sun w/m^2
  
  def initialize
    @states = Array.new
    @day_times = 1..23
    # initialize states
    # only using single time for now
    si = Sketchup.active_model.shadow_info
    t_old = si['ShadowTime']
    
#    t = Time.new(2014)
#    t_end = Time.new(2015)
#    while t<t_end
#      si['ShadowTime'] = t
#      @states.push SunState.new(si['SunDirection'],t, 1)
#      t += 60 * 60
#    end
    
    (1..12).each do |month|
      (1..23).each do |hour|
        t = Time.new(2014, month, 01, hour)
        si['ShadowTime'] = t
        @states.push SunState.new(si['SunDirection'],t, 1)
      end
    end
    
    si['ShadowTime'] = t_old # restore initial time
    # generate states for times
    # initialize vectors given location on earth and time
    # initialize tsi (atmospheric thickness, cloud cover, etc.)
  end
end

class SunState
  attr_reader :vector, :time, :tsi
  def initialize(vector, time, tsi)
    @vector = vector
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
      p_new = center + s.vector.transform(@radius)
      @group.entities.add_edges(p_old, p_new)
      p_old = p_new
      progress.work
    end
    Sketchup.active_model.commit_operation
  end
end