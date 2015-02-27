require 'solar_integration/progress.rb'

class DataCollector
  attr_writer :current_point
  
  def initialize(grid)
    # implement this
  end
  
  def put(sun_state, irradiance)
    # implement this
  end
  
  def wrapup
    # implement this
  end
end

class TotalIrradianceSquares < DataCollector
  def initialize(grid)
    @group = Sketchup.active_model.entities.add_group
    
    progress = Progress.new(grid.points.length, 'Creating squares...')
    @squares = Hash.new
    grid.points.each do |p|
      # lift by 1cm so not to intersect with original face
      @squares[p] = Square.new(@group, p + grid.normal, grid.side1, grid.side2)
      progress.work
    end
  end
  
  def put(sun_state, irradiance)
    return if not irradiance
    @squares[@current_point].irradiance += irradiance
  end
  
  def wrapup
    minmax = @squares.values.collect{|s| s.irradiance}.minmax
    color_bar = ColorBar.new(*minmax)
    progress = Progress.new(@squares.length, 'Coloring squares...')
    @squares.values.each do |s|
      s.face.material=color_bar.to_color(s.irradiance)
      progress.work
    end
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
    @bin_size = Math::PI / 360
  end
  
  def put(sun_state, irradiance)
    return if not irradiance
    v = sun_state.vector
    rho = Math::hypot(v[0], v[1])
    polar_angle = Math::atan2(rho, v[2])
    bin = (polar_angle / @bin_size).floor * @bin_size * 360 / (2 * Math::PI)
    @histogram[bin] += irradiance
  end
  
  def wrapup
    @histogram = @histogram.sort_by { |a,i| a }
    File.open('polar_angle_histogram.txt', 'w') do |file|
      @histogram.each { |a,i| file.write("#{a},#{i}\n") }
    end
  end
end