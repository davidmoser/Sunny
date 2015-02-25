require 'solar_integration/flat_bounding_box.rb'

# a grid is the splitting of a face into small @squares
# all the small squares have the common @normal and @area
class Grid
  attr_reader :points, :normal, :area, :side1, :side2
  
  def initialize(face, grid_length)
    @face = face
    @grid_length = grid_length
    
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
    
    @points = []
    (0..l1).each do |i|
      (0..l2).each do |j|
        point = base + Geom::Vector3d.linear_combination(i+0.5,@side1,j+0.5,@side2)
        if face.classify_point(point) == 1
          @points.push point
        end
      end
    end
  end  
end
