require 'solar_integration/progress.rb'
require 'solar_integration/angle_conversion.rb'

class DataCollector
  attr_writer :current_point
  
  def initialize(grid)
    raise 'need to implement'
  end
  
  def put(sun_state, irradiance)
    raise 'need to implement'
  end
  
  def wrapup
    raise 'need to implement'
  end
end

class TotalIrradianceSquares < DataCollector
  def initialize(grid)
    @group = grid.face.parent.entities.add_group
    
    progress = Progress.new(grid.points.length, 'Creating squares...')
    Sketchup.active_model.start_operation('Creating squares', true)
    @squares = Hash.new
    grid.points.each do |p|
      @squares[p] = Square.new(@group, p, grid.side1, grid.side2)
      progress.work
    end
    Sketchup.active_model.commit_operation
  end
  
  def put(sun_state, irradiance)
    return if not irradiance
    @squares[@current_point].irradiance += irradiance
  end
  
  def wrapup
    minmax = @squares.values.collect{|s| s.irradiance}.minmax
    color_bar = ColorBar.new(*minmax)
    progress = Progress.new(@squares.length, 'Coloring squares...')
    Sketchup.active_model.start_operation('Coloring squares', true)
    @squares.values.each do |s|
      s.face.material=color_bar.to_color(s.irradiance)
      s.face.set_attribute 'solar_integration', 'total_irradiance', s.irradiance
      progress.work
    end
    Sketchup.active_model.commit_operation
  end
end

# a square has a @center, @irradiance information and the reference
# to its visual representation @face
class Square
  attr_accessor :irradiance, :face
  
  def initialize(group, center, side1, side2)
    @irradiance = 0
    @center = center
    corner = center + Geom::Vector3d.linear_combination(-0.5,side1,-0.5,side2)
    @face = group.entities.add_face([corner, corner+side1, corner+side1+side2, corner+side2])
    @face.edges.each{|e|e.hidden=true}
  end
end

class ColorBar
  def initialize(min, max)
    @min = min
    @max = max
  end
  def to_color(number)
    return [(number-@min) / (@max-@min), 0, 0]
  end
end

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
    @histogram = @histogram.sort_by { |a,i| a }
    File.open('polar_angle_histogram.txt', 'w') do |file|
      @histogram.each { |a,i| file.write("#{a},#{i}\n") }
    end
  end
end