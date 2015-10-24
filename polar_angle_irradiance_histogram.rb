require 'solar_integration/data_collector.rb'

class PolarAngleIrradianceHistogram < DataCollector
  def initialize(grid)
    @histogram = Hash.new(0)
    @bin_size = to_radian(1)
  end

  def put(sun_state, irradiance)
    return if not irradiance
    v = sun_state.vector
    rho = Math::hypot(v[0], v[1])
    polar_angle = Math::atan2(rho, v[2])
    bin = to_degree((polar_angle / @bin_size).floor * @bin_size)
    @histogram[bin] += irradiance
  end

  def wrapup
    @histogram = @histogram.sort_by { |a, i| a }
    File.open('polar_angle_histogram.txt', 'w') do |file|
      @histogram.each { |a, i| file.write("#{a},#{i}\n") }
    end
  end
end