class Square
  attr_reader :center, :points

  def initialize(grid, center)
    @center = center
    @points = []
    corner = center + Geom::Vector3d.linear_combination(-0.5 * (grid.subdivisions-1), grid.subside1, -0.5 * (grid.subdivisions-1), grid.subside2)
    (0..grid.subdivisions).each do |i|
      (0..grid.subdivisions).each do |j|
        point = corner + Geom::Vector3d.linear_combination(i, grid.subside1, j, grid.subside2)
        if grid.face.classify_point(point) == 1
          @points.push point + grid.normal
        end
      end
    end
  end

  def initialize_clone(source)
    super
    @center = source.center.clone
    @points = source.points.collect { |p| p.clone }
  end

  def transform(transformation)
    c = clone
    c.transform!(transformation)
    return c
  end

  def transform!(transformation)
    [@center].concat(@points).each { |p| p.transform!(transformation) }
  end
end