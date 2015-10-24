require 'solar_integration/bounding_rectangle.rb'
require 'solar_integration/globals.rb'
require 'solar_integration/square.rb'

# a grid is the splitting of a face into small @squares
# all the small squares have the common @normal, length of the normal is the
# area of a square in m^2
class Grid
  include BoundingRectangle

  attr_reader :squares, :number_of_subsquares, :side1, :side2, :face, :normal
  attr_reader :subdivisions, :subside1, :subside2, :square_length, :tile_area, :total_area

  def initialize(face, configuration)
    @face = face
    @normal = face.normal
    @tile_length = configuration.tile_length
    @tile_area = @tile_length * @tile_length

    bounding_rectangle = calculate_bounding_rectangle(face)
    v1 = bounding_rectangle[1] - bounding_rectangle[0]
    v2 = bounding_rectangle[3] - bounding_rectangle[0]
    if configuration.assume_faces_up and @normal % Z_AXIS < -0.01
      @normal = @normal.reverse
      v1, v2 = v2, v1
    end

    if configuration.infer_square_length_from_face
      @square_length = [v1.length, v2.length].min
    else
      @square_length = configuration.square_length
    end
    @subdivisions = (@square_length.to_f / @tile_length).ceil
    @square_length = @subdivisions * @tile_length

    l1 = v1.length / @square_length.m
    l2 = v2.length / @square_length.m
    @side1 = v1.normalize.transform(@square_length.m)
    @side2 = v2.normalize.transform(@square_length.m)
    @subside1 = @side1.transform(1.0/@subdivisions)
    @subside2 = @side2.transform(1.0/@subdivisions)

    base = bounding_rectangle[0]

    @squares = []
    @number_of_subsquares = 0
    (0..l1).each do |i|
      (0..l2).each do |j|
        center = base + Geom::Vector3d.linear_combination(i+0.5, @side1, j+0.5, @side2)
        square = Square.new(self, center)
        if square.points.length>0
          @squares.push square
          @number_of_subsquares += square.points.length
        end
      end
    end

    @total_area = @number_of_subsquares * @tile_area
  end

  def initialize_clone(source)
    super
    @normal = source.normal.clone
    @side1 = source.side1.clone
    @side2 = source.side2.clone
    @subside1 = source.subside1.clone
    @subside2 = source.subside2.clone
    @squares = source.squares.collect { |s| s.clone }
  end

  def transform(transformation)
    c = clone
    c.transform!(transformation)
    return c
  end

  def transform!(transformation)
    [@normal, @side1, @side2, @subside1, @subside2].concat(@squares)
        .each { |s| s.transform!(transformation) }
  end
end
