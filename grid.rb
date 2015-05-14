require 'solar_integration/flat_bounding_box.rb'
require 'solar_integration/globals.rb'

# a grid is the splitting of a face into small @squares
# all the small squares have the common @normal, length of the normal is the
# area of a square in m^2
class Grid
  include FlatBoundingBox
  
  attr_reader :squares, :number_of_subsquares, :side1, :side2, :face, :normal
  attr_reader :subdivisions, :subside1, :subside2, :square_length
  
  def initialize(face)
    @face = face
    @normal = face.normal
    @tile_length = $configuration.tile_length
    
    bounding_box = calculate_flat_bounding_box(face)
    v1 = bounding_box[1] - bounding_box[0]
    v2 = bounding_box[3] - bounding_box[0]
    
    if $configuration.infer_square_length_from_face
      @square_length = [v1.length, v2.length].min
    else
      @square_length = $configuration.square_length
    end
    @subdivisions = (@square_length.to_f / @tile_length).ceil
    @square_length = @subdivisions * @tile_length
    
    l1 = v1.length / @square_length.m
    l2 = v2.length / @square_length.m
    @side1 = v1.normalize.transform(@square_length.m)
    @side2 = v2.normalize.transform(@square_length.m)
    @subside1 = @side1.transform(1.0/@subdivisions)
    @subside2 = @side2.transform(1.0/@subdivisions)
    
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
    corner = center + Geom::Vector3d.linear_combination(-0.5 * (grid.subdivisions-1),grid.subside1,-0.5 * (grid.subdivisions-1),grid.subside2)
    (0..grid.subdivisions).each do |i|
      (0..grid.subdivisions).each do |j|
        point = corner + Geom::Vector3d.linear_combination(i,grid.subside1,j,grid.subside2)
        if grid.face.classify_point(point) == 1
          @points.push point + grid.normal
        end
      end
    end
  end
end