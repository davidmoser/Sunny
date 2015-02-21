require 'solar_integration/flat_bounding_box.rb'

# a grid is the splitting of a face into small @squares
# all the small squares have the common @normal and @area
class Grid
  attr_reader :squares, :normal, :area
  
  def initialize(face, grid_length)
    @face = face
    @grid_length = grid_length
    
    @group = Sketchup.active_model.entities.add_group
    
    bounding_box = attach_flat_bounding_box(face)
    
    v1 = bounding_box[1] - bounding_box[0]
    v2 = bounding_box[3] - bounding_box[0]
    l1 = v1.length / grid_length
    l2 = v2.length / grid_length
    @side1 = v1.normalize.transform(grid_length)
    @side2 = v2.normalize.transform(grid_length)
    # a cross product is a 2-form, doesn't have unit length, but area.
    # might be a problem depending on how unit conversion works ... keep an eye on it.
    @normal = @side1 * @side2
    @area = @normal.length
    @normal.normalize!
    base = bounding_box[0]
    
    progress_bar = ProgressBar.new(l1.floor*l2.floor, 'Creating squares...')
    @squares = []
    (0..l1).each do |i|
      (0..l2).each do |j|
        center = base + Geom::Vector3d.linear_combination(i+0.5,@side1,j+0.5,@side2)
        if face.classify_point(center) == 1
          # lift by 1cm so not to intersect with original face
          @squares.push Square.new(@group, center + @normal, @side1, @side2)
          progress_bar.update(i*l2.floor + j)
        end
      end
    end
  end  
end

# a square has a @center, @irradiance information and the reference
# to its visual representation @face
class Square
  attr_reader :center
  attr_accessor :irradiance, :color_bar, :face
  
  def initialize(group, center, side1, side2)
    @center = center
    corner = center + Geom::Vector3d.linear_combination(-0.5,side1,-0.5,side2)
    @face = group.entities.add_face([corner, corner+side1, corner+side1+side2, corner+side2])
    @face.edges.each{|e|e.hidden=true}
  end
  
  def color_bar=(color_bar)
    @color_bar = color_bar
    update_color
  end
  
  def update_color
    @face.material = @color_bar.to_color(@irradiance)
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