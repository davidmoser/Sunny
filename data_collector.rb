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

class TotalIrradianceCollector < DataCollector
  def initialize(grid)
    @group = Sketchup.active_model.entities.add_group
    
    progress_bar = ProgressBar.new(grid.points.length, 'Creating squares...')
    @squares = Hash.new
    grid.points.each do |p|
      # lift by 1cm so not to intersect with original face
      @squares[p] = Square.new(@group, p + grid.normal, grid.side1, grid.side2)
      progress_bar.update(grid.points.find_index(p))
    end
  end
  
  def put(sun_state, irradiance)
    return if not irradiance
    @squares[@current_point].irradiance += irradiance
  end
  
  def wrapup
    minmax = @squares.values.collect{|s| s.irradiance}.minmax
    color_bar = ColorBar.new(*minmax)
    @squares.values.each {|s| s.face.material=color_bar.to_color(s.irradiance) }
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