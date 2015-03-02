require 'solar_integration/flat_bounding_box.rb'

# a grid is the splitting of a face into small @squares
# all the small squares have the common @normal and @area
class Grid
  attr_reader :normal, :area, :side1, :side2, :face
  attr_reader :squares, :sub_divisions, :subside1, :subside2, :number_of_subsquares
  
  def initialize(face, grid_length, sub_divisions)
    @face = face
    @grid_length = grid_length
    @sub_divisions = sub_divisions
    
    bounding_box = calculate_flat_bounding_box(face)
    
    v1 = bounding_box[1] - bounding_box[0]
    v2 = bounding_box[3] - bounding_box[0]
    l1 = v1.length / grid_length
    l2 = v2.length / grid_length
    @side1 = v1.normalize.transform(grid_length)
    @side2 = v2.normalize.transform(grid_length)
    @subside1 = @side1.transform(1.0/@sub_divisions)
    @subside2 = @side2.transform(1.0/@sub_divisions)
    
    # the cross product has the wrong units, it's length but should be area.
    # might be a problem depending on how unit conversion works ... keep an eye on it.
    @normal = @side1 * @side2
    @area = @normal.length
    @normal.normalize!
    base = bounding_box[0]
    
    @squares = []
    @number_of_subsquares = 0
    (0..l1).each do |i|
      (0..l2).each do |j|
        center = base + Geom::Vector3d.linear_combination(i+0.5,@side1,j+0.5,@side2)
        square = Square.new(self, center)
        if square.points.length>0
          @squares.push square
          @number_of_subsquares += square.points.length
        end
      end
    end
  end  
end

class Square
  attr_reader :center, :points
  
  def initialize(grid, center)
    @center = center
    @points = []
    corner = center + Geom::Vector3d.linear_combination(-0.5 * (grid.sub_divisions-1),grid.subside1,-0.5 * (grid.sub_divisions-1),grid.subside2)
    (0..grid.sub_divisions).each do |i|
      (0..grid.sub_divisions).each do |j|
        point = corner + Geom::Vector3d.linear_combination(i,grid.subside1,j,grid.subside2)
        if grid.face.classify_point(point) == 1
          @points.push point + grid.normal
        end
      end
    end
  end
end